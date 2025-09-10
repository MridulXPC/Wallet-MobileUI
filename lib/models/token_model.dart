// lib/services/models/vault_token.dart
class VaultToken {
  final String? id;
  final String name;
  final String symbol;
  final String chain;
  final String? contractAddress;

  /// Balance as a string (e.g., "0.0000")
  final String balance;

  /// Total USD value of the position (balance * price)
  final double value;

  /// Optional current price in USD
  final double? priceUsd;

  /// Optional 24h percent change (e.g., -3.42 means -3.42%)
  final double? changePercent;

  VaultToken({
    required this.id,
    required this.name,
    required this.symbol,
    required this.chain,
    required this.contractAddress,
    required this.balance,
    required this.value,
    required this.priceUsd,
    required this.changePercent,
  });

  static double? _d(dynamic v) {
    if (v == null) return null;
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v);
    return null;
  }

  factory VaultToken.fromJson(Map<String, dynamic> j) {
    final balanceStr = (j['balance'] ?? j['amount'] ?? '0').toString();
    final price = _d(j['priceUsd'] ?? j['usdPrice'] ?? j['price']);
    final fiat = _d(j['fiatValue'] ?? j['usdValue'] ?? j['balanceUSD']);
    final balanceNum = _d(j['balance']) ?? _d(j['amount']) ?? 0.0;
    final totalUsd = fiat ?? ((balanceNum ?? 0.0) * (price ?? 0.0));

    // Try multiple keys commonly used by APIs for 24h % change
    final pct = _d(j['change24h']) ??
        _d(j['percentChange24h']) ??
        _d(j['priceChangePercent']) ??
        _d(j['changePercent']);

    return VaultToken(
      id: (j['_id'] ?? j['id'])?.toString(),
      name: (j['name'] ?? j['symbol'] ?? '').toString(),
      symbol: (j['symbol'] ?? '').toString(),
      chain: (j['chain'] ?? '').toString(),
      contractAddress: j['contractAddress']?.toString(),
      balance: balanceStr,
      value: (totalUsd ?? 0.0),
      priceUsd: price,
      changePercent: pct,
    );
  }
}
