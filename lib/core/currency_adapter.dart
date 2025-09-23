import 'package:cryptowallet/core/currency_notifier.dart';

/// Wraps your CurrencyNotifier and provides a tolerant API:
/// - rateFromUsd (double): USD -> selected currency multiplier
/// - symbol (String): currency symbol, default '$'
/// - code (String): currency code, default 'USD'
/// - formatFromUsd(double): pretty print from USD
class FxAdapter {
  final dynamic _fx; // dynamic to avoid static errors if fields differ
  FxAdapter(CurrencyNotifier fx) : _fx = fx;

  // Try common property names you might already have; fall back to sane defaults.
  double get rateFromUsd {
    try {
      return (_fx.rateFromUsd as double);
    } catch (_) {}
    try {
      return (_fx.usdToFiatRate as double);
    } catch (_) {}
    try {
      return (_fx.multiplier as double);
    } catch (_) {}
    return 1.0; // USD
  }

  String get symbol {
    try {
      return (_fx.symbol as String);
    } catch (_) {}
    try {
      return (_fx.currencySymbol as String);
    } catch (_) {}
    try {
      return (_fx.selected.symbol as String);
    } catch (_) {}
    return r'$';
  }

  String get code {
    try {
      return (_fx.code as String);
    } catch (_) {}
    try {
      return (_fx.currencyCode as String);
    } catch (_) {}
    try {
      return (_fx.selected.code as String);
    } catch (_) {}
    return 'USD';
  }

  String formatFromUsd(double usd) {
    // Prefer a formatter on your notifier if it exists
    try {
      return _fx.formatFromUsd(usd) as String;
    } catch (_) {}
    try {
      return _fx.format(usd) as String;
    } catch (_) {}
    // Fallback: basic formatting
    final v = (usd * rateFromUsd).toStringAsFixed(2);
    return '$symbol$v';
  }

  /// Convert selected currency -> USD (if you need it)
  double toUsd(double selectedAmount) {
    final r = rateFromUsd;
    return r == 0 ? 0.0 : selectedAmount / r;
  }

  /// Convert USD -> selected currency
  double fromUsd(double usd) => usd * rateFromUsd;
}
