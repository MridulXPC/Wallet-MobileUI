// lib/stores/portfolio_store.dart
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cryptowallet/services/api_service.dart';
import 'package:cryptowallet/models/token_model.dart'; // ✅ use your existing VaultToken model

/// 🔹 App-level model (PortfolioToken)
class PortfolioToken {
  final String id;
  final String name;
  final String symbol;
  final String chain;
  final String iconUrl;
  final double balance;
  final double value;

  const PortfolioToken({
    required this.id,
    required this.name,
    required this.symbol,
    required this.chain,
    required this.iconUrl,
    required this.balance,
    required this.value,
  });
  factory PortfolioToken.fromVault(VaultToken v) {
    return PortfolioToken(
      id: v.id ?? '',
      name: v.name,
      symbol: v.symbol,
      chain: v.chain,
      iconUrl: v.iconUrl,
      balance: double.tryParse(v.balance) ?? 0.0,
      value: v.value,
    );
  }
}

/// 🔹 Global portfolio store with caching + auto-refresh
class PortfolioStore extends ChangeNotifier {
  bool loading = false;
  String? error;
  List<PortfolioToken> tokens = [];
  double totalUsd = 0.0;

  DateTime? _lastFetched;
  Timer? _autoRefreshTimer;

  static const Duration cacheDuration = Duration(minutes: 2);
  static const Duration autoRefreshInterval = Duration(seconds: 60);

  /// Fetch portfolio for a wallet
  Future<void> fetchPortfolio(String walletId,
      {bool forceRefresh = false}) async {
    if (!forceRefresh &&
        _lastFetched != null &&
        DateTime.now().difference(_lastFetched!) < cacheDuration &&
        tokens.isNotEmpty) {
      debugPrint('🟢 Using cached portfolio');
      return;
    }

    loading = true;
    error = null;
    notifyListeners();

    try {
      // ✅ using VaultToken from token_model.dart
      final List<VaultToken> vaultTokens =
          await AuthService.fetchTokensByWallet(walletId: walletId);

      tokens = vaultTokens
          .map((v) => PortfolioToken.fromVault(v))
          .toList(growable: false);

      totalUsd = tokens.fold(0.0, (sum, t) => sum + t.value);
      _lastFetched = DateTime.now();
      debugPrint('✅ Portfolio loaded (${tokens.length} tokens)');
    } on ApiException catch (e) {
      error = e.message;
      debugPrint('⚠️ API error: ${e.message}');
    } catch (e, s) {
      error = 'Failed to fetch portfolio: $e';
      debugPrint('❌ Error: $e\n$s');
    }

    loading = false;
    notifyListeners();
  }

  /// Fetch using stored walletId
  Future<void> fetchCurrentWalletPortfolio({bool forceRefresh = false}) async {
    final prefs = await SharedPreferences.getInstance();
    final walletId = prefs.getString('wallet_id');
    if (walletId == null || walletId.isEmpty) {
      error = 'No wallet ID found';
      notifyListeners();
      return;
    }
    await fetchPortfolio(walletId, forceRefresh: forceRefresh);
  }

  /// Auto-refresh every 60 seconds
  void startAutoRefresh() {
    _autoRefreshTimer?.cancel();
    _autoRefreshTimer =
        Timer.periodic(autoRefreshInterval, (_) => _refreshSilently());
    debugPrint('🔁 Auto-refresh started (${autoRefreshInterval.inSeconds}s)');
  }

  void stopAutoRefresh() {
    _autoRefreshTimer?.cancel();
    _autoRefreshTimer = null;
    debugPrint('🛑 Auto-refresh stopped');
  }

  Future<void> _refreshSilently() async {
    final prefs = await SharedPreferences.getInstance();
    final walletId = prefs.getString('wallet_id');
    if (walletId == null || walletId.isEmpty) return;
    try {
      final vaultTokens =
          await AuthService.fetchTokensByWallet(walletId: walletId);
      tokens =
          vaultTokens.map(PortfolioToken.fromVault).toList(growable: false);
      totalUsd = tokens.fold(0.0, (sum, t) => sum + t.value);
      _lastFetched = DateTime.now();
      notifyListeners();
      debugPrint('🔄 Auto-refreshed portfolio');
    } catch (e) {
      debugPrint('⚠️ Auto-refresh failed: $e');
    }
  }

  PortfolioToken? getBySymbol(String symbol) {
    try {
      return tokens.firstWhere(
        (t) => t.symbol.toUpperCase() == symbol.toUpperCase(),
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> refresh() async =>
      fetchCurrentWalletPortfolio(forceRefresh: true);

  void clear() {
    tokens = [];
    totalUsd = 0.0;
    error = null;
    loading = false;
    _lastFetched = null;
    stopAutoRefresh();
    notifyListeners();
  }
}
