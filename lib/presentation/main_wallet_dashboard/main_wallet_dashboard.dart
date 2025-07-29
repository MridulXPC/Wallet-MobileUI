import 'dart:async';

import 'package:cryptowallet/presentation/bottomnavbar.dart';
import 'package:cryptowallet/presentation/main_wallet_dashboard/widgets/action_buttons_grid_widget.dart';
import 'package:cryptowallet/presentation/main_wallet_dashboard/widgets/crypto_portfolio_widget.dart';
import 'package:cryptowallet/routes/app_routes.dart';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:sizer/sizer.dart';
import 'dart:math';

class WalletHomeScreen extends StatefulWidget {
  const WalletHomeScreen({super.key});

  @override
  State<WalletHomeScreen> createState() => _WalletHomeScreenState();
}

class _WalletHomeScreenState extends State<WalletHomeScreen> {
  int _selectedIndex = 0;

  final String _vaultName = 'Main Vault';
  final String _totalValue = '\$0.00';

void _onItemTapped(int index) {
  if (index == 2) {
    Navigator.pushNamed(context, AppRoutes.swapScreen); // ✅ Add this line
    return;
  }

  if (index == 3) {
    Navigator.pushNamed(context, AppRoutes.profileScreen);
    return;
  }

  setState(() {
    _selectedIndex = index;
  });
}


  late final PageController _pageController;
int _currentPage = 0;
late final Timer _timer;


@override
void initState() {
  super.initState();
  _pageController = PageController(viewportFraction: 0.92);

  _timer = Timer.periodic(const Duration(seconds: 5), (Timer timer) {
    if (_pageController.hasClients) {
      _currentPage++;
      if (_currentPage >= 3) _currentPage = 0;

      _pageController.animateToPage(
        _currentPage,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );
    }
  });
}

@override
void dispose() {
  _pageController.dispose();
  _timer.cancel();
  super.dispose();
}

  void _showWalletOptionsSheet() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(16.0),
          child: Wrap(
            children: [
              ListTile(
                leading: const Icon(Icons.account_balance_wallet),
                title: const Text('My Vaults'),
                onTap: () {
                  Navigator.pop(context);
                },
              ),
              ListTile(
                leading: const Icon(Icons.add),
                title: const Text('Create New Wallet'),
                onTap: () {
                  Navigator.pop(context);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  List<FlSpot> generateSpots(List<double> prices) {
    return List.generate(
        prices.length, (index) => FlSpot(index.toDouble(), prices[index]));
  }

  double getMinY(List<List<double>> allData) {
    return allData.expand((e) => e).reduce(min) * 0.98;
  }

  double getMaxY(List<List<double>> allData) {
    return allData.expand((e) => e).reduce(max) * 1.02;
  }

  List<Map<String, dynamic>> cryptoCards = [
    {
      'title': 'Bitcoin',
      'price': 61547.81,
      'monthly': List.generate(30, (i) => 61000 + Random().nextDouble() * 1000),
      'today': List.generate(24, (i) => 61200 + Random().nextDouble() * 500),
      'yearly': List.generate(12, (i) => 59000 + Random().nextDouble() * 2000),
    },
    {
      'title': 'Ethereum',
      'price': 3457.32,
      'monthly': List.generate(30, (i) => 3400 + Random().nextDouble() * 100),
      'today': List.generate(24, (i) => 3450 + Random().nextDouble() * 50),
      'yearly': List.generate(12, (i) => 3200 + Random().nextDouble() * 200),
    },
    {
      'title': 'Polygon',
      'price': 0.98,
      'monthly': List.generate(30, (i) => 0.9 + Random().nextDouble() * 0.1),
      'today': List.generate(24, (i) => 0.95 + Random().nextDouble() * 0.05),
      'yearly': List.generate(12, (i) => 0.8 + Random().nextDouble() * 0.2),
    },
  ];

  @override
@override
Widget build(BuildContext context) {
  return Scaffold(
    backgroundColor: Colors.white,
   bottomNavigationBar: BottomNavBar(
  selectedIndex: _selectedIndex,
  onTap: _onItemTapped,
),

    body: SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.only(bottom: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            VaultHeaderCard(
              totalValue: _totalValue,
              vaultName: _vaultName,
              onTap: _showWalletOptionsSheet,
            ),
            const SizedBox(height: 8),

            SizedBox(
              height: 56.h,
              child: PageView.builder(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: cryptoCards.length,
                itemBuilder: (context, index) {
                  final card = cryptoCards[index];
                  return CryptoStatCard(
                    title: card['title'],
                    currentPrice: card['price'],
                    monthlyData: card['monthly'],
                    todayData: card['today'],
                    yearlyData: card['yearly'],
                  );
                },
              ),
            ),
            const SizedBox(height: 16),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: SizedBox(
                height: 300, // Or use 32.h if using Sizer
                child: CryptoPortfolioWidget(
                  portfolio: [
                    {
                      "symbol": "BCH",
                      "name": "Bitcoin Cash",
                      "balance": "0",
                      "usdValue": "\$0.00",
                      "change24h": "0.00%",
                      "isPositive": true,
                      "icon": "https://example.com/bch-icon.png",
                    },
                    {
                      "symbol": "BTC",
                      "name": "Bitcoin",
                      "balance": "0",
                      "usdValue": "\$0.00",
                      "change24h": "-1.25%",
                      "isPositive": false,
                      "icon": "https://example.com/btc-icon.png",
                    },
                    {
                      "symbol": "ETH",
                      "name": "Ethereum",
                      "balance": "0",
                      "usdValue": "\$0.00",
                      "change24h": "0.75%",
                      "isPositive": true,
                      "icon": "https://example.com/eth-icon.png",
                    },
                    {
                      "symbol": "MATIC",
                      "name": "Polygon",
                      "balance": "0",
                      "usdValue": "\$0.00",
                      "change24h": "-0.50%",
                      "isPositive": false,
                      "icon": "https://example.com/matic-icon.png",
                    },
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

}

class CryptoStatCard extends StatelessWidget {
  final String title;
  final double currentPrice;
  final List<double> monthlyData;
  final List<double> todayData;
  final List<double> yearlyData;

  const CryptoStatCard({
    super.key,
    required this.title,
    required this.currentPrice,
    required this.monthlyData,
    required this.todayData,
    required this.yearlyData,
  });

  List<FlSpot> generateSpots(List<double> prices) {
    return List.generate(prices.length, (i) => FlSpot(i.toDouble(), prices[i]));
  }

  double getMinY() {
    final all = [...monthlyData, ...todayData, ...yearlyData];
    return all.reduce(min) * 0.98;
  }

  double getMaxY() {
    final all = [...monthlyData, ...todayData, ...yearlyData];
    return all.reduce(max) * 1.02;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color.fromARGB(255, 100, 162, 228), Color(0xFF1A73E8)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('$title price',
                  style: const TextStyle(color: Colors.white, fontSize: 14)),
              const Icon(Icons.qr_code_scanner, color: Colors.white),
            ],
          ),
          const SizedBox(height: 8),
          Text('\$${currentPrice.toStringAsFixed(2)}',
              style: const TextStyle(
                  color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          const Text('▲74.99% (+\$51,176.67)',
              style: TextStyle(color: Colors.white, fontSize: 14)),
          const SizedBox(height: 8),
          SizedBox(
            height: 80,
            child: LineChart(
              LineChartData(
                lineBarsData: [
                  LineChartBarData(
                    spots: generateSpots(monthlyData),
                    isCurved: true,
                    color: Colors.orange,
                    barWidth: 2,
                    dotData: FlDotData(show: false),
                  ),
                  LineChartBarData(
                    spots: generateSpots(todayData),
                    isCurved: true,
                    color: Colors.green,
                    barWidth: 2,
                    dotData: FlDotData(show: false),
                  ),
                  LineChartBarData(
                    spots: generateSpots(yearlyData),
                    isCurved: true,
                    color: Colors.yellowAccent,
                    barWidth: 2,
                    dotData: FlDotData(show: false),
                  ),
                ],
                minY: getMinY(),
                maxY: getMaxY(),
                gridData: FlGridData(show: false),
                borderData: FlBorderData(show: false),
                titlesData: FlTitlesData(show: false),
                lineTouchData: LineTouchData(enabled: false),
              ),
            ),
          ),
          const SizedBox(height: 8),
          const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              LegendItem(color: Colors.orange, label: 'Monthly'),
              SizedBox(width: 12),
              LegendItem(color: Colors.green, label: 'Today'),
              SizedBox(width: 12),
              LegendItem(color: Colors.yellowAccent, label: 'Yearly'),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Start investing – buy your first $title now!',
            style: const TextStyle(
                color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(height: 8),
          const Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _AmountButton(amount: '\$100'),
              _AmountButton(amount: '\$200'),
              _AmountButton(amount: '\$500'),
            ],
          ),
          const SizedBox(height: 8),
          const ActionButtonsGridWidget(),
        ],
      ),
    );
  }
}


class LegendItem extends StatelessWidget {
  final Color color;
  final String label;

  const LegendItem({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(color: Colors.white)),
      ],
    );
  }
}

class VaultHeaderCard extends StatelessWidget {
  final String totalValue;
  final String vaultName;
  final VoidCallback onTap;

  const VaultHeaderCard({
    required this.totalValue,
    required this.vaultName,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Card(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        elevation: 2,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Total Portfolio Value",
                    style: TextStyle(fontSize: 14, color: Colors.grey),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    totalValue,
                    style:
                        const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              Row(
                children: [
                  Text(
                    vaultName,
                    style: const TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 14),
                  ),
                  const SizedBox(width: 4),
                  const Icon(Icons.keyboard_arrow_down),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AmountButton extends StatelessWidget {
  final String amount;
  const _AmountButton({required this.amount});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.2),
        borderRadius: BorderRadius.circular(30),
      ),
      child: Text(
        amount,
        style:
            const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
      ),
    );
  }
}