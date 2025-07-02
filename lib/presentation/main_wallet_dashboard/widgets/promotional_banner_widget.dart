import 'package:flutter/material.dart';
import 'package:sizer/sizer.dart';

import '../../../core/app_export.dart';

class PromotionalBannerWidget extends StatelessWidget {
  final VoidCallback onDismiss;

  const PromotionalBannerWidget({
    super.key,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 4.w),
      child: Card(
        color: AppTheme.primary.withValues(alpha: 0.1),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
            color: AppTheme.primary.withValues(alpha: 0.3),
            width: 1,
          ),
        ),
        child: Padding(
          padding: EdgeInsets.all(4.w),
          child: Row(
            children: [
              Container(
                width: 12.w,
                height: 12.w,
                decoration: BoxDecoration(
                  color: AppTheme.primary.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Center(
                  child: CustomIconWidget(
                    iconName: 'local_offer',
                    color: AppTheme.primary,
                    size: 24,
                  ),
                ),
              ),
              SizedBox(width: 4.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Connect to Binance',
                      style: AppTheme.darkTheme.textTheme.titleMedium?.copyWith(
                        color: AppTheme.darkTheme.colorScheme.onSurface,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    SizedBox(height: 0.5.h),
                    Text(
                      'Link your account for seamless trading',
                      style: AppTheme.darkTheme.textTheme.bodyMedium?.copyWith(
                        color: AppTheme.darkTheme.colorScheme.onSurfaceVariant,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              SizedBox(width: 2.w),
              TextButton(
                onPressed: () {
                  // Navigate to Binance integration
                },
                style: TextButton.styleFrom(
                  foregroundColor: AppTheme.primary,
                  padding: EdgeInsets.symmetric(
                    horizontal: 3.w,
                    vertical: 1.h,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: Text(
                  'Connect',
                  style: AppTheme.darkTheme.textTheme.labelLarge?.copyWith(
                    color: AppTheme.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              SizedBox(width: 1.w),
              GestureDetector(
                onTap: onDismiss,
                child: Container(
                  padding: EdgeInsets.all(1.w),
                  child: CustomIconWidget(
                    iconName: 'close',
                    color: AppTheme.darkTheme.colorScheme.onSurfaceVariant,
                    size: 20,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
