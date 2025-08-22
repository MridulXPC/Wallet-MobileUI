import 'package:cryptowallet/coin_store.dart';
import 'package:flutter/material.dart';
import 'package:sizer/sizer.dart';
import 'package:provider/provider.dart';
import '../../../core/app_export.dart';

class CryptoPortfolioWidget extends StatefulWidget {
  /// If true (default), the widget ignores [portfolio] and builds rows from CoinStore (all coins).
  /// Set to false if you want to pass a custom subset via [portfolio].
  final bool useAllCoinsFromProvider;

  /// Optional manual list (used only when [useAllCoinsFromProvider] == false).
  final List<Map<String, dynamic>> portfolio;

  const CryptoPortfolioWidget({
    super.key,
    this.useAllCoinsFromProvider = true,
    this.portfolio = const [],
  });

  @override
  State<CryptoPortfolioWidget> createState() => _CryptoPortfolioWidgetState();
}

class _CryptoPortfolioWidgetState extends State<CryptoPortfolioWidget> {
  late List<Map<String, dynamic>> _visiblePortfolio;

  @override
  void initState() {
    super.initState();
    _refreshFromSource();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // If we’re sourcing from Provider, rebuild when dependencies change.
    if (widget.useAllCoinsFromProvider) {
      _refreshFromSource();
    }
  }

  void _refreshFromSource() {
    if (widget.useAllCoinsFromProvider) {
      final store = context.read<CoinStore>();
      // Build a row for each coin in the store with dummy balances/changes
      final all = store.coins.values.map((c) {
        return <String, dynamic>{
          "id": c.id, // e.g., USDT-ETH
          "symbol": c.symbol, // e.g., USDT
          "name": c.name, // e.g., Tether (ETH)
          "icon": c.assetPath, // asset path from store
          "balance": "0", // dummy
          "usdValue": "\$0.00", // dummy current price label
          "usdBalance": "0.00", // dummy balance in USD
          "change24h": "0.00%", // dummy change
          "isPositive": true, // dummy sign
          "enabled": true, // default enabled for filters
        };
      }).toList();

      _visiblePortfolio = all.where((x) => x["enabled"] != false).toList();
    } else {
      _visiblePortfolio =
          widget.portfolio.where((x) => x["enabled"] != false).toList();
    }
    if (mounted) setState(() {});
  }

  void _openTokenFilterSheet(BuildContext context) {
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
    // If we’re auto-sourcing from Provider, listen to changes to keep UI in sync.
    if (widget.useAllCoinsFromProvider) {
      context.watch<CoinStore>();
      // When coin set changes, rebuild list from source
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _refreshFromSource();
      });
    }

    if (_visiblePortfolio.isEmpty) {
      return _buildEmptyState(context);
    }

    return Column(
      children: [
        _buildTopSection(context),
        ListView.separated(
          physics: const NeverScrollableScrollPhysics(),
          shrinkWrap: true,
          itemCount: _visiblePortfolio.length,
          separatorBuilder: (_, __) => const SizedBox(height: 0),
          itemBuilder: (context, index) {
            final crypto = _visiblePortfolio[index];
            return _buildCryptoCard(context, crypto);
          },
        ),
        _buildFilterButton(context),
      ],
    );
  }

  Widget _buildTopSection(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        // Tokens tab
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Tokens',
              style: TextStyle(
                color: Colors.white,
                fontSize: 10.sp,
                fontWeight: FontWeight.w600,
              ),
            ),
            SizedBox(height: 0.5.h),
            Container(
              height: 2,
              width: 12.w,
              color: Colors.white,
            ),
          ],
        ),

        // Filter Icon
        IconButton(
          icon: Icon(
            Icons.tune,
            color: Colors.white,
            size: 16.sp,
          ),
          onPressed: () => _openTokenFilterSheet(context),
        ),
      ],
    );
  }

  Widget _buildCryptoCard(BuildContext context, Map<String, dynamic> crypto) {
    final bool isPositive = crypto["isPositive"] ?? true;
    final Color changeColor = isPositive ? Colors.green : Colors.red;

    // Resolve icon:
    final String? explicitPath = crypto["icon"] as String?;
    String? path = explicitPath;

    // If not provided or empty, try resolve from provider by id/symbol.
    if (path == null || path.isEmpty) {
      final store = context.read<CoinStore>();
      final String? id = crypto["id"] as String?;
      if (id != null) {
        path = store.getById(id)?.assetPath;
      } else {
        // fallback: look up by symbol (less precise but better than nothing)
        final String? symbol = crypto["symbol"] as String?;
        if (symbol != null) {
          final match = store.coins.values.firstWhere(
              (c) => c.symbol.toUpperCase() == symbol.toUpperCase(),
              orElse: () => store.coins.values.first);
          path = match.assetPath;
        }
      }
    }

    const fallbackAsset = 'assets/icons/placeholder.png';

    return InkWell(
      onTap: () {
        Navigator.pushNamed(
          context,
          AppRoutes.tokenDetail,
          arguments: crypto,
        );
      },
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: 1.h),
        child: Row(
          children: [
            // Icon
            SizedBox(
              width: 8.w,
              height: 8.w,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(50),
                child: Image.asset(
                  (path != null && path.isNotEmpty) ? path : fallbackAsset,
                  width: 8.w,
                  height: 8.w,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) =>
                      Image.asset(fallbackAsset, fit: BoxFit.cover),
                ),
              ),
            ),
            SizedBox(width: 2.w),

            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Prefer name if present, else symbol
                  Text(
                    crypto["name"] ?? crypto["symbol"] ?? '',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12.sp,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Row(
                    children: [
                      Text(
                        crypto["usdValue"] ?? '\$0.00',
                        style: TextStyle(
                          color: Colors.grey[400],
                          fontSize: 12.sp,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                      SizedBox(width: 2.w),
                      Icon(
                        isPositive
                            ? Icons.arrow_drop_up
                            : Icons.arrow_drop_down,
                        color: changeColor,
                        size: 16.sp,
                      ),
                      Text(
                        crypto["change24h"] ?? "0.00%",
                        style: TextStyle(
                          color: changeColor,
                          fontSize: 12.sp,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Balance
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  crypto["balance"] ?? "0.00",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12.sp,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  '≈ \$${crypto["usdBalance"] ?? "0.00"}',
                  style: TextStyle(
                    color: Colors.grey[400],
                    fontSize: 12.sp,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterButton(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(horizontal: 4.w),
      child: TextButton.icon(
        onPressed: () => _openTokenFilterSheet(context),
        icon: Icon(
          Icons.tune,
          color: Colors.white,
          size: 18.sp,
        ),
        label: Text(
          'Filter Tokens',
          style: TextStyle(
            color: Colors.white,
            fontSize: 12.sp,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 8.w),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CustomIconWidget(
              iconName: 'account_balance_wallet_outlined',
              color: AppTheme.lightTheme.colorScheme.onSurfaceVariant,
              size: 64,
            ),
            SizedBox(height: 3.h),
            Text(
              'Get Started',
              style: AppTheme.lightTheme.textTheme.headlineSmall?.copyWith(
                color: AppTheme.lightTheme.colorScheme.onSurface,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 1.h),
            Text(
              'Start building your crypto portfolio today',
              style: AppTheme.lightTheme.textTheme.bodyLarge?.copyWith(
                color: AppTheme.lightTheme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
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
    final store = context.watch<CoinStore>(); // ✅ keep icons fresh

    return SafeArea(
      child: Container(
        height: MediaQuery.of(context).size.height,
        decoration: BoxDecoration(
          color: const Color(0xFF1A1D29),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: EdgeInsets.symmetric(horizontal: 4.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Padding(
              padding: EdgeInsets.only(top: 4.h, bottom: 1.h),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    "Token Filter",
                    style: TextStyle(
                      fontSize: 12.sp,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close, color: Colors.white),
                  ),
                ],
              ),
            ),

            // Search Bar
            Container(
              padding: EdgeInsets.symmetric(horizontal: 3.w),
              decoration: BoxDecoration(
                color: Colors.transparent,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white24),
              ),
              child: Row(
                children: [
                  const Icon(Icons.search, color: Colors.white54),
                  SizedBox(width: 2.w),
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
            SizedBox(height: 2.h),

            // Token List
            Expanded(
              child: ListView.builder(
                itemCount: filteredList.length,
                itemBuilder: (context, index) {
                  final token = filteredList[index];
                  // match against name + symbol
                  final symbol =
                      (token["symbol"] ?? "").toString().toLowerCase();
                  final name = (token["name"] ?? "").toString().toLowerCase();

                  if (searchQuery.isNotEmpty &&
                      !symbol.contains(searchQuery) &&
                      !name.contains(searchQuery)) {
                    return const SizedBox.shrink();
                  }

                  // Resolve icon (prefer token.icon, else provider by id)
                  String? iconPath = token["icon"] as String?;
                  final String? id = token["id"] as String?;
                  if ((iconPath == null || iconPath.isEmpty) && id != null) {
                    iconPath = store.getById(id)?.assetPath;
                  }

                  return SwitchListTile(
                    value: token["enabled"] ?? true,
                    onChanged: (val) {
                      setState(() {
                        filteredList[index]["enabled"] = val;
                      });
                    },
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      token["name"] ?? token["symbol"] ?? '',
                      style: const TextStyle(color: Colors.white),
                    ),
                    subtitle: Text(
                      token["subtitle"] ?? token["usdValue"] ?? '',
                      style: const TextStyle(color: Colors.grey),
                    ),
                    secondary: (iconPath != null && iconPath.isNotEmpty)
                        ? Image.asset(iconPath,
                            width: 32,
                            height: 32,
                            errorBuilder: (_, __, ___) =>
                                const Icon(Icons.error, color: Colors.white))
                        : const Icon(Icons.currency_bitcoin,
                            color: Colors.white),
                    activeColor: AppTheme.info,
                    inactiveThumbColor: Colors.white,
                    inactiveTrackColor: Colors.grey,
                  );
                },
              ),
            ),

            // Apply Filter Button
            Padding(
              padding: EdgeInsets.only(bottom: 2.h, top: 1.h),
              child: SizedBox(
                width: double.infinity,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [
                        Color.fromARGB(255, 100, 162, 228),
                        Color(0xFF1A73E8)
                      ],
                    ),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Material(
                    color: Colors.transparent,
                    borderRadius: BorderRadius.circular(16),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: () {
                        Navigator.pop(context);
                        widget.onApplyFilter(filteredList);
                      },
                      child: Padding(
                        padding: EdgeInsets.symmetric(vertical: 1.6.h),
                        child: Center(
                          child: Text(
                            "Apply Filter",
                            style: TextStyle(
                              fontSize: 12.sp,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChip(String label, {String? icon}) {
    return Padding(
      padding: EdgeInsets.only(right: 3.w),
      child: Chip(
        label: Row(
          children: [
            if (icon != null)
              Padding(
                padding: EdgeInsets.only(right: 1.w),
                child: Image.asset(icon, width: 16, height: 16),
              ),
            Text(label),
          ],
        ),
        backgroundColor: Colors.white10,
        labelStyle: TextStyle(color: Colors.white, fontSize: 10.sp),
        padding: EdgeInsets.symmetric(horizontal: 3.w, vertical: 1.h),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
      ),
    );
  }
}
