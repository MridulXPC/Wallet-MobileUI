import 'package:cryptowallet/coin_store.dart';
import 'package:cryptowallet/presentation/walletscreen/wallet_screen.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
    _tabController = TabController(length: 3, vsync: this, initialIndex: 0);
    _generateMockChartData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
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

  void _navigateToTransactionDetails(Map<String, dynamic> transaction) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            TransactionDetailsScreen(transaction: transaction),
      ),
    );
  }

  // --------- Dummy transactions (keys must match selectedCoinId) -------------
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
            'from': '0x742d35Cc6Dd7D8b4B8B4f42C8B4B2f4D8E8F8G8H',
            'to': '0x1234567890abcdef1234567890abcdef12345678',
            'hash':
                '0xeth123456789abcdef123456789abcdef123456789abcdef123456789abcdef',
            'block': 18245673,
            'feeDetails': {
              'Gas Used': '21,000',
              'Gas Price': '25 Gwei',
              'Total Fee': '0.000525 ETH',
            },
          },
          {
            'id': 'eth_receive_1',
            'type': 'receive',
            'status': 'Confirmed',
            'amount': '1.8',
            'coin': 'ETH',
            'dateTime': '19 Aug 2025 11:30:45',
            'from': '0x9876543210fedcba9876543210fedcba98765432',
            'to': '0x742d35Cc6Dd7D8b4B8B4f42C8B4B2f4D8E8F8G8H',
            'hash':
                '0xeth987654321fedcba987654321fedcba987654321fedcba987654321fedcba',
            'block': 18244890,
            'feeDetails': {'Total Fee': '0.00031 ETH'},
          },
          {
            'id': 'eth_swap_1',
            'type': 'swap',
            'status': 'Confirmed',
            'amount': '3.2',
            'coin': 'ETH',
            'dateTime': '16 Aug 2025 08:22:18',
            'hash':
                '0xswapeth123456789abcdef123456789abcdef123456789abcdef123456789ab',
            'swapDetails': {
              'fromCoin': 'USDT',
              'fromAmount': '8500',
              'toCoin': 'ETH',
              'toAmount': '3.2',
              'rate': '2656.25',
              'swapId': 'SWAP_ETH_001'
            },
            'feeDetails': {'Swap Fee': '0.3%', 'Network Fee': '0.0015 ETH'},
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
            'hash':
                '72c2e0618ba1c320f6da0e8dfaba7dc6e7f54a531609889e01af6edb800d55429',
            'block': 74680192,
            'feeDetails': {'Bandwidth Fee': '0.0', 'Total Fee': '13.84485 TRX'},
          },
          {
            'id': 'usdt_send_2',
            'type': 'send',
            'status': 'Confirmed',
            'amount': '52.842548',
            'coin': 'USDT',
            'dateTime': '09 Aug 2025 05:40:06',
            'from': 'TH2B65...TbTDJv',
            'to': 'TLntW9...828ird',
            'hash':
                'd414a6af812068499d3348d9c8cd2d54064d25538b14735c0b787443727a0ff8',
            'block': 74679758,
            'feeDetails': {'Bandwidth Fee': '699.0', 'Total Fee': '0.00 TRX'},
          },
          {
            'id': 'usdt_swap_1',
            'type': 'swap',
            'status': 'Confirmed',
            'amount': '1000',
            'coin': 'USDT',
            'dateTime': '15 Aug 2025 09:25:33',
            'hash':
                'SWAPUSDT123456789ABCDEF123456789ABCDEF123456789ABCDEF123456789A',
            'swapDetails': {
              'fromCoin': 'BTC',
              'fromAmount': '0.0228',
              'toCoin': 'USDT',
              'toAmount': '1000',
              'rate': '43859.65',
              'swapId': 'SWAP_USDT_001'
            },
            'feeDetails': {'Swap Fee': '0.1%', 'Network Fee': '15 TRX'},
          },
        ],
        'BTC-LN': [
          {
            'id': 'ln_send_1',
            'type': 'send',
            'status': 'Confirmed',
            'amount': '0.00116463',
            'coin': 'BTC-LN',
            'dateTime': '09 Aug 2025 05:25:10',
            'from': '033834...485b7d',
            'to': 'lnbc1164...p8wjgwt',
            'hash':
                'ea3cd3027c1445ebc88e30f2da55d1fafc4706f08feb97864c6a25a5680b0098',
            'lightningDetails': {
              'Swap ID': 'TCkQ1ZmWzeqy',
              'Description': '-',
              'Destination public key': '032842...2571de',
              'Payment hash':
                  '0c0d12b226cd40dadf1262fdfe11e940a7074fdac6250697eca7e5442b2f1dca',
              'Refund amount': '0',
            },
          },
          {
            'id': 'ln_send_2',
            'type': 'send',
            'status': 'Confirmed',
            'amount': '0.0005',
            'coin': 'BTC-LN',
            'dateTime': '12 Aug 2025 14:18:25',
            'from': '033834...485b7d',
            'to': 'lnbc500...xyz789',
            'hash':
                'ln987654321abcdef987654321abcdef987654321abcdef987654321abcdef12',
            'lightningDetails': {
              'Swap ID': 'LN_SWAP_002',
              'Description': 'Coffee payment',
              'Destination public key': '035512...8841ac',
              'Payment hash':
                  '1a2b3c4d5e6f789012345678901234567890abcdef1234567890abcdef123456',
              'Refund amount': '0',
            },
          },
          {
            'id': 'ln_receive_1',
            'type': 'receive',
            'status': 'Confirmed',
            'amount': '0.00046011',
            'coin': 'BTC-LN',
            'dateTime': '11 Aug 2025 18:33:42',
            'from': 'lnbc4601...def456',
            'to': '033834...485b7d',
            'hash':
                'lnreceive123456789abcdef123456789abcdef123456789abcdef123456789ab',
            'lightningDetails': {
              'Swap ID': 'LN_RCV_001',
              'Description': 'Payment received',
              'Source public key': '028847...9923fe',
              'Payment hash':
                  '9f8e7d6c5b4a392817263544536271890abcdef1234567890abcdef123456789',
              'Refund amount': '0',
            },
          },
        ],

        // Minimal examples for remaining families
        'TRX': [
          {
            'id': 'trx_receive_1',
            'type': 'receive',
            'status': 'Confirmed',
            'amount': '120',
            'coin': 'TRX',
            'dateTime': '18 Aug 2025 10:12:00',
            'from': 'TDv...abc',
            'to': 'TAJ6...xyz',
            'hash': 'trxHash1',
            'block': 74670001,
            'feeDetails': {'Total Fee': '0 TRX'},
          },
        ],
        'SOL': [
          {
            'id': 'sol_send_1',
            'type': 'send',
            'status': 'Confirmed',
            'amount': '1.25',
            'coin': 'SOL',
            'dateTime': '19 Aug 2025 09:01:00',
            'from': '4Nd1mW2...',
            'to': '7Gh3pQk...',
            'hash': 'solHash1',
            'feeDetails': {'Total Fee': '0.000005 SOL'},
          },
        ],
        'BNB': [
          {
            'id': 'bnb_send_1',
            'type': 'send',
            'status': 'Confirmed',
            'amount': '0.5',
            'coin': 'BNB',
            'dateTime': '20 Aug 2025 12:20:00',
            'from': 'bnb1qxy2...',
            'to': 'bnb1abc9...',
            'hash': 'bnbHash1',
            'feeDetails': {'Total Fee': '0.000375 BNB'},
          },
        ],
        'XMR': [
          {
            'id': 'xmr_send_1',
            'type': 'send',
            'status': 'Confirmed',
            'amount': '0.75',
            'coin': 'XMR',
            'dateTime': '21 Aug 2025 15:45:00',
            'from': '44AFFq...',
            'to': '488fyrk...',
            'hash': 'xmrHash1',
            'feeDetails': {'Total Fee': '0.0002 XMR'},
          },
        ],
      };

  // ---------- conveniences with safe fallbacks ----------
  String get sym => tokenData?['symbol'] ?? 'BTC';
  String get name => tokenData?['name'] ?? 'Bitcoin';
  String get iconPath =>
      tokenData?['icon'] ?? 'assets/currencyicons/bitcoin.png';

  double get price => (tokenData?['price'] as num?)?.toDouble() ?? 113649.08;
  String get changeText => tokenData?['changeText'] ?? r'$72.42 (+0.06%)';
  bool get changePositive => tokenData?['changePositive'] ?? true;
  double get balance {
    final bal = tokenData?['balance'];
    if (bal == null) return 0.0;

    if (bal is num) {
      return bal.toDouble(); // already a number
    } else if (bal is String) {
      return double.tryParse(bal) ?? 0.0; // convert string -> double
    }
    return 0.0;
  }

  double get fiatValue => (tokenData?['fiatValue'] as num?)?.toDouble() ?? 0.0;

  String get marketCap => tokenData?['marketCap'] ?? r'$2.4T';
  String get volume24h => tokenData?['volume24h'] ?? r'$45.2B';
  String get circulating => tokenData?['circulating'] ?? '—';
  String get alltimehigh => tokenData?['All time high'] ?? '\$4,944.63';
  String get alltimelow => tokenData?['All time low'] ?? '\$0.43';
  String get fullydiluted => tokenData?['Fully diluted'] ?? '\$53.25KCr';
  String get volumemarketcap => tokenData?['Volume / Market Cap'] ?? '8.90%';

  String get aboutText =>
      tokenData?['about'] ?? 'No description provided for $name.';

  void _generateMockChartData() {
    chartData = List.generate(50, (index) {
      final base = 1.0;
      final trend = index * 0.015;
      final noise = (index % 7) * 0.02 - 0.01;
      return FlSpot(index.toDouble(), base + trend + noise);
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

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Scaffold(
        backgroundColor: darkBackground,
        body: Column(
          children: [
            // Upper Half
            Expanded(
              flex: 1,
              child: Container(
                width: double.infinity,
                color: darkBackground,
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
                              Expanded(child: ActionButtonsGridtoken()),
                              SizedBox(width: 3.w),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Lower Half
            Expanded(
              flex: 1,
              child: Container(
                width: double.infinity,
                color: darkBackground,
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
            ),
          ],
        ),
      ),
    );
  }

  // ---------- UI pieces ----------
  Widget _buildDarkAppBar() {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 3.w, vertical: 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // back
            GestureDetector(
              onTap: () => Navigator.pop(context),
              child: const Icon(Icons.arrow_back_ios,
                  color: Colors.white, size: 18),
            ),

            // token title with icon
            Row(
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
                        color: Colors.orange),
                  ),
                ),
                SizedBox(width: 2.w),
                Column(
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

            // menu / bookmark
            GestureDetector(
              onTap: _toggleBookmark,
              child: Icon(
                isBookmarked ? Icons.bookmark : Icons.more_vert,
                color: Colors.white,
                size: 20,
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
          minY:
              chartData.map((s) => s.y).reduce((a, b) => a < b ? a : b) - 0.05,
          maxY:
              chartData.map((s) => s.y).reduce((a, b) => a > b ? a : b) + 0.05,
        ),
      ),
    );
  }

  Widget _buildHoldingsTab() {
    return SingleChildScrollView(
      padding: EdgeInsets.symmetric(horizontal: 3.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(height: 1.h),

          // Balance Section with coin icon
          Container(
            padding: EdgeInsets.all(3.w),
            decoration: BoxDecoration(
              color: cardBackground,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.asset(
                    iconPath,
                    width: 36,
                    height: 36,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => const Icon(
                        Icons.currency_bitcoin,
                        color: Colors.orange),
                  ),
                ),
                SizedBox(width: 3.w),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${balance.toStringAsFixed(8)} $sym',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      '\$${fiatValue.toStringAsFixed(2)}',
                      style: const TextStyle(color: greyColor, fontSize: 14),
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

  String selectedCoinId = 'BTC';

  Widget _buildTransactionsSection() {
    final transactions = dummyTransactions[selectedCoinId] ?? [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section header with tabs

        const SizedBox(height: 24),

        if (transactions.isNotEmpty) ...[
          ...transactions.map((tx) => _buildTransactionItem(tx)).toList(),
        ] else ...[
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
        ],

        const SizedBox(height: 100),
      ],
    );
  }

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

  // ------------------- Helpers -------------------

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
    // coinKey could be 'BTC', 'BTC-LN', 'USDT-ETH', etc.
    // Prefer mapping by id => symbol from provider where possible:
    final store = context.read<CoinStore>();
    final coin = store.getById(coinKey);
    if (coin != null) return coin.symbol;

    // Fallback from known families:
    if (coinKey.startsWith('USDT')) return 'USDT';
    if (coinKey.startsWith('ETH')) return 'ETH';
    if (coinKey.startsWith('TRX')) return 'TRX';
    if (coinKey.startsWith('SOL')) return 'SOL';
    if (coinKey.startsWith('BNB')) return 'BNB';
    if (coinKey.startsWith('XMR')) return 'XMR';
    if (coinKey.startsWith('BTC')) return 'BTC';
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

  Widget _buildTransactionItem(Map<String, dynamic> transaction) {
    return InkWell(
      onTap: () => _navigateToTransactionDetails(transaction),
      splashColor: const Color(0xFF2A2D3A).withOpacity(0.3),
      highlightColor: const Color(0xFF2A2D3A).withOpacity(0.1),
      child: Container(
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
              child: Icon(_getTransactionTypeIcon(transaction['type']),
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
                            transaction['status'],
                            style: TextStyle(
                              color: _getStatusColor(transaction['status']),
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _getTransactionTypeLabel(transaction['type']),
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
                            _getTimeAgo(transaction['dateTime']),
                            style: const TextStyle(
                              color: Color(0xFF6B7280),
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${transaction['amount']} ${_getCoinSymbol(transaction['coin'])}',
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
                        child: _kvSmall('From:',
                            _shortenAddress(transaction['from'] ?? 'Unknown')),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _kvSmall('To:',
                            _shortenAddress(transaction['to'] ?? 'Unknown'),
                            end: true),
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

  Widget _buildHistoryTab() {
    return SingleChildScrollView(child: _buildTransactionsSection());
  }

  Widget _buildAboutTab() {
    return SingleChildScrollView(
      padding: EdgeInsets.symmetric(horizontal: 4.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(height: 2.h),

          // Market Stats
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

          // About token with icon
          Container(
            padding: EdgeInsets.all(4.w),
            decoration: BoxDecoration(
              color: cardBackground,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
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
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'About $name',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          sym,
                          style:
                              const TextStyle(color: greyColor, fontSize: 14),
                        ),
                      ],
                    ),
                  ],
                ),
                SizedBox(height: 3.h),
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
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

// ---- actions bar (kept from your version, just reused) ----
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
      _ActionButton("Bridge", Icons.compare_arrows, "/bridge"),
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
