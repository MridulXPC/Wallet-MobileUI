import 'package:flutter/foundation.dart';
import 'package:cryptowallet/services/api_service.dart'; // for AuthService + ApiException
import 'package:shared_preferences/shared_preferences.dart';

/// 🔹 Model representing a token in the vault/portfolio
class VaultToken {
  final String id;
  final String name;
  final String symbol;
  final String contractAddress;
  final String chain;
  final String iconUrl;
  final String balance;
  final double value;

  VaultToken({
    required this.id,
    required this.name,
    required this.symbol,
    required this.contractAddress,
    required this.chain,
    required this.iconUrl,
    required this.balance,
    required this.value,
  });

  factory VaultToken.fromJson(Map<String, dynamic> json) {
    return VaultToken(
      id: json['_id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      symbol: json['symbol']?.toString() ?? '',
      contractAddress: json['contractAddress']?.toString() ?? '',
      chain: json['chain']?.toString() ?? '',
      iconUrl: json['iconUrl']?.toString() ?? '',
      balance: json['balance']?.toString() ?? '0.0',
      value: (json['value'] ?? 0).toDouble(),
    );
  }
}

/// 🔹 UI-level model (PortfolioToken)
class PortfolioToken {
  final String id;
  final String name;
  final String symbol;
  final String chain;
  final String iconUrl;
  final double balance;
  final double value;

  PortfolioToken({
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
      id: v.id,
      name: v.name,
      symbol: v.symbol,
      chain: v.chain,
      iconUrl: v.iconUrl,
      balance: double.tryParse(v.balance) ?? 0.0,
      value: v.value,
    );
  }
}

/// 🔹 Portfolio Store
class PortfolioStore extends ChangeNotifier {
  bool loading = false;
  String? error;
  List<PortfolioToken> tokens = [];
  double totalUsd = 0.0;

  /// Fetch portfolio for a specific walletId
  Future<void> fetchPortfolio(String walletId) async {
    loading = true;
    error = null;
    notifyListeners();

    try {
      final rawTokens =
          await AuthService.fetchTokensByWallet(walletId: walletId);

      tokens = rawTokens
          .map((t) => PortfolioToken.fromVault(t as VaultToken))
          .toList(growable: false);

      totalUsd = tokens.fold(0.0, (sum, t) => sum + t.value);
    } on ApiException catch (e) {
      error = e.message;
    } catch (e) {
      error = 'Failed to fetch portfolio: $e';
    }

    loading = false;
    notifyListeners();
  }

  /// Fetch portfolio for the stored walletId
  Future<void> fetchCurrentWalletPortfolio() async {
    final prefs = await SharedPreferences.getInstance();
    final walletId = prefs.getString('wallet_id');
    if (walletId == null || walletId.isEmpty) {
      error = 'No wallet ID found';
      notifyListeners();
      return;
    }
    await fetchPortfolio(walletId);
  }

  /// Clear state (e.g. on logout or wallet deletion)
  void clear() {
    tokens = [];
    totalUsd = 0.0;
    error = null;
    loading = false;
    notifyListeners();
  }
}
