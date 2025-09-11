class ExploreData {
  final String walletAddress;
  final String detectedChain;
  final ExploreSummary summary;
  final List<ExploreBalance> balances;
  final List<dynamic> assets;
  final List<ExploreTransaction> transactions;
  final ExploreMetadata? metadata;

  ExploreData({
    required this.walletAddress,
    required this.detectedChain,
    required this.summary,
    required this.balances,
    required this.assets,
    required this.transactions,
    this.metadata,
  });

  factory ExploreData.fromJson(Map<String, dynamic> json) {
    return ExploreData(
      walletAddress: (json['walletAddress'] ?? '').toString(),
      detectedChain: (json['detectedChain'] ?? '').toString(),
      summary: ExploreSummary.fromJson(
          (json['summary'] as Map?)?.cast<String, dynamic>() ?? const {}),
      balances: ((json['balances'] as List?) ?? const [])
          .whereType<Map>()
          .map((e) => ExploreBalance.fromJson(e.cast<String, dynamic>()))
          .toList(growable: false),
      assets: (json['assets'] as List?) ?? const [],
      transactions: ((json['transactions'] as List?) ?? const [])
          .whereType<Map>()
          .map((e) => ExploreTransaction.fromJson(e.cast<String, dynamic>()))
          .toList(growable: false),
      metadata: json['metadata'] is Map
          ? ExploreMetadata.fromJson(
              (json['metadata'] as Map).cast<String, dynamic>())
          : null,
    );
  }
}

class ExploreSummary {
  final num totalValueUSD;
  final int totalAssets;
  final int totalTransactions;
  final int? firstActivity; // epoch seconds
  final int? lastActivity; // epoch seconds

  ExploreSummary({
    required this.totalValueUSD,
    required this.totalAssets,
    required this.totalTransactions,
    this.firstActivity,
    this.lastActivity,
  });

  factory ExploreSummary.fromJson(Map<String, dynamic> json) {
    num parseNum(dynamic v) {
      if (v == null) return 0;
      if (v is num) return v;
      return num.tryParse(v.toString()) ?? 0;
    }

    int? parseInt(dynamic v) {
      if (v == null) return null;
      if (v is int) return v;
      return int.tryParse(v.toString());
    }

    return ExploreSummary(
      totalValueUSD: parseNum(json['totalValueUSD']),
      totalAssets: parseInt(json['totalAssets']) ?? 0,
      totalTransactions: parseInt(json['totalTransactions']) ?? 0,
      firstActivity: parseInt(json['firstActivity']),
      lastActivity: parseInt(json['lastActivity']),
    );
  }
}

class ExploreBalance {
  final String chain;
  final String nativeBalance; // raw (wei on ETH)
  final String nativeSymbol;
  final String formattedBalance; // already formatted by backend (e.g., ETH)

  ExploreBalance({
    required this.chain,
    required this.nativeBalance,
    required this.nativeSymbol,
    required this.formattedBalance,
  });

  factory ExploreBalance.fromJson(Map<String, dynamic> json) {
    return ExploreBalance(
      chain: (json['chain'] ?? '').toString(),
      nativeBalance: (json['nativeBalance'] ?? '0').toString(),
      nativeSymbol: (json['nativeSymbol'] ?? '').toString(),
      formattedBalance: (json['formattedBalance'] ?? '0').toString(),
    );
  }
}

class ExploreTransaction {
  final String chain;
  final String hash;
  final String from;
  final String to;
  final String value; // raw base units (string)
  final int? timestamp; // epoch seconds
  final int? blockNumber;
  final String? gasUsed;
  final String? gasPrice;
  final String status; // success/failed
  final String type; // send/receive

  ExploreTransaction({
    required this.chain,
    required this.hash,
    required this.from,
    required this.to,
    required this.value,
    this.timestamp,
    this.blockNumber,
    this.gasUsed,
    this.gasPrice,
    required this.status,
    required this.type,
  });

  factory ExploreTransaction.fromJson(Map<String, dynamic> json) {
    int? toInt(dynamic v) {
      if (v == null) return null;
      if (v is int) return v;
      return int.tryParse(v.toString());
    }

    return ExploreTransaction(
      chain: (json['chain'] ?? '').toString(),
      hash: (json['hash'] ?? '').toString(),
      from: (json['from'] ?? '').toString(),
      to: (json['to'] ?? '').toString(),
      value: (json['value'] ?? '0').toString(),
      timestamp: toInt(json['timestamp']),
      blockNumber: toInt(json['blockNumber']),
      gasUsed: json['gasUsed']?.toString(),
      gasPrice: json['gasPrice']?.toString(),
      status: (json['status'] ?? '').toString(),
      type: (json['type'] ?? '').toString(),
    );
  }
}

class ExploreMetadata {
  final num? explorationTime;
  final int? dataFreshness;
  final List<String> supportedChains;

  ExploreMetadata({
    this.explorationTime,
    this.dataFreshness,
    required this.supportedChains,
  });

  factory ExploreMetadata.fromJson(Map<String, dynamic> json) {
    num? parseNum(dynamic v) {
      if (v == null) return null;
      if (v is num) return v;
      return num.tryParse(v.toString());
    }

    int? parseInt(dynamic v) {
      if (v == null) return null;
      if (v is int) return v;
      return int.tryParse(v.toString());
    }

    final sc = (json['supportedChains'] as List?)
            ?.map((e) => e.toString())
            .toList(growable: false) ??
        const <String>[];

    return ExploreMetadata(
      explorationTime: parseNum(json['explorationTime']),
      dataFreshness: parseInt(json['dataFreshness']),
      supportedChains: sc,
    );
  }
}
