// lib/core/currency_notifier.dart
import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

class CurrencyNotifier extends ChangeNotifier {
  static const _kCurr = 'pref_currency';
  static const _defaultCode = 'USD';

  /// Refresh every 20 minutes
  static const Duration _refreshInterval = Duration(minutes: 20);

  /// Currencies your app supports (uppercase ISO codes).
  static const List<String> _supported = [
    'USD',
    'EUR',
    'GBP',
    'JPY',
    'CNY',
    'INR',
    'BRL',
    'AUD',
    'CAD',
    'NGN',
  ];

  String _code = _defaultCode;
  String get code => _code;
  Map<String, double> get rates => Map.unmodifiable(_usdFx);
  double get selectedRate => _usdFx[_code] ?? 1.0;

  /// Map of <ISO code> -> rate where value means: **1 USD = X <code>**
  Map<String, double> _usdFx = const {'USD': 1.0};
  DateTime? _lastFxRefresh;
  Timer? _timer;

  CurrencyNotifier({String? initialCode}) {
    _code =
        (initialCode != null && _supported.contains(initialCode.toUpperCase()))
            ? initialCode.toUpperCase()
            : _defaultCode;
  }

  /// Call this once at app start (e.g., in main.dart after creating the provider).
  Future<void> bootstrap() async {
    final sp = await SharedPreferences.getInstance();
    final saved = sp.getString(_kCurr);
    if (saved != null && _supported.contains(saved)) {
      _code = saved;
    }

    await _refreshFxIfNeeded(force: true);

    // Auto-refresh every 20 minutes
    _timer?.cancel();
    _timer = Timer.periodic(
        _refreshInterval, (_) => _refreshFxIfNeeded(force: true));

    notifyListeners();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> setCurrency(String newCode) async {
    final up = newCode.toUpperCase();
    if (!_supported.contains(up)) return;
    if (up == _code) return;

    _code = up;
    final sp = await SharedPreferences.getInstance();
    await sp.setString(_kCurr, _code);
    notifyListeners();
  }

  // ---------- Conversions & formatting ----------

  double usdToSelected(num usdAmount) {
    final rate = _usdFx[_code] ?? 1.0;
    return usdAmount.toDouble() * rate;
  }

  /// For values you have in **USD**, convert to currently selected fiat and format.
  String formatFromUsd(num usdAmount, {int? fractionDigits}) {
    final v = usdToSelected(usdAmount);
    return format(v, code: _code, fractionDigits: fractionDigits);
  }

  /// For values already in the target fiat (rare; e.g., when your WS is local fiat),
  /// just format with symbol/decimals.
  String format(num amount, {String? code, int? fractionDigits}) {
    final c = (code ?? _code).toUpperCase();
    final decimals = fractionDigits ?? _defaultDecimalsFor(c, amount);
    final f = NumberFormat.currency(
      symbol: _symbolFor(c),
      decimalDigits: decimals,
    );
    return f.format(amount);
  }

  int _defaultDecimalsFor(String code, num amount) {
    switch (code) {
      case 'JPY':
        return 0;
      default:
        return amount.abs() < 1 ? 4 : 2;
    }
  }

  String _symbolFor(String c) {
    switch (c) {
      case 'USD':
        return '\$';
      case 'EUR':
        return '€';
      case 'GBP':
        return '£';
      case 'JPY':
        return '¥';
      case 'CNY':
        return '¥';
      case 'INR':
        return '₹';
      case 'BRL':
        return 'R\$';
      case 'AUD':
        return 'A\$';
      case 'CAD':
        return 'C\$';
      case 'NGN':
        return '₦';
      default:
        return '$c ';
    }
  }

  // ---------- Live FX fetching (CoinGecko) ----------

  Future<void> _refreshFxIfNeeded({bool force = false}) async {
    if (!force && _lastFxRefresh != null) {
      final age = DateTime.now().difference(_lastFxRefresh!);
      if (age < _refreshInterval) return;
    }
    await _fetchFxFromCoinGecko();
  }

  /// Uses CoinGecko “simple/price” with `ids=usd` and a comma-separated list
  /// of vs_currencies. The response we expect is like:
  /// {
  ///   "usd": { "inr": 83.2, "eur": 0.92, ... }
  /// }
  Future<void> _fetchFxFromCoinGecko() async {
    try {
      final vs = _supported
          .where((c) => c != 'USD')
          .map((c) => c.toLowerCase())
          .join(',');

      final uri = Uri.parse(
        'https://api.coingecko.com/api/v3/simple/price?ids=usd&vs_currencies=$vs',
      );

      final res = await http.get(uri, headers: {
        'Accept': 'application/json',
        'Cache-Control': 'no-cache',
      });

      if (res.statusCode == 200) {
        final raw = json.decode(res.body) as Map<String, dynamic>;
        final usdMap = (raw['usd'] as Map?)?.cast<String, dynamic>() ?? {};

        final Map<String, double> next = {'USD': 1.0};
        for (final c in _supported) {
          if (c == 'USD') continue;
          final v = usdMap[c.toLowerCase()];
          final parsed = (v is num) ? v.toDouble() : double.tryParse('$v');
          if (parsed != null && parsed > 0) next[c] = parsed;
        }

        if (next.length > 1) {
          _usdFx = next;
          _lastFxRefresh = DateTime.now();

          // 👇 PRINT FX snapshot
          if (kDebugMode) {
            debugPrint('FX updated @ $_lastFxRefresh — 1 USD = '
                '${_usdFx.entries.map((e) => '${e.key}:${e.value}').join(', ')}');
            debugPrint(
                'Current currency: $_code  (1 USD = ${selectedRate.toStringAsFixed(6)} $_code)');
          }

          notifyListeners();
          return;
        }
      }

      if (kDebugMode) {
        debugPrint(
            'CurrencyNotifier: CoinGecko FX fetch failed (${res.statusCode}). Body: ${res.body}');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('CurrencyNotifier: FX fetch error: $e');
      }
    }
  }
}
