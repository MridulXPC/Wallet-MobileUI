// lib/presentation/token_detail/token_detail_screen.dart
import 'dart:async';
import 'dart:convert';
import 'package:cryptowallet/presentation/main_wallet_dashboard/widgets/action_buttons_grid_widget.dart';
import 'package:cryptowallet/presentation/receive_cryptocurrency/receive_cryptocurrency.dart';
import 'package:cryptowallet/services/api_service.dart';
import 'package:cryptowallet/stores/balance_store.dart';
import 'package:cryptowallet/stores/coin_store.dart';
import 'package:cryptowallet/stores/wallet_store.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sizer/sizer.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:web_socket_channel/io.dart';
import 'package:cryptowallet/core/currency_notifier.dart';
import 'package:cryptowallet/core/currency_adapter.dart';
import 'package:cryptowallet/services/api_service.dart' show TxRecord;
import 'package:bip39/bip39.dart' as bip39;

class TokenDetailScreen extends StatefulWidget {
  const TokenDetailScreen({super.key, required this.coinId});
  final String coinId;
  @override
  State<TokenDetailScreen> createState() => _TokenDetailScreenState();
}

class _TokenDetailScreenState extends State<TokenDetailScreen>
    with SingleTickerProviderStateMixin {
  Map<String, dynamic>? tokenData;
  final Set<String> _deletedKeys = {}; // track dismissed wallets

  // ---- live price state (Binance) ----
  WebSocketChannel? _ws;
  StreamSubscription? _wsSub;
  double? _livePrice;

  // 👇 transactions future
  Future<List<TxRecord>>? _txFuture;

  // ---- chart state (CoinGecko) ----
  List<FlSpot> chartData = [];
  bool _chartLoading = false;
  String selectedPeriod = 'LIVE';
  Timer? _reconnectTimer;
  double? _livePriceUsd;
  double? _changePercent24;
  double? _changeAbsUsd24;
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
      _startLiveStream();
      _loadChartFor(selectedPeriod);
      _txFuture = AuthService.fetchTransactionHistoryByWallet(limit: 100);

      // 👇 Add this block — refresh wallet and balance stores
      final bs = context.read<BalanceStore>();
      final walletStore = context.read<WalletStore>();

      Future.microtask(() async {
        await walletStore.loadWalletsFromBackend(); // 🆕
        await bs.refresh(); // 🆕 ensures holdings up to date
        if (mounted) setState(() {});
      });
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

  void _connectKrakenTicker(String pair) {
    try {
      _ws = WebSocketChannel.connect(Uri.parse('wss://ws.kraken.com'));
      _ws!.sink.add(jsonEncode({
        "event": "subscribe",
        "pair": [pair],
        "subscription": {"name": "ticker"}
      }));

      _wsSub = _ws!.stream.listen(
        (raw) {
          try {
            final data = jsonDecode(raw as String);
            if (data is List && data.length > 1 && data[1] is Map) {
              final m = (data[1] as Map).cast<String, dynamic>();
              final lastStr = (m['c'] is List && (m['c'] as List).isNotEmpty)
                  ? '${m['c'][0]}'
                  : null;
              final last = lastStr != null ? double.tryParse(lastStr) : null;

              double? pct;
              double? abs;
              if (m['o'] is List &&
                  (m['o'] as List).length >= 2 &&
                  last != null) {
                final open24 = double.tryParse('${m['o'][1]}');
                if (open24 != null && open24 > 0) {
                  abs = last - open24;
                  pct = (abs / open24) * 100.0;
                }
              }

              if (!mounted) return;
              setState(() {
                if (last != null) _livePriceUsd = last;
                if (pct != null) _changePercent24 = pct;
                if (abs != null) _changeAbsUsd24 = abs;
              });
            }
          } catch (_) {}
        },
        onDone: _scheduleReconnect,
        onError: (_) => _scheduleReconnect(),
        cancelOnError: true,
      );
    } catch (_) {
      _scheduleReconnect();
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

  // Mapping: app symbol -> Binance stream symbol ("btcusdt")
  String? _binanceStreamSymbol(String s) {
    final base = s.toUpperCase();
    const supported = {
      'BTC': 'btcusdt',
      'ETH': 'ethusdt',
      'BNB': 'bnbusdt',
      'SOL': 'solusdt',
      'TRX': 'trxusdt',
      'XMR': 'xmrusdt',
      'USDT': null, // no sense to stream USDT/USDT
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
    _reconnectTimer?.cancel();
    _wsSub?.cancel();
    _ws?.sink.close();

    final streamSym = _binanceStreamSymbol(sym);
    if (streamSym == null) return;

    final url = 'wss://stream.binance.com:9443/ws/$streamSym@ticker';
    debugPrint('🌐 Connecting Binance stream: $url');
    _ws = IOWebSocketChannel.connect(Uri.parse(url));

    _wsSub = _ws!.stream.listen(
      (event) {
        try {
          final data = jsonDecode(event as String) as Map<String, dynamic>;

          // Binance ticker event keys:
          // c = last price, P = percent change, p = absolute change
          final last = double.tryParse(data['c']?.toString() ?? '');
          final changePct = double.tryParse(data['P']?.toString() ?? '');
          final changeAbs = double.tryParse(data['p']?.toString() ?? '');

          if (!mounted) return;

          setState(() {
            if (last != null) {
              _livePrice = last;
              _livePriceUsd = last; // ✅ also update USD price for display
            }
            if (changePct != null) _changePercent24 = changePct;
            if (changeAbs != null) _changeAbsUsd24 = changeAbs;
          });
        } catch (e) {
          debugPrint('⚠️ Binance stream parse error: $e');
        }
      },
      onDone: () {
        debugPrint('🔌 Binance stream closed, reconnecting...');
        _scheduleReconnect();
      },
      onError: (err) {
        debugPrint('❌ Binance stream error: $err');
        _scheduleReconnect();
      },
      cancelOnError: true,
    );
  }

  void _scheduleReconnect() {
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(const Duration(seconds: 3), () {
      if (!mounted) return;
      _connectKrakenTicker('${sym.toUpperCase()}/USD');
    });
  }

  /* ===================== COINGECKO CHART ===================== */

  Future<void> _loadChartFor(String period) async {
    setState(() => _chartLoading = true);

    try {
      final id = _coingeckoIdForSymbol(sym);
      final (days, filterHours) = switch (period) {
        'LIVE' => ('1', 1),
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

      if (points.isEmpty) {
        final p = _livePrice ?? _fallbackPrice;
        final t = DateTime.now().millisecondsSinceEpoch.toDouble();
        points.addAll([
          FlSpot(t - 600000, p * 0.995),
          FlSpot(t - 300000, p * 1.002),
          FlSpot(t, p),
        ]);
      }

      // Normalize X to 0..N
      final t0 = points.first.x;
      final norm = <FlSpot>[];
      for (final s in points) {
        norm.add(FlSpot((s.x - t0) / 1000.0, s.y));
      }

      if (!mounted) return;
      setState(() {
        chartData = norm;
        _chartLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _chartLoading = false);
    }
  }

  /* ===================== UI ===================== */

  void _onPeriodSelected(String period) {
    setState(() => selectedPeriod = period);
    HapticFeedback.selectionClick();
    _loadChartFor(period);
  }

  // --------------------- Receive handling ---------------------

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
                  flex: 1,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      _buildTokenPriceDisplay(fx),
                      SizedBox(height: 4), // tighter
                      Flexible(
                        flex: 1,
                        child: Padding(
                          padding: EdgeInsets.symmetric(horizontal: 3.w),
                          child: _buildPriceChart(),
                        ),
                      ),
                      SizedBox(height: 2),
                      _buildTimePeriodSelector(),
                      SizedBox(height: 4),
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 5.w),
                        child: ActionButtonsGridWidget(
                          isLarge: isLarge,
                          isTablet: isTablet,
                          coinId: _coinId,
                          onReceive: _openReceive,
                        ),
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
                      _buildHoldingsTab(
                          fx), // 👈 updated with Create Wallet btn
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
        height: 46, // 🔽 reduced from 56
        child: Stack(
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: IconButton(
                icon: const Icon(Icons.arrow_back_ios_new_rounded,
                    color: Colors.white, size: 16), // 🔽 slightly smaller
                splashRadius: 18,
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
                      width: 26,
                      height: 26,
                      fit: BoxFit.cover,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(sym,
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 17,
                              fontWeight: FontWeight.w600)),
                      Text('COIN | $name',
                          style: const TextStyle(
                              color: greyColor, fontSize: 11, height: 1.1)),
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

  Widget _buildTokenPriceDisplay(FxAdapter fx) {
    // Show nothing until first live or fallback data ready
    final hasLive = _livePrice != null || _livePriceUsd != null;
    final price = _livePrice ?? _livePriceUsd ?? _fallbackPrice;
    final changePct = _changePercent24 ?? 0.0;
    final changeAbs = _changeAbsUsd24 ?? 0.0;
    final isUp = changePct >= 0;

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 4.w),
      child: hasLive
          ? Column(
              children: [
                Text(
                  '\$${price.toStringAsFixed(2)}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 30,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                SizedBox(height: 0.8.h),
                Text(
                  '${isUp ? '+' : ''}${changePct.toStringAsFixed(2)}% '
                  '(${isUp ? '+' : ''}\$${changeAbs.toStringAsFixed(2)})',
                  style: TextStyle(
                    color: isUp ? Colors.greenAccent : Colors.redAccent,
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            )
          : const Center(
              child: Padding(
                padding: EdgeInsets.only(top: 16),
                child: Text(
                  'Fetching live price...',
                  style: TextStyle(color: Colors.white70, fontSize: 16),
                ),
              ),
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

    return SizedBox(
      height: 160, // 🔼 taller, shows chart clearly
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
              barWidth: 2.5, // 🔽 thinner stroke
              isStrokeCapRound: true,
              dotData: FlDotData(show: false),
              belowBarData: BarAreaData(
                show: true,
                gradient: LinearGradient(
                  colors: [
                    greenColor.withOpacity(0.3),
                    Colors.transparent,
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
            ),
          ],
          minY: minY,
          maxY: maxY,
        ),
      ),
    );
  }

// ------------------ Holdings tab ------------------
  Widget _buildHoldingsTab(FxAdapter fx) {
    final items = _buildCoinHoldings(fx);

    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
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
                ...items,
                SizedBox(height: 12.h), // space above bottom button
              ],
            ),
          ),
        ),
        // 👇 fixed bottom button
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(
              vertical: 10, horizontal: 16), // 🔽 smaller
          decoration: const BoxDecoration(
            color: Color(0xFF0B0D1A),
            border: Border(
              top: BorderSide(color: Color(0xFF1E1E1E), width: 1),
            ),
          ),
          child: _buildCreateWalletButton(context),
        ),
      ],
    );
  }

  List<Widget> _buildCoinHoldings(FxAdapter fx) {
    final bs = context.watch<BalanceStore>();
    final walletStore = context.watch<WalletStore>();
    final store = context.read<CoinStore>();

    final wantedSym = sym.toUpperCase();

    // 🧩 Log wallet store state
    debugPrint(
        '🟢 WalletStore has ${walletStore.wallets.length} wallets loaded');
    for (final w in walletStore.wallets) {
      debugPrint('   → walletId=${w.id}, chains=${w.chains.length}');
    }

    debugPrint(
        '🟢 BalanceStore rows = ${bs.rows.length}, loading=${bs.loading}');

    // ✅ Prefer balance store data if non-empty
    List<Widget> holdings = [];

    if (bs.rows.isNotEmpty) {
      final rowsForCoin = bs.rows.where((r) {
        final s = (r.symbol.isNotEmpty
                ? r.symbol
                : (r.token.isNotEmpty ? r.token : r.blockchain))
            .toUpperCase();
        return s == wantedSym || s.startsWith('$wantedSym ');
      }).toList();

      debugPrint(
          '✅ Found ${rowsForCoin.length} rows in BalanceStore for $wantedSym');

      if (rowsForCoin.isNotEmpty) {
        holdings = rowsForCoin.map((r) {
          final chainNorm = _normalizeChain(r.blockchain.toUpperCase());
          final balance = double.tryParse(r.balance) ?? 0.0;
          final usd = (r.value ?? 0.0);
          final nickname = (r.nickname ?? '').trim();

          final coinIdGuess = switch (wantedSym) {
            'USDT' => 'USDT-$chainNorm',
            'BTC' => chainNorm == 'LN' ? 'BTC-LN' : 'BTC',
            _ => '$wantedSym-$chainNorm',
          };

          final coinForIcon =
              store.getById(coinIdGuess) ?? store.getById(wantedSym);
          final icon =
              coinForIcon?.assetPath ?? 'assets/currencyicons/bitcoin.png';

          final baseTitle = coinForIcon?.name ??
              (wantedSym == 'USDT'
                  ? 'USDT (${_chainUiName(chainNorm)})'
                  : '$wantedSym (${_chainUiName(chainNorm)})');
          final title =
              nickname.isNotEmpty ? '$baseTitle ($nickname)' : baseTitle;

          final networkSubtitle = wantedSym == 'USDT'
              ? '${_networkShort(chainNorm)} • ${_chainUiName(chainNorm)} Network'
              : '${_chainUiName(chainNorm)} Network';

          return _buildHoldingCard(
            icon: icon,
            title: title,
            networkSubtitle: networkSubtitle,
            balance: balance,
            usd: usd,
            symbol: wantedSym,
            nickname: nickname,
            chain: chainNorm,
          );
        }).toList();
      }
    }

    // ✅ Fallback to WalletStore if BalanceStore empty or incomplete
    if (holdings.isEmpty && walletStore.wallets.isNotEmpty) {
      final allChains =
          walletStore.wallets.expand((w) => w.chains).toList(growable: false);
      debugPrint(
          '⚡ Fallback: ${allChains.length} total chains across all wallets');

      final chains = allChains.where((c) {
        final symbol = (c.symbol).toString().toUpperCase();
        final chainCode = (c.chain).toString().toUpperCase();
        return symbol == wantedSym || chainCode == wantedSym;
      }).toList();

      debugPrint(
          '⚡ Found ${chains.length} $wantedSym chains in WalletStore fallback');

      holdings = chains.map((chain) {
        final chainCode = (chain.blockchain).toUpperCase();
        final nickname = (chain.nickname ?? '').trim();
        final balance = double.tryParse(chain.balance) ?? 0.0;
        final usd = chain.value ?? 0.0;

        final coinForIcon =
            store.getById('$wantedSym-$chainCode') ?? store.getById(wantedSym);
        final icon =
            coinForIcon?.assetPath ?? 'assets/currencyicons/bitcoin.png';
        final baseTitle =
            coinForIcon?.name ?? '$wantedSym (${_chainUiName(chainCode)})';
        final title =
            nickname.isNotEmpty ? '$baseTitle ($nickname)' : baseTitle;
        final networkSubtitle =
            '${_networkShort(chainCode)} • ${_chainUiName(chainCode)} Network';

        return _buildHoldingCard(
          icon: icon,
          title: title,
          networkSubtitle: networkSubtitle,
          balance: balance,
          usd: usd,
          symbol: wantedSym,
          nickname: nickname,
          chain: chainCode,
        );
      }).toList();
    }

    // ✅ Final fallback — default templates
// ✅ Final fallback — default templates
    if (holdings.isEmpty) {
      debugPrint(
          '⚠️ No holdings found for $wantedSym, showing default template.');
      final defaultChains = switch (wantedSym) {
        'BTC' => ['BTC', 'LN'],
        'USDT' => ['ETH', 'TRX', 'GASFREE'],
        _ => ['MAIN'],
      };

      holdings = defaultChains.map((chainCode) {
        final icon = store.getById('$wantedSym-$chainCode')?.assetPath ??
            store.getById(wantedSym)?.assetPath ??
            'assets/currencyicons/bitcoin.png';

        final title = wantedSym == 'USDT'
            ? 'USDT (${_chainUiName(chainCode)})'
            : '$wantedSym (${_chainUiName(chainCode)})';

        final networkSubtitle = wantedSym == 'USDT'
            ? '${_networkShort(chainCode)} • ${_chainUiName(chainCode)} Network'
            : '${_chainUiName(chainCode)} Network';

        // 👇  No address here, just use chainCode to make the key unique
        return _buildHoldingCard(
          icon: icon,
          title: title,
          networkSubtitle: networkSubtitle,
          balance: 0.0,
          usd: 0.0,
          symbol: wantedSym,
          nickname: null,
          chain: chainCode,
          address: chainCode, // <- safe unique id
        );
      }).toList();
    }

    return holdings;
  }

  Widget _buildHoldingCard({
    required String icon,
    required String title,
    required String networkSubtitle,
    required double balance,
    required double usd,
    required String symbol,
    String? nickname,
    String? chain,
    String? address,
    String? walletId, // 👈 optional backend wallet ID
  }) {
    // ✅ Always generate a unique fallback key
    final safeUnique = address?.isNotEmpty == true
        ? address!
        : (walletId ?? Object.hash(symbol, chain, nickname).toString());

    final keyValue = '${symbol}_${chain ?? ''}_${nickname ?? ''}_$safeUnique'
        .replaceAll(' ', '_')
        .trim();

    if (_deletedKeys.contains(keyValue)) return const SizedBox.shrink();

    return Dismissible(
      key: ValueKey(keyValue), // ✅ now guaranteed unique
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        color: Colors.redAccent.withOpacity(0.9),
        child: const Icon(Icons.delete_forever, color: Colors.white, size: 28),
      ),
      confirmDismiss: (_) async {
        if (nickname == null || nickname.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Main wallet cannot be deleted'),
            backgroundColor: Colors.orange,
          ));
          return false;
        }
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: const Color(0xFF1A1A1A),
            title: const Text('Delete Wallet',
                style: TextStyle(color: Colors.white)),
            content: Text(
              'Are you sure you want to delete “$nickname”?',
              style: const TextStyle(color: Colors.white70, fontSize: 14),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child:
                    const Text('Cancel', style: TextStyle(color: Colors.grey)),
              ),
              ElevatedButton(
                style:
                    ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Delete'),
              ),
            ],
          ),
        );
        return confirmed ?? false;
      },
      onDismissed: (_) async {
        _deletedKeys.add(keyValue);
        setState(() {});
        if (nickname != null && nickname.isNotEmpty) {
          await _deleteChainWallet(context, nickname);
        }
      },
      child: Container(
        margin: EdgeInsets.only(bottom: 2.h),
        padding: EdgeInsets.all(3.w),
        decoration: BoxDecoration(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(8),
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
                errorBuilder: (_, __, ___) => const Icon(Icons.currency_bitcoin,
                    color: Colors.orangeAccent),
              ),
            ),
            SizedBox(width: 3.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Flexible(
                        child: Text(
                          title,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                      Text(
                        '${_formatCrypto(balance)} $symbol',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 0.6.h),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        networkSubtitle,
                        style: const TextStyle(
                            color: Color(0xFF8E8E8E), fontSize: 13),
                      ),
                      Text(
                        FxAdapter(context.read<CurrencyNotifier>())
                            .formatFromUsd(usd),
                        style: const TextStyle(
                            color: Color(0xFF8E8E8E), fontSize: 14),
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

  Future<void> _deleteChainWallet(BuildContext context, String nickname) async {
    // ✅ Load walletId from storage
    final prefs = await SharedPreferences.getInstance();
    final walletId = prefs.getString('wallet_id');

    if (walletId == null || walletId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('❌ No wallet ID found. Please log in again.'),
        backgroundColor: Colors.redAccent,
      ));
      return;
    }

    // 🔹 Show loader dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(
        child: CircularProgressIndicator(color: Color(0xFF00D4AA)),
      ),
    );

    // 🔹 Call API
    final result = await AuthService.deleteSingleChainWallet(
      walletId: walletId,
      nickname: nickname,
    );

    // Close loader
    Navigator.pop(context);

    if (result.success) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('✅ Wallet “$nickname” deleted successfully'),
        backgroundColor: Colors.green,
      ));

      // 🔄 Refresh both stores
      final bs = context.read<BalanceStore>();
      final walletStore = context.read<WalletStore>();
      await walletStore.loadWalletsFromBackend(); // 🆕
      await bs.refresh(); // 🆕

      if (mounted) setState(() {});
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('❌ ${result.message ?? 'Failed to delete wallet'}'),
        backgroundColor: Colors.redAccent,
      ));
    }
  }

  /* ---------- small helpers ---------- */
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

  /* ===================== HISTORY TAB ===================== */

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
                        limit: 100,
                      );
                    });
                  },
                  child: const Text('Retry'),
                ),
              ],
            ),
          );
        }

        final all = snap.data ?? const <TxRecord>[];

        final wanted = sym.toUpperCase();
        final filtered =
            all.where((t) => (t.token ?? '').toUpperCase() == wanted).toList();

        filtered.sort((a, b) => (b.createdAt ??
                DateTime.fromMillisecondsSinceEpoch(0))
            .compareTo(a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0)));

        return SingleChildScrollView(
          child: _buildTransactionsSection(filtered),
        );
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

  Widget _buildTransactionItemTx(TxRecord tx) {
    final type = (tx.type ?? '').toUpperCase();
    final status = (tx.status ?? '').toUpperCase();
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

  // ------------------ About tab ------------------
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
                _buildStatRow('Market Cap', tokenData?['marketCap'] ?? r'$'),
                _buildStatRow('24h Volume', tokenData?['volume24h'] ?? r'$'),
                _buildStatRow(
                    'Circulating Supply', tokenData?['circulating'] ?? '—'),
                _buildStatRow('Volume / Market Cap',
                    tokenData?['Volume / Market Cap'] ?? '%'),
                _buildStatRow(
                    'All time high', tokenData?['All time high'] ?? '\$'),
                _buildStatRow(
                    'All time low', tokenData?['All time low'] ?? '\$'),
                _buildStatRow(
                    'Fully diluted', tokenData?['Fully diluted'] ?? '\$'),
              ],
            ),
          ),
          SizedBox(height: 3.h),
          Container(
            padding: EdgeInsets.all(4.w),
            decoration: BoxDecoration(
              color: Colors.transparent,
              border: Border.all(color: greyColor, width: 1),
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

  String _timeAgoFromDate(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inSeconds < 60) return '${diff.inSeconds}s ago';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays == 1) return 'Yesterday';
    if (diff.inDays < 30) return '${diff.inDays} days ago';
    return '${dt.day.toString().padLeft(2, '0')} ${_month3(dt.month)} ${dt.year}';
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

  /* ===================== CREATE WALLET FLOW ===================== */

  // ✅ Floating button on Holdings tab
  Widget _buildCreateWalletButton(BuildContext context) {
    return Center(
      child: ElevatedButton.icon(
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF00D4AA),
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
        icon: const Icon(Icons.add_rounded, size: 20),
        label: Text(
          'Create ${sym.toUpperCase()} Wallet',
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        onPressed: () => _onCreateWalletPressed(context),
      ),
    );
  }

  // 🔹 Entry point
  void _onCreateWalletPressed(BuildContext context) {
    final current = sym.toUpperCase();
    if (current == 'BTC') {
      _showChainSheet(
        context,
        coin: 'BTC',
        options: [
          {'name': 'Bitcoin (Native SegWit)', 'chain': 'BTC'},
          {'name': 'Lightning Network', 'chain': 'LN'},
        ],
      );
    } else if (current == 'USDT') {
      _showChainSheet(
        context,
        coin: 'USDT',
        options: [
          {'name': 'Ethereum (ERC-20)', 'chain': 'ETH'},
          {'name': 'Tron (TRC-20)', 'chain': 'TRX'},
          {'name': 'Gas-Free Network', 'chain': 'GASFREE'},
        ],
      );
    } else {
      _showNicknameSheet(context, current, current);
    }
  }

  // 🔹 Ask nickname (bottom-sheet style)
  void _showNicknameSheet(BuildContext context, String coin, String chain) {
    final ctrl = TextEditingController();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1A1A1A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding:
            EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom + 24),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 14),
              decoration: BoxDecoration(
                color: Colors.grey[700],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Text('Name Your $coin Wallet',
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w700)),
            const SizedBox(height: 20),
            TextField(
              controller: ctrl,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                hintText: 'Enter a name (e.g. Trading Wallet)',
                hintStyle: TextStyle(color: Colors.grey),
                enabledBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: Colors.grey)),
                focusedBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: Colors.white)),
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00D4AA),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 32, vertical: 12)),
              onPressed: () {
                final name = ctrl.text.trim();
                if (name.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                      content: Text('Please enter a wallet name'),
                      backgroundColor: Colors.orange));
                  return;
                }
                Navigator.pop(ctx);
                _showMnemonicSheet(context, coin, chain, name);
              },
              child: const Text('Next'),
            ),
          ]),
        ),
      ),
    );
  }

  // 🔹 Show mnemonic + confirm (bottom-sheet)
  void _showMnemonicSheet(
      BuildContext context, String coin, String chain, String nickname) {
    final mnemonic = bip39.generateMnemonic();
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A1A1A),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding:
            EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom + 24),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 14),
              decoration: BoxDecoration(
                color: Colors.grey[700],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Text('Create $coin Wallet ($chain)',
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w700)),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.black26,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(mnemonic,
                  style: const TextStyle(color: Colors.white, height: 1.5)),
            ),
            const SizedBox(height: 10),
            const Text(
              '⚠️ Store these words safely — they restore your wallet.',
              style: TextStyle(
                  color: Colors.orangeAccent, fontSize: 13, height: 1.4),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00D4AA),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 32, vertical: 12)),
              onPressed: () async {
                Navigator.pop(ctx);
                await _createWallet(context, mnemonic, chain, nickname);
              },
              child: const Text('Confirm'),
            ),
          ]),
        ),
      ),
    );
  }

  // 🔹 Modern bottom-sheet selector (only BTC / USDT)
  void _showChainSheet(BuildContext context,
      {required String coin, required List<Map<String, String>> options}) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A1A1A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 14),
                decoration: BoxDecoration(
                  color: Colors.grey[700],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Text('Select ${coin.toUpperCase()} Chain',
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w700)),
              const SizedBox(height: 20),
              for (final o in options)
                InkWell(
                  onTap: () {
                    Navigator.pop(ctx);
                    _showNicknameSheet(context, coin, o['chain']!);
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 14),
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2A2A2A),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: Colors.white.withOpacity(0.08), width: 1),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.circle,
                            color: Color(0xFF00D4AA), size: 10),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(o['name']!,
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w500)),
                        ),
                        const Icon(Icons.arrow_forward_ios_rounded,
                            color: Colors.grey, size: 16),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

// 🔹 API call + refresh
  Future<void> _createWallet(
    BuildContext context,
    String mnemonic,
    String chain,
    String nickname,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final walletId = prefs.getString('wallet_id');
    if (walletId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('No wallet ID found – please log in again.'),
        backgroundColor: Colors.redAccent,
      ));
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(
        child: CircularProgressIndicator(color: Color(0xFF00D4AA)),
      ),
    );

    final result = await AuthService.createSingleChainWallet(
      mnemonic: mnemonic,
      chain: chain,
      walletId: walletId,
      nickname: nickname,
    );

    Navigator.pop(context); // close loader

    final bs = context.read<BalanceStore>();

    if (result.success && result.data != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('✅ $chain wallet “$nickname” created successfully!'),
        backgroundColor: Colors.green,
      ));

      // ✅ 1️⃣ Instantly add the new chain wallet to holdings
      await bs.addTempChainFromResponse(result.data!);

      // ✅ 2️⃣ Optional delayed refresh to sync USD balances from backend
      Future.delayed(const Duration(seconds: 3), () => bs.refresh());

      // ✅ 3️⃣ Force UI rebuild of holdings tab
      if (mounted) setState(() {});
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('❌ ${result.message ?? 'Failed to create wallet'}'),
        backgroundColor: Colors.red,
      ));
    }
  }
}
