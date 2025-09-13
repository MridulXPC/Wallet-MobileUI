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
import 'package:provider/provider.dart';
import 'package:intl/intl.dart'; // ⬅️ for currency formatting

class WalletHomeScreen extends StatefulWidget {
  const WalletHomeScreen({super.key});

  @override
  State<WalletHomeScreen> createState() => _WalletHomeScreenState();
}

class _WalletHomeScreenState extends State<WalletHomeScreen> {
  int _selectedIndex = 0;

  // ⬇️ live portfolio total (display string)
  String _portfolioDisplay = '—';
  bool _loadingPortfolio = false;

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
  void initState() {
    super.initState();
    _pageController = PageController(viewportFraction: 1.0);

    _timer = Timer.periodic(const Duration(seconds: 4), (t) {
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
  }

  // ⬇️ Fetch wallets and compute total USD
  Future<void> _refreshPortfolioTotal() async {
    setState(() => _loadingPortfolio = true);
    try {
      final wallets = await AuthService.fetchWallets();
      final totalUsd = _sumAllWalletsUsd(wallets);
      final formatted = NumberFormat.currency(symbol: '\$', decimalDigits: 2)
          .format(totalUsd);
      if (!mounted) return;
      setState(() => _portfolioDisplay = formatted);
    } catch (_) {
      // keep previous display on error
    } finally {
      if (mounted) setState(() => _loadingPortfolio = false);
    }
  }

  // -------- Aggregation helpers (robust to varied shapes) --------
  double _sumAllWalletsUsd(List<Map<String, dynamic>> wallets) {
    double total = 0.0;
    for (final w in wallets) {
      total += _walletUsd(w);
    }
    return total;
  }

  double _walletUsd(Map<String, dynamic> w) {
    final chains = (w['chains'] as List?) ?? const [];
    if (chains.isNotEmpty) {
      double sum = 0.0;
      for (final c in chains) {
        if (c is! Map) continue;
        final m = c.cast<String, dynamic>();

        final usdDirect = _asDouble(m['fiatValue']) ??
            _asDouble(m['usdValue']) ??
            _asDouble(m['balanceUSD']);
        if (usdDirect != null) {
          sum += usdDirect;
          continue;
        }
        final bal = _asDouble(m['balance']) ?? _asDouble(m['amount']);
        final price = _asDouble(m['priceUsd']) ??
            _asDouble(m['usdPrice']) ??
            _asDouble(m['price']);
        if (bal != null && price != null) sum += bal * price;
      }
      return sum;
    }

    // wallet-level fallback values
    return _asDouble(w['fiatValue']) ??
        _asDouble(w['usdValue']) ??
        _asDouble(w['totalUsd']) ??
        _asDouble(w['total']) ??
        0.0;
  }

  double? _asDouble(dynamic v) {
    if (v == null) return null;
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v);
    return null;
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

  static const Color _pageBg = Color(0xFF0B0D1A); // deep navy

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
              final w = await WalletFlow.createNewWallet(); // API + save

              if (mounted) {
                final store = rootCtx.read<WalletStore>();
                await store.reloadFromLocalAndActivate(w.id);
                await _refreshPortfolioTotal(); // ⬅️ recompute after create
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
                        onTap: () async {
                          Navigator.of(rootCtx).pop();
                          if (mounted) {
                            await rootCtx.read<WalletStore>().setActive(w.id);
                            await _refreshPortfolioTotal(); // ⬅️ recompute after switch
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
                  totalValue: _portfolioDisplay, // ⬅️ dynamic total
                  vaultName: 'Main Wallet',
                  onTap: () {}, // open portfolio
                  onChangeWallet: () => _openChangeWalletSheet(context),
                  onActivities: () => Navigator.of(context, rootNavigator: true)
                      .pushNamed(AppRoutes.transactionHistory),
                ),
                const MainCoinsOnly(),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: const CryptoPortfolioWidget(),
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
