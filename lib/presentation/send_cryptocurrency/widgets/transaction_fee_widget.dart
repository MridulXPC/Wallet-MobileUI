import 'package:flutter/material.dart';
import 'package:sizer/sizer.dart';

import '../../../core/app_export.dart';

class TransactionFeeWidget extends StatelessWidget {
  final String selectedFeeType;
  final double networkFee;
  final String selectedAssetSymbol;
  final Function(String) onFeeTypeChanged;

  const TransactionFeeWidget({
    super.key,
    required this.selectedFeeType,
    required this.networkFee,
    required this.selectedAssetSymbol,
    required this.onFeeTypeChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Network Fee',
          style: AppTheme.darkTheme.textTheme.titleMedium?.copyWith(
            color: AppTheme.textHighEmphasis,
            fontWeight: FontWeight.w500,
          ),
        ),
        SizedBox(height: 1.h),
        Container(
          decoration: BoxDecoration(
            color: AppTheme.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: AppTheme.dividerDark,
              width: 1,
            ),
          ),
          child: Column(
            children: [
              _buildFeeOption(
                'Fast',
                '~2-5 minutes',
                0.0003,
                selectedFeeType == 'Fast',
              ),
              Divider(
                color: AppTheme.dividerDark,
                height: 1,
                indent: 4.w,
                endIndent: 4.w,
              ),
              _buildFeeOption(
                'Standard',
                '~10-15 minutes',
                0.0001,
                selectedFeeType == 'Standard',
              ),
              Divider(
                color: AppTheme.dividerDark,
                height: 1,
                indent: 4.w,
                endIndent: 4.w,
              ),
              _buildFeeOption(
                'Slow',
                '~30-60 minutes',
                0.00005,
                selectedFeeType == 'Slow',
              ),
            ],
          ),
        ),
        SizedBox(height: 1.h),
        Container(
          padding: EdgeInsets.all(3.w),
          decoration: BoxDecoration(
            color: AppTheme.primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              CustomIconWidget(
                iconName: 'info',
                color: AppTheme.primary,
                size: 16,
              ),
              SizedBox(width: 2.w),
              Expanded(
                child: Text(
                  'Network fees are paid to miners to process your transaction. Higher fees result in faster confirmation times.',
                  style: AppTheme.darkTheme.textTheme.bodySmall?.copyWith(
                    color: AppTheme.textMediumEmphasis,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFeeOption(
      String type, String time, double fee, bool isSelected) {
    return GestureDetector(
      onTap: () => onFeeTypeChanged(type),
      child: Container(
        padding: EdgeInsets.all(4.w),
        child: Row(
          children: [
            Container(
              width: 5.w,
              height: 5.w,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected ? AppTheme.primary : AppTheme.dividerDark,
                  width: 2,
                ),
                color: isSelected ? AppTheme.primary : Colors.transparent,
              ),
              child: isSelected
                  ? Center(
                      child: Container(
                        width: 2.w,
                        height: 2.w,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppTheme.onPrimary,
                        ),
                      ),
                    )
                  : null,
            ),
            SizedBox(width: 3.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        type,
                        style:
                            AppTheme.darkTheme.textTheme.titleSmall?.copyWith(
                          color: AppTheme.textHighEmphasis,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      Text(
                        '${fee.toStringAsFixed(5)} $selectedAssetSymbol',
                        style:
                            AppTheme.darkTheme.textTheme.titleSmall?.copyWith(
                          color: AppTheme.textHighEmphasis,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 0.5.h),
                  Text(
                    time,
                    style: AppTheme.darkTheme.textTheme.bodySmall?.copyWith(
                      color: AppTheme.textMediumEmphasis,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
