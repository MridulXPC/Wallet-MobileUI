import 'package:flutter/material.dart';
import 'package:sizer/sizer.dart';

import '../../../core/app_export.dart';

class ReviewSectionWidget extends StatelessWidget {
  final String recipientAddress;
  final double amount;
  final String assetSymbol;
  final double networkFee;
  final double fiatConversion;

  const ReviewSectionWidget({
    super.key,
    required this.recipientAddress,
    required this.amount,
    required this.assetSymbol,
    required this.networkFee,
    required this.fiatConversion,
  });

  @override
  Widget build(BuildContext context) {
    final totalAmount = amount + networkFee;
    final totalFiatValue = fiatConversion +
        (networkFee * 43250.0); // Assuming BTC price for fee conversion

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Review Transaction',
          style: AppTheme.darkTheme.textTheme.titleMedium?.copyWith(
            color: AppTheme.textHighEmphasis,
            fontWeight: FontWeight.w500,
          ),
        ),
        SizedBox(height: 1.h),
        Container(
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
          child: Column(
            children: [
              _buildReviewRow(
                'Recipient',
                '${recipientAddress.substring(0, 8)}...${recipientAddress.substring(recipientAddress.length - 8)}',
                isAddress: true,
              ),
              SizedBox(height: 2.h),
              _buildReviewRow(
                'Amount',
                '${amount.toStringAsFixed(6)} $assetSymbol',
                subtitle: '≈ \$${fiatConversion.toStringAsFixed(2)} USD',
              ),
              SizedBox(height: 2.h),
              _buildReviewRow(
                'Network Fee',
                '${networkFee.toStringAsFixed(6)} $assetSymbol',
                subtitle:
                    '≈ \$${(networkFee * 43250.0).toStringAsFixed(2)} USD',
              ),
              SizedBox(height: 2.h),
              Container(
                height: 1,
                color: AppTheme.dividerDark,
              ),
              SizedBox(height: 2.h),
              _buildReviewRow(
                'Total',
                '${totalAmount.toStringAsFixed(6)} $assetSymbol',
                subtitle: '≈ \$${totalFiatValue.toStringAsFixed(2)} USD',
                isTotal: true,
              ),
            ],
          ),
        ),
        SizedBox(height: 2.h),
        Container(
          padding: EdgeInsets.all(3.w),
          decoration: BoxDecoration(
            color: AppTheme.warning.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              CustomIconWidget(
                iconName: 'warning',
                color: AppTheme.warning,
                size: 16,
              ),
              SizedBox(width: 2.w),
              Expanded(
                child: Text(
                  'Double-check the recipient address. Cryptocurrency transactions cannot be reversed.',
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

  Widget _buildReviewRow(
    String label,
    String value, {
    String? subtitle,
    bool isAddress = false,
    bool isTotal = false,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: AppTheme.darkTheme.textTheme.bodyMedium?.copyWith(
            color: isTotal
                ? AppTheme.textHighEmphasis
                : AppTheme.textMediumEmphasis,
            fontWeight: isTotal ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                value,
                style: isAddress
                    ? AppTheme.monoTextStyle(
                        isLight: false,
                        fontSize: 14,
                        fontWeight: isTotal ? FontWeight.w600 : FontWeight.w400,
                      )
                    : AppTheme.darkTheme.textTheme.bodyMedium?.copyWith(
                        color: AppTheme.textHighEmphasis,
                        fontWeight: isTotal ? FontWeight.w600 : FontWeight.w500,
                      ),
                textAlign: TextAlign.end,
              ),
              if (subtitle != null) ...[
                SizedBox(height: 0.5.h),
                Text(
                  subtitle,
                  style: AppTheme.darkTheme.textTheme.bodySmall?.copyWith(
                    color: AppTheme.textMediumEmphasis,
                  ),
                  textAlign: TextAlign.end,
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
