// lib/stores/wallet_store.dart
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cryptowallet/services/api_service.dart';

class LocalWallet {
  final String id;
  final String name;
  final String primaryAddress;
  final DateTime createdAt;
  final List<ChainBalance> chains;

  LocalWallet({
    required this.id,
    required this.name,
    required this.primaryAddress,
    required this.createdAt,
    required this.chains,
  });

  LocalWallet copyWith({
    String? id,
    String? name,
    String? primaryAddress,
    DateTime? createdAt,
    List<ChainBalance>? chains,
  }) {
    return LocalWallet(
      id: id ?? this.id,
      name: name ?? this.name,
      primaryAddress: primaryAddress ?? this.primaryAddress,
      createdAt: createdAt ?? this.createdAt,
      chains: chains ?? this.chains,
    );
  }
}

class WalletStore extends ChangeNotifier {
  static const _spActiveId = 'active_wallet_id';

  List<LocalWallet> _wallets = [];
  String? _activeWalletId;
  bool _loading = false;

  // ---- Getters ----
  List<LocalWallet> get wallets => _wallets;
  String? get activeWalletId => _activeWalletId;
  bool get hasWallets => _wallets.isNotEmpty;
  bool get isLoading => _loading;

  LocalWallet? get activeWallet {
    if (_wallets.isEmpty) return null;
    if (_activeWalletId == null) return _wallets.first;
    return _wallets.firstWhere(
      (w) => w.id == _activeWalletId,
      orElse: () => _wallets.first,
    );
  }

  // ---------------- Hydration ----------------

  Future<void> hydrateFromBackend({required String walletId}) async {
    try {
      _loading = true;
      notifyListeners();

      final prefs = await SharedPreferences.getInstance();
      final savedId = prefs.getString(_spActiveId);

      debugPrint('🌐 Fetching wallets for user... ($walletId)');
      final chains = await AuthService.fetchWalletsForUser(walletId: walletId);

      if (chains.isEmpty) {
        debugPrint('⚠️ No chains returned from backend for $walletId');
        _wallets = [];
        _activeWalletId = null;
        _loading = false;
        notifyListeners();
        return;
      }

      final wallet = LocalWallet(
        id: walletId,
        name: 'Wallet',
        primaryAddress: chains.first.address,
        createdAt: DateTime.now(),
        chains: chains,
      );

      _wallets = [wallet];

      if (savedId != null && _wallets.any((w) => w.id == savedId)) {
        _activeWalletId = savedId;
      } else {
        _activeWalletId = _wallets.first.id;
        await _persistActive(_activeWalletId!);
      }

      debugPrint('✅ Hydrated WalletStore: ${_wallets.length} wallet(s) loaded');

      _loading = false;
      notifyListeners();
    } catch (e, st) {
      _loading = false;
      debugPrint('❌ hydrateFromBackend failed: $e\n$st');
      rethrow;
    }
  }

  Future<void> reloadFromBackend({required String walletId}) async {
    await hydrateFromBackend(walletId: walletId);
  }

  /// 🆕 Load wallets automatically (using saved wallet_id)
  Future<void> loadWalletsFromBackend() async {
    try {
      _loading = true;
      notifyListeners();

      final prefs = await SharedPreferences.getInstance();
      final walletId = prefs.getString('wallet_id');

      if (walletId == null || walletId.isEmpty) {
        debugPrint('⚠️ No wallet_id found in SharedPreferences');
        _wallets = [];
        _activeWalletId = null;
        _loading = false;
        notifyListeners();
        return;
      }

      await hydrateFromBackend(walletId: walletId);
      debugPrint('✅ WalletStore successfully refreshed from backend');
    } catch (e, st) {
      _loading = false;
      debugPrint('❌ loadWalletsFromBackend failed: $e\n$st');
      notifyListeners();
    }
  }

  // ---------------- Active Wallet ----------------

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

  // ---------------- Rename Wallet ----------------

  Future<void> renameWalletLocally({
    required String walletId,
    required String newName,
  }) async {
    final idx = _wallets.indexWhere((w) => w.id == walletId);
    if (idx == -1) return;
    final updated = _wallets[idx].copyWith(name: newName.trim());
    _wallets = List.from(_wallets)..[idx] = updated;
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

  // ---------------- Utility ----------------

  LocalWallet? findById(String id) {
    if (_wallets.isEmpty) return null;
    return _wallets.firstWhere(
      (w) => w.id == id,
      orElse: () => _wallets.first,
    );
  }

  String nextAvailableName({String base = 'My Wallet'}) {
    final names = _wallets.map((w) => w.name.trim()).toSet();
    if (!names.contains(base)) return base;
    for (int i = 1;; i++) {
      final candidate = '$base $i';
      if (!names.contains(candidate)) return candidate;
    }
  }
}
