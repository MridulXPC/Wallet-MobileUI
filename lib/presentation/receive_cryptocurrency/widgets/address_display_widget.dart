import 'package:flutter/material.dart';
import 'package:sizer/sizer.dart';

import '../../../core/app_export.dart';

class AddressDisplayWidget extends StatelessWidget {
  final String address;
  final VoidCallback onCopy;
  final VoidCallback onRefresh;

  const AddressDisplayWidget({
    super.key,
    required this.address,
    required this.onCopy,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(4.w),
      decoration: BoxDecoration(
        color: AppTheme.darkTheme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Wallet Address',
                style: AppTheme.darkTheme.textTheme.titleMedium,
              ),
              IconButton(
                onPressed: onRefresh,
                icon: CustomIconWidget(
                  iconName: 'refresh',
                  color: AppTheme.primary,
                  size: 20,
                ),
                tooltip: 'Generate new address',
              ),
            ],
          ),
          SizedBox(height: 2.h),

          // Address Container
          Container(
            padding: EdgeInsets.all(3.w),
            decoration: BoxDecoration(
              color: AppTheme.darkTheme.scaffoldBackgroundColor,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: AppTheme.darkTheme.colorScheme.outline,
                width: 1,
              ),
            ),
            child: Column(
              children: [
                // Address Text
                SelectableText(
                  address,
                  style: AppTheme.monoTextStyle(
                    isLight: false,
                    fontSize: 12.sp,
                    fontWeight: FontWeight.w400,
                  ),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 2.h),

                // Copy Button
                SizedBox(
                  width: double.infinity,
                  height: 5.h,
                  child: OutlinedButton.icon(
                    onPressed: onCopy,
                    icon: CustomIconWidget(
                      iconName: 'content_copy',
                      color: AppTheme.primary,
                      size: 18,
                    ),
                    label: Text(
                      'Copy Address',
                      style: AppTheme.darkTheme.textTheme.labelLarge?.copyWith(
                        color: AppTheme.primary,
                      ),
                    ),
                    style: AppTheme.darkTheme.outlinedButtonTheme.style,
                  ),
                ),
              ],
            ),
          ),

          SizedBox(height: 1.h),

          // Address Info
          Row(
            children: [
              CustomIconWidget(
                iconName: 'info_outline',
                color: AppTheme.darkTheme.colorScheme.onSurfaceVariant,
                size: 16,
              ),
              SizedBox(width: 2.w),
              Expanded(
                child: Text(
                  'This address can be used multiple times. Tap refresh for a new address.',
                  style: AppTheme.darkTheme.textTheme.bodySmall,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
