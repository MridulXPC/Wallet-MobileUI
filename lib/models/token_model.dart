// lib/services/models/vault_token.dart

class VaultToken {
  final String? id;
  final String name;
  final String symbol;
  final String chain;
  final String? contractAddress;
  final String iconUrl;

  /// Balance as string (e.g., "0.0000")
  final String balance;

  /// Total USD value (balance * price)
  final double value;

  /// Optional: price in USD
  final double? priceUsd;

  /// Optional: 24h % change (may be null)
  final double? changePercent;

  VaultToken({
    required this.id,
    required this.name,
    required this.symbol,
    required this.chain,
    required this.contractAddress,
    required this.iconUrl,
    required this.balance,
    required this.value,
    this.priceUsd,
    this.changePercent,
  });

  // --- Helper to safely parse dynamic values to double ---
  static double? _toDouble(dynamic v) {
    if (v == null) return null;
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v);
    return null;
  }

  factory VaultToken.fromJson(Map<String, dynamic> j) {
    final balanceStr = (j['balance'] ?? '0').toString();
    final balanceNum = _toDouble(j['balance']) ?? 0.0;
    final valueNum = _toDouble(j['value']) ?? 0.0;

    // Optional fields
    final price = _toDouble(j['priceUsd']);
    final pct = _toDouble(j['changePercent']);

    return VaultToken(
      id: (j['_id'] ?? j['id'])?.toString(),
      name: (j['name'] ?? j['symbol'] ?? '').toString(),
      symbol: (j['symbol'] ?? '').toString(),
      chain: (j['chain'] ?? '').toString(),
      contractAddress: j['contractAddress']?.toString(),
      iconUrl: j['iconUrl']?.toString() ?? '',
      balance: balanceStr,
      value: valueNum != 0.0 ? valueNum : (balanceNum * (price ?? 0.0)),
      priceUsd: price,
      changePercent: pct,
    );
  }
}
