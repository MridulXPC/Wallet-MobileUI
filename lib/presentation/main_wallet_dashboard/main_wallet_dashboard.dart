import 'dart:async';
import 'dart:math';
import 'package:cryptowallet/coin_store.dart';
import 'package:cryptowallet/core/app_export.dart';
import 'package:cryptowallet/presentation/bottomnavbar.dart';
import 'package:cryptowallet/presentation/main_wallet_dashboard/widgets/crypto_portfolio_widget.dart';
import 'package:cryptowallet/presentation/main_wallet_dashboard/widgets/dashborad_card.dart';
import 'package:cryptowallet/presentation/main_wallet_dashboard/widgets/wallet_card_dashboard.dart';
import 'package:cryptowallet/routes/app_routes.dart';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:provider/provider.dart'; // ✅ Provider

class WalletHomeScreen extends StatefulWidget {
  const WalletHomeScreen({super.key});

  @override
  State<WalletHomeScreen> createState() => _WalletHomeScreenState();
}

class _WalletHomeScreenState extends State<WalletHomeScreen> {
  int _selectedIndex = 0;

  final String _vaultName = 'Main Vault';
  final String _totalValue = '\$500.00';

  void _onItemTapped(int index) {
    if (index == 1) {
      Navigator.pushNamed(context, AppRoutes.walletInfoScreen);
      return;
    }
    if (index == 2) {
      Navigator.pushNamed(context, AppRoutes.swapScreen);
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
      prices.length,
      (index) => FlSpot(index.toDouble(), prices[index]),
    );
  }

  double getMinY(List<List<double>> allData) {
    return allData.expand((e) => e).reduce(min) * 0.98;
  }

  double getMaxY(List<List<double>> allData) {
    return allData.expand((e) => e).reduce(max) * 1.02;
  }

  // ✅ Use only supported coins & drive icons via CoinStore by ID
  // Each card carries a coinId; UI will resolve icon/name/symbol from Provider.
// Put this inside _WalletHomeScreenState
  final List<Map<String, dynamic>> _cryptoCardsSeed = [
    // -------- BTC family --------
    {
      'coinId': 'BTC',
      'title': 'Bitcoin',
      'price': 61547.81,
      'monthly': List.generate(30, (i) => 61000 + Random().nextDouble() * 1000),
      'today': List.generate(24, (i) => 61200 + Random().nextDouble() * 500),
      'yearly': List.generate(12, (i) => 59000 + Random().nextDouble() * 2000),
    },
    {
      'coinId': 'BTC-LN',
      'title': 'Bitcoin Lightning',
      'price': 61547.81,
      'monthly': List.generate(30, (i) => 61000 + Random().nextDouble() * 1000),
      'today': List.generate(24, (i) => 61200 + Random().nextDouble() * 500),
      'yearly': List.generate(12, (i) => 59000 + Random().nextDouble() * 2000),
    },

    // -------- BNB --------
    {
      'coinId': 'BNB',
      'title': 'BNB',
      'price': 575.42,
      'monthly': List.generate(30, (i) => 540 + Random().nextDouble() * 50),
      'today': List.generate(24, (i) => 565 + Random().nextDouble() * 10),
      'yearly': List.generate(12, (i) => 400 + Random().nextDouble() * 200),
    },
    {
      'coinId': 'BNB-BNB',
      'title': 'BNB (BNB Chain)',
      'price': 575.42,
      'monthly': List.generate(30, (i) => 540 + Random().nextDouble() * 50),
      'today': List.generate(24, (i) => 565 + Random().nextDouble() * 10),
      'yearly': List.generate(12, (i) => 400 + Random().nextDouble() * 200),
    },

    // -------- ETH --------
    {
      'coinId': 'ETH',
      'title': 'Ethereum',
      'price': 3457.32,
      'monthly': List.generate(30, (i) => 3400 + Random().nextDouble() * 100),
      'today': List.generate(24, (i) => 3450 + Random().nextDouble() * 50),
      'yearly': List.generate(12, (i) => 3200 + Random().nextDouble() * 200),
    },
    {
      'coinId': 'ETH-ETH',
      'title': 'ETH (Ethereum)',
      'price': 3457.32,
      'monthly': List.generate(30, (i) => 3400 + Random().nextDouble() * 100),
      'today': List.generate(24, (i) => 3450 + Random().nextDouble() * 50),
      'yearly': List.generate(12, (i) => 3200 + Random().nextDouble() * 200),
    },

    // -------- SOL --------
    {
      'coinId': 'SOL',
      'title': 'Solana',
      'price': 148.12,
      'monthly': List.generate(30, (i) => 140 + Random().nextDouble() * 12),
      'today': List.generate(24, (i) => 147 + Random().nextDouble() * 3),
      'yearly': List.generate(12, (i) => 120 + Random().nextDouble() * 30),
    },
    {
      'coinId': 'SOL-SOL',
      'title': 'SOL (Solana)',
      'price': 148.12,
      'monthly': List.generate(30, (i) => 140 + Random().nextDouble() * 12),
      'today': List.generate(24, (i) => 147 + Random().nextDouble() * 3),
      'yearly': List.generate(12, (i) => 120 + Random().nextDouble() * 30),
    },

    // -------- TRX --------
    {
      'coinId': 'TRX',
      'title': 'Tron',
      'price': 0.13,
      'monthly': List.generate(30, (i) => 0.12 + Random().nextDouble() * 0.02),
      'today': List.generate(24, (i) => 0.125 + Random().nextDouble() * 0.01),
      'yearly': List.generate(12, (i) => 0.10 + Random().nextDouble() * 0.04),
    },
    {
      'coinId': 'TRX-TRX',
      'title': 'TRX (Tron)',
      'price': 0.13,
      'monthly': List.generate(30, (i) => 0.12 + Random().nextDouble() * 0.02),
      'today': List.generate(24, (i) => 0.125 + Random().nextDouble() * 0.01),
      'yearly': List.generate(12, (i) => 0.10 + Random().nextDouble() * 0.04),
    },

    // -------- USDT --------
    {
      'coinId': 'USDT',
      'title': 'Tether',
      'price': 1.00,
      'monthly': List.generate(30, (i) => 0.99 + Random().nextDouble() * 0.02),
      'today': List.generate(24, (i) => 0.995 + Random().nextDouble() * 0.01),
      'yearly': List.generate(12, (i) => 0.98 + Random().nextDouble() * 0.04),
    },
    {
      'coinId': 'USDT-ETH',
      'title': 'Tether (ETH)',
      'price': 1.00,
      'monthly': List.generate(30, (i) => 0.99 + Random().nextDouble() * 0.02),
      'today': List.generate(24, (i) => 0.995 + Random().nextDouble() * 0.01),
      'yearly': List.generate(12, (i) => 0.98 + Random().nextDouble() * 0.04),
    },
    {
      'coinId': 'USDT-TRX',
      'title': 'Tether (TRX)',
      'price': 1.00,
      'monthly': List.generate(30, (i) => 0.99 + Random().nextDouble() * 0.02),
      'today': List.generate(24, (i) => 0.995 + Random().nextDouble() * 0.01),
      'yearly': List.generate(12, (i) => 0.98 + Random().nextDouble() * 0.04),
    },

    // -------- XMR --------
    {
      'coinId': 'XMR',
      'title': 'Monero',
      'price': 165.50,
      'monthly': List.generate(30, (i) => 150 + Random().nextDouble() * 20),
      'today': List.generate(24, (i) => 162 + Random().nextDouble() * 6),
      'yearly': List.generate(12, (i) => 120 + Random().nextDouble() * 60),
    },
    {
      'coinId': 'XMR-XMR',
      'title': 'Monero (XMR)',
      'price': 165.50,
      'monthly': List.generate(30, (i) => 150 + Random().nextDouble() * 20),
      'today': List.generate(24, (i) => 162 + Random().nextDouble() * 6),
      'yearly': List.generate(12, (i) => 120 + Random().nextDouble() * 60),
    },
  ];

  static const Color _pageBg = Color(0xFF0B0D1A); // deep navy

  @override
  Widget build(BuildContext context) {
    // ✅ Read coins from Provider (rebuilds if coin map changes)
    final coinStore = context.watch<CoinStore>();

    return Scaffold(
      backgroundColor: _pageBg,
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

                // ✅ Crypto stats pager pulling iconPath from CoinStore by coinId
                CryptoStatsPager(
                  cards: _cryptoCardsSeed.map((card) {
                    final String coinId = card['coinId'] as String;
                    return CryptoStatCard(
                      coinId: coinId,
                      title: card['title'] as String,
                      currentPrice: card['price'] as double,
                      monthlyData: List<double>.from(card['monthly'] as List),
                      todayData: List<double>.from(card['today'] as List),
                      yearlyData: List<double>.from(card['yearly'] as List),
                    );
                  }).toList(),
                  height: 340,
                  showArrows: false,
                  showDots: false,
                  scrollable: true,
                ),

                // ✅ Portfolio list: build from Provider coins so icons are guaranteed
                // ✅ Portfolio list: build from Provider coins so icons are guaranteed
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child:
                      const CryptoPortfolioWidget(), // auto-loads ALL coins from CoinStore
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// Responsive Legend Item (unchanged)
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
