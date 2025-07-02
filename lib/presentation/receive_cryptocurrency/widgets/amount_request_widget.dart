import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sizer/sizer.dart';

import '../../../core/app_export.dart';

class AmountRequestWidget extends StatelessWidget {
  final String amount;
  final String symbol;
  final bool includeInQR;
  final Function(String) onAmountChanged;
  final Function(bool) onToggleInclude;

  const AmountRequestWidget({
    super.key,
    required this.amount,
    required this.symbol,
    required this.includeInQR,
    required this.onAmountChanged,
    required this.onToggleInclude,
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
          Text(
            'Request Amount (Optional)',
            style: AppTheme.darkTheme.textTheme.titleMedium,
          ),
          SizedBox(height: 2.h),

          // Amount Input
          TextFormField(
            initialValue: amount,
            onChanged: onAmountChanged,
            keyboardType: TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
            ],
            decoration: InputDecoration(
              hintText: 'Enter amount',
              suffixText: symbol,
              suffixStyle: AppTheme.darkTheme.textTheme.bodyMedium?.copyWith(
                color: AppTheme.primary,
                fontWeight: FontWeight.w600,
              ),
              prefixIcon: Padding(
                padding: EdgeInsets.all(3.w),
                child: CustomIconWidget(
                  iconName: 'attach_money',
                  color: AppTheme.darkTheme.colorScheme.onSurfaceVariant,
                  size: 20,
                ),
              ),
            ),
            style: AppTheme.darkTheme.textTheme.bodyLarge,
          ),

          SizedBox(height: 2.h),

          // Include in QR Toggle
          Container(
            padding: EdgeInsets.all(3.w),
            decoration: BoxDecoration(
              color: AppTheme.darkTheme.scaffoldBackgroundColor,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Include amount in QR code',
                        style: AppTheme.darkTheme.textTheme.bodyMedium,
                      ),
                      SizedBox(height: 0.5.h),
                      Text(
                        'When enabled, the QR code will include the requested amount',
                        style: AppTheme.darkTheme.textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                SizedBox(width: 3.w),
                Switch(
                  value: includeInQR,
                  onChanged: amount.isNotEmpty ? onToggleInclude : null,
                  activeColor: AppTheme.primary,
                ),
              ],
            ),
          ),

          if (amount.isNotEmpty && includeInQR) ...[
            SizedBox(height: 2.h),
            Container(
              padding: EdgeInsets.all(3.w),
              decoration: BoxDecoration(
                color: AppTheme.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppTheme.primary.withValues(alpha: 0.3),
                  width: 1,
                ),
              ),
              child: Row(
                children: [
                  CustomIconWidget(
                    iconName: 'check_circle_outline',
                    color: AppTheme.primary,
                    size: 20,
                  ),
                  SizedBox(width: 3.w),
                  Expanded(
                    child: Text(
                      'QR code will request \$amount \$symbol',
                      style: AppTheme.darkTheme.textTheme.bodySmall?.copyWith(
                        color: AppTheme.primary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          SizedBox(height: 2.h),

          // Quick Amount Buttons
          Text(
            'Quick Amounts',
            style: AppTheme.darkTheme.textTheme.bodyMedium,
          ),
          SizedBox(height: 1.h),

          Wrap(
            spacing: 2.w,
            runSpacing: 1.h,
            children: _getQuickAmounts().map((quickAmount) {
              return GestureDetector(
                onTap: () => onAmountChanged(quickAmount),
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 3.w, vertical: 1.h),
                  decoration: BoxDecoration(
                    color: amount == quickAmount
                        ? AppTheme.primary.withValues(alpha: 0.2)
                        : AppTheme.darkTheme.scaffoldBackgroundColor,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: amount == quickAmount
                          ? AppTheme.primary
                          : AppTheme.darkTheme.colorScheme.outline,
                      width: 1,
                    ),
                  ),
                  child: Text(
                    '\$quickAmount \$symbol',
                    style: AppTheme.darkTheme.textTheme.bodySmall?.copyWith(
                      color: amount == quickAmount
                          ? AppTheme.primary
                          : AppTheme.darkTheme.colorScheme.onSurface,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  List<String> _getQuickAmounts() {
    switch (symbol) {
      case 'BTC':
        return ['0.001', '0.01', '0.1', '1'];
      case 'ETH':
        return ['0.1', '0.5', '1', '5'];
      case 'BNB':
        return ['1', '5', '10', '50'];
      default:
        return ['1', '10', '100', '1000'];
    }
  }
}
