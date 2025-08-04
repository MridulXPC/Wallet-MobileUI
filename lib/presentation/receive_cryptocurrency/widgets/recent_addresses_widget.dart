import 'package:flutter/material.dart';
import 'package:sizer/sizer.dart';

import '../../../core/app_export.dart';

class RecentAddressesWidget extends StatelessWidget {
  final List<Map<String, dynamic>> addresses;
  final Function(String) onCopy;

  const RecentAddressesWidget({
    super.key,
    required this.addresses,
    required this.onCopy,
  });

  @override
  Widget build(BuildContext context) {
    if (addresses.isEmpty) {
      return SizedBox.shrink();
    }

    return Container(
      padding: EdgeInsets.all(2.w),
      decoration: BoxDecoration(
          boxShadow: [
                  BoxShadow(
                    color: AppTheme.darkTheme.colorScheme.shadow,
                    blurRadius: 8,
                    offset: Offset(0, 4),
                  ),
                ],
        color: AppTheme.onSurface,
        borderRadius: BorderRadius.circular(16), border: Border.all(
          color: AppTheme.onPrimary,
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Recent Addresses',
      style: AppTheme.lightTheme.textTheme.titleMedium,
              ),
              TextButton(
                onPressed: () {
                  // Show all addresses
                },
                child: Text(
                  'View All',
                  style: AppTheme.lightTheme.textTheme.titleMedium,
                ),
              ),
            ],
          ),


          // Address List
          ...addresses.take(3).map((addressData) {
            final address = addressData["address"] as String;
            final timestamp = addressData["timestamp"] as String;
            final asset = addressData["asset"] as String;
            final isUsed = addressData["used"] as bool;

            return Container(
              margin: EdgeInsets.only(bottom: 2.h),
              padding: EdgeInsets.all(3.w),
              decoration: BoxDecoration(
                color: AppTheme.darkTheme.scaffoldBackgroundColor,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppTheme.info,
                  width: 1,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Address Header
                  Row(
                    children: [
                      Container(
                        padding: EdgeInsets.symmetric(
                            horizontal: 2.w, vertical: 0.5.h),
                        decoration: BoxDecoration(
                          color: AppTheme.info.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          asset,
                          style:
                              AppTheme.darkTheme.textTheme.bodySmall?.copyWith(
                            color: AppTheme.info,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      Spacer(),
                      Container(
                        padding: EdgeInsets.symmetric(
                            horizontal: 2.w, vertical: 0.5.h),
                        decoration: BoxDecoration(
                          color: isUsed
                              ? AppTheme.darkTheme.colorScheme.outline
                                  .withValues(alpha: 0.2)
                              : AppTheme.info.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          isUsed ? 'Used' : 'Active',
                          style:
                              AppTheme.darkTheme.textTheme.bodySmall?.copyWith(
                            color: isUsed
                                ? AppTheme
                                    .darkTheme.colorScheme.onSurfaceVariant
                                : AppTheme.info,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 1.h),

                  // Address Text
                  Text(
                    '${address.substring(0, 12)}...${address.substring(address.length - 8)}',
                    style: AppTheme.monoTextStyle(
                      isLight: false,
                      fontSize: 11.sp,
                    ),
                  ),
                  SizedBox(height: 1.h),

                  // Timestamp and Actions
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          timestamp,
                          style: AppTheme.darkTheme.textTheme.bodySmall,
                        ),
                      ),
                      TextButton.icon(
                        onPressed: () => onCopy(address),
                        icon: CustomIconWidget(
                          iconName: 'content_copy',
                          color: AppTheme.info,
                          size: 16,
                        ),
                        label: Text(
                          'Copy',
                          style:
                              AppTheme.darkTheme.textTheme.bodySmall?.copyWith(
                            color: AppTheme.info,
                          ),
                        ),
                        style: TextButton.styleFrom(
                          padding: EdgeInsets.symmetric(
                              horizontal: 2.w, vertical: 0.5.h),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          }),

          if (addresses.length > 3) ...[
            SizedBox(height: 1.h),
            Center(
              child: TextButton(
                onPressed: () {
                  // Show all addresses in a new screen or modal
                },
                child: Text(
                  'Show ${addresses.length - 3} more addresses',
                  style: AppTheme.darkTheme.textTheme.bodyMedium?.copyWith(
                    color: AppTheme.info,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
