// lib/presentation/token_detail/token_detail_screen.dart
import 'dart:async';
import 'dart:convert';
import 'package:cryptowallet/presentation/main_wallet_dashboard/widgets/action_buttons_grid_widget.dart';
import 'package:cryptowallet/presentation/receive_cryptocurrency/receive_cryptocurrency.dart';
import 'package:cryptowallet/stores/coin_store.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:sizer/sizer.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:web_socket_channel/io.dart';

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
  double? _livePrice; // last price
  double? _liveChangePercent; // 24h % change (+/-)
  String? _liveChangeAbs; // optional abs change text if available

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

  // Fallbacks if no live stream yet
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
      if (res.statusCode != 200)
        throw Exception('Chart HTTP ${res.statusCode}');
      final map = jsonDecode(res.body) as Map<String, dynamic>;
      final List prices = (map['prices'] as List?) ?? const [];

      final nowMs = DateTime.now().millisecondsSinceEpoch;
      final cutoffMs =
          (filterHours != null) ? nowMs - (filterHours * 60 * 60 * 1000) : null;

      final points = <FlSpot>[];
      for (final row in prices) {
        if (row is! List || row.length < 2) continue;
        final ts = (row[0] as num).toInt();
        final price = (row[1] as num).toDouble();
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
        chartData = norm;
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

// In TokenDetailScreenState
// In _TokenDetailScreenState
  String get _coinId {
    // Prefer explicit coin id from the navigation args/payload, if present
    final explicit = tokenData?['coinId']?.toString();
    if (explicit != null && explicit.isNotEmpty) return explicit.toUpperCase();

    // Then the constructor param (this is the reliable one)
    if (widget.coinId.isNotEmpty) return widget.coinId.toUpperCase();

    // Last resort: derive from symbol + chain text
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

// TokenDetailScreen: replace your _openReceive() with this
  void _openReceive() {
    final id = _coinId; // e.g. BTC, BTC-LN, USDT-TRX, SOL-SOL
    // Prefer CoinStore's display name; otherwise fallback to the symbol
    final coin = context.read<CoinStore>().getById(id);
    final pretty = coin?.name ?? sym; // <-- use sym, not tokenData['name']

    final String? mode =
        id.contains('-LN') ? 'ln' : (id.startsWith('BTC') ? 'onchain' : null);

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ReceiveQR(
          title: 'Your address to receive $pretty',
          address: '', // let ReceiveQR resolve from wallet
          coinId: id, // pass a VALID coin id (BTC, BTC-LN, USDT-TRX…)
          mode: mode, // 'ln' / 'onchain' / null
          minSats: (mode == 'onchain' && id.startsWith('BTC')) ? 25000 : null,
        ),
      ),
    );
  }

  // --------------------- UI ---------------------
  @override
  Widget build(BuildContext context) {
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
                      _buildTokenPriceDisplay(),
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
                      _buildHoldingsTab(),
                      _buildHistoryTab(),
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

  Widget _buildTokenPriceDisplay() {
    final price = _livePrice ?? _fallbackPrice;
    final pct = _liveChangePercent;
    final isUp = (pct ?? 0) >= 0
        ? (_liveChangePercent != null ? true : _fallbackChangePositive)
        : false;
    final changeClr = isUp ? greenColor : Colors.redAccent;

    final pctText = (pct != null)
        ? '${pct >= 0 ? '+' : ''}${pct.toStringAsFixed(2)}%'
        : _fallbackChangeText;

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 4.w),
      child: Column(
        children: [
          Text(
            '\$${price.toStringAsFixed(2)}',
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
                    ? '${_liveChangeAbs!.startsWith('-') ? '' : '+'}\$${double.tryParse(_liveChangeAbs!)?.toStringAsFixed(2) ?? _liveChangeAbs} ($pctText)'
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
          titlesData: FlTitlesData(show: false),
          borderData: FlBorderData(show: false),
          lineBarsData: [
            LineChartBarData(
              spots: spots,
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

  // ------------------ Holdings tab (unchanged UI) ------------------
  Widget _buildHoldingsTab() {
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
          ..._buildCoinHoldings(),
        ],
      ),
    );
  }

  List<Widget> _buildCoinHoldings() {
    final store = context.read<CoinStore>();

    List<Map<String, dynamic>> rows;
    if (sym.toUpperCase() == 'USDT') {
      final usdt = store.getById('USDT');
      final usdtEth = store.getById('USDT-ETH');
      final usdtTrx = store.getById('USDT-TRX');

      rows = [
        _variantRow(
          id: 'USDT-ETH',
          name: 'USDT (Ethereum)',
          network: 'ERC-20 • Ethereum Network',
          iconPath: usdtEth?.assetPath,
          fallbackIcon: Icons.monetization_on,
          fallbackColor: Colors.green,
        ),
        _variantRow(
          id: 'USDT-TRX',
          name: 'USDT (Tron)',
          network: 'TRC-20 • Tron Network',
          iconPath: usdtTrx?.assetPath,
          fallbackIcon: Icons.monetization_on,
          fallbackColor: Colors.green,
        ),
        _variantRow(
          id: 'USDT-GASFREE',
          name: 'USDT (Gas Free)',
          network: 'USDT',
          iconPath: usdt?.assetPath,
          fallbackIcon: Icons.local_gas_station,
          fallbackColor: Colors.green,
          borderColor: Colors.green,
        ),
      ];
    } else if (sym.toUpperCase() == 'SOL') {
      final solSol = store.getById('SOL-SOL');
      rows = [
        _variantRow(
          id: 'SOL-SOL',
          name: 'Solana',
          network: 'Solana Network',
          iconPath: solSol?.assetPath,
          fallbackIcon: Icons.currency_bitcoin,
          fallbackColor: Colors.orange,
        ),
      ];
    } else if (sym.toUpperCase() == 'TRX') {
      final trxTrx = store.getById('TRX-TRX');
      rows = [
        _variantRow(
          id: 'TRX-TRX',
          name: 'Tron',
          network: 'Tron Network',
          iconPath: trxTrx?.assetPath,
          fallbackIcon: Icons.currency_bitcoin,
          fallbackColor: Colors.orange,
        ),
      ];
    } else if (sym.toUpperCase() == 'XMR') {
      final xmrXmr = store.getById('XMR-XMR');
      rows = [
        _variantRow(
          id: 'XMR-XMR',
          name: 'Monero',
          network: 'Monero Network',
          iconPath: xmrXmr?.assetPath,
          fallbackIcon: Icons.currency_bitcoin,
          fallbackColor: Colors.orange,
        ),
      ];
    } else if (sym.toUpperCase() == 'ETH') {
      final ethEth = store.getById('ETH-ETH');
      rows = [
        _variantRow(
          id: 'ETH-ETH',
          name: 'Ethereum',
          network: 'Ethereum Network',
          iconPath: ethEth?.assetPath,
          fallbackIcon: Icons.currency_bitcoin,
          fallbackColor: Colors.blue,
        ),
      ];
    } else if (sym.toUpperCase() == 'BTC') {
      final btc = store.getById('BTC');
      final btcLn = store.getById('BTC-LN');
      rows = [
        _variantRow(
          id: 'BTC',
          name: 'Bitcoin',
          network: 'Bitcoin Network',
          iconPath: btc?.assetPath,
          fallbackIcon: Icons.currency_bitcoin,
          fallbackColor: Colors.orange,
        ),
        _variantRow(
          id: 'BTC-LN',
          name: 'Bitcoin Lightning',
          network: 'Lightning Network',
          iconPath: btcLn?.assetPath,
          fallbackIcon: Icons.flash_on,
          fallbackColor: Colors.yellow,
        ),
      ];
    } else {
      final bnbbnb = store.getById('BNB-BNB');
      rows = [
        _variantRow(
          id: 'BNB',
          name: 'BNB-BNB',
          network: 'BNB Chain',
          iconPath: bnbbnb?.assetPath,
          fallbackIcon: Icons.currency_bitcoin,
          fallbackColor: Colors.orange,
        ),
      ];
    }

    return rows.map<Widget>((v) {
      final bool isGasFree = (v['id'] == 'USDT-GASFREE');
      final Color outline = isGasFree
          ? (v['borderColor'] as Color? ?? const Color(0xFF22C55E))
          : Colors.white.withOpacity(0.1);

      return Container(
        margin: EdgeInsets.only(bottom: 2.h),
        padding: EdgeInsets.all(3.w),
        decoration: BoxDecoration(
          color: cardBackground,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: outline,
            width: isGasFree ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: (v['icon'] as String?)?.isNotEmpty == true
                  ? Image.asset(
                      v['icon'],
                      width: 40,
                      height: 40,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Icon(
                        v['fallbackIcon'],
                        color: v['iconColor'],
                        size: 32,
                      ),
                    )
                  : Icon(
                      v['fallbackIcon'],
                      color: v['iconColor'],
                      size: 32,
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
                        v['name'],
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        _getVariantBalance(v['id']),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 0.5.h),
                  // network + fiat value
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        v['network'],
                        style: const TextStyle(
                          color: greyColor,
                          fontSize: 13,
                        ),
                      ),
                      Text(
                        _getVariantFiatValue(v['id']),
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

  Map<String, dynamic> _variantRow({
    required String id,
    required String name,
    required String network,
    required IconData fallbackIcon,
    required Color fallbackColor,
    String? iconPath,
    Color? borderColor,
  }) {
    return {
      'id': id,
      'name': name,
      'network': network,
      'icon': iconPath ?? '',
      'fallbackIcon': fallbackIcon,
      'iconColor': fallbackColor,
      'borderColor': borderColor,
    };
  }

  // Balance strings (demo)
  String _getVariantBalance(String variantId) {
    switch (variantId) {
      case 'USDT-ETH':
        return '1,250.50 USDT';
      case 'USDT-TRX':
        return '850.25 USDT';
      case 'BTC':
        return '0.02145678 BTC';
      case 'BTC-LN':
        return '0.00567890 BTC';
      default:
        return '0.00000000 $sym';
    }
  }

  // Fiat value = parsed balance * (live price when available)
  String _getVariantFiatValue(String variantId) {
    final raw = _getVariantBalance(variantId);
    final amountStr = (raw.split(' ').isNotEmpty ? raw.split(' ').first : '0')
        .replaceAll(',', '');
    final amount = double.tryParse(amountStr) ?? 0.0;

    // Prefer live price if this variant matches the selected coin
    final p = (variantId.startsWith(sym))
        ? (_livePrice ?? _fallbackPrice)
        : _dummyPrices[variantId] ?? _dummyPrices[sym] ?? _fallbackPrice;

    final usd = amount * p;
    return '\$${usd.toStringAsFixed(2)}';
  }

  // ------------------ History tab (demo) ------------------
  Map<String, List<Map<String, dynamic>>> get dummyTransactions => {
        'BTC': [
          {
            'id': 'btc_send_1',
            'type': 'send',
            'status': 'Confirmed',
            'amount': '0.004256',
            'coin': 'BTC',
            'dateTime': '20 Aug 2025 10:38:50',
            'from': 'bc1q07...eyla0f',
            'to': 'bc1qkv...sft0rz',
          },
        ],
        'ETH': [
          {
            'id': 'eth_send_1',
            'type': 'send',
            'status': 'Confirmed',
            'amount': '2.5',
            'coin': 'ETH',
            'dateTime': '21 Aug 2025 16:45:12',
            'from': '0x742d...F8H',
            'to': '0x1234...5678',
          },
        ],
      };

  Widget _buildHistoryTab() {
    return SingleChildScrollView(child: _buildTransactionsSection());
  }

  Widget _buildTransactionsSection() {
    final transactions = dummyTransactions[sym.toUpperCase()] ?? [];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 24),
        if (transactions.isNotEmpty)
          ...transactions.map(_buildTransactionItem)
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

  Widget _buildTransactionItem(Map<String, dynamic> tx) {
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
            child: Icon(_getTransactionTypeIcon(tx['type']),
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
                          tx['status'],
                          style: TextStyle(
                            color: _getStatusColor(tx['status']),
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _getTransactionTypeLabel(tx['type']),
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
                          _getTimeAgo(tx['dateTime']),
                          style: const TextStyle(
                            color: Color(0xFF6B7280),
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${tx["amount"]} ${_getCoinSymbol(tx["coin"])}',
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
                    Expanded(
                      child: _kvSmall(
                          'From:', _shortenAddress(tx['from'] ?? 'Unknown')),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _kvSmall(
                          'To:', _shortenAddress(tx['to'] ?? 'Unknown'),
                          end: true),
                    ),
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
              color: cardBackground,
              borderRadius: BorderRadius.circular(16),
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

  IconData _getTransactionTypeIcon(String type) {
    switch (type) {
      case 'send':
        return Icons.send;
      case 'receive':
        return Icons.arrow_downward;
      case 'swap':
        return Icons.swap_horiz;
      default:
        return Icons.account_balance_wallet;
    }
  }

  String _getTransactionTypeLabel(String type) {
    switch (type) {
      case 'send':
        return 'Send';
      case 'receive':
        return 'Received';
      case 'swap':
        return 'Swap';
      default:
        return 'Transaction';
    }
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'confirmed':
        return Colors.green;
      case 'pending':
        return Colors.orange;
      case 'failed':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  String _shortenAddress(String address) {
    if (address.length <= 12) return address;
    return '${address.substring(0, 6)}...${address.substring(address.length - 6)}';
  }

  // simple fallback price book for non-selected variants or offline
  static const Map<String, double> _dummyPrices = {
    "BTC": 43825.67,
    "BTC-LN": 43825.67,
    "ETH": 2641.25,
    "ETH-ETH": 2641.25,
    "USDT": 1.00,
    "USDT-ETH": 1.00,
    "USDT-TRX": 1.00,
    "BNB": 575.42,
    "BNB-BNB": 575.42,
    "SOL": 148.12,
    "SOL-SOL": 148.12,
    "TRX": 0.13,
    "TRX-TRX": 0.13,
    "XMR": 165.50,
    "XMR-XMR": 165.50,
  };
}
