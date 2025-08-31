// lib/presentation/token_detail/token_detail_screen.dart
import 'package:cryptowallet/coin_store.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:provider/provider.dart';
import 'package:sizer/sizer.dart';

class TokenDetailScreen extends StatefulWidget {
  const TokenDetailScreen({super.key});

  @override
  State<TokenDetailScreen> createState() => _TokenDetailScreenState();
}

class _TokenDetailScreenState extends State<TokenDetailScreen>
    with SingleTickerProviderStateMixin {
  Map<String, dynamic>? tokenData;
  String selectedPeriod = 'LIVE';
  bool isBookmarked = false;
  List<FlSpot> chartData = [];
  late TabController _tabController;

  final List<String> timePeriods = ['LIVE', '4H', '1D', '1W', '1M', 'MAX'];
  final List<String> tabs = ['Holdings', 'History', 'About'];

  // Dark theme colors
  static const Color darkBackground = Color(0xFF0A0A0A);
  static const Color cardBackground = Color(0xFF1A1A1A);
  static const Color greenColor = Color(0xFF00D4AA);
  static const Color greyColor = Color(0xFF8E8E8E);
  static const Color lightGreyColor = Color(0xFFB8B8B8);

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: tabs.length, vsync: this);
    _generateMockChartData();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final args =
        ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    if (args != null) {
      setState(() => tokenData = args);
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // --------- Dummy transactions (by coin symbol) -------------
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
            'hash':
                'e275b987f6c5b8e715e01461d8fae15dc4f5ae9e9ec178a65bc2173cabfded5b',
            'block': 910917,
            'feeDetails': {'Total Fee': '0.00000378 BTC'},
          },
          {
            'id': 'btc_receive_1',
            'type': 'receive',
            'status': 'Confirmed',
            'amount': '0.0046011',
            'coin': 'BTC',
            'dateTime': '18 Aug 2025 14:22:15',
            'from': 'bc1q89...xyz123',
            'to': 'bc1q07...eyla0f',
            'hash':
                'a1b2c3d4e5f6789012345678901234567890abcdef1234567890abcdef123456',
            'block': 910815,
            'feeDetails': {'Total Fee': '0.00000245 BTC'},
          },
          {
            'id': 'btc_swap_1',
            'type': 'swap',
            'status': 'Confirmed',
            'amount': '0.002',
            'coin': 'BTC',
            'dateTime': '17 Aug 2025 09:15:30',
            'hash':
                'swap123456789abcdef123456789abcdef123456789abcdef123456789abcdef',
            'swapDetails': {
              'fromCoin': 'ETH',
              'fromAmount': '1.25',
              'toCoin': 'BTC',
              'toAmount': '0.002',
              'rate': '0.0016',
              'swapId': 'SWAP_BTC_001'
            },
            'feeDetails': {'Swap Fee': '0.5%', 'Network Fee': '0.00001 BTC'},
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
            'hash': '0xeth1234...89abcdef',
            'block': 18245673,
            'feeDetails': {
              'Gas Used': '21,000',
              'Gas Price': '25 Gwei',
              'Total Fee': '0.000525 ETH',
            },
          },
        ],
        'USDT': [
          {
            'id': 'usdt_send_1',
            'type': 'send',
            'status': 'Confirmed',
            'amount': '50.332725',
            'coin': 'USDT',
            'dateTime': '09 Aug 2025 06:01:48',
            'from': 'TAJ6r4...t372GF',
            'to': 'TBmLQS...LFGABn',
            'hash': '72c2e0...d55429',
            'block': 74680192,
            'feeDetails': {'Bandwidth Fee': '0.0', 'Total Fee': '13.84485 TRX'},
          },
        ],
      };

  // ---------- conveniences with safe fallbacks ----------
  String get sym => (tokenData?['symbol'] ?? 'BTC').toString();
  String get name => tokenData?['name'] ?? 'Bitcoin';
  String get iconPath =>
      tokenData?['icon'] ?? 'assets/currencyicons/bitcoin.png';

  double get price => (tokenData?['price'] as num?)?.toDouble() ?? 43825.67;
  String get changeText => tokenData?['changeText'] ?? r'$72.42 (+0.06%)';
  bool get changePositive => tokenData?['changePositive'] ?? true;

  String get marketCap => tokenData?['marketCap'] ?? r'$2.4T';
  String get volume24h => tokenData?['volume24h'] ?? r'$45.2B';
  String get circulating => tokenData?['circulating'] ?? '—';
  String get alltimehigh => tokenData?['All time high'] ?? '\$73,737.00';
  String get alltimelow => tokenData?['All time low'] ?? '\$65.00';
  String get fullydiluted => tokenData?['Fully diluted'] ?? '\$2.6T';
  String get volumemarketcap => tokenData?['Volume / Market Cap'] ?? '8.90%';
  String get aboutText =>
      tokenData?['about'] ?? 'No description provided for $name.';

  // Simple dummy price lookup for variants (until you wire an API)
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

  void _generateMockChartData() {
    chartData = List.generate(50, (i) {
      final base = 1.0;
      final trend = i * 0.015;
      final noise = (i % 7) * 0.02 - 0.01;
      return FlSpot(i.toDouble(), base + trend + noise);
    });
  }

  void _onPeriodSelected(String period) {
    setState(() {
      selectedPeriod = period;
      _generateMockChartData();
    });
    HapticFeedback.selectionClick();
  }

  void _toggleBookmark() {
    setState(() => isBookmarked = !isBookmarked);
    HapticFeedback.lightImpact();
  }

  // --------------------- UI ---------------------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFF0B0D1A),
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
                          Expanded(child: const ActionButtonsGridtoken()),
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
            // ← Back button (left)
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

            // Centered token title with icon
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
    final changeClr = changePositive ? greenColor : Colors.redAccent;
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
              Icon(
                changePositive ? Icons.arrow_upward : Icons.arrow_downward,
                color: changeClr,
                size: 18,
              ),
              const SizedBox(width: 4),
              Text(
                changeText,
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
    final minY =
        chartData.map((s) => s.y).reduce((a, b) => a < b ? a : b) - 0.05;
    final maxY =
        chartData.map((s) => s.y).reduce((a, b) => a > b ? a : b) + 0.05;

    return Container(
      margin: EdgeInsets.symmetric(horizontal: 2.w),
      child: LineChart(
        LineChartData(
          gridData: FlGridData(show: false),
          titlesData: FlTitlesData(show: false),
          borderData: FlBorderData(show: false),
          lineBarsData: [
            LineChartBarData(
              spots: chartData,
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
          minX: 0,
          maxX: chartData.length.toDouble() - 1,
          minY: minY,
          maxY: maxY,
        ),
      ),
    );
  }

  // ------------------ Holdings tab ------------------
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
    // Only these exact pairs when sym is USDT or BTC
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
        // 🔥 New Gas Free row
        _variantRow(
          id: 'USDT-GASFREE', // <— variant id
          name: 'USDT (Gas Free)', // title
          network: 'USDT', // shows as the network line
          iconPath: usdt?.assetPath, // use base USDT icon
          fallbackIcon: Icons.local_gas_station,
          fallbackColor: Colors.green,
          borderColor: Colors.green, // <— custom green border for this row
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
      // Other coins → single card using its own id (sym)

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

    // Render cards
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
      'borderColor': borderColor, // <— new
    };
  }

  // Balance strings (demo). Replace with your real balances.
  String _getVariantBalance(String variantId) {
    // demo numbers:
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

  // Fiat value = parsed balance * dummy price
  String _getVariantFiatValue(String variantId) {
    // Parse "12.34 SYMBOL" → 12.34
    final raw = _getVariantBalance(variantId);
    final amountStr = (raw.split(' ').isNotEmpty ? raw.split(' ').first : '0')
        .replaceAll(',', '');
    final amount = double.tryParse(amountStr) ?? 0.0;

    final price = _dummyPrices[variantId] ??
        _dummyPrices[sym] ??
        0.0; // fall back to symbol price
    final usd = amount * price;
    return '\$${usd.toStringAsFixed(2)}';
    // If you want to support multi-fiat later, swap the symbol and conversion here.
  }

  String _getDefaultNetwork(String symbol) {
    switch (symbol.toUpperCase()) {
      case 'ETH':
        return 'Ethereum Network';
      case 'TRX':
        return 'Tron Network';
      case 'SOL':
        return 'Solana Network';
      case 'BNB':
        return 'BSC Network';
      case 'XMR':
        return 'Monero Network';
      default:
        return 'Native Network';
    }
  }

  // ------------------ History tab ------------------
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
          // Type icon
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
          // Details
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
                          '${tx['amount']} ${_getCoinSymbol(tx['coin'])}',
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

  // ------------------ About tab ------------------
  Widget _buildAboutTab() {
    return SingleChildScrollView(
      padding: EdgeInsets.symmetric(horizontal: 4.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(height: 2.h),
          // Market stats
          Container(
            padding: EdgeInsets.all(1.w),
            child: Column(
              children: [
                _buildStatRow('Market Cap', marketCap),
                _buildStatRow('24h Volume', volume24h),
                _buildStatRow('Circulating Supply', circulating),
                _buildStatRow('Volume / Market Cap', volumemarketcap),
                _buildStatRow('All time high', alltimehigh),
                _buildStatRow('All time low', alltimelow),
                _buildStatRow('Fully diluted', fullydiluted),
              ],
            ),
          ),
          SizedBox(height: 3.h),
          // About block
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
                        aboutText,
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
}

// ---- actions bar (simple demo) ----
class ActionButtonsGridtoken extends StatelessWidget {
  final bool isLarge;
  final bool isTablet;

  const ActionButtonsGridtoken({
    super.key,
    this.isLarge = false,
    this.isTablet = false,
  });

  @override
  Widget build(BuildContext context) {
    final List<_ActionButton> actionButtons = [
      _ActionButton("Send", Icons.send, "/send"),
      _ActionButton("Receive", Icons.download, "/receive"),
      _ActionButton("Swap", Icons.swap_horiz, "/swap"),
      _ActionButton("Activity", Icons.history, "/activity", enabled: false),
    ];

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(6),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 6,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: actionButtons.map((b) {
          return _buildActionItem(
            context,
            title: b.title,
            icon: b.icon,
            route: b.route,
            enabled: b.enabled,
          );
        }).toList(),
      ),
    );
  }

  Widget _buildActionItem(
    BuildContext context, {
    required String title,
    required IconData icon,
    required String route,
    bool enabled = true,
  }) {
    final Color activeColor = const Color(0xFF2E5BFF);
    final Color disabledColor = Colors.grey.shade400;

    return GestureDetector(
      onTap: enabled ? () => Navigator.pushNamed(context, route) : null,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 20, color: enabled ? activeColor : disabledColor),
          const SizedBox(height: 6),
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: enabled ? Colors.black : disabledColor,
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionButton {
  final String title;
  final IconData icon;
  final String route;
  final bool enabled;
  _ActionButton(this.title, this.icon, this.route, {this.enabled = true});
}
