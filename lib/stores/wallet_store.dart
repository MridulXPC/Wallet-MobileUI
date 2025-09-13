// lib/stores/wallet_store.dart
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cryptowallet/services/wallet_flow.dart';

/// Minimal local wallet model used by WalletStore.
/// If you already have a model, keep yours — just ensure these fields exist.
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

  // Optional: helpers for (de)serialization if needed later
  factory LocalWallet.fromJson(Map<String, dynamic> json) => LocalWallet(
        id: json['id'] as String,
        name: json['name'] as String,
        primaryAddress: json['primaryAddress'] as String,
        createdAt: DateTime.parse(json['createdAt'] as String),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'primaryAddress': primaryAddress,
        'createdAt': createdAt.toIso8601String(),
      };
}

class WalletStore extends ChangeNotifier {
  static const _spActiveId = 'active_wallet_id';

  List<LocalWallet> _wallets = <LocalWallet>[];
  String? _activeWalletId;

  /// Read-only list of wallets
  List<LocalWallet> get wallets => _wallets;

  /// Currently active wallet id (may be null if none yet)
  String? get activeWalletId => _activeWalletId;

  /// The active wallet object, or:
  /// - first wallet if active id not set,
  /// - null if there are no wallets.
  LocalWallet? get activeWallet {
    if (_wallets.isEmpty) return null;
    if (_activeWalletId == null) return _wallets.first;
    final idx = _wallets.indexWhere((w) => w.id == _activeWalletId);
    return idx == -1 ? _wallets.first : _wallets[idx];
  }

  /// Convenience flags/helpers
  bool get hasWallets => _wallets.isNotEmpty;

  LocalWallet? findById(String id) {
    final i = _wallets.indexWhere((w) => w.id == id);
    return i == -1 ? null : _wallets[i];
  }

  // ---------- hydrate / reload ----------

  /// Loads wallets from local storage (via WalletFlow) and restores last active.
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

  /// Reloads the wallets list from local storage (no active change).
  Future<void> reloadFromLocal() async {
    _wallets = await WalletFlow.loadLocalWallets();
    notifyListeners();
  }

  /// Reloads from local and activates `preferId` if present; otherwise keeps current or first.
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

  /// Sets the active wallet id and persists it.
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

  /// Creates a new wallet via WalletFlow, saves locally, and activates it.
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
