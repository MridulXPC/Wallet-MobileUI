// lib/presentation/main_wallet_dashboard/widgets/crypto_portfolio_widget.dart
import 'package:cryptowallet/stores/coin_store.dart';
import 'package:cryptowallet/core/app_export.dart';
import 'package:cryptowallet/services/api_service.dart';
import 'package:cryptowallet/stores/wallet_store.dart';
import 'package:cryptowallet/core/currency_notifier.dart'; // 👈 added

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

/// Optional: pre-cache all coin icons once (e.g., call from splash/init)
Future<void> precacheCoinIcons(BuildContext context) async {
  final store = context.read<CoinStore>();
  for (final coin in store.coins.values) {
    try {
      await precacheImage(AssetImage(coin.assetPath), context);
    } catch (_) {}
  }
}

/// Portfolio list widget (reacts to active wallet & selected currency)
class CryptoPortfolioWidget extends StatefulWidget {
  const CryptoPortfolioWidget({super.key});

  @override
  State<CryptoPortfolioWidget> createState() => _CryptoPortfolioWidgetState();
}

class _CryptoPortfolioWidgetState extends State<CryptoPortfolioWidget>
    with AutomaticKeepAliveClientMixin {
  static const String _fallbackAsset = 'assets/currencyicons/bitcoin.png';

  /// Each item holds raw USD numbers; we format to selected fiat at build time.
  List<Map<String, dynamic>> _visible = [];
  bool _loading = false;
  String? _error;

  String? _activeWalletIdMemo;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final id = context.read<WalletStore>().activeWalletId;
      _activeWalletIdMemo = id;
      _refreshForWallet(id);
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // React to wallet change
    final currentId = context.watch<WalletStore>().activeWalletId;
    if (currentId != _activeWalletIdMemo) {
      _activeWalletIdMemo = currentId;
      _refreshForWallet(currentId);
    }
  }

  @override
  bool get wantKeepAlive => true;

  // ---------------- Helpers ----------------

  String _baseSymbolFor(String? symbol, String? chain) {
    final s = (symbol ?? '').toUpperCase();
    final c = (chain ?? '').toUpperCase();

    if (s == 'USDTERC20' || (s == 'USDT' && c == 'ETH')) return 'USDT';
    if (s == 'USDTTRC20' || (s == 'USDT' && (c == 'TRX' || c == 'TRON'))) {
      return 'USDT';
    }
    return s.isEmpty ? c : s;
  }

  String _assetForSymbol(BuildContext context, String base) {
    final store = context.read<CoinStore>();
    final byId = store.getById(base);
    if (byId != null) return byId.assetPath;
    try {
      final match = store.coins.values.firstWhere(
        (c) => c.symbol.toUpperCase() == base.toUpperCase(),
      );
      return match.assetPath;
    } catch (_) {}
    return _fallbackAsset;
  }

  String _nameForSymbol(
      BuildContext context, String base, String? defaultName) {
    final store = context.read<CoinStore>();
    final byId = store.getById(base);
    if (byId != null) return byId.name;
    try {
      final match = store.coins.values.firstWhere(
        (c) => c.symbol.toUpperCase() == base.toUpperCase(),
      );
      return match.name;
    } catch (_) {}
    return defaultName ?? base;
  }

  // ---------------- Fetch & map ----------------

  Future<void> _refreshForWallet(String? walletId) async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      String? useWalletId = walletId;
      final wallets = await AuthService.fetchWallets();
      if (wallets.isNotEmpty) {
        useWalletId = useWalletId ??
            wallets.first['walletId']?.toString() ??
            wallets.first['id']?.toString() ??
            wallets.first['_id']?.toString();
      }

      if (useWalletId == null || useWalletId.isEmpty) {
        setState(() {
          _visible = const [];
          _loading = false;
          _error = 'No wallet available.';
        });
        return;
      }

      final tokens =
          await AuthService.fetchTokensByWallet(walletId: useWalletId);

      // ✅ Group by symbol & take only MAINNET chains
      final Map<String, Map<String, dynamic>> grouped = {};

      for (final t in tokens) {
        final base = _baseSymbolFor(t.symbol, t.chain);
        final chain = (t.chain ?? '').toUpperCase();

        final isMainnet = switch (base) {
          'BTC' => chain == 'BTC',
          'ETH' => chain == 'ETH',
          'USDT' => chain == 'ETH' || chain == 'TRX' || chain == 'TRON',
          _ => true,
        };
        if (!isMainnet) continue;

        final usdValNum = (t.value is num)
            ? (t.value as num).toDouble()
            : double.tryParse('${t.value}') ?? 0.0;

        final balNum = double.tryParse('${t.balance}') ?? 0.0;

        final existing = grouped[base];
        if (existing != null) {
          existing['usdValueNum'] += usdValNum;
          existing['usdBalanceNum'] += usdValNum; // ✅ add this line
          existing['balanceNum'] += balNum;
        } else {
          grouped[base] = {
            "symbol": base,
            "name": _nameForSymbol(context, base, t.name),
            "icon": _assetForSymbol(context, base),
            "usdValueNum": usdValNum,
            "usdBalanceNum": usdValNum, // used for fiat display
            "balanceNum": balNum,
            "balance": t.balance ?? '0.0000',
            "change24h": '${t.changePercent ?? 0.0}%',
            "isPositive": (t.changePercent ?? 0.0) >= 0,
          };
        }
      }

// Convert numeric balanceNum → string for UI
      _visible = grouped.values.map((e) {
        e['balance'] = (e['balanceNum'] ?? 0.0).toStringAsFixed(4);
        e['usdBalanceNum'] =
            (e['usdBalanceNum'] ?? 0.0); // ✅ ensure it’s up to date
        return e;
      }).toList();

// Convert numeric balanceNum → string for UI
      _visible = grouped.values.map((e) {
        e['balance'] = (e['balanceNum'] ?? 0.0).toStringAsFixed(4);
        return e;
      }).toList();
    } catch (e, st) {
      debugPrint('❌ Portfolio load error: $e\n$st');
      _error = e.toString();
      _visible = const [];
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // ---------------- UI ----------------

  void _openTokenFilterSheet() {
    final initial = List<Map<String, dynamic>>.from(_visible);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => TokenFilterBottomSheet(
        portfolio: initial,
        onApplyFilter: (filtered) {
          setState(() {
            _visible = filtered.where((x) => x["enabled"] != false).toList();
          });
        },
        fallbackAsset: _fallbackAsset,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    if (_loading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 24.0),
        child: Center(child: CircularProgressIndicator(color: Colors.white)),
      );
    }

    if (_error != null) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 24.0),
        child: Column(
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.redAccent),
            const SizedBox(height: 8),
            Text(_error!,
                style: const TextStyle(color: Colors.white70),
                textAlign: TextAlign.center),
            const SizedBox(height: 12),
            TextButton.icon(
              onPressed: () => _refreshForWallet(_activeWalletIdMemo),
              icon: const Icon(Icons.refresh, color: Colors.white),
              label: const Text('Retry', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      );
    }

    if (_visible.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 24.0),
        child: Column(
          children: const [
            Icon(Icons.account_balance_wallet_outlined,
                size: 56, color: Colors.white70),
            SizedBox(height: 12),
            Text('No tokens found',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w600)),
            SizedBox(height: 6),
            Text('Pull down to refresh and fetch your tokens.',
                style: TextStyle(color: Colors.white54, fontSize: 14),
                textAlign: TextAlign.center),
          ],
        ),
      );
    }

    return Column(
      children: [
        _buildTopBar(),
        ListView.separated(
          physics: const NeverScrollableScrollPhysics(),
          shrinkWrap: true,
          itemCount: _visible.length,
          separatorBuilder: (_, __) => const SizedBox(height: 0),
          itemBuilder: (context, i) => _PortfolioRow(item: _visible[i]),
        ),
        _buildFilterButton(),
      ],
    );
  }

  Widget _buildTopBar() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            Text('Tokens',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w700)),
            SizedBox(height: 4),
            SizedBox(
                height: 2,
                width: 60,
                child: DecoratedBox(
                    decoration: BoxDecoration(color: Colors.white))),
          ],
        ),
        IconButton(
          icon: const Icon(Icons.tune, color: Colors.white),
          onPressed: _openTokenFilterSheet,
        ),
      ],
    );
  }

  Widget _buildFilterButton() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: TextButton.icon(
        onPressed: _openTokenFilterSheet,
        icon: const Icon(Icons.tune, color: Colors.white),
        label:
            const Text('Manage Tokens', style: TextStyle(color: Colors.white)),
      ),
    );
  }
}

/// Single, non-overlapping coin avatar (asset-only).
class _CoinAvatar extends StatelessWidget {
  final String assetPath;
  final double size;

  const _CoinAvatar({required this.assetPath, this.size = 44});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(size / 2),
        child: Image.asset(assetPath, fit: BoxFit.contain),
      ),
    );
  }
}

/// One row item — values formatted by CurrencyNotifier (reactive to currency).
class _PortfolioRow extends StatelessWidget {
  final Map<String, dynamic> item;
  const _PortfolioRow({required this.item});

  @override
  Widget build(BuildContext context) {
    final fx = context.watch<CurrencyNotifier>(); // 👈 react to currency/rates

    final String icon =
        (item["icon"] as String?) ?? 'assets/currencyicons/bitcoin.png';
    final isPositive = (item["isPositive"] ?? true) as bool;
    final changeColor = isPositive ? Colors.green : Colors.red;

    // Raw USD numbers stored by parent:
    final double usdValueNum = (item["usdValueNum"] is num)
        ? (item["usdValueNum"] as num).toDouble()
        : 0.0;
    final double usdBalanceNum = (item["usdBalanceNum"] is num)
        ? (item["usdBalanceNum"] as num).toDouble()
        : 0.0;

    // Format now in selected fiat:
    final String fiatValue = fx.formatFromUsd(usdValueNum);
    final String fiatBalanceApprox = fx.formatFromUsd(usdBalanceNum);

    return InkWell(
      key: ValueKey(item["id"] ?? item["symbol"]),
      onTap: () {
        Navigator.pushNamed(context, AppRoutes.tokenDetail, arguments: item);
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10.0),
        child: Row(
          children: [
            _CoinAvatar(assetPath: icon, size: 44),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(item["name"] ?? item["symbol"] ?? '',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w700)),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Text(fiatValue,
                          style: const TextStyle(
                              color: Colors.white54, fontSize: 12)),
                      const SizedBox(width: 6),
                      Icon(
                          isPositive
                              ? Icons.arrow_drop_up
                              : Icons.arrow_drop_down,
                          color: changeColor,
                          size: 18),
                      Text(item["change24h"] ?? "0.00%",
                          style: TextStyle(color: changeColor, fontSize: 12)),
                    ],
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(item["balance"]?.toString() ?? "0.00",
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w700)),
                const SizedBox(height: 2),
                Text('≈ $fiatBalanceApprox',
                    style:
                        const TextStyle(color: Colors.white54, fontSize: 12)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------- Filter Sheet ----------------

class TokenFilterBottomSheet extends StatefulWidget {
  final List<Map<String, dynamic>> portfolio;
  final void Function(List<Map<String, dynamic>>) onApplyFilter;
  final String fallbackAsset;

  const TokenFilterBottomSheet({
    super.key,
    required this.portfolio,
    required this.onApplyFilter,
    required this.fallbackAsset,
  });

  @override
  State<TokenFilterBottomSheet> createState() => _TokenFilterBottomSheetState();
}

class _TokenFilterBottomSheetState extends State<TokenFilterBottomSheet> {
  late List<Map<String, dynamic>> filteredList;
  String searchQuery = "";

  @override
  void initState() {
    super.initState();
    filteredList = List<Map<String, dynamic>>.from(widget.portfolio);
  }

  @override
  Widget build(BuildContext context) {
    final fx = context.watch<CurrencyNotifier>(); // 👈 live currency in sheet

    return SafeArea(
      child: Container(
        height: MediaQuery.of(context).size.height,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomRight,
            stops: [0.0, 0.55, 1.0],
            colors: [
              Color.fromARGB(255, 6, 11, 33),
              Color.fromARGB(255, 0, 0, 0),
              Color.fromARGB(255, 0, 12, 56),
            ],
          ),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.only(top: 20, bottom: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text("Token Filter",
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w700)),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close, color: Colors.white),
                  ),
                ],
              ),
            ),

            // Search
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: Colors.transparent,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white24),
              ),
              child: Row(
                children: [
                  const Icon(Icons.search, color: Colors.white54),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(
                        hintText: 'Search tokens',
                        hintStyle: TextStyle(color: Colors.white54),
                        border: InputBorder.none,
                      ),
                      onChanged: (value) =>
                          setState(() => searchQuery = value.toLowerCase()),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // List
            Expanded(
              child: ListView.builder(
                itemCount: filteredList.length,
                itemBuilder: (context, index) {
                  final token = filteredList[index];

                  final symbol =
                      (token["symbol"] ?? "").toString().toLowerCase();
                  final name = (token["name"] ?? "").toString().toLowerCase();

                  if (searchQuery.isNotEmpty &&
                      !symbol.contains(searchQuery) &&
                      !name.contains(searchQuery)) {
                    return const SizedBox.shrink();
                  }

                  final iconPath =
                      (token["icon"] as String?) ?? widget.fallbackAsset;
                  final String title = token["name"] ?? token["symbol"] ?? '';

                  // Show value in selected fiat
                  final double usdValNum = (token["usdValueNum"] is num)
                      ? (token["usdValueNum"] as num).toDouble()
                      : 0.0;
                  final String fiatVal = fx.formatFromUsd(usdValNum);

                  return SwitchListTile(
                    value: token["enabled"] ?? true,
                    onChanged: (val) {
                      setState(() => filteredList[index]["enabled"] = val);
                    },
                    contentPadding: EdgeInsets.zero,
                    title: Text(title,
                        style: const TextStyle(color: Colors.white)),
                    subtitle: Text(fiatVal,
                        style: const TextStyle(color: Colors.grey)),
                    secondary: _CoinAvatar(assetPath: iconPath, size: 32),
                    activeColor: Colors.blueAccent,
                    inactiveThumbColor: Colors.white,
                    inactiveTrackColor: Colors.grey,
                  );
                },
              ),
            ),

            // Apply
            Padding(
              padding: const EdgeInsets.only(bottom: 16, top: 8),
              child: SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    widget.onApplyFilter(filteredList);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1A73E8),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                    elevation: 0,
                  ),
                  child: const Text("Apply Filter",
                      style: TextStyle(
                          color: Colors.white, fontWeight: FontWeight.w700)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
