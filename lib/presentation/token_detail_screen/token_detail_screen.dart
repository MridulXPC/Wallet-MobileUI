import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

  Widget _buildHistoryTab() {
    return SingleChildScrollView(
      child: Column(
        children: [
          SizedBox(height: 8.h),
          Icon(Icons.receipt_long_outlined, size: 80, color: greyColor),
          SizedBox(height: 2.h),
          const Text(
            'You currently have no transactions.',
            style: TextStyle(color: lightGreyColor, fontSize: 16),
          ),
          SizedBox(height: 2.h),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 8.w),
            child: RichText(
              textAlign: TextAlign.center,
              text: TextSpan(
                style: const TextStyle(color: greyColor, fontSize: 14),
                children: [
                  const TextSpan(text: 'Get started by purchasing '),
                  TextSpan(
                    text: name,
                    style: const TextStyle(
                      color: greenColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const TextSpan(
                      text: ' with a credit card or tapping receive.'),
                ],
              ),
            ),
          ),
          SizedBox(height: 4.h),
        ],
      ),
    );
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
            padding: EdgeInsets.all(4.w),
            decoration: BoxDecoration(
              color: cardBackground,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                _buildStatRow('Market Cap', marketCap),
                const Divider(color: Color(0xFF2A2A2A), height: 32),
                _buildStatRow('24h Volume', volume24h),
                const Divider(color: Color(0xFF2A2A2A), height: 32),
                _buildStatRow('Circulating Supply', circulating),
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
    return Row(
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
