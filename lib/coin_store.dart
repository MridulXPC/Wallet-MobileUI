// lib/stores/coin_store.dart
import 'package:flutter/foundation.dart';

class Coin {
  final String id; // e.g. BTC, USDT-ETH, BTC-LN
  final String name; // "Bitcoin", "Tether (ETH)"
  final String symbol; // "BTC", "USDT"
  final String assetPath; // asset path for icon
  const Coin(
      {required this.id,
      required this.name,
      required this.symbol,
      required this.assetPath});
}

class CoinStore extends ChangeNotifier {
  Map<String, Coin> _coins = {
    "BTC": const Coin(
        id: "BTC",
        name: "Bitcoin",
        symbol: "BTC",
        assetPath: "assets/currencyicons/bitcoin.png"),
    "BTC-LN": const Coin(
        id: "BTC-LN",
        name: "Bitcoin Lightning",
        symbol: "BTC",
        assetPath: "assets/currencyicons/bitcoinlightning.png"),
    "BNB": const Coin(
        id: "BNB",
        name: "BNB",
        symbol: "BNB",
        assetPath: "assets/currencyicons/bnb.png"),
    "ETH": const Coin(
        id: "ETH",
        name: "Ethereum",
        symbol: "ETH",
        assetPath: "assets/currencyicons/eth.png"),
    "SOL": const Coin(
        id: "SOL",
        name: "Solana",
        symbol: "SOL",
        assetPath: "assets/currencyicons/sol.png"),
    "TRX": const Coin(
        id: "TRX",
        name: "Tron",
        symbol: "TRX",
        assetPath: "assets/currencyicons/trx.png"),
    "USDT": const Coin(
        id: "USDT",
        name: "Tether",
        symbol: "USDT",
        assetPath: "assets/currencyicons/usdt.png"),
    "USDT-ETH": const Coin(
        id: "USDT-ETH",
        name: "Tether",
        symbol: "USDT",
        assetPath: "assets/currencyicons/usdtoneth.png"),
    "USDT-TRX": const Coin(
        id: "USDT-TRX",
        name: "Tether",
        symbol: "USDT",
        assetPath: "assets/currencyicons/usdtontrx.png"),
    "XMR": const Coin(
        id: "XMR",
        name: "Monero",
        symbol: "XMR",
        assetPath: "assets/currencyicons/xmr.png"),
    "XMR-XMR": const Coin(
        id: "XMR-XMR",
        name: "Monero",
        symbol: "XMR",
        assetPath: "assets/currencyicons/xmronxmr.png"),
    "BNB-BNB": const Coin(
        id: "BNB-BNB",
        name: "BNB",
        symbol: "BNB",
        assetPath: "assets/currencyicons/bnbonbnb.png"),
    "ETH-ETH": const Coin(
        id: "ETH-ETH",
        name: "ETH",
        symbol: "ETH",
        assetPath: "assets/currencyicons/ethoneth.png"),
    "SOL-SOL": const Coin(
        id: "SOL-SOL",
        name: "SOL",
        symbol: "SOL",
        assetPath: "assets/currencyicons/solonsol.png"),
    "TRX-TRX": const Coin(
        id: "TRX-TRX",
        name: "TRX",
        symbol: "TRX",
        assetPath: "assets/currencyicons/trxontrx.png"),
  };

  Map<String, Coin> get coins => _coins;
  Coin? getById(String id) => _coins[id];

  // If later your dummy/API wants to tweak labels/icons:
  void upsertMany(Iterable<Coin> items) {
    final next = Map<String, Coin>.from(_coins);
    for (final c in items) next[c.id] = c;
    _coins = next;
    notifyListeners();
  }
}
