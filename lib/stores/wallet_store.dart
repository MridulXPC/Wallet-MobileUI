import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cryptowallet/services/wallet_flow.dart';

/// If you already have this model, keep yours.
/// Only requirement: id, name, primaryAddress, createdAt.
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
}

class WalletStore extends ChangeNotifier {
  static const _spActiveId = 'active_wallet_id';

  List<LocalWallet> _wallets = [];
  String? _activeWalletId;

  List<LocalWallet> get wallets => _wallets;
  String? get activeWalletId => _activeWalletId;
  LocalWallet? get activeWallet =>
      _wallets.firstWhere((w) => w.id == _activeWalletId,
          orElse: () =>
              _wallets.isNotEmpty ? _wallets.first : (null as LocalWallet));

  // ---------- hydrate / reload ----------

  Future<void> hydrate() async {
    final prefs = await SharedPreferences.getInstance();
    final savedId = prefs.getString(_spActiveId);

    _wallets = await WalletFlow.loadLocalWallets();

    // pick active:
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
    if (_wallets.isEmpty) return;

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

  // ---------- auto-naming ----------

  /// Returns next available name: "My Wallet", "My Wallet 1", "My Wallet 2", …
  String nextAvailableName({String base = 'My Wallet'}) {
    final names = _wallets.map((w) => w.name.trim()).toSet();
    if (!names.contains(base)) return base;

    // find smallest N not used for "base N"
    for (int i = 1;; i++) {
      final candidate = '$base $i';
      if (!names.contains(candidate)) return candidate;
    }
  }

  // ---------- create new wallet (auto-named) ----------

  Future<LocalWallet> createAndSendToBackend(
      {String baseName = 'My Wallet'}) async {
    // ensure latest list to calculate name
    _wallets = await WalletFlow.loadLocalWallets();
    final name = nextAvailableName(base: baseName);

    final newW = await WalletFlow.createNewWallet(
        name: name); // calls backend + saves locally
    // refresh & activate the new one
    await reloadFromLocalAndActivate(newW.id);
    return newW;
  }
}
