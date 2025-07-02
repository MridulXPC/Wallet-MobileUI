import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sizer/sizer.dart';

import '../../../core/app_export.dart';

class AmountInputWidget extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final String selectedAssetSymbol;
  final double selectedAssetBalance;
  final double fiatConversion;
  final bool isValid;
  final VoidCallback onMaxPressed;

  const AmountInputWidget({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.selectedAssetSymbol,
    required this.selectedAssetBalance,
    required this.fiatConversion,
    required this.isValid,
    required this.onMaxPressed,
  });

  @override
  Widget build(BuildContext context) {
    final amount = double.tryParse(controller.text) ?? 0.0;
    final hasInsufficientBalance = amount > selectedAssetBalance;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Amount',
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
              color: controller.text.isNotEmpty
                  ? (hasInsufficientBalance
                      ? AppTheme.error
                      : isValid
                          ? AppTheme.success
                          : AppTheme.dividerDark)
                  : AppTheme.dividerDark,
              width: 1,
            ),
          ),
          child: Column(
            children: [
              TextField(
                controller: controller,
                focusNode: focusNode,
                style: AppTheme.darkTheme.textTheme.headlineSmall?.copyWith(
                  color: AppTheme.textHighEmphasis,
                  fontWeight: FontWeight.w600,
                ),
           decoration: InputDecoration(
  hintText: '0.00',
  hintStyle: AppTheme.darkTheme.textTheme.headlineSmall?.copyWith(
    color: AppTheme.textDisabled,
    fontWeight: FontWeight.w600,
  ),
  border: InputBorder.none,
  filled: true,
  fillColor: Colors.transparent, // ✅ Transparent background
  contentPadding: EdgeInsets.fromLTRB(4.w, 3.h, 4.w, 1.h),
  suffixIcon: Padding(
    padding: EdgeInsets.only(right: 4.w, top: 2.h),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          selectedAssetSymbol,
          style: AppTheme.darkTheme.textTheme.titleMedium?.copyWith(
            color: AppTheme.textMediumEmphasis,
            fontWeight: FontWeight.w500,
          ),
        ),
        SizedBox(height: 1.h),
        GestureDetector(
          onTap: onMaxPressed,
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: 2.w, vertical: 0.5.h),
            decoration: BoxDecoration(
              color: AppTheme.primary.withAlpha(51), // ~20% opacity
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              'MAX',
              style: AppTheme.darkTheme.textTheme.labelSmall?.copyWith(
                color: AppTheme.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ],
    ),
  ),
),

                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
                ],
                textInputAction: TextInputAction.done,
              ),
         
         
         
              if (fiatConversion > 0) ...[
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.fromLTRB(4.w, 0, 4.w, 2.h),
                  child: Text(
                    '≈ \$${fiatConversion.toStringAsFixed(2)} USD',
                    style: AppTheme.darkTheme.textTheme.bodyMedium?.copyWith(
                      color: AppTheme.textMediumEmphasis,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        SizedBox(height: 1.h),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            if (hasInsufficientBalance) ...[
              Row(
                children: [
                  CustomIconWidget(
                    iconName: 'error',
                    color: AppTheme.error,
                    size: 16,
                  ),
                  SizedBox(width: 1.w),
                  Text(
                    'Insufficient balance',
                    style: AppTheme.darkTheme.textTheme.bodySmall?.copyWith(
                      color: AppTheme.error,
                    ),
                  ),
                ],
              ),
            ] else ...[
              SizedBox.shrink(),
            ],
            Text(
              'Available: ${selectedAssetBalance.toStringAsFixed(4)} $selectedAssetSymbol',
              style: AppTheme.darkTheme.textTheme.bodySmall?.copyWith(
                color: AppTheme.textMediumEmphasis,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
