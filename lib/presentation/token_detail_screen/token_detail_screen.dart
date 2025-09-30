// lib/presentation/token_detail/token_detail_screen.dart
import 'dart:async';
import 'dart:convert';
import 'package:cryptowallet/presentation/main_wallet_dashboard/widgets/action_buttons_grid_widget.dart';
import 'package:cryptowallet/presentation/receive_cryptocurrency/receive_cryptocurrency.dart';
import 'package:cryptowallet/services/api_service.dart';
import 'package:cryptowallet/stores/balance_store.dart';
import 'package:cryptowallet/stores/coin_store.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:sizer/sizer.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:web_socket_channel/io.dart';
import 'package:cryptowallet/core/currency_notifier.dart';
import 'package:cryptowallet/core/currency_adapter.dart';
import 'package:cryptowallet/services/api_service.dart' show TxRecord;

class TokenDetailScreen extends StatefulWidget {
  const TokenDetailScreen({super.key, required this.coinId});
  final String coinId;
  @override
  State<TokenDetailScreen> createState() => _TokenDetailScreenState();
}

class _TokenDetailScreenState extends State<TokenDetailScreen>
    with SingleTickerProviderStateMixin {
  Map<String, dynamic>? tokenData;

  // ---- live price state (Binance) ----
  WebSocketChannel? _ws;
  StreamSubscription? _wsSub;
  double? _livePrice; // last price (USDT ~ USD)
  double? _liveChangePercent; // 24h % change (+/-)
  String? _liveChangeAbs; // optional abs change text if available

  // 👇 NEW: transactions future
  Future<List<TxRecord>>? _txFuture;

  // ---- chart state (CoinGecko) ----
  List<FlSpot> chartData = [];
  bool _chartLoading = false;
  String selectedPeriod = 'LIVE';
  Timer? _reconnectTimer;

  bool isBookmarked = false;
  late TabController _tabController;

  final List<String> timePeriods = ['LIVE', '4H', '1D', '1W', '1M', 'MAX'];
  final List<String> tabs = ['Holdings', 'History', 'About'];

  // Dark theme palette
  static const Color darkBackground = Color(0xFF0B0D1A);
  static const Color cardBackground = Color(0xFF1A1A1A);
  static const Color greenColor = Color(0xFF00D4AA);
  static const Color greyColor = Color(0xFF8E8E8E);
  static const Color lightGreyColor = Color(0xFFB8B8B8);

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: tabs.length, vsync: this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final args =
        ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    if (args != null && tokenData == null) {
      setState(() => tokenData = args);
      _applyInitialTabFromArgs();
      _startLiveStream(); // <- Binance WS
      _loadChartFor(selectedPeriod); // <- CoinGecko chart

      // 👇 Kick off transaction history load (wallet-wide; we filter by token below)
      _txFuture = AuthService.fetchTransactionHistoryByWallet(
        // chain: ... // optionally pass a chain filter if you want
        limit: 100,
      );
    }
  }

  @override
  void dispose() {
    _reconnectTimer?.cancel();
    _wsSub?.cancel();
    _ws?.sink.close();
    _tabController.dispose();
    super.dispose();
  }

  // --------- Initial tab helpers -------------
  int? _extractInitialTabFromArgs() {
    final argsAny = ModalRoute.of(context)?.settings.arguments;
    try {
      if (argsAny is Map<String, dynamic>) return argsAny['initialTab'] as int?;
      final dynamic d = argsAny;
      return d?.initialTab as int?;
    } catch (_) {
      return null;
    }
  }

  void _applyInitialTabFromArgs() {
    final idx = _extractInitialTabFromArgs();
    if (idx != null &&
        idx >= 0 &&
        idx < tabs.length &&
        idx != _tabController.index) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _tabController.animateTo(idx);
      });
    }
  }

  // ---------- symbol / ids ----------
  String get sym => (tokenData?['symbol'] ?? 'BTC').toString().toUpperCase();
  String get name => tokenData?['name'] ?? 'Bitcoin';
  String get iconPath =>
      tokenData?['icon'] ?? 'assets/currencyicons/bitcoin.png';

  // Fallbacks if no live stream yet (USD)
  double get _fallbackPrice =>
      (tokenData?['price'] as num?)?.toDouble() ?? 43825.67;
  String get _fallbackChangeText =>
      tokenData?['changeText'] ?? r'$72.42 (+0.06%)';
  bool get _fallbackChangePositive => tokenData?['changePositive'] ?? true;

  // Mapping: app symbol -> Binance stream symbol ("btcusdt")
  String? _binanceStreamSymbol(String s) {
    final base = s.toUpperCase();
    // We stream vs USDT by default
    const supported = {
      'BTC': 'btcusdt',
      'ETH': 'ethusdt',
      'BNB': 'bnbusdt',
      'SOL': 'solusdt',
      'TRX': 'trxusdt',
      'XMR': 'xmrusdt', // may not be supported on Binance in some regions
      'USDT': null, // USDT/USDT doesn’t make sense — skip stream
    };
    return supported[base] ?? '${base.toLowerCase()}usdt';
  }

  // Mapping: app symbol -> CoinGecko coin id
  String _coingeckoIdForSymbol(String s) {
    switch (s.toUpperCase()) {
      case 'BTC':
        return 'bitcoin';
      case 'ETH':
        return 'ethereum';
      case 'BNB':
        return 'binancecoin';
      case 'SOL':
        return 'solana';
      case 'TRX':
        return 'tron';
      case 'USDT':
        return 'tether';
      case 'XMR':
        return 'monero';
      default:
        return 'bitcoin';
    }
  }

  /* ===================== BINANCE LIVE TICKER ===================== */

  void _startLiveStream() {
    // Close any previous stream
    _reconnectTimer?.cancel();
    _wsSub?.cancel();
    _ws?.sink.close();

    final streamSym = _binanceStreamSymbol(sym);
    if (streamSym == null) return; // e.g., USDT

    final url = 'wss://stream.binance.com:9443/ws/$streamSym@ticker';
    _ws = IOWebSocketChannel.connect(Uri.parse(url));

    _wsSub = _ws!.stream.listen(
      (event) {
        try {
          final m = jsonDecode(event as String) as Map<String, dynamic>;
          final last = double.tryParse(m['c']?.toString() ?? '');
          final pct = double.tryParse(m['P']?.toString() ?? '');
          final abs = m['p']?.toString(); // optional absolute change
          if (!mounted) return;
          setState(() {
            if (last != null) _livePrice = last;
            if (pct != null) _liveChangePercent = pct;
            _liveChangeAbs = abs;
          });
        } catch (_) {}
      },
      onDone: _scheduleReconnect,
      onError: (_) => _scheduleReconnect(),
      cancelOnError: true,
    );
  }

  void _scheduleReconnect() {
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(const Duration(seconds: 3), () {
      if (!mounted) return;
      _startLiveStream();
    });
  }

  /* ===================== COINGECKO CHART ===================== */

  Future<void> _loadChartFor(String period) async {
    setState(() => _chartLoading = true);

    try {
      final id = _coingeckoIdForSymbol(sym);
      // Map UI period -> CoinGecko days
      final (days, filterHours) = switch (period) {
        'LIVE' => ('1', 1), // last 1h from 1D data
        '4H' => ('1', 4),
        '1D' => ('1', null),
        '1W' => ('7', null),
        '1M' => ('30', null),
        _ => ('max', null),
      };

      final uri = Uri.parse(
          'https://api.coingecko.com/api/v3/coins/$id/market_chart?vs_currency=usd&days=$days');
      final res = await http.get(uri).timeout(const Duration(seconds: 15));
      if (res.statusCode != 200) {
        throw Exception('Chart HTTP ${res.statusCode}');
      }
      final map = jsonDecode(res.body) as Map<String, dynamic>;
      final List prices = (map['prices'] as List?) ?? const [];

      final nowMs = DateTime.now().millisecondsSinceEpoch;
      final cutoffMs =
          (filterHours != null) ? nowMs - (filterHours * 60 * 60 * 1000) : null;

      final points = <FlSpot>[];
      for (final row in prices) {
        if (row is! List || row.length < 2) continue;
        final ts = (row[0] as num).toInt();
        final price = (row[1] as num).toDouble(); // USD
        if (cutoffMs != null && ts < cutoffMs) continue;
        points.add(FlSpot(ts.toDouble(), price));
      }

      // If CoinGecko is throttled or empty, fall back to last known price
      if (points.isEmpty) {
        final p = _livePrice ?? _fallbackPrice;
        final t = DateTime.now().millisecondsSinceEpoch.toDouble();
        points.addAll([
          FlSpot(t - 600000, p * 0.995),
          FlSpot(t - 300000, p * 1.002),
          FlSpot(t, p),
        ]);
      }

      // Normalize X to 0..N for smoother FLChart
      final t0 = points.first.x;
      final norm = <FlSpot>[];
      for (final s in points) {
        norm.add(FlSpot((s.x - t0) / 1000.0, s.y)); // seconds from start
      }

      if (!mounted) return;
      setState(() {
        chartData = norm; // USD values; axis labels hidden
        _chartLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      // graceful fallback — keep previous data, stop spinner
      setState(() => _chartLoading = false);
    }
  }

  /* ===================== UI ===================== */

  void _onPeriodSelected(String period) {
    setState(() => selectedPeriod = period);
    HapticFeedback.selectionClick();
    _loadChartFor(period);
  }

  // --------------------- Receive handling (unchanged) ---------------------
  String? _tryKeys(List<String> keys) {
    for (final k in keys) {
      final v = tokenData?[k];
      if (v is String && v.trim().isNotEmpty) return v.trim();
    }
    return null;
  }

  String get _coinId {
    final explicit = tokenData?['coinId']?.toString();
    if (explicit != null && explicit.isNotEmpty) return explicit.toUpperCase();
    if (widget.coinId.isNotEmpty) return widget.coinId.toUpperCase();
    final s = (tokenData?['symbol'] ?? '').toString().toUpperCase();
    final c = _normalizeChain(tokenData?['chain']);
    if (s.isNotEmpty && c.isNotEmpty && c != s) return '$s-$c';
    return s.isNotEmpty ? s : 'BTC';
  }

  String _normalizeChain(dynamic v) {
    final raw = (v ?? '').toString().trim().toUpperCase();
    switch (raw) {
      case 'ETHEREUM':
      case 'ERC20':
      case 'ERC-20':
      case 'ETH-ETH':
        return 'ETH';
      case 'TRON':
      case 'TRC20':
      case 'TRC-20':
      case 'TRX-TRX':
        return 'TRX';
      case 'SOLANA':
      case 'SOL-SOL':
        return 'SOL';
      case 'BSC':
      case 'BNB CHAIN':
      case 'BNB-CHAIN':
      case 'BEP20':
      case 'BEP-20':
      case 'BNB-BNB':
        return 'BNB';
      case 'LIGHTNING':
      case 'LN':
      case 'BTC-LN':
        return 'LN';
      default:
        return raw;
    }
  }

  void _openReceive() {
    final id = _coinId; // e.g. BTC, BTC-LN, USDT-TRX, SOL-SOL
    final coin = context.read<CoinStore>().getById(id);
    final pretty = coin?.name ?? sym;

    final String? mode =
        id.contains('-LN') ? 'ln' : (id.startsWith('BTC') ? 'onchain' : null);

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ReceiveQR(
          title: 'Your address to receive $pretty',
          address: '',
          coinId: id,
          mode: mode,
          minSats: (mode == 'onchain' && id.startsWith('BTC')) ? 25000 : null,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // 👇 React to currency changes everywhere in this screen
    final fx = FxAdapter(context.watch<CurrencyNotifier>());

    final screenWidth = MediaQuery.of(context).size.width;
    final isLarge = screenWidth > 900;
    final isTablet = screenWidth > 600;

    return Scaffold(
      backgroundColor: darkBackground,
      body: Column(
        children: [
          // Upper half
          Expanded(
            flex: 1,
            child: Column(
              children: [
                _buildDarkAppBar(),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildTokenPriceDisplay(fx), // 👈 pass adapter
                      Expanded(child: _buildPriceChart()),
                      const SizedBox(height: 6),
                      _buildTimePeriodSelector(),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Expanded(
                            child: ActionButtonsGridWidget(
                              isLarge: isLarge,
                              isTablet: isTablet,
                              coinId: _coinId,
                              onReceive: _openReceive,
                            ),
                          ),
                          SizedBox(width: 3.w),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // Lower half
          Expanded(
            flex: 1,
            child: Column(
              children: [
                TabBar(
                  controller: _tabController,
                  indicatorColor: Colors.white,
                  indicatorWeight: 3,
                  indicatorSize: TabBarIndicatorSize.label,
                  labelColor: Colors.white,
                  unselectedLabelColor: greyColor,
                  labelStyle: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                  unselectedLabelStyle: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w400,
                  ),
                  tabs: tabs.map((t) => Tab(text: t)).toList(),
                ),
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _buildHoldingsTab(fx), // 👈 pass adapter
                      _buildHistoryTab(), // 👈 UPDATED
                      _buildAboutTab(),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDarkAppBar() {
    return SafeArea(
      child: SizedBox(
        height: 56,
        child: Stack(
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: IconButton(
                icon: const Icon(
                  Icons.arrow_back_ios_new_rounded,
                  color: Colors.white,
                  size: 18,
                ),
                splashRadius: 20,
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
            Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.asset(
                      iconPath,
                      width: 28,
                      height: 28,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const Icon(
                        Icons.currency_bitcoin,
                        color: Colors.orange,
                      ),
                    ),
                  ),
                  SizedBox(width: 2.w),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Text(
                        sym,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        'COIN | $name',
                        style: const TextStyle(color: greyColor, fontSize: 12),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 👇 currency-aware price display
  Widget _buildTokenPriceDisplay(FxAdapter fx) {
    final usdPrice = _livePrice ?? _fallbackPrice; // USDT≈USD
    final priceText = fx.formatFromUsd(usdPrice);

    final pct = _liveChangePercent;
    final isUp = (pct ?? 0) >= 0
        ? (_liveChangePercent != null ? true : _fallbackChangePositive)
        : false;
    final changeClr = isUp ? greenColor : Colors.redAccent;

    final pctText = (pct != null)
        ? '${pct >= 0 ? '+' : ''}${pct.toStringAsFixed(2)}%'
        : _fallbackChangeText; // this already includes a $ if from fallback

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 4.w),
      child: Column(
        children: [
          Text(
            priceText, // e.g., €42,123.45
            style: const TextStyle(
              color: Colors.white,
              fontSize: 26,
              fontWeight: FontWeight.w700,
            ),
          ),
          SizedBox(height: 1.h),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(isUp ? Icons.arrow_upward : Icons.arrow_downward,
                  color: changeClr, size: 18),
              const SizedBox(width: 4),
              Text(
                _liveChangeAbs != null
                    // absolute change is in USDT/USD; convert & format
                    ? '${_liveChangeAbs!.startsWith('-') ? '' : '+'}'
                        '${fx.formatFromUsd(double.tryParse(_liveChangeAbs!) ?? 0)} ($pctText)'
                    : pctText,
                style: TextStyle(
                  color: changeClr,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTimePeriodSelector() {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 4.w),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: timePeriods.map((p) {
          final isSel = selectedPeriod == p;
          return GestureDetector(
            onTap: () => _onPeriodSelected(p),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: isSel ? cardBackground : Colors.transparent,
                borderRadius: BorderRadius.circular(20),
                border: isSel
                    ? Border.all(color: greyColor.withOpacity(0.3))
                    : null,
              ),
              child: Text(
                p,
                style: TextStyle(
                  color: isSel ? Colors.white : greyColor,
                  fontSize: 13,
                  fontWeight: isSel ? FontWeight.w600 : FontWeight.w400,
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildPriceChart() {
    if (_chartLoading && chartData.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.only(bottom: 24.0),
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }

    final spots =
        chartData.isNotEmpty ? chartData : [FlSpot(0, _fallbackPrice)];
    final minY = spots.map((s) => s.y).reduce((a, b) => a < b ? a : b) * 0.995;
    final maxY = spots.map((s) => s.y).reduce((a, b) => a > b ? a : b) * 1.005;

    return Container(
      margin: EdgeInsets.symmetric(horizontal: 2.w),
      child: LineChart(
        LineChartData(
          gridData: FlGridData(show: false),
          titlesData: FlTitlesData(show: false), // axis labels hidden
          borderData: FlBorderData(show: false),
          lineBarsData: [
            LineChartBarData(
              spots: spots, // still in USD internally
              isCurved: true,
              color: greenColor,
              barWidth: 3,
              isStrokeCapRound: true,
              dotData: FlDotData(show: false),
              belowBarData: BarAreaData(
                show: true,
                gradient: LinearGradient(
                  colors: [
                    greenColor.withOpacity(0.4),
                    greenColor.withOpacity(0.1),
                    Colors.transparent,
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
            ),
          ],
          minX: spots.first.x,
          maxX: spots.last.x,
          minY: minY,
          maxY: maxY,
        ),
      ),
    );
  }

  // ------------------ Holdings tab (currency-aware) ------------------
  Widget _buildHoldingsTab(FxAdapter fx) {
    return SingleChildScrollView(
      padding: EdgeInsets.symmetric(horizontal: 3.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(height: 1.h),
          const Padding(
            padding: EdgeInsets.only(bottom: 16.0),
            child: Text(
              'Your Holdings',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          ..._buildCoinHoldings(fx),
        ],
      ),
    );
  }

  List<Widget> _buildCoinHoldings(FxAdapter fx) {
    final bs = context.watch<BalanceStore>();
    final store = context.read<CoinStore>();

    if (bs.loading && bs.rows.isEmpty) {
      return const [
        Center(
          child: Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: SizedBox(
                width: 28,
                height: 28,
                child: CircularProgressIndicator(strokeWidth: 2)),
          ),
        ),
      ];
    }

    final wantedSym = sym.toUpperCase();

    final rowsForCoin = bs.rows.where((r) {
      final s = (r.symbol.isNotEmpty
              ? r.symbol
              : (r.token.isNotEmpty ? r.token : r.blockchain))
          .toUpperCase();
      return s == wantedSym;
    }).toList();

    if (rowsForCoin.isEmpty) {
      return [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(40),
          decoration: BoxDecoration(
            color: Colors.transparent,
            border: Border.all(color: greyColor, width: 1), // outline
            borderRadius: BorderRadius.circular(6), // radius 6
          ),
          child: Text(
            'No $wantedSym balances found for this wallet.',
            textAlign: TextAlign.center,
            style: const TextStyle(color: greyColor, fontSize: 14),
          ),
        ),
      ];
    }

    return rowsForCoin.map((r) {
      final chainRaw = (r.blockchain).toUpperCase();
      final chainNorm = _normalizeChain(chainRaw);

      final balance = double.tryParse(r.balance) ?? 0.0;
      final usd = (r.value ?? 0.0); // USD from store

      String coinIdGuess;
      if (wantedSym == 'USDT') {
        coinIdGuess = 'USDT-$chainNorm';
      } else if (wantedSym == 'BTC' && chainNorm == 'LN') {
        coinIdGuess = 'BTC-LN';
      } else if (wantedSym == 'BTC') {
        coinIdGuess = 'BTC';
      } else {
        coinIdGuess = '$wantedSym-$chainNorm';
      }

      final coinForIcon =
          store.getById(coinIdGuess) ?? store.getById(wantedSym);

      final icon = coinForIcon?.assetPath ?? 'assets/currencyicons/bitcoin.png';
      final title = coinForIcon?.name ??
          (wantedSym == 'USDT' ? 'USDT (${_chainUiName(chainNorm)})' : name);

      final networkSubtitle = wantedSym == 'USDT'
          ? '${_networkShort(chainNorm)} • ${_chainUiName(chainNorm)} Network'
          : '${_chainUiName(chainNorm)} Network';

      return Container(
        margin: EdgeInsets.only(bottom: 2.h),
        padding: EdgeInsets.all(3.w),
        decoration: BoxDecoration(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: Colors.white.withOpacity(0.10), width: 1),
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.asset(
                icon,
                width: 40,
                height: 40,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const Icon(
                  Icons.currency_bitcoin,
                  color: Colors.orange,
                  size: 32,
                ),
              ),
            ),
            SizedBox(width: 3.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // title + balance
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        '${_formatCrypto(balance)} $wantedSym',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 0.5.h),
                  // network + fiat value (currency-aware)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        networkSubtitle,
                        style: const TextStyle(
                          color: greyColor,
                          fontSize: 13,
                        ),
                      ),
                      Text(
                        fx.formatFromUsd(usd), // 👈 convert from USD
                        style: const TextStyle(
                          color: greyColor,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }).toList();
  }

  /* ---------- tiny helpers for holdings ---------- */
  String _formatCrypto(double v) {
    var s = v.toStringAsFixed(8);
    s = s.replaceAll(RegExp(r'0+$'), '');
    if (s.endsWith('.')) s = s.substring(0, s.length - 1);
    return s.isEmpty ? '0' : s;
  }

  String _chainUiName(String code) {
    switch (code.toUpperCase()) {
      case 'ETH':
        return 'Ethereum';
      case 'BNB':
        return 'BNB Chain';
      case 'SOL':
        return 'Solana';
      case 'TRX':
        return 'Tron';
      case 'BTC':
        return 'Bitcoin';
      case 'LN':
        return 'Lightning';
      default:
        return code.toUpperCase();
    }
  }

  String _networkShort(String code) {
    switch (code.toUpperCase()) {
      case 'ETH':
        return 'ERC-20';
      case 'TRX':
        return 'TRC-20';
      case 'BNB':
        return 'BEP-20';
      case 'SOL':
        return 'SOL';
      case 'BTC':
        return 'BTC';
      case 'LN':
        return 'LN';
      default:
        return code.toUpperCase();
    }
  }

  /* ===================== HISTORY TAB (REAL DATA) ===================== */

  Widget _buildHistoryTab() {
    return FutureBuilder<List<TxRecord>>(
      future: _txFuture,
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 40),
            child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
          );
        }
        if (snap.hasError) {
          return Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                const Text(
                  'Couldn’t load transactions',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                Text(
                  '${snap.error}',
                  style:
                      const TextStyle(color: Color(0xFF6B7280), fontSize: 13),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                TextButton(
                  onPressed: () {
                    setState(() {
                      _txFuture = AuthService.fetchTransactionHistoryByWallet(
                          limit: 100);
                    });
                  },
                  child: const Text('Retry'),
                ),
              ],
            ),
          );
        }

        final all = snap.data ?? const <TxRecord>[];

        // TOKEN-WISE FILTER (case-insensitive)
        final wanted = sym.toUpperCase();
        final filtered =
            all.where((t) => (t.token ?? '').toUpperCase() == wanted).toList();

        // newest → oldest
        filtered.sort((a, b) => (b.createdAt ??
                DateTime.fromMillisecondsSinceEpoch(0))
            .compareTo(a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0)));

        return SingleChildScrollView(
            child: _buildTransactionsSection(filtered));
      },
    );
  }

  Widget _buildTransactionsSection(List<TxRecord> txs) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 24),
        if (txs.isNotEmpty)
          ...txs.map(_buildTransactionItemTx)
        else
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(40),
            child: const Column(
              children: [
                Text(
                  'No transactions yet',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w500),
                ),
                SizedBox(height: 8),
                Text(
                  'Your transactions will appear here',
                  style: TextStyle(color: Color(0xFF6B7280), fontSize: 14),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        const SizedBox(height: 100),
      ],
    );
  }

  // 👇 Row builder using TxRecord from the API
  Widget _buildTransactionItemTx(TxRecord tx) {
    // Adjust these field reads to your TxRecord model if necessary:
    final type = (tx.type ?? '').toUpperCase(); // "SEND"/"RECEIVE"/...
    final status = (tx.status ?? '').toUpperCase(); // "COMPLETED"/"PENDING"/...
    final amountStr = tx.amount ?? '0';
    final token = tx.token ?? '';
    final from = tx.fromAddress ?? '';
    final to = tx.toAddress ?? '';
    final dt = tx.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 10),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: const Color(0xFF2A2D3A),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Icon(_getTransactionTypeIconUpper(type),
                color: Colors.white, size: 18),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Status + Type + Amount row
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          status,
                          style: TextStyle(
                            color: _getStatusColorUpper(status),
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _getTransactionTypeLabelUpper(type),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          _timeAgoFromDate(dt),
                          style: const TextStyle(
                            color: Color(0xFF6B7280),
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '$amountStr ${_getCoinSymbol(token)}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                // From / To
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(child: _kvSmall('From:', _shortenAddress(from))),
                    const SizedBox(width: 16),
                    Expanded(
                        child: _kvSmall('To:', _shortenAddress(to), end: true)),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ------------------ About tab (unchanged UI) ------------------
  Widget _buildAboutTab() {
    return SingleChildScrollView(
      padding: EdgeInsets.symmetric(horizontal: 4.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(height: 2.h),
          Container(
            padding: EdgeInsets.all(1.w),
            child: Column(
              children: [
                _buildStatRow(
                    'Market Cap', tokenData?['marketCap'] ?? r'$2.4T'),
                _buildStatRow(
                    '24h Volume', tokenData?['volume24h'] ?? r'$45.2B'),
                _buildStatRow(
                    'Circulating Supply', tokenData?['circulating'] ?? '—'),
                _buildStatRow('Volume / Market Cap',
                    tokenData?['Volume / Market Cap'] ?? '8.90%'),
                _buildStatRow('All time high',
                    tokenData?['All time high'] ?? '\$73,737.00'),
                _buildStatRow(
                    'All time low', tokenData?['All time low'] ?? '\$65.00'),
                _buildStatRow(
                    'Fully diluted', tokenData?['Fully diluted'] ?? '\$2.6T'),
              ],
            ),
          ),
          SizedBox(height: 3.h),
          Container(
            padding: EdgeInsets.all(4.w),
            decoration: BoxDecoration(
              color: Colors.transparent,
              border: Border.all(color: greyColor, width: 1), // outline
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.asset(
                    iconPath,
                    width: 40,
                    height: 40,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => const Icon(
                      Icons.currency_bitcoin,
                      color: Colors.orange,
                      size: 28,
                    ),
                  ),
                ),
                SizedBox(width: 3.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('About $name',
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w600)),
                      Text(sym,
                          style:
                              const TextStyle(color: greyColor, fontSize: 14)),
                      SizedBox(height: 1.5.h),
                      Text(
                        tokenData?['about'] ??
                            'No description provided for $name.',
                        style: const TextStyle(
                          color: lightGreyColor,
                          fontSize: 14,
                          height: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: 4.h),
        ],
      ),
    );
  }

  Widget _buildStatRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: greyColor, fontSize: 16)),
          Text(value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              )),
        ],
      ),
    );
  }

  // ------------------- Small helpers -------------------
  Widget _kvSmall(String label, String value, {bool end = false}) {
    return Column(
      crossAxisAlignment:
          end ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(color: Color(0xFF6B7280), fontSize: 12)),
        Text(value,
            style: const TextStyle(color: Color(0xFF6B7280), fontSize: 12)),
      ],
    );
  }

  // Old string-based timeago kept for backward compatibility (not used now)
  String _getTimeAgo(String dateTime) {
    try {
      final parts = dateTime.split(' ');
      if (parts.length >= 3) {
        final day = int.parse(parts[0]);
        final month = parts[1];
        final year = int.parse(parts[2]);

        final months = {
          'Jan': 1,
          'Feb': 2,
          'Mar': 3,
          'Apr': 4,
          'May': 5,
          'Jun': 6,
          'Jul': 7,
          'Aug': 8,
          'Sep': 9,
          'Oct': 10,
          'Nov': 11,
          'Dec': 12
        };

        final transactionDate = DateTime(year, months[month] ?? 1, day);
        final now = DateTime.now();
        final difference = now.difference(transactionDate).inDays;

        if (difference == 0) return 'Today';
        if (difference == 1) return 'Yesterday';
        if (difference < 30) return '$difference days ago';
        return '$day $month $year';
      }
    } catch (_) {}
    return '12 days ago';
  }

  // 👇 NEW: timeago from DateTime (used for API records)
  String _timeAgoFromDate(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inSeconds < 60) return '${diff.inSeconds}s ago';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays == 1) return 'Yesterday';
    if (diff.inDays < 30) return '${diff.inDays} days ago';
    return '${dt.day.toString().padLeft(2, '0')} '
        '${_month3(dt.month)} ${dt.year}';
  }

  String _month3(int m) {
    const mm = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec'
    ];
    return mm[(m - 1).clamp(0, 11)];
  }

  String _getCoinSymbol(String coinKey) {
    final store = context.read<CoinStore>();
    final coin = store.getById(coinKey);
    if (coin != null) return coin.symbol;

    if (coinKey.toString().startsWith('USDT')) return 'USDT';
    if (coinKey.toString().startsWith('ETH')) return 'ETH';
    if (coinKey.toString().startsWith('TRX')) return 'TRX';
    if (coinKey.toString().startsWith('SOL')) return 'SOL';
    if (coinKey.toString().startsWith('BNB')) return 'BNB';
    if (coinKey.toString().startsWith('XMR')) return 'XMR';
    if (coinKey.toString().startsWith('BTC')) return 'BTC';
    return coinKey;
  }

  // Existing helpers adapted to accept upper-case types/status
  IconData _getTransactionTypeIconUpper(String typeUpper) {
    switch (typeUpper) {
      case 'SEND':
        return Icons.send;
      case 'RECEIVE':
        return Icons.arrow_downward;
      case 'SWAP':
        return Icons.swap_horiz;
      default:
        return Icons.account_balance_wallet;
    }
  }

  String _getTransactionTypeLabelUpper(String typeUpper) {
    switch (typeUpper) {
      case 'SEND':
        return 'Send';
      case 'RECEIVE':
        return 'Received';
      case 'SWAP':
        return 'Swap';
      default:
        return 'Transaction';
    }
  }

  Color _getStatusColorUpper(String statusUpper) {
    switch (statusUpper) {
      case 'COMPLETED':
      case 'SUCCESS':
      case 'CONFIRMED':
        return Colors.green;
      case 'PENDING':
        return Colors.orange;
      case 'FAILED':
      case 'ERROR':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  String _shortenAddress(String address) {
    if (address.length <= 12) return address;
    return '${address.substring(0, 6)}...${address.substring(address.length - 6)}';
  }

  // simple fallback price book for non-selected variants or offline (USD)
}
