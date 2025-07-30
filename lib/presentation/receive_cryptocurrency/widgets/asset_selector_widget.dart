import 'package:flutter/material.dart';
import 'package:sizer/sizer.dart';

import '../../../core/app_export.dart';

class AssetSelectorWidget extends StatelessWidget {
  final List<Map<String, dynamic>> assets;
  final int selectedIndex;
  final Function(int) onAssetSelected;

  const AssetSelectorWidget({
    super.key,
    required this.assets,
    required this.selectedIndex,
    required this.onAssetSelected,
  });

  @override
  Widget build(BuildContext context) {
    final selectedAsset = assets[selectedIndex];

    return Container(
      padding: EdgeInsets.all(4.w),
      decoration: BoxDecoration(
        color: AppTheme.darkTheme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Select Asset',
            style: AppTheme.darkTheme.textTheme.titleMedium,
          ),
          SizedBox(height: 2.h),

          // Selected Asset Display
          GestureDetector(
            onTap: () => _showAssetSelector(context),
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 2.h),
              decoration: BoxDecoration(
                color: AppTheme.darkTheme.scaffoldBackgroundColor,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppTheme.darkTheme.colorScheme.outline,
                  width: 1,
                ),
              ),
              child: Row(
                children: [
                  // Asset Icon
                  Center(
                    child: Image.asset(
                      selectedAsset["icon"] as String,
                      width: 6.w,
                      height: 6.w,
                      fit: BoxFit.contain,
                    ),
                  ),
                  SizedBox(width: 3.w),

                  // Asset Info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          selectedAsset["name"] as String,
                          style: AppTheme.darkTheme.textTheme.titleMedium,
                        ),
                        SizedBox(height: 0.5.h),
                        Text(
                          'Balance: ${selectedAsset["balance"]} ${selectedAsset["symbol"]}',
                          style: AppTheme.darkTheme.textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),

                  // Dropdown Arrow
                  CustomIconWidget(
                    iconName: 'keyboard_arrow_down',
                    color: AppTheme.darkTheme.colorScheme.onSurface,
                    size: 24,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showAssetSelector(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.darkTheme.colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: EdgeInsets.all(4.w),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle
            Container(
              width: 12.w,
              height: 0.5.h,
              decoration: BoxDecoration(
                color: AppTheme.darkTheme.colorScheme.outline,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            SizedBox(height: 2.h),

            Text(
              'Select Cryptocurrency',
              style: AppTheme.darkTheme.textTheme.titleLarge,
            ),
            SizedBox(height: 2.h),

            // Asset List
            ...assets.asMap().entries.map((entry) {
              final index = entry.key;
              final asset = entry.value;
              final isSelected = index == selectedIndex;

              return GestureDetector(
                onTap: () {
                  onAssetSelected(index);
                  Navigator.pop(context);
                },
                child: Container(
                  margin: EdgeInsets.only(bottom: 1.h),
                  padding: EdgeInsets.all(3.w),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AppTheme.primary.withOpacity(0.1)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isSelected ? AppTheme.primary : Colors.transparent,
                      width: 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      // Asset Icon
                      Center(
                        child: Image.asset(
                          asset["icon"] as String,
                          width: 6.w,
                          height: 6.w,
                          fit: BoxFit.contain,
                        ),
                      ),
                      SizedBox(width: 3.w),

                      // Asset Info
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              asset["name"] as String,
                              style: AppTheme.darkTheme.textTheme.titleMedium,
                            ),
                            SizedBox(height: 0.5.h),
                            Text(
                              '${asset["balance"]} ${asset["symbol"]}',
                              style: AppTheme.darkTheme.textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),

                      // Check Icon if selected
                      if (isSelected)
                        CustomIconWidget(
                          iconName: 'check_circle',
                          color: AppTheme.primary,
                          size: 24,
                        ),
                    ],
                  ),
                ),
              );
            }),

            SizedBox(height: 2.h),
          ],
        ),
      ),
    );
  }
}
