import 'dart:async';
import 'dart:math';
import 'package:cryptowallet/services/api_service.dart';
import 'package:cryptowallet/services/wallet_flow.dart';
import 'package:cryptowallet/stores/coin_store.dart';
import 'package:cryptowallet/core/app_export.dart';
import 'package:cryptowallet/presentation/bottomnavbar.dart';
import 'package:cryptowallet/presentation/main_wallet_dashboard/widgets/crypto_portfolio_widget.dart';
import 'package:cryptowallet/presentation/main_wallet_dashboard/widgets/dashborad_card.dart';
import 'package:cryptowallet/presentation/main_wallet_dashboard/widgets/wallet_card_dashboard.dart';
import 'package:cryptowallet/routes/app_routes.dart';
import 'package:cryptowallet/stores/wallet_store.dart';
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
  bool _didBootstrap = false;

  @override
  @override
  void initState() {
    super.initState();
    _pageController = PageController(viewportFraction: 1.0);
    WidgetsBinding.instance.addPostFrameCallback((_) => _bootstrapOnce());
    _timer = Timer.periodic(const Duration(seconds: 4), (t) {
      if (!mounted) return; // guard
      if (_pageController.hasClients) {
        _currentPage = (_currentPage + 1) % 4;
        _pageController.animateToPage(
          _currentPage,
          duration: const Duration(milliseconds: 400),
          curve: Curves.bounceIn,
        );
      }
    });
  }

  Future<void> _bootstrapOnce() async {
    if (_didBootstrap) return;
    _didBootstrap = true;

    try {
      await AuthService.fetchMe();

      final local = await WalletFlow
          .ensureDefaultWallet(); // creates + saves locally if none
      debugPrint('Current wallet: ${local.name} | ${local.primaryAddress}');

      if (!mounted) return;
      // 🔥 tell the store to pull from local and activate the new/first wallet
      await context.read<WalletStore>().reloadFromLocalAndActivate(local.id);
    } catch (e) {
      debugPrint('Bootstrap failed: $e');
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    _timer.cancel();
    super.dispose();
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

  void _openActivities() {
    // you'll define this next
    Navigator.of(context, rootNavigator: true)
        .pushNamed(AppRoutes.transactionHistory);
  }

  static const Color _pageBg = Color(0xFF0B0D1A); // deep navy

  void _openChangeWalletSheet(BuildContext context) async {
    // 👇 keep a safe context from the parent screen
    final rootCtx = context;

    final wallets = await WalletFlow.loadLocalWallets();

    showModalBottomSheet(
      context: rootCtx,
      backgroundColor: const Color(0xFF1A1D29),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => StatefulBuilder(
        builder: (bottomSheetCtx, setModal) {
          Future<void> _create() async {
            try {
              // close using the root (still-mounted) context
              Navigator.of(rootCtx).pop();

              final w = await WalletFlow.createNewWallet(); // calls API + saves

              // ✅ update store so UI sees the new wallet
              if (mounted) {
                final store = rootCtx.read<WalletStore>();
                await store.reloadFromLocalAndActivate(w.id);
              }

              // show snackbar with the root context (NOT the disposed sheet)
              ScaffoldMessenger.of(rootCtx).showSnackBar(
                SnackBar(content: Text('Wallet created: ${w.name}')),
              );
            } catch (e) {
              if (mounted) {
                ScaffoldMessenger.of(rootCtx).showSnackBar(
                  SnackBar(content: Text('Failed: $e')),
                );
              }
            }
          }

          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(height: 6),
                  const Text('Your Wallets',
                      style: TextStyle(color: Colors.white, fontSize: 18)),
                  const SizedBox(height: 12),
                  ...wallets.map((w) => ListTile(
                        leading: const Icon(Icons.account_balance_wallet,
                            color: Colors.white70),
                        title: Text(w.name,
                            style: const TextStyle(color: Colors.white)),
                        subtitle: Text(
                          w.primaryAddress.isEmpty
                              ? 'No address'
                              : '${w.primaryAddress.substring(0, 8)}…${w.primaryAddress.substring(w.primaryAddress.length - 6)}',
                          style: const TextStyle(
                              color: Colors.white54, fontSize: 12),
                        ),
                        onTap: () {
                          Navigator.of(rootCtx).pop();
                          if (mounted) {
                            rootCtx.read<WalletStore>().setActive(w.id);
                          }
                        },
                      )),
                  const SizedBox(height: 6),
                  const Divider(color: Colors.white24),
                  ListTile(
                    leading:
                        const Icon(Icons.add_circle, color: Colors.lightGreen),
                    title: const Text('Create New Wallet',
                        style: TextStyle(color: Colors.white)),
                    subtitle: const Text('Generates a new seed & address',
                        style: TextStyle(color: Colors.white54, fontSize: 12)),
                    onTap: _create,
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // ✅ Read coins from Provider (rebuilds if coin map changes)
    context.watch<CoinStore>();

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
                  totalValue: '\$12,345.67',
                  vaultName: 'Main Wallet',
                  onTap: () {}, // open portfolio
                  onChangeWallet: () => _openChangeWalletSheet(context),
                  onActivities: () => Navigator.of(context, rootNavigator: true)
                      .pushNamed(AppRoutes.transactionHistory),
                ),

                // ✅ Crypto stats pager pulling iconPath from CoinStore by coinId
                const MainCoinsOnly(),

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

class MainCoinsOnly extends StatelessWidget {
  const MainCoinsOnly({super.key});

  @override
  Widget build(BuildContext context) {
    final store = context.watch<CoinStore>();

    // Only these 7 coins in your desired order
    const ids = ['BTC', 'ETH', 'SOL', 'TRX', 'USDT', 'BNB', 'XMR'];

    // Build cards only for coins that exist in the store
    final cards = <Widget>[];
    for (final id in ids) {
      final coin = store.getById(id);
      if (coin == null) continue;

      // dummy sparkline data; swap with real series if you have it
      const series = [1.0, 1.06, 1.02, 1.12, 1.08, 1.18];

      cards.add(
        CryptoStatCard(
          key: ValueKey('card-${coin.id}'),
          coinId: coin.id,
          title: coin.name,
          // Ensures one card per color/icon (even if duplicates are passed accidentally)
          colorKey: coin.assetPath,
          // TODO: replace with your live price (e.g., from a price provider)
          currentPrice: 0.0,
          monthlyData: series,
          todayData: series,
          yearlyData: series,
        ),
      );
    }

    // If none found, show a friendly empty state
    if (cards.isEmpty) {
      return const SizedBox(
        height: 160,
        child: Center(
          child: Text(
            'No main coins available',
            style: TextStyle(color: Colors.white70),
          ),
        ),
      );
    }

    return CryptoStatsPager(
      cards: cards, // exactly and only the 7 cards above
      viewportPeek: 0.95,
      height: 340,
      showArrows: false,
      showDots: false,
      scrollable: true,
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
