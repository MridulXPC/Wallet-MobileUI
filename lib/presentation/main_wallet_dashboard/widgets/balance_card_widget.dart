import 'package:flutter/material.dart';
import 'package:sizer/sizer.dart';

import '../../../core/app_export.dart';

class BalanceCardWidget extends StatelessWidget {
  const BalanceCardWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 4.w),
      child: Card(
        color: AppTheme.darkTheme.colorScheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        child: Container(
          width: double.infinity,
          padding: EdgeInsets.all(6.w),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AppTheme.darkTheme.colorScheme.surface,
                AppTheme.darkTheme.colorScheme.surface.withValues(alpha: 0.8),
              ],
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Total Balance',
                style: AppTheme.darkTheme.textTheme.bodyLarge?.copyWith(
                  color: AppTheme.darkTheme.colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w400,
                ),
              ),
              SizedBox(height: 1.h),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: Text(
                      '\$12,345.67',
                      style:
                          AppTheme.darkTheme.textTheme.displaySmall?.copyWith(
                        color: AppTheme.darkTheme.colorScheme.onSurface,
                        fontWeight: FontWeight.w700,
                        fontSize: 32.sp,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  SizedBox(width: 2.w),
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: 3.w,
                      vertical: 0.5.h,
                    ),
                    decoration: BoxDecoration(
                      color: AppTheme.success.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CustomIconWidget(
                          iconName: 'trending_up',
                          color: AppTheme.success,
                          size: 16,
                        ),
                        SizedBox(width: 1.w),
                        Text(
                          '+8.45%',
                          style: AppTheme.darkTheme.textTheme.labelMedium
                              ?.copyWith(
                            color: AppTheme.success,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              SizedBox(height: 2.h),
              Row(
                children: [
                  CustomIconWidget(
                    iconName: 'visibility_outlined',
                    color: AppTheme.darkTheme.colorScheme.onSurfaceVariant,
                    size: 20,
                  ),
                  SizedBox(width: 2.w),
                  Text(
                    'Portfolio Performance',
                    style: AppTheme.darkTheme.textTheme.bodyMedium?.copyWith(
                      color: AppTheme.darkTheme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '+\$1,023.45 (24h)',
                    style: AppTheme.darkTheme.textTheme.bodyMedium?.copyWith(
                      color: AppTheme.success,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
