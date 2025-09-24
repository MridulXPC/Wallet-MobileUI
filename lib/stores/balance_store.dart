import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart';
import 'package:cryptowallet/services/api_service.dart';

/// Keeps /api/get-balance/walletId rows in memory and exposes USD total.
class BalanceStore extends ChangeNotifier {
  BalanceStore({String? walletId}) : _walletId = walletId;

  bool _loading = false;
  String? _error;
  List<ChainBalance> _rows = const [];
  double _totalUsd = 0.0;
  String? _walletId;

  Timer? _ticker;
  bool _disposed = false;

  bool get loading => _loading;
  String? get error => _error;
  List<ChainBalance> get rows => _rows;
  double get totalUsd => _totalUsd;
  String? get walletId => _walletId;

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

  /// Set (or change) the active walletId. Optionally triggers an immediate refresh.
  Future<void> setWalletId(String walletId, {bool refreshNow = true}) async {
    _walletId = walletId;
    if (refreshNow) {
      _postFrame(() => refresh());
    } else {
      _safeNotify();
    }
  }

  /// Pulls rows + USD total from backend for the current walletId.
  Future<void> refresh({String? walletId}) async {
    if (_loading) return;

    final effectiveWalletId = walletId ?? _walletId;
    if (effectiveWalletId == null || effectiveWalletId.isEmpty) {
      _error = 'No walletId set';
      _safeNotify();
      return;
    }

    _loading = true;
    _error = null;
    _safeNotify();

    try {
      final payload = await AuthService.fetchBalancesAndTotal(
        walletId: effectiveWalletId,
      );
      _rows = payload.rows;
      _totalUsd = payload.totalUsd;
    } catch (e) {
      _error = e.toString();
    } finally {
      _loading = false;
      _safeNotify();
    }
  }

  /// Refresh immediately (deferred to next frame) and then every [interval].
  void startAutoRefresh({
    Duration interval = const Duration(seconds: 30),
    String? walletId,
  }) {
    if (walletId != null && walletId.isNotEmpty) {
      _walletId = walletId;
    }
    _ticker?.cancel();

    // First tick: defer to next frame (prevents notify during build).
    _postFrame(() => refresh());

    _ticker = Timer.periodic(interval, (_) => refresh());
  }

  void stopAutoRefresh() {
    _ticker?.cancel();
    _ticker = null;
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _disposed = true;
    super.dispose();
  }

  // ---------- helpers ----------

  void _postFrame(VoidCallback cb) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_disposed) cb();
    });
  }

  /// Notifies listeners safely. If called during the build phase,
  /// defer the notification to the next frame.
  void _safeNotify() {
    if (_disposed) return;

    final phase = SchedulerBinding.instance.schedulerPhase;
    final inBuildPhase = phase == SchedulerPhase.persistentCallbacks;

    if (inBuildPhase) {
      // We're in the middle of a frame (build/layout/paint). Defer.
      _postFrame(() {
        if (!_disposed) notifyListeners();
      });
    } else {
      notifyListeners();
    }
  }
}
