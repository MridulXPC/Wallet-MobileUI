import 'package:flutter/material.dart';
import 'package:sizer/sizer.dart';
import '../../../core/app_export.dart';

class CryptoPortfolioWidget extends StatefulWidget {
  final List<Map<String, dynamic>> portfolio;

  const CryptoPortfolioWidget({
    super.key,
    required this.portfolio,
  });

  @override
  State<CryptoPortfolioWidget> createState() => _CryptoPortfolioWidgetState();
}

class _CryptoPortfolioWidgetState extends State<CryptoPortfolioWidget> {
  late List<Map<String, dynamic>> _visiblePortfolio;

  @override
  void initState() {
    super.initState();
    _visiblePortfolio = widget.portfolio
        .where((item) => item["enabled"] != false)
        .toList();
  }

  void _openTokenFilterSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => TokenFilterBottomSheet(
        portfolio: List<Map<String, dynamic>>.from(widget.portfolio),
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
          separatorBuilder: (context, index) => SizedBox(height: 0),
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

    final String? imagePath = crypto["icon"] as String?;
    final String fallbackAsset = 'assets/icons/placeholder.png';

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
            Container(
              width: 8.w,
              height: 8.w,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(50),
                child: Image.asset(
                  (imagePath != null && imagePath.isNotEmpty)
                      ? imagePath
                      : fallbackAsset,
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
                  Text(
                    crypto["symbol"] ?? '',
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
                        isPositive ? Icons.arrow_drop_up : Icons.arrow_drop_down,
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
  State<TokenFilterBottomSheet> createState() =>
      _TokenFilterBottomSheetState();
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
        decoration: BoxDecoration(
          color:   const Color(0xFF1A1D29),
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
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
                    icon: Icon(Icons.close, color: Colors.white),
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
                border: Border.all(
                  color: Colors.white24,
                ),
              ),
              child: Row(
                children: [
                  Icon(Icons.search, color: Colors.white54),
                  SizedBox(width: 2.w),
                  Expanded(
                    child: TextField(
                      style: TextStyle(color: Colors.white),
                      decoration: InputDecoration(
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
                  final String symbol =
                      (token["symbol"] ?? "").toString().toLowerCase();
      
                  if (!symbol.contains(searchQuery)) return SizedBox.shrink();
      
                  return SwitchListTile(
                    value: token["enabled"] ?? true,
                    onChanged: (val) {
                      setState(() {
                        filteredList[index]["enabled"] = val;
                      });
                    },
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      token["symbol"] ?? '',
                      style: TextStyle(color: Colors.white),
                    ),
                    subtitle: Text(
                      token["subtitle"] ?? token["usdValue"] ?? '',
                      style: TextStyle(color: Colors.grey),
                    ),
                    secondary: Image.asset(
                      token["icon"] ?? 'assets/icons/placeholder.png',
                      width: 32,
                      height: 32,
                      errorBuilder: (_, __, ___) => Icon(Icons.error),
                    ),
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
        gradient: LinearGradient(
         colors: [Color.fromARGB(255, 100, 162, 228), Color(0xFF1A73E8)],
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

