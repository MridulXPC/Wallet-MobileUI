import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:cryptowallet/services/api_service.dart';

/// Keeps /api/get-balance/get-balance rows in memory and exposes USD total.
class BalanceStore extends ChangeNotifier {
  bool _loading = false;
  String? _error;
  List<ChainBalance> _rows = const [];
  double _totalUsd = 0.0;

  Timer? _ticker;

  bool get loading => _loading;
  String? get error => _error;
  List<ChainBalance> get rows => _rows;
  double get totalUsd => _totalUsd;

  /// "$" formatted for UI
  String get totalUsdFormatted =>
      NumberFormat.currency(symbol: '\$', decimalDigits: 2).format(_totalUsd);

  /// Fast lookup: "ETH" -> row
  Map<String, ChainBalance> get bySymbol {
    final map = <String, ChainBalance>{};
    for (final r in _rows) {
      final k = (r.symbol.isNotEmpty
              ? r.symbol
              : (r.token.isNotEmpty ? r.token : r.blockchain))
          .toUpperCase();
      if (k.isNotEmpty) map[k] = r;
    }
    return map;
  }

  List<String> get symbols {
    final s = <String>{};
    for (final r in _rows) {
      final k = (r.symbol.isNotEmpty
              ? r.symbol
              : (r.token.isNotEmpty ? r.token : r.blockchain))
          .toUpperCase();
      if (k.isNotEmpty) s.add(k);
    }
    return s.toList(growable: false);
  }

  String balanceFor(String symbolOrChain) {
    final k = symbolOrChain.toUpperCase();
    final row = bySymbol[k];
    return row?.balance ?? '0';
  }

  String addressFor(String symbolOrChain) {
    final k = symbolOrChain.toUpperCase();
    final row = bySymbol[k];
    return row?.address ?? '';
  }

  /// Pulls rows + USD total from backend.
  Future<void> refresh() async {
    if (_loading) return;
    _loading = true;
    _error = null;
    notifyListeners();

    try {
      final payload = await AuthService
          .fetchBalancesAndTotal(); // <— uses data.total_balance
      _rows = payload.rows;
      _totalUsd = payload.totalUsd;
    } catch (e) {
      _error = e.toString();
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  /// Refresh immediately and then every [interval] (default: 30s).
  void startAutoRefresh({Duration interval = const Duration(seconds: 30)}) {
    _ticker?.cancel();
    refresh(); // fire now
    _ticker = Timer.periodic(interval, (_) => refresh());
  }

  void stopAutoRefresh() {
    _ticker?.cancel();
    _ticker = null;
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }
}
