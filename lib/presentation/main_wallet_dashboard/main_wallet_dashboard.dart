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
  _pageController = PageController(viewportFraction: 0.98);

  _timer = Timer.periodic(const Duration(seconds: 4), (Timer timer) {
    if (_pageController.hasClients) {
      _currentPage++;
      if (_currentPage >= 4) _currentPage = 0;

      _pageController.animateToPage(
        _currentPage,
        duration: const Duration(milliseconds: 400),
        curve: Curves.bounceIn,
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
      'title': 'Matic',
      'price': 0.98,
      'monthly': List.generate(30, (i) => 0.9 + Random().nextDouble() * 0.1),
      'today': List.generate(24, (i) => 0.95 + Random().nextDouble() * 0.05),
      'yearly': List.generate(12, (i) => 0.8 + Random().nextDouble() * 0.2),
    },
       {
      'title': 'Trx',
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
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2),
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
          
        
              SizedBox(
                height: 55.h,
                child: PageView.builder(
                  controller: _pageController,
              
                  itemCount: cryptoCards.length,
                  itemBuilder: (context, index) {
                    final card = cryptoCards[index];
                    return CryptoStatCard(
                      title: card['title'],
                      currentPrice: card['price'],
                      monthlyData: card['monthly'],
                      todayData: card['today'],
                      yearlyData: card['yearly'], iconPath: 'assets/currencyicons/${card['title'].toLowerCase()}.png',
                    );
                  },
                ),
              ),
          
        
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: CryptoPortfolioWidget(
                  portfolio: [
                  
                    {
                      "symbol": "BTC",
                      "name": "Bitcoin",
                      "balance": "0",
                      "usdValue": "\$0.00",
                      "change24h": "-1.25%",
                      "isPositive": false,
                      "icon": "assets/currencyicons/bitcoin.png",
                    },
                    {
                      "symbol": "ETH",
                      "name": "Ethereum",
                      "balance": "0",
                      "usdValue": "\$0.00",
                      "change24h": "0.75%",
                      "isPositive": true,
                      "icon": "assets/currencyicons/ethereum.png",
                    },
                    {
                      "symbol": "MATIC",
                      "name": "Polygon",
                      "balance": "0",
                      "usdValue": "\$0.00",
                      "change24h": "-0.50%",
                      "isPositive": false,
                      "icon": "assets/currencyicons/matic.png",
                    },
                      {
                      "symbol": "BCH",
                      "name": "Bitcoin Cash",
                      "balance": "0",
                      "usdValue": "\$0.00",
                      "change24h": "0.00%",
                      "isPositive": true,
                      "icon": "assets/currencyicons/bitcoin-cash.png",
                    },
                    {
                      "symbol": "TRX",
                      "name": "Tron",
                      "balance": "0",
                      "usdValue": "\$0.00",
                      "change24h": "-0.25%",
                      "isPositive": false,
                      "icon": "assets/currencyicons/trx.png",
                    },

                  ],
                ),
             
             
              ),
           
           
            ],
          ),
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
  final String iconPath;

  const CryptoStatCard({
    super.key,
    required this.title,
    required this.currentPrice,
    required this.monthlyData,
    required this.todayData,
    required this.yearlyData,
    required this.iconPath,
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
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final isTablet = screenWidth > 600;
    final isLargeScreen = screenWidth > 900;
    
    // Responsive dimensions
    final cardPadding = isLargeScreen ? 24.0 : isTablet ? 20.0 : 16.0;
    final borderRadius = isLargeScreen ? 24.0 : isTablet ? 22.0 : 20.0;
    final iconSize = isLargeScreen ? 40.0 : isTablet ? 36.0 : 32.0;
    final priceTextSize = isLargeScreen ? 32.0 : isTablet ? 30.0 : 28.0;
    final chartHeight = isLargeScreen ? 100.0 : isTablet ? 90.0 : 80.0;
    
    // Responsive margins
    final horizontalMargin = screenWidth * 0.02; // 2% of screen width
    final verticalMargin = screenHeight * 0.015; // 1.5% of screen height

    return Container(
      margin: EdgeInsets.symmetric(
        horizontal: horizontalMargin.clamp(8.0, 20.0),
        vertical: verticalMargin.clamp(8.0, 16.0),
      ),
      padding: EdgeInsets.all(cardPadding),
      decoration: BoxDecoration(
        boxShadow: [
          BoxShadow(
            color: const Color.fromARGB(31, 0, 0, 0),
            blurRadius: isLargeScreen ? 8 : 6,
            offset: Offset(isLargeScreen ? 10 : 8, isLargeScreen ? 10 : 8),
          )
        ],
        gradient: const LinearGradient(
          colors: [Color.fromARGB(255, 100, 162, 228), Color(0xFF1A73E8)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        borderRadius: BorderRadius.circular(borderRadius),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top Row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Flexible(
                    child: Text(
                      '$title price',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: isLargeScreen ? 16 : isTablet ? 15 : 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  Icon(
                    Icons.qr_code_scanner,
                    color: Colors.white,
                    size: isLargeScreen ? 24 : isTablet ? 22 : 20,
                  ),
                ],
              ),
              SizedBox(height: isLargeScreen ? 12 : isTablet ? 10 : 8),
              
              // Price + Icon Row
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Image.asset(
                    iconPath,
                    width: iconSize,
                    height: iconSize,
                    errorBuilder: (_, __, ___) => Icon(
                      Icons.currency_bitcoin,
                      color: Colors.white,
                      size: iconSize,
                    ),
                  ),
                  SizedBox(width: isLargeScreen ? 12 : isTablet ? 10 : 8),
                  Flexible(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        '\$${currentPrice.toStringAsFixed(2)}',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: priceTextSize,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),

              SizedBox(height: isLargeScreen ? 8 : isTablet ? 6 : 4),
              
              // Percentage Change
              Text(
                '▲74.99% (+\$51,176.67)',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: isLargeScreen ? 16 : isTablet ? 15 : 14,
                  fontWeight: FontWeight.w400,
                ),
              ),
              SizedBox(height: isLargeScreen ? 12 : isTablet ? 10 : 8),

              // Chart
              SizedBox(
                height: chartHeight,
                child: LineChart(
                  LineChartData(
                    lineBarsData: [
                      LineChartBarData(
                        spots: generateSpots(monthlyData),
                        isCurved: true,
                        color: Colors.orange,
                        barWidth: isLargeScreen ? 3 : 2,
                        dotData: const FlDotData(show: false),
                      ),
                      LineChartBarData(
                        spots: generateSpots(todayData),
                        isCurved: true,
                        color: Colors.green,
                        barWidth: isLargeScreen ? 3 : 2,
                        dotData: const FlDotData(show: false),
                      ),
                      LineChartBarData(
                        spots: generateSpots(yearlyData),
                        isCurved: true,
                        color: Colors.yellowAccent,
                        barWidth: isLargeScreen ? 3 : 2,
                        dotData: const FlDotData(show: false),
                      ),
                    ],
                    minY: getMinY(),
                    maxY: getMaxY(),
                    gridData: const FlGridData(show: false),
                    borderData: FlBorderData(show: false),
                    titlesData: const FlTitlesData(show: false),
                    lineTouchData: const LineTouchData(enabled: false),
                  ),
                ),
              ),

              SizedBox(height: isLargeScreen ? 12 : isTablet ? 10 : 8),

              // Legend - Responsive layout
              if (isTablet)
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    LegendItem(
                      color: Colors.orange,
                      label: 'Monthly',
                      fontSize: isLargeScreen ? 14 : 13,
                    ),
                    LegendItem(
                      color: Colors.green,
                      label: 'Today',
                      fontSize: isLargeScreen ? 14 : 13,
                    ),
                    LegendItem(
                      color: Colors.yellowAccent,
                      label: 'Yearly',
                      fontSize: isLargeScreen ? 14 : 13,
                    ),
                  ],
                )
              else
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 12,
                  children: [
                    LegendItem(
                      color: Colors.orange,
                      label: 'Monthly',
                      fontSize: 12,
                    ),
                    LegendItem(
                      color: Colors.green,
                      label: 'Today',
                      fontSize: 12,
                    ),
                    LegendItem(
                      color: Colors.yellowAccent,
                      label: 'Yearly',
                      fontSize: 12,
                    ),
                  ],
                ),

              SizedBox(height: isLargeScreen ? 12 : isTablet ? 10 : 8),
              
              // Investment text
              Text(
                'Start investing – buy your first $title now!',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: isLargeScreen ? 18 : isTablet ? 17 : 16,
                ),
              ),
              SizedBox(height: isLargeScreen ? 12 : isTablet ? 10 : 8),

              // Amount Buttons - Single row for all devices
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: _AmountButton(
                      amount: '\$100',
                      isLarge: isLargeScreen,
                    ),
                  ),
                  SizedBox(width: isLargeScreen ? 12 : isTablet ? 10 : 8),
                  Expanded(
                    child: _AmountButton(
                      amount: '\$200',
                      isLarge: isLargeScreen,
                    ),
                  ),
                  SizedBox(width: isLargeScreen ? 12 : isTablet ? 10 : 8),
                  Expanded(
                    child: _AmountButton(
                      amount: '\$500',
                      isLarge: isLargeScreen,
                    ),
                  ),
                ],
              ),

              SizedBox(height: isLargeScreen ? 12 : isTablet ? 10 : 8),

              // Actions
              ActionButtonsGridWidget(isLarge: isLargeScreen, isTablet: isTablet),
            ],
          );
        },
      ),
    );
  }
}

// Responsive Legend Item
class LegendItem extends StatelessWidget {
  final Color color;
  final String label;
  final double? fontSize;

  const LegendItem({
    super.key,
    required this.color,
    required this.label,
    this.fontSize,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            color: Colors.white,
            fontSize: fontSize ?? 12,
            fontWeight: FontWeight.w400,
          ),
        ),
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
        shadowColor: Colors.black,
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

// Responsive Amount Button
class _AmountButton extends StatelessWidget {
  final String amount;
  final bool isLarge;

  const _AmountButton({
    required this.amount,
    this.isLarge = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        vertical: isLarge ? 6 : 6,
        horizontal: isLarge ? 6 : 8,
      ),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.2),
        borderRadius: BorderRadius.circular(isLarge ? 12 : 10),
        border: Border.all(
          color: Colors.white.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Center(
        child: Text(
          amount,
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: isLarge ? 16 : 14,
          ),
        ),
      ),
    );
  }
}
