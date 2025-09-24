// lib/stores/wallet_store.dart
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cryptowallet/services/wallet_flow.dart';
import 'package:cryptowallet/services/api_service.dart';

class LocalWallet {
  final String id;
  final String name;
  final String primaryAddress;
  final DateTime createdAt;

  LocalWallet({
    required this.id,
    required this.name,
    required this.primaryAddress,
    required this.createdAt,
  });

  LocalWallet copyWith({
    String? id,
    String? name,
    String? primaryAddress,
    DateTime? createdAt,
  }) {
    return LocalWallet(
      id: id ?? this.id,
      name: name ?? this.name,
      primaryAddress: primaryAddress ?? this.primaryAddress,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

class WalletStore extends ChangeNotifier {
  static const _spActiveId = 'active_wallet_id';

  List<LocalWallet> _wallets = <LocalWallet>[];
  String? _activeWalletId;

  List<LocalWallet> get wallets => _wallets;
  String? get activeWalletId => _activeWalletId;
  String? get activeWalletName => activeWallet?.name;

  LocalWallet? get activeWallet {
    if (_wallets.isEmpty) return null;
    if (_activeWalletId == null) return _wallets.first;
    final idx = _wallets.indexWhere((w) => w.id == _activeWalletId);
    return idx == -1 ? _wallets.first : _wallets[idx];
  }

  bool get hasWallets => _wallets.isNotEmpty;

  LocalWallet? findById(String id) {
    final i = _wallets.indexWhere((w) => w.id == id);
    return i == -1 ? null : _wallets[i];
  }

  Future<void> hydrate() async {
    final prefs = await SharedPreferences.getInstance();
    final savedId = prefs.getString(_spActiveId);

    _wallets = await WalletFlow.loadLocalWallets();

    if (_wallets.isEmpty) {
      _activeWalletId = null;
    } else if (savedId != null && _wallets.any((w) => w.id == savedId)) {
      _activeWalletId = savedId;
    } else {
      _activeWalletId = _wallets.first.id;
      await _persistActive(_activeWalletId!);
    }
    notifyListeners();
  }

  Future<void> reloadFromLocal() async {
    _wallets = await WalletFlow.loadLocalWallets();
    notifyListeners();
  }

  Future<void> reloadFromLocalAndActivate(String? preferId) async {
    await reloadFromLocal();
    if (_wallets.isEmpty) {
      _activeWalletId = null;
      notifyListeners();
      return;
    }
    if (preferId != null && _wallets.any((w) => w.id == preferId)) {
      _activeWalletId = preferId;
    } else {
      _activeWalletId ??= _wallets.first.id;
    }
    if (_activeWalletId != null) await _persistActive(_activeWalletId!);
    notifyListeners();
  }

  Future<void> _persistActive(String id) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_spActiveId, id);
  }

  Future<void> setActive(String id) async {
    if (_activeWalletId == id) return;
    _activeWalletId = id;
    await _persistActive(id);
    notifyListeners();
  }

  String nextAvailableName({String base = 'My Wallet'}) {
    final names = _wallets.map((w) => w.name.trim()).toSet();
    if (!names.contains(base)) return base;
    for (int i = 1;; i++) {
      final candidate = '$base $i';
      if (!names.contains(candidate)) return candidate;
    }
  }

  Future<LocalWallet> createAndSendToBackend(
      {String baseName = 'My Wallet'}) async {
    _wallets = await WalletFlow.loadLocalWallets();
    final name = nextAvailableName(base: baseName);
    final newW = await WalletFlow.createNewWallet(name: name);
    await reloadFromLocalAndActivate(newW.id);
    return newW;
  }

  // ---------- rename (local + backend) ----------

  Future<void> renameWalletLocally({
    required String walletId,
    required String newName,
  }) async {
    final idx = _wallets.indexWhere((w) => w.id == walletId);
    if (idx == -1) return;

    // ✅ fix: use _wallets (not "llets")
    final updated = _wallets[idx].copyWith(name: newName.trim());
    _wallets = List<LocalWallet>.from(_wallets)..[idx] = updated;

    // Optional: if you add a local persistence method, uncomment:
    // await WalletFlow.renameLocalWallet(walletId: walletId, newName: newName.trim());

    notifyListeners();
  }

  Future<void> renameWalletOnBackend({
    required String walletId,
    required String newName,
  }) async {
    final name = newName.trim();
    if (name.isEmpty) {
      throw const ApiException('walletName is required');
    }

    await AuthService.updateWalletName(walletId: walletId, walletName: name);
    await renameWalletLocally(walletId: walletId, newName: name);

    if (_activeWalletId == walletId) {
      await _persistActive(walletId);
    }
  }
}
