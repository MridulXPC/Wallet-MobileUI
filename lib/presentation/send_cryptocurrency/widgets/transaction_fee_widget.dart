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
            color: AppTheme.background,
            fontWeight: FontWeight.w500,
          ),
        ),
        SizedBox(height: 1.h),
        Container(
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
                isFirst: true,
              ),
              Divider(
                color: AppTheme.onSurface,
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
                color: AppTheme.onSurface,
                height: 1,
                indent: 4.w,
                endIndent: 4.w,
              ),
              _buildFeeOption(
                'Slow',
                '~30-60 minutes',
                0.00005,
                selectedFeeType == 'Slow',
                isLast: true,
              ),
            ],
          ),
        ),
        SizedBox(height: 1.h),
      ],
    );
  }

  Widget _buildFeeOption(
    String type,
    String time,
    double fee,
    bool isSelected, {
    bool isFirst = false,
    bool isLast = false,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => onFeeTypeChanged(type),
        borderRadius: BorderRadius.vertical(
          top: isFirst ? Radius.circular(12) : Radius.zero,
          bottom: isLast ? Radius.circular(12) : Radius.zero,
        ),
        child: Container(
          padding: EdgeInsets.all(4.w),
          decoration: BoxDecoration(
            color: AppTheme.onSurface,
            borderRadius: BorderRadius.vertical(
              top: isFirst ? Radius.circular(12) : Radius.zero,
              bottom: isLast ? Radius.circular(12) : Radius.zero,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 5.w,
                height: 5.w,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isSelected ? AppTheme.info : AppTheme.dividerDark,
                    width: 2,
                  ),
                  color: isSelected ? AppTheme.info : Colors.transparent,
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
                          style: AppTheme.darkTheme.textTheme.titleSmall?.copyWith(
                            color: isSelected ? AppTheme.info : AppTheme.background,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        Text(
                          '${fee.toStringAsFixed(5)} $selectedAssetSymbol',
                          style: AppTheme.darkTheme.textTheme.titleSmall?.copyWith(
                            color: isSelected ? AppTheme.info : AppTheme.background,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                   
                    Text(
                      time,
                      style: AppTheme.darkTheme.textTheme.bodySmall?.copyWith(
                        color: isSelected ? AppTheme.info : AppTheme.background,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}