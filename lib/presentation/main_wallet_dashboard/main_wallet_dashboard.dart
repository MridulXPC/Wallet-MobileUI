import 'package:cryptowallet/presentation/main_wallet_dashboard/widgets/action_buttons_grid_widget.dart';
import 'package:cryptowallet/presentation/main_wallet_dashboard/widgets/crypto_portfolio_widget.dart';
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
    setState(() {
      _selectedIndex = index;
    });
  }

  List<double> getFakeBtcMonthlyPrices() {
    final now = DateTime.now();

    final random = Random();
    double base = 61000;
    return List.generate(now.day, (index) {
      double fluctuation = random.nextDouble() * 2000 - 1000; // ±1000
      return (base + fluctuation);
    });
  }

  List<FlSpot> generateMonthlySpots(List<double> prices) {
    return List.generate(prices.length, (index) {
      return FlSpot(index.toDouble(), prices[index]);
    });
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

  // Simulated data generation
  List<double> monthlyData =
      List.generate(30, (i) => 61000 + Random().nextDouble() * 2000 - 1000);
  List<double> todayData =
      List.generate(24, (i) => 61200 + Random().nextDouble() * 1000 - 500);
  List<double> yearlyData =
      List.generate(12, (i) => 59000 + Random().nextDouble() * 4000 - 2000);

  List<FlSpot> generateSpots(List<double> prices) {
    return List.generate(
        prices.length, (index) => FlSpot(index.toDouble(), prices[index]));
  }

  double getMinY() {
    return [...monthlyData, ...todayData, ...yearlyData].reduce(min) * 0.98;
  }

  double getMaxY() {
    return [...monthlyData, ...todayData, ...yearlyData].reduce(max) * 1.02;
  }

  @override
  Widget build(BuildContext context) {
    final btcPrices = getFakeBtcMonthlyPrices();
    final spots = generateMonthlySpots(btcPrices);
    final minY = btcPrices.reduce(min) * 0.98;
    final maxY = btcPrices.reduce(max) * 1.02;

    return Scaffold(
      backgroundColor: Colors.white,
      bottomNavigationBar: BottomNavigationBar(
        selectedItemColor: Colors.blue,
        unselectedItemColor: Colors.grey,
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(
              icon: Icon(Icons.bar_chart), label: 'Markets'),
          BottomNavigationBarItem(icon: Icon(Icons.swap_horiz), label: 'Trade'),
          BottomNavigationBarItem(icon: Icon(Icons.article), label: 'News'),
          BottomNavigationBarItem(icon: Icon(Icons.more_horiz), label: 'More'),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            children: [
              VaultHeaderCard(
                totalValue: _totalValue,
                vaultName: _vaultName,
                onTap: _showWalletOptionsSheet,
              ),
              Container(
                margin: const EdgeInsets.all(16),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF3B9BFF), Color(0xFF1A73E8)],
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
                      children: const [
                        Text('Bitcoin price',
                            style:
                                TextStyle(color: Colors.white, fontSize: 14)),
                        Icon(Icons.qr_code_scanner, color: Colors.white),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text('\$${btcPrices.last.toStringAsFixed(2)}',
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 28,
                            fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    const Text('▲74.99% (+\$51,176.67)',
                        style: TextStyle(color: Colors.white, fontSize: 14)),
                    const SizedBox(height: 12),
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
                              belowBarData: BarAreaData(show: false),
                            ),
                            LineChartBarData(
                              spots: generateSpots(todayData),
                              isCurved: true,
                              color: Colors.green[400],
                              barWidth: 2,
                              dotData: FlDotData(show: false),
                              belowBarData: BarAreaData(show: false),
                            ),
                            LineChartBarData(
                              spots: generateSpots(yearlyData),
                              isCurved: true,
                              color: Colors.yellowAccent,
                              barWidth: 2,
                              dotData: FlDotData(show: false),
                              belowBarData: BarAreaData(show: false),
                            ),
                          ],
                          minY: getMinY(),
                          maxY: getMaxY(),
                          gridData: FlGridData(show: false),
                          borderData: FlBorderData(show: false),
                          titlesData: FlTitlesData(show: false),
                          lineTouchData: LineTouchData(enabled: true),
                        ),
                      ),
                    ),
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
                    const Text(
                      'Start investing – buy your first Bitcoin now!',
                      style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: const [
                        _AmountButton(amount: '\$100'),
                        _AmountButton(amount: '\$200'),
                        _AmountButton(amount: '\$500'),
                      ],
                    ),
                    const SizedBox(height: 12),
                    const ActionButtonsGridWidget(),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: SizedBox(
                  height: 60.h,
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
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        elevation: 2,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text(
                    "Total Portfolio Value",
                    style: TextStyle(fontSize: 14, color: Colors.grey),
                  ),
                  SizedBox(height: 4),
                  Text(
                    "\$0.00",
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
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
