/// Simple token model for /api/token/get-tokens
class VaultToken {
  final String id;
  final String name;
  final String symbol;
  final String contractAddress;
  final String balance; // server returns String "0.0000"
  final num value; // server returns number (0)
  final String chain;
  final String iconUrl;

  const VaultToken({
    required this.id,
    required this.name,
    required this.symbol,
    required this.contractAddress,
    required this.balance,
    required this.value,
    required this.chain,
    required this.iconUrl,
  });

  factory VaultToken.fromJson(Map<String, dynamic> json) {
    return VaultToken(
      id: json['_id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      symbol: json['symbol']?.toString() ?? '',
      contractAddress: json['contractAddress']?.toString() ?? '',
      balance: json['balance']?.toString() ?? '0.0000',
      value: (json['value'] is num)
          ? json['value'] as num
          : num.tryParse(json['value']?.toString() ?? '0') ?? 0,
      chain: json['chain']?.toString() ?? '',
      iconUrl: json['iconUrl']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        '_id': id,
        'name': name,
        'symbol': symbol,
        'contractAddress': contractAddress,
        'balance': balance,
        'value': value,
        'chain': chain,
        'iconUrl': iconUrl,
      };
}
