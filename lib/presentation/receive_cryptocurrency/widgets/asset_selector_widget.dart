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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
       Text(
                'Select Asset',
                style: AppTheme.lightTheme.textTheme.titleMedium,
              ),
     
        SizedBox(height: 1.h),
        // Selected Asset Display
        GestureDetector(
          onTap: () => _showAssetSelector(context),
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 1.h),
            decoration: BoxDecoration(
                 boxShadow: const [
          BoxShadow(
            color: Color.fromARGB(31, 0, 0, 0),
            blurRadius: 6,
            offset: Offset(0, 10),
          )
        ],
              color: AppTheme.onSurface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: AppTheme.onPrimary,
                width: 1,
              ),
            ),
            child: Row(
              children: [
                // Asset Icon
                Center(
                  child: Image.asset(
                    selectedAsset["icon"] as String,
                    width: 8.w,
                    height: 8.w,
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
                        style: TextStyle(color: AppTheme.info),
                      ),
                      SizedBox(height: 0.5.h),
                      Text(
                        'Balance: ${selectedAsset["balance"]} ${selectedAsset["symbol"]}',
                        style: TextStyle(
                          color: AppTheme.info,
                        ),
                      ),
                    ],
                  ),
                ),
    
                // Dropdown Arrow
                CustomIconWidget(
                  iconName: 'keyboard_arrow_down',
                  color: AppTheme.info,
                  size: 24,
                ),
              ],
            ),
          ),
        ),
      ],
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
                color: AppTheme.onSurface,
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
                        ? AppTheme.info.withOpacity(0.1)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isSelected ? AppTheme.info : Colors.transparent,
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
                              style: TextStyle(
                                color: isSelected
                                    ? AppTheme.info
                                    : AppTheme.darkTheme.colorScheme.onSurface,
                              ),
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
                          color: AppTheme.info,
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
