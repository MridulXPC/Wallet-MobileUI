import 'package:flutter/material.dart';
import 'package:sizer/sizer.dart';
import '../../../core/app_export.dart';

class CryptoPortfolioWidget extends StatelessWidget {
  final List<Map<String, dynamic>> portfolio;

  const CryptoPortfolioWidget({
    super.key,
    required this.portfolio,
  });

  @override
  Widget build(BuildContext context) {
    if (portfolio.isEmpty) {
      return _buildEmptyState(context);
    }

    return ListView.separated(
      physics: const NeverScrollableScrollPhysics(),
      shrinkWrap: true,
      itemCount: portfolio.length,
      separatorBuilder: (context, index) => SizedBox(height: 0),
      itemBuilder: (context, index) {
        final crypto = portfolio[index];
        return _buildCryptoCard(context, crypto);
      },
    );
  }

  Widget _buildCryptoCard(BuildContext context, Map<String, dynamic> crypto) {
    final bool isPositive = crypto["isPositive"] ?? true;
    final Color changeColor = isPositive ? AppTheme.success : AppTheme.error;

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
        padding: EdgeInsets.symmetric(vertical: 1.5.h),
        child: Row(
          children: [
            Container(
              width: 12.w,
              height: 12.w,
              decoration: BoxDecoration(
        
                borderRadius: BorderRadius.circular(8),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.asset(
                  (imagePath != null && imagePath.isNotEmpty)
                      ? imagePath
                      : fallbackAsset,
                  width: 12.w,
                  height: 12.w,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) =>
                      Image.asset(fallbackAsset, fit: BoxFit.cover),
                ),
              ),
            ),
            SizedBox(width: 4.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        crypto["symbol"] ?? '',
                        style: AppTheme.lightTheme.textTheme.titleMedium?.copyWith(
                          color: AppTheme.lightTheme.colorScheme.onSurface,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      SizedBox(width: 2.w),
                      Expanded(
                        child: Text(
                          crypto["name"] ?? '',
                          style: AppTheme.lightTheme.textTheme.bodyMedium?.copyWith(
                            color: AppTheme.lightTheme.colorScheme.onSurfaceVariant,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 0.5.h),
                  Text(
                    '${crypto["balance"] ?? "0"} ${crypto["symbol"] ?? ""}',
                    style: AppTheme.monoTextStyle(
                      isLight: false,
                      fontSize: 12.sp,
                      color: AppTheme.lightTheme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  crypto["usdValue"] ?? '\$0.00',
                  style: AppTheme.lightTheme.textTheme.titleMedium?.copyWith(
                    color: AppTheme.lightTheme.colorScheme.onSurface,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(height: 0.6.h),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 2.w, vertical: 0.3.h),
                  decoration: BoxDecoration(
                    color: changeColor.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CustomIconWidget(
                        iconName: isPositive ? 'trending_up' : 'trending_down',
                        color: changeColor,
                        size: 12,
                      ),
                      SizedBox(width: 1.w),
                      Text(
                        crypto["change24h"] ?? "0.00%",
                        style: AppTheme.lightTheme.textTheme.labelSmall?.copyWith(
                          color: changeColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
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
            SizedBox(height: 4.h),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      // Navigate to buy crypto
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.info,
                      foregroundColor: AppTheme.onPrimary,
                      padding: EdgeInsets.symmetric(vertical: 2.h),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      'Buy Crypto',
                      style: AppTheme.lightTheme.textTheme.titleMedium?.copyWith(
                        color: AppTheme.onPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                SizedBox(width: 4.w),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      // Navigate to deposit crypto
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.info,
                      side: BorderSide(color: AppTheme.info, width: 1.5),
                      padding: EdgeInsets.symmetric(vertical: 2.h),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      'Deposit Crypto',
                      style: AppTheme.lightTheme.textTheme.titleMedium?.copyWith(
                        color: AppTheme.info,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
