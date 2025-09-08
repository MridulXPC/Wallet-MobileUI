import 'package:cryptowallet/stores/coin_store.dart';
import 'package:cryptowallet/core/app_export.dart';
import 'package:cryptowallet/services/api_service.dart';
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

/// Portfolio list widget (icons strictly from CoinStore base symbol; no overlays/combo PNGs)
class CryptoPortfolioWidget extends StatefulWidget {
  final bool fetchFromApi; // always true in your flow, but keep configurable
  final List<Map<String, dynamic>> portfolio; // optional manual list

  const CryptoPortfolioWidget({
    super.key,
    this.fetchFromApi = true,
    this.portfolio = const [],
  });

  @override
  State<CryptoPortfolioWidget> createState() => _CryptoPortfolioWidgetState();
}

class _CryptoPortfolioWidgetState extends State<CryptoPortfolioWidget>
    with AutomaticKeepAliveClientMixin {
  static const String _fallbackAsset = 'assets/icons/placeholder.png';

  List<Map<String, dynamic>> _visible = [];
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  @override
  bool get wantKeepAlive => true;

  // --- Always resolve a single, base-symbol asset from CoinStore ---
  String _baseSymbolFor(String symbol, String chain) {
    final s = symbol.toUpperCase();
    final c = chain.toUpperCase();

    // Normalize API symbols to a base symbol (no network in the icon)
    if (s == 'USDTERC20' || (s == 'USDT' && c == 'ETH')) return 'USDT';
    if (s == 'USDTTRC20' || (s == 'USDT' && (c == 'TRX' || c == 'TRON')))
      return 'USDT';

    // Everything else: just the base
    return s; // BTC, ETH, BNB, SOL, TRX, XMR, etc.
  }

  String _assetFromStoreByBase(CoinStore store, String baseSymbol) {
    // Force base symbol icon only (never the network-specific id)
    return store.getById(baseSymbol)?.assetPath ?? _fallbackAsset;
  }

  Future<void> _refresh() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final store = context.read<CoinStore>();

      if (widget.fetchFromApi) {
        final tokens = await AuthService.fetchTokens(); // List<VaultToken>

        _visible = tokens.map((t) {
          final base = _baseSymbolFor(t.symbol, t.chain);
          final iconAsset = _assetFromStoreByBase(store, base);

          // Name: prefer CoinStore base name when available; fall back to API
          final coinName = store.getById(base)?.name ?? t.name;

          return {
            "id": t.symbol, // keep API symbol for routing if needed
            "symbol": base, // base symbol used throughout UI
            "name": coinName,
            "icon": iconAsset, // ✅ single image from CoinStore
            "balance": t.balance, // string like "0.0000"
            "usdValue": "\$${t.value.toString()}",
            "usdBalance": t.value.toStringAsFixed(2),
            "change24h": "0.00%", // placeholder unless backend provides it
            "isPositive": true, // placeholder
            "enabled": true,
            "chain": t.chain,
            "contractAddress": t.contractAddress,
            "_id": t.id,
          };
        }).toList();
      } else {
        // Purely use provided portfolio but ensure icon = base icon
        _visible = widget.portfolio.map((m) {
          final base = (m["symbol"] ?? m["id"] ?? "").toString().toUpperCase();
          final iconAsset = _assetFromStoreByBase(store, base);
          return {
            ...m,
            "symbol": base,
            "icon": iconAsset, // enforce base icon
          };
        }).toList();
      }

      _visible = _visible.where((x) => x["enabled"] != false).toList();
    } catch (e) {
      _error = e.toString();
      _visible = const [];
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

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
              onPressed: _refresh,
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

  const _CoinAvatar({super.key, required this.assetPath, this.size = 44});

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

/// One row item — strictly base-symbol icon.
class _PortfolioRow extends StatelessWidget {
  final Map<String, dynamic> item;
  const _PortfolioRow({required this.item});

  @override
  Widget build(BuildContext context) {
    final String icon =
        (item["icon"] as String?) ?? 'assets/icons/placeholder.png';
    final isPositive = item["isPositive"] ?? true;
    final changeColor = isPositive ? Colors.green : Colors.red;

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
                      Text(item["usdValue"] ?? '\$0.00',
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
                Text('≈ \$${item["usdBalance"] ?? "0.00"}',
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

                  return SwitchListTile(
                    value: token["enabled"] ?? true,
                    onChanged: (val) {
                      setState(() => filteredList[index]["enabled"] = val);
                    },
                    contentPadding: EdgeInsets.zero,
                    title: Text(title,
                        style: const TextStyle(color: Colors.white)),
                    subtitle: Text(token["usdValue"]?.toString() ?? '',
                        style: const TextStyle(color: Colors.grey)),
                    // ✅ single base icon
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
