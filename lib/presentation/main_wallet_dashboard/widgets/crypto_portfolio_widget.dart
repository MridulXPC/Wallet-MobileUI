import 'package:cryptowallet/coin_store.dart';
import 'package:cryptowallet/core/app_export.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

/// Optional: pre-cache all coin icons once (e.g., call from splash/init)
Future<void> precacheCoinIcons(BuildContext context) async {
  final store = context.read<CoinStore>();
  for (final coin in store.coins.values) {
    final provider = AssetImage(coin.assetPath);
    try {
      await precacheImage(provider, context);
    } catch (_) {
      // ignore missing assets
    }
  }
}

/// Portfolio list widget (optimized)
class CryptoPortfolioWidget extends StatefulWidget {
  /// If true (default), the widget ignores [portfolio] and builds rows from CoinStore (all coins).
  /// Set to false if you want to pass a custom subset via [portfolio].
  final bool useAllCoinsFromProvider;

  final List<Map<String, dynamic>> portfolio;

  const CryptoPortfolioWidget({
    super.key,
    this.useAllCoinsFromProvider = true,
    this.portfolio = const [],
  });

  @override
  State<CryptoPortfolioWidget> createState() => _CryptoPortfolioWidgetState();
}

class _CryptoPortfolioWidgetState extends State<CryptoPortfolioWidget>
    with AutomaticKeepAliveClientMixin {
  late List<Map<String, dynamic>> _visiblePortfolio;

  @override
  void initState() {
    super.initState();
    _refreshFromSource();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (widget.useAllCoinsFromProvider) {
      _refreshFromSource();
    }
  }

  @override
  bool get wantKeepAlive => true;

  void _refreshFromSource() {
    if (widget.useAllCoinsFromProvider) {
      final store = context.read<CoinStore>();

      // ✅ BTC added
      const allowedIds = <String>[
        "BTC",
        "TRX-TRX",
        "BNB-BNB",
        "USDT",
        "XMR-XMR",
        "ETH-ETH",
      ];

      final all = store.coins.values
          .where((c) => allowedIds.contains(c.id))
          .map((c) => {
                "id": c.id,
                "symbol": c.symbol,
                "name": c.name,
                "icon": c.assetPath,
                "balance": "0",
                "usdValue": "\$0.00",
                "usdBalance": "0.00",
                "change24h": "0.00%",
                "isPositive": true,
                "enabled": true,
              })
          .toList();

      _visiblePortfolio = all.where((x) => x["enabled"] != false).toList();
    } else {
      _visiblePortfolio =
          widget.portfolio.where((x) => x["enabled"] != false).toList();
    }
    if (mounted) setState(() {});
  }

  void _openTokenFilterSheet() {
    final sourceList = widget.useAllCoinsFromProvider
        ? List<Map<String, dynamic>>.from(_visiblePortfolio)
        : List<Map<String, dynamic>>.from(widget.portfolio);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => TokenFilterBottomSheet(
        portfolio: sourceList,
        onApplyFilter: (filtered) {
          setState(() {
            _visiblePortfolio =
                filtered.where((item) => item["enabled"] != false).toList();
          });
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    if (_visiblePortfolio.isEmpty) {
      return _buildEmptyState();
    }

    return Column(
      children: [
        _buildTopBar(),
        ListView.separated(
          physics: const NeverScrollableScrollPhysics(),
          shrinkWrap: true,
          itemCount: _visiblePortfolio.length,
          separatorBuilder: (_, __) => const SizedBox(height: 0),
          itemBuilder: (context, index) {
            return _PortfolioRow(crypto: _visiblePortfolio[index]);
          },
        ),
        _buildFilterButton(),
      ],
    );
  }

  Widget _buildTopBar() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        // "Tokens" + underline
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Tokens',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            Container(height: 2, width: 60, color: Colors.white),
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
        label: const Text(
          'Manage Tokens',
          style: TextStyle(color: Colors.white),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24.0),
      child: Column(
        children: const [
          Icon(Icons.account_balance_wallet_outlined,
              size: 56, color: Colors.white70),
          SizedBox(height: 12),
          Text('Get Started',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w600)),
          SizedBox(height: 6),
          Text(
            'Start building your crypto portfolio today',
            style: TextStyle(color: Colors.white54, fontSize: 14),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

/// A single row that rebuilds minimally using [Selector] for icon changes.
class _PortfolioRow extends StatelessWidget {
  final Map<String, dynamic> crypto;
  const _PortfolioRow({required this.crypto});

  @override
  Widget build(BuildContext context) {
    final id = crypto["id"] as String?;
    final explicitPath = crypto["icon"] as String?;
    const fallbackAsset = 'assets/icons/placeholder.png';

    // Resolve icon path via Selector only if we DON'T have an explicit path in map.
    final iconPath = explicitPath ??
        context.select<CoinStore, String>(
          (s) => id != null
              ? (s.getById(id)?.assetPath ?? fallbackAsset)
              : fallbackAsset,
        );

    final isPositive = crypto["isPositive"] ?? true;
    final changeColor = isPositive ? Colors.green : Colors.red;

    return InkWell(
      key: ValueKey(crypto["id"] ?? crypto["symbol"]),
      onTap: () {
        Navigator.pushNamed(
          context,
          AppRoutes.tokenDetail, // <-- route name constant
          arguments: crypto,
        );
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10.0),
        child: Row(
          children: [
            // Icon (cheap decode using ResizeImage)
            CircleAvatar(
              radius: 22,
              backgroundColor: Colors.transparent,
              child: Padding(
                padding:
                    const EdgeInsets.all(4), // small padding prevents cutting
                child: Image.asset(
                  iconPath,
                  fit: BoxFit.contain,
                ),
              ),
            ),
            const SizedBox(width: 12),

            // Name + price/change
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    crypto["name"] ?? crypto["symbol"] ?? '',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Text(
                        crypto["usdValue"] ?? '\$0.00',
                        style: const TextStyle(
                            color: Colors.white54, fontSize: 12),
                      ),
                      const SizedBox(width: 6),
                      Icon(
                        isPositive
                            ? Icons.arrow_drop_up
                            : Icons.arrow_drop_down,
                        color: changeColor,
                        size: 18,
                      ),
                      Text(
                        crypto["change24h"] ?? "0.00%",
                        style: TextStyle(color: changeColor, fontSize: 12),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Balances
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  crypto["balance"] ?? "0.00",
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 2),
                Text(
                  '≈ \$${crypto["usdBalance"] ?? "0.00"}',
                  style: const TextStyle(color: Colors.white54, fontSize: 12),
                ),
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
  final Function(List<Map<String, dynamic>>) onApplyFilter;

  const TokenFilterBottomSheet({
    super.key,
    required this.portfolio,
    required this.onApplyFilter,
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
    final bg = const Color(0xFF1A1D29);

    return SafeArea(
      child: Container(
        height: MediaQuery.of(context).size.height,
        decoration: BoxDecoration(
          color: bg,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
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
                      onChanged: (value) {
                        setState(() {
                          searchQuery = value.toLowerCase();
                        });
                      },
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

                  final iconPath = token["icon"] as String?;
                  final String title = token["name"] ?? token["symbol"] ?? '';

                  return SwitchListTile(
                    value: token["enabled"] ?? true,
                    onChanged: (val) {
                      setState(() {
                        filteredList[index]["enabled"] = val;
                      });
                    },
                    contentPadding: EdgeInsets.zero,
                    title: Text(title,
                        style: const TextStyle(color: Colors.white)),
                    subtitle: Text(
                      token["subtitle"] ?? token["usdValue"] ?? '',
                      style: const TextStyle(color: Colors.grey),
                    ),
                    secondary: (iconPath != null && iconPath.isNotEmpty)
                        ? CircleAvatar(
                            radius: 16,
                            backgroundColor: const Color(0xFF2A2D3A),
                            foregroundImage: ResizeImage(
                              AssetImage(iconPath),
                              width:
                                  (32 * MediaQuery.of(context).devicePixelRatio)
                                      .round(),
                            ),
                            onForegroundImageError: (_, __) {},
                            child: const Icon(Icons.currency_bitcoin,
                                color: Colors.white, size: 16),
                          )
                        : const Icon(Icons.currency_bitcoin,
                            color: Colors.white),
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
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 0,
                  ),
                  child: const Text(
                    "Apply Filter",
                    style: TextStyle(
                        color: Colors.white, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
