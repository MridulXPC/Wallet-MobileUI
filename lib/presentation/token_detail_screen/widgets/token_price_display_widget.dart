import 'package:flutter/material.dart';
import 'package:sizer/sizer.dart';

import '../../../core/app_export.dart';

class TokenPriceDisplayWidget extends StatelessWidget {
  final String currentPrice;
  final String priceChange;
  final String percentageChange;
  final bool isPositive;
  final String period;

  const TokenPriceDisplayWidget({
    super.key,
    required this.currentPrice,
    required this.priceChange,
    required this.percentageChange,
    required this.isPositive,
    required this.period,
  });

  @override
  Widget build(BuildContext context) {
    final changeColor = isPositive ? AppTheme.success : AppTheme.error;

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 4.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            currentPrice,
            style: AppTheme.darkTheme.textTheme.displaySmall?.copyWith(
              fontWeight: FontWeight.w700,
              color: AppTheme.darkTheme.colorScheme.onSurface,
            ),
          ),
          SizedBox(height: 1.h),
          Row(
            children: [
              Container(
                padding: EdgeInsets.symmetric(horizontal: 2.w, vertical: 0.5.h),
                decoration: BoxDecoration(
                  color: changeColor.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CustomIconWidget(
                      iconName: isPositive ? 'trending_up' : 'trending_down',
                      color: changeColor,
                      size: 16,
                    ),
                    SizedBox(width: 1.w),
                    Text(
                      '$priceChange ($percentageChange)',
                      style: AppTheme.darkTheme.textTheme.bodyMedium?.copyWith(
                        color: changeColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(width: 3.w),
              Text(
                period,
                style: AppTheme.darkTheme.textTheme.bodyMedium?.copyWith(
                  color: AppTheme.darkTheme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
