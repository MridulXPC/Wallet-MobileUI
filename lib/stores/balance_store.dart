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
      // ✅ Also fetch new wallets/chains before balance refresh
      await _syncWalletChains(effectiveWalletId);

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

  /// 🔄 Fetches the latest wallet data (including new chains)
  Future<void> _syncWalletChains(String walletId) async {
    try {
      final data = await AuthService.fetchWalletsForUser(walletId: walletId);
      if (data.isNotEmpty) {
        for (final newChain in data) {
          final already = _rows.any((r) =>
              r.blockchain.toUpperCase() ==
              (newChain.blockchain.toUpperCase()));
          if (!already) {
            _rows = [..._rows, newChain];
          }
        }
      }
    } catch (e) {
      debugPrint('⚠️ Wallet sync failed: $e');
    }
  }

  /// ✅ Called right after createSingleChainWallet() succeeds.
  /// Adds new wallets (with nicknames) to holdings immediately.
  Future<void> addTempChainFromResponse(Map<String, dynamic> data) async {
    try {
      if (data['wallets'] == null) return;
      final List wallets = data['wallets'] as List;

      final newBalances = <ChainBalance>[];

      for (final w in wallets) {
        final chain = (w['chain'] ?? '').toString().toUpperCase();
        if (chain.isEmpty) continue;

        final nickname = (w['nickname'] ?? '').toString();
        final addr = (w['address'] ?? '').toString();

        final cb = ChainBalance(
          blockchain: chain,
          symbol: chain,
          token: '',
          balance: '0',
          value: 0.0,
          address: addr,
          nickname: nickname, // ✅ now valid
        );

        final exists = _rows.any((r) =>
            r.blockchain.toUpperCase() == chain &&
            r.address.toLowerCase() == addr.toLowerCase());
        if (!exists) newBalances.add(cb);
      }

      _rows = [..._rows, ...newBalances];
      _safeNotify();
    } catch (e) {
      debugPrint('⚠️ addTempChainFromResponse failed: $e');
    }
  }

  /// R
  ///
  /// efresh immediately (deferred to next frame) and then every [interval].
  void startAutoRefresh({
    Duration interval = const Duration(seconds: 30),
    String? walletId,
  }) {
    if (walletId != null && walletId.isNotEmpty) {
      _walletId = walletId;
    }
    _ticker?.cancel();

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

  void _safeNotify() {
    if (_disposed) return;

    final phase = SchedulerBinding.instance.schedulerPhase;
    final inBuildPhase = phase == SchedulerPhase.persistentCallbacks;

    if (inBuildPhase) {
      _postFrame(() {
        if (!_disposed) notifyListeners();
      });
    } else {
      notifyListeners();
    }
  }
}
