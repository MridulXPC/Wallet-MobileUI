import 'dart:async';
import 'package:cryptowallet/core/app_export.dart';
import 'package:cryptowallet/presentation/bottomnavbar.dart';
import 'package:cryptowallet/presentation/main_wallet_dashboard/widgets/crypto_portfolio_widget.dart';
import 'package:cryptowallet/presentation/main_wallet_dashboard/widgets/dashborad_card.dart';
import 'package:cryptowallet/presentation/main_wallet_dashboard/widgets/wallet_card_dashboard.dart';
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
    if (index == 1) {
    Navigator.pushNamed(context, AppRoutes.walletInfoScreen); // ✅ Add this line
    return;
  }
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
  _pageController = PageController(viewportFraction: 1.0);

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
Widget build(BuildContext context) {
  return Scaffold(
    backgroundColor: const Color(0xFF1A1D29),
   bottomNavigationBar: BottomNavBar(
  selectedIndex: _selectedIndex,
  onTap: _onItemTapped,
),

    body: SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 3),
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
                height: 38.h,
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


// Resp
//onsive Legend Item
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


