import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sizer/sizer.dart';

import '../../../core/app_export.dart';

class AmountInputWidget extends StatefulWidget {
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
  State<AmountInputWidget> createState() => _AmountInputWidgetState();
}

class _AmountInputWidgetState extends State<AmountInputWidget> {
  @override
  void initState() {
    super.initState();
    // Listen to text changes to rebuild the widget
    widget.controller.addListener(_onTextChanged);
    widget.focusNode.addListener(_onFocusChanged);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onTextChanged);
    widget.focusNode.removeListener(_onFocusChanged);
    super.dispose();
  }

  void _onTextChanged() {
    setState(() {
      // This will trigger a rebuild when text changes
    });
  }

  void _onFocusChanged() {
    setState(() {
      // This will trigger a rebuild when focus changes
    });
  }

  Color _getBorderColor() {
    final amount = double.tryParse(widget.controller.text) ?? 0.0;
    final hasInsufficientBalance = amount > widget.selectedAssetBalance;
    final hasFocus = widget.focusNode.hasFocus;

    print('controller.text: "${widget.controller.text}"');
    print('hasInsufficientBalance: $hasInsufficientBalance');
    print('isValid: ${widget.isValid}');
    print('hasFocus: $hasFocus');

    if (widget.controller.text.isNotEmpty) {
      if (hasInsufficientBalance) {
        print('Using error color');
        return AppTheme.error;
      } else if (widget.isValid) {
        print('Using info color');
        return AppTheme.info;
      } else {
        print('Using dividerDark color');
        return AppTheme.dividerDark;
      }
    } else {
      if (hasFocus) {
        print('Using info color (focused)');
        return AppTheme.info;
      } else {
        print('Using dividerDark color (empty text)');
        return AppTheme.dividerDark;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final amount = double.tryParse(widget.controller.text) ?? 0.0;
    final hasInsufficientBalance = amount > widget.selectedAssetBalance;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Amount',
          style: TextStyle(
            color: const Color.fromARGB(255, 93, 93, 93),
            fontSize: 12.sp,
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
    color: const Color(0xFF3A3D4A)// Background color when focused/selected
,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: _getBorderColor(),
              width: 1,
            ),
          ),
          child: Column(
            children: [
              TextField(
                controller: widget.controller,
                focusNode: widget.focusNode,
                style: AppTheme.darkTheme.textTheme.headlineSmall?.copyWith(
                  color: AppTheme.background,
                  fontWeight: FontWeight.w600,
                ),
                decoration: InputDecoration(
                  hintText: '0.00',
                  hintStyle: AppTheme.darkTheme.textTheme.headlineSmall?.copyWith(
                 color: Colors.white70,
                    fontWeight: FontWeight.w600,
                  ),
                  border: InputBorder.none,
                  filled: true,
                  fillColor: Colors.transparent,
                  contentPadding: EdgeInsets.fromLTRB(4.w, 3.h, 4.w, 0.h),
                  suffixIcon: Padding(
                    padding: EdgeInsets.only(right: 4.w, top: 2.h),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          widget.selectedAssetSymbol,
                          style: AppTheme.darkTheme.textTheme.titleMedium?.copyWith(
                           color: Colors.white70,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        SizedBox(height: 1.h),
                        GestureDetector(
                          onTap: widget.onMaxPressed,
                          child: Container(
                            padding: EdgeInsets.symmetric(horizontal: 2.w, vertical: 0.5.h),
                            decoration: BoxDecoration(
                              color: AppTheme.info,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              'MAX',
                              style: AppTheme.darkTheme.textTheme.labelSmall?.copyWith(
                                color: AppTheme.onSurface,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
                ],
                textInputAction: TextInputAction.done,
              ),
              if (widget.fiatConversion > 0) ...[
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.fromLTRB(4.w, 0, 4.w, 2.h),
                  child: Text(
                    '≈ \$${widget.fiatConversion.toStringAsFixed(2)} USD',
                    style: AppTheme.darkTheme.textTheme.bodyMedium?.copyWith(
                      color: AppTheme.background,
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
              'Available: ${widget.selectedAssetBalance.toStringAsFixed(4)} ${widget.selectedAssetSymbol}',
             style: TextStyle(
            color: const Color.fromARGB(255, 93, 93, 93),
            fontSize: 12.sp,
            fontWeight: FontWeight.w500,
          ),
            ),
          ],
        ),
      ],
    );
  }
}