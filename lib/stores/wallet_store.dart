// lib/stores/wallet_store.dart
import 'dart:async';
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
  static const _refreshInterval = Duration(seconds: 20);

  List<LocalWallet> _wallets = [];
  String? _activeWalletId;
  bool _loading = false;
  Timer? _balanceTimer;

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

// Add this method to WalletStore class (lib/stores/wallet_store.dart)

  /// 🆕 Get all chain balances for a specific chain
  List<ChainBalance>? getChainWallets(String chain) {
    final wallet = activeWallet;
    if (wallet == null) return null;

    final chainUpper = chain.toUpperCase();
    return wallet.chains
        .where((c) => (c.chain ?? '').toUpperCase() == chainUpper)
        .toList();
  }

  /// 🆕 Get chain balance by address or symbol
  ChainBalance? getChainByAddress(String chain, String address) {
    final wallet = activeWallet;
    if (wallet == null) return null;

    final chainUpper = chain.toUpperCase();
    try {
      return wallet.chains.firstWhere(
        (c) =>
            (c.chain ?? '').toUpperCase() == chainUpper && c.address == address,
      );
    } catch (_) {
      return null;
    }
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
        _stopBalanceTimer();
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
        _stopBalanceTimer();
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

  // ---------------- Auto Refresh Balances ----------------

  // void _startBalanceTimer() {
  //   _stopBalanceTimer(); // cancel any existing timer
  //   if (_activeWalletId == null) return;

  //   _balanceTimer = Timer.periodic(_refreshInterval, (_) async {
  //     await _refreshBalances();
  //   });

  //   debugPrint('🔁 Started balance refresh timer (20s)');
  // }

  void _stopBalanceTimer() {
    _balanceTimer?.cancel();
    _balanceTimer = null;
    debugPrint('🛑 Balance refresh timer stopped');
  }

  // Future<void> _refreshBalances() async {
  //   final id = _activeWalletId;
  //   if (id == null) return;

  //   try {
  //     debugPrint('⏳ Refreshing balances for wallet $id...');
  //     final payload = await AuthService.fetchBalancesAndTotal(walletId: id);

  //     final idx = _wallets.indexWhere((w) => w.id == id);
  //     if (idx != -1) {
  //       final updated = _wallets[idx].copyWith(chains: payload.rows);
  //       _wallets = List.from(_wallets)..[idx] = updated;
  //       notifyListeners();
  //       debugPrint('💰 Updated balances (total USD: ${payload.totalUsd})');
  //     }
  //   } catch (e) {
  //     debugPrint('⚠️ Failed to refresh balances: $e');
  //   }
  // }

  // ---------------- Active Wallet ----------------

  Future<void> _persistActive(String id) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_spActiveId, id);
  }

  Future<void> setActive(String id) async {
    if (_activeWalletId == id) return;
    _activeWalletId = id;
    await _persistActive(id);
    // restart timer for new wallet
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

  // ---------------- Cleanup ----------------

  @override
  void dispose() {
    _stopBalanceTimer();
    super.dispose();
  }
}
