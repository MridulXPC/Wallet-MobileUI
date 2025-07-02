import 'package:flutter/material.dart';
import 'package:sizer/sizer.dart';

import '../../../core/app_export.dart';

class AssetSelectorWidget extends StatelessWidget {
  final String selectedAsset;
  final String selectedAssetSymbol;
  final double selectedAssetBalance;
  final String selectedAssetIcon;
  final List<Map<String, dynamic>> cryptoAssets;
  final Function(Map<String, dynamic>) onAssetSelected;

  const AssetSelectorWidget({
    super.key,
    required this.selectedAsset,
    required this.selectedAssetSymbol,
    required this.selectedAssetBalance,
    required this.selectedAssetIcon,
    required this.cryptoAssets,
    required this.onAssetSelected,
  });

  void _showAssetSelector(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: EdgeInsets.all(4.w),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 12.w,
              height: 0.5.h,
              decoration: BoxDecoration(
                color: AppTheme.dividerDark,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            SizedBox(height: 2.h),
            Text(
              'Select Asset',
              style: AppTheme.darkTheme.textTheme.titleLarge?.copyWith(
                color: AppTheme.textHighEmphasis,
                fontWeight: FontWeight.w600,
              ),
            ),
            SizedBox(height: 2.h),
            Container(
              decoration: BoxDecoration(
                color: AppTheme.background,
                borderRadius: BorderRadius.circular(12),
              ),
              child: TextField(
                style: AppTheme.darkTheme.textTheme.bodyMedium?.copyWith(
                  color: AppTheme.textHighEmphasis,
                ),
                decoration: InputDecoration(
                  hintText: 'Search assets...',
                  hintStyle: AppTheme.darkTheme.textTheme.bodyMedium?.copyWith(
                    color: AppTheme.textDisabled,
                  ),
                  prefixIcon: CustomIconWidget(
                    iconName: 'search',
                    color: AppTheme.textMediumEmphasis,
                    size: 20,
                  ),
                  border: InputBorder.none,
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 4.w, vertical: 2.h),
                ),
              ),
            ),
            SizedBox(height: 2.h),
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: cryptoAssets.length,
                separatorBuilder: (context, index) => Divider(
                  color: AppTheme.dividerDark,
                  height: 1,
                ),
                itemBuilder: (context, index) {
                  final asset = cryptoAssets[index];
                  final isSelected =
                      (asset["symbol"] as String) == selectedAssetSymbol;

                  return ListTile(
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 2.w, vertical: 1.h),
                    leading: Container(
                      width: 10.w,
                      height: 10.w,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppTheme.background,
                      ),
                      child: ClipOval(
                        child: CustomImageWidget(
                          imageUrl: asset["icon"] as String,
                          width: 10.w,
                          height: 10.w,
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                    title: Text(
                      asset["name"] as String,
                      style: AppTheme.darkTheme.textTheme.titleMedium?.copyWith(
                        color: AppTheme.textHighEmphasis,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    subtitle: Text(
                      asset["symbol"] as String,
                      style: AppTheme.darkTheme.textTheme.bodySmall?.copyWith(
                        color: AppTheme.textMediumEmphasis,
                      ),
                    ),
                    trailing: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          (asset["balance"] as double).toStringAsFixed(4),
                          style:
                              AppTheme.darkTheme.textTheme.titleSmall?.copyWith(
                            color: AppTheme.textHighEmphasis,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        Text(
                          '\$${((asset["balance"] as double) * (asset["price"] as double)).toStringAsFixed(2)}',
                          style:
                              AppTheme.darkTheme.textTheme.bodySmall?.copyWith(
                            color: AppTheme.textMediumEmphasis,
                          ),
                        ),
                      ],
                    ),
                    selected: isSelected,
                    selectedTileColor: AppTheme.primary.withValues(alpha: 0.1),
                    onTap: () {
                      onAssetSelected(asset);
                      Navigator.of(context).pop();
                    },
                  );
                },
              ),
            ),
            SizedBox(height: 2.h),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Asset',
          style: AppTheme.darkTheme.textTheme.titleMedium?.copyWith(
            color: AppTheme.textHighEmphasis,
            fontWeight: FontWeight.w500,
          ),
        ),
        SizedBox(height: 1.h),
        GestureDetector(
          onTap: () => _showAssetSelector(context),
          child: Container(
            width: double.infinity,
            padding: EdgeInsets.all(4.w),
            decoration: BoxDecoration(
              color: AppTheme.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: AppTheme.dividerDark,
                width: 1,
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 12.w,
                  height: 12.w,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppTheme.background,
                  ),
                  child: ClipOval(
                    child: CustomImageWidget(
                      imageUrl: selectedAssetIcon,
                      width: 12.w,
                      height: 12.w,
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
                SizedBox(width: 3.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        selectedAsset,
                        style:
                            AppTheme.darkTheme.textTheme.titleMedium?.copyWith(
                          color: AppTheme.textHighEmphasis,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      Text(
                        'Balance: ${selectedAssetBalance.toStringAsFixed(4)} $selectedAssetSymbol',
                        style: AppTheme.darkTheme.textTheme.bodySmall?.copyWith(
                          color: AppTheme.textMediumEmphasis,
                        ),
                      ),
                    ],
                  ),
                ),
                CustomIconWidget(
                  iconName: 'keyboard_arrow_down',
                  color: AppTheme.textMediumEmphasis,
                  size: 24,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
