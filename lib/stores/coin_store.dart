// lib/stores/coin_store.dart
import 'package:flutter/foundation.dart';

class Coin {
  final String id; // e.g. BTC, USDT-ETH, BTC-LN
  final String name; // "Bitcoin", "Tether (ETH)"
  final String symbol; // "BTC", "USDT"
  final String assetPath; // asset path for small icon
  const Coin({
    required this.id,
    required this.name,
    required this.symbol,
    required this.assetPath,
  });
}

class CoinStore extends ChangeNotifier {
  Map<String, Coin> _coins = {
    "BTC": const Coin(
      id: "BTC",
      name: "Bitcoin",
      symbol: "BTC",
      assetPath: "assets/currencyicons/bitcoin.png",
    ),
    "BTC-LN": const Coin(
      id: "BTC-LN",
      name: "Bitcoin Lightning",
      symbol: "BTC",
      assetPath: "assets/currencyicons/bitcoinlightning.png",
    ),
    "BNB": const Coin(
      id: "BNB",
      name: "BNB",
      symbol: "BNB",
      assetPath: "assets/currencyicons/bnb.png",
    ),
    "ETH": const Coin(
      id: "ETH",
      name: "Ethereum",
      symbol: "ETH",
      assetPath: "assets/currencyicons/eth.png",
    ),
    "SOL": const Coin(
      id: "SOL",
      name: "Solana",
      symbol: "SOL",
      assetPath: "assets/currencyicons/sol.png",
    ),
    "TRX": const Coin(
      id: "TRX",
      name: "Tron",
      symbol: "TRX",
      assetPath: "assets/currencyicons/trx.png",
    ),
    "USDT": const Coin(
      id: "USDT",
      name: "Tether",
      symbol: "USDT",
      assetPath: "assets/currencyicons/usdt.png",
    ),
    "USDT-ETH": const Coin(
      id: "USDT-ETH",
      name: "Tether (ERC20)",
      symbol: "USDT",
      assetPath: "assets/currencyicons/usdtoneth.png",
    ),
    "USDT-TRX": const Coin(
      id: "USDT-TRX",
      name: "Tether (TRC20)",
      symbol: "USDT",
      assetPath: "assets/currencyicons/usdtontrx.png",
    ),
    "XMR": const Coin(
      id: "XMR",
      name: "Monero",
      symbol: "XMR",
      assetPath: "assets/currencyicons/xmr.png",
    ),
    "XMR-XMR": const Coin(
      id: "XMR-XMR",
      name: "Monero",
      symbol: "XMR",
      assetPath: "assets/currencyicons/xmronxmr.png",
    ),
    "BNB-BNB": const Coin(
      id: "BNB-BNB",
      name: "BNB",
      symbol: "BNB",
      assetPath: "assets/currencyicons/bnbonbnb.png",
    ),
    "ETH-ETH": const Coin(
      id: "ETH-ETH",
      name: "ETH",
      symbol: "ETH",
      assetPath: "assets/currencyicons/ethoneth.png",
    ),
    "SOL-SOL": const Coin(
      id: "SOL-SOL",
      name: "SOL",
      symbol: "SOL",
      assetPath: "assets/currencyicons/solonsol.png",
    ),
    "TRX-TRX": const Coin(
      id: "TRX-TRX",
      name: "TRX",
      symbol: "TRX",
      assetPath: "assets/currencyicons/trxontrx.png",
    ),
  };

  /// 🔹 Separate big, soft watermark logos just for cards
  final Map<String, String> _cardAssets = const {
    'BTC': 'assets/iconsforcard/logoicon.png',
    'BNB': 'assets/iconsforcard/logoicon13.png',
    'ETH': 'assets/iconsforcard/logoicon14.png',
    'SOL': 'assets/iconsforcard/logoicon15.png',
    'XMR': 'assets/iconsforcard/logoicon16.png',
    'TRX': 'assets/iconsforcard/logoicon17.png',
    'USDT': 'assets/iconsforcard/logoicon18.png',
  };

  Map<String, Coin> get coins => _coins;

  /// ✅ Smart resolver: handles variant IDs from APIs
  /// ✅ Smart resolver: handles variant IDs from APIs (with correct priority)
  Coin? getById(String id) {
    final key = id.toUpperCase();

    // Direct match
    if (_coins.containsKey(key)) return _coins[key];

    // 🔹 Check USDT variants FIRST (so ETH inside USDTERC20 doesn’t override)
    if (key.contains('USDTERC20') || key.contains('USDT-ETH')) {
      return _coins['USDT-ETH'];
    }
    if (key.contains('USDTTRC20') || key.contains('USDT-TRX')) {
      return _coins['USDT-TRX'];
    }

    // 🔹 Then handle other tokens normally
    if (key.contains('BTC-LN')) return _coins['BTC-LN'];
    if (key.contains('BTC')) return _coins['BTC'];
    if (key.contains('BNB')) return _coins['BNB'];
    if (key.contains('SOL')) return _coins['SOL'];
    if (key.contains('TRX')) return _coins['TRX'];
    if (key.contains('XMR')) return _coins['XMR'];
    if (key.contains('USDT')) return _coins['USDT'];
    if (key.contains('ETH')) return _coins['ETH'];

    return null;
  }

  /// ✅ Returns the background/watermark PNG path for any coin id (e.g. "USDT-ETH")
  String? cardAssetFor(String coinId) {
    final base = coinId.contains('-') ? coinId.split('-').first : coinId;
    return _cardAssets[base];
  }

  /// ✅ Safe upsert method (used by dynamic updates)
  void upsertMany(Iterable<Coin> items) {
    final next = Map<String, Coin>.from(_coins);
    for (final c in items) next[c.id] = c;
    _coins = next;
    notifyListeners();
  }
}
