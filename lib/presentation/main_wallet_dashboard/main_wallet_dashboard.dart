import 'dart:async';
import 'dart:math';
import 'package:cryptowallet/services/wallet_flow.dart';
import 'package:cryptowallet/services/api_service.dart'; // Add your API service import
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
import 'package:provider/provider.dart';
import 'package:cryptowallet/stores/balance_store.dart';

class WalletHomeScreen extends StatefulWidget {
  const WalletHomeScreen({super.key});

  @override
  State<WalletHomeScreen> createState() => _WalletHomeScreenState();
}

class _WalletHomeScreenState extends State<WalletHomeScreen> {
  int _selectedIndex = 0;
  late final PageController _pageController;
  int _currentPage = 0;
  late final Timer _pagerTimer;
  late final Timer _balanceRefreshTimer;
  late final BalanceStore _balanceStore;

  // Balance data
  List<ChainBalance> _balances = [];
  double _totalUsd = 0.0;
  bool _isLoadingBalance = false;

  static const Color _pageBg = Color(0xFF0B0D1A);

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
    setState(() => _selectedIndex = index);
  }

  Future<void> _fetchBalance() async {
    if (!mounted || _isLoadingBalance) return;

    setState(() => _isLoadingBalance = true);

    try {
      debugPrint('🔄 Fetching balance at ${DateTime.now()}');

      // Direct API call using your existing function
      final payload = await AuthService.fetchBalancesAndTotal();

      if (!mounted) return;

      setState(() {
        _balances = payload.rows;
        _totalUsd = payload.totalUsd;
      });

      debugPrint(
          '✅ Balance refreshed successfully: \$${_totalUsd.toStringAsFixed(2)}');
    } catch (e) {
      debugPrint('❌ Error refreshing balance: $e');

      if (mounted && !e.toString().contains('authentication')) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to refresh balance: ${e.toString()}'),
            duration: const Duration(seconds: 2),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoadingBalance = false);
      }
    }
  }

  @override
  void initState() {
    super.initState();
    _pageController = PageController(viewportFraction: 1.0);
    _balanceStore = context.read<BalanceStore>();

    // Auto-scroll timer for cards
    _pagerTimer = Timer.periodic(const Duration(seconds: 4), (t) {
      if (!mounted) return;
      if (_pageController.hasClients) {
        _currentPage = (_currentPage + 1) % 4;
        _pageController.animateToPage(
          _currentPage,
          duration: const Duration(milliseconds: 400),
          curve: Curves.bounceIn,
        );
      }
    });

    // Balance refresh timer - every 20 seconds
    _balanceRefreshTimer =
        Timer.periodic(const Duration(seconds: 2000000000000000000), (t) {
      _fetchBalance();
    });

    // Initial fetch
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _fetchBalance();
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    _pagerTimer.cancel();
    _balanceRefreshTimer.cancel();
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

  void _openChangeWalletSheet(BuildContext context) async {
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
              Navigator.of(rootCtx).pop();
              final w = await WalletFlow.createNewWallet();

              if (mounted) {
                await _fetchBalance(); // Refresh after wallet creation
              }

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
                  const Text(
                    'Your Wallets',
                    style: TextStyle(color: Colors.white, fontSize: 18),
                  ),
                  const SizedBox(height: 12),
                  ...wallets.map((w) => ListTile(
                        leading: const Icon(Icons.account_balance_wallet,
                            color: Colors.white70),
                        title: Text(
                          w.name,
                          style: const TextStyle(color: Colors.white),
                        ),
                        subtitle: Text(
                          w.primaryAddress.isEmpty
                              ? 'No address'
                              : '${w.primaryAddress.substring(0, 8)}…${w.primaryAddress.substring(w.primaryAddress.length - 6)}',
                          style: const TextStyle(
                            color: Colors.white54,
                            fontSize: 12,
                          ),
                        ),
                        onTap: () async {
                          Navigator.of(rootCtx).pop();
                          if (mounted) {
                            await rootCtx.read<WalletStore>().setActive(w.id);
                            await _fetchBalance(); // Refresh after wallet change
                          }
                        },
                      )),
                  const SizedBox(height: 6),
                  const Divider(color: Colors.white24),
                  ListTile(
                    leading:
                        const Icon(Icons.add_circle, color: Colors.lightGreen),
                    title: const Text(
                      'Wallet',
                      style: TextStyle(color: Colors.white),
                    ),
                    subtitle: const Text(
                      'Generates a new seed & address',
                      style: TextStyle(color: Colors.white54, fontSize: 12),
                    ),
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

  String get _totalUsdFormatted => '\$${_totalUsd.toStringAsFixed(2)}';

  @override
  Widget build(BuildContext context) {
    context.watch<CoinStore>();

    // Use local state for balance display
    final totalDisplay = _totalUsdFormatted;

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
                Stack(
                  children: [
                    VaultHeaderCard(
                      totalValue: totalDisplay,
                      vaultName: 'Main Wallet',
                      onTap: () {},
                      onChangeWallet: () => _openChangeWalletSheet(context),
                      onActivities: () =>
                          Navigator.of(context, rootNavigator: true)
                              .pushNamed(AppRoutes.transactionHistory),
                    ),
                    // Loading indicator
                    if (_isLoadingBalance)
                      Positioned(
                        top: 8,
                        right: 8,
                        child: SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.white.withOpacity(0.7),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                const MainCoinsOnly(),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 12),
                  child: CryptoPortfolioWidget(),
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
    const ids = ['BTC', 'ETH', 'SOL', 'TRX', 'USDT', 'BNB', 'XMR'];

    final cards = <Widget>[];
    for (final id in ids) {
      final coin = store.getById(id);
      if (coin == null) continue;
      const series = [1.0, 1.06, 1.02, 1.12, 1.08, 1.18];
      cards.add(
        CryptoStatCard(
          key: ValueKey('card-${coin.id}'),
          coinId: coin.id,
          title: coin.name,
          colorKey: coin.assetPath,
          currentPrice: 0.0,
          monthlyData: series,
          todayData: series,
          yearlyData: series,
        ),
      );
    }

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
      cards: cards,
      viewportPeek: 0.95,
      height: 340,
      showArrows: false,
      showDots: false,
      scrollable: true,
    );
  }
}
