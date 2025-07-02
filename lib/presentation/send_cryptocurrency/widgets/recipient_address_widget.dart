import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sizer/sizer.dart';

import '../../../core/app_export.dart';

class RecipientAddressWidget extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final bool isValid;

  const RecipientAddressWidget({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.isValid,
  });

  Future<void> _pasteFromClipboard() async {
    final clipboardData = await Clipboard.getData(Clipboard.kTextPlain);
    if (clipboardData?.text != null) {
      controller.text = clipboardData!.text!;
    }
  }

  void _scanQRCode(BuildContext context) {
    // Simulate QR code scanning
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.darkTheme.cardColor,
        title: Text(
          'QR Scanner',
          style: AppTheme.darkTheme.textTheme.titleMedium?.copyWith(
            color: AppTheme.textHighEmphasis,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 60.w,
              height: 30.h,
              decoration: BoxDecoration(
                color: AppTheme.background,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppTheme.primary,
                  width: 2,
                ),
              ),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CustomIconWidget(
                      iconName: 'qr_code_scanner',
                      color: AppTheme.primary,
                      size: 48,
                    ),
                    SizedBox(height: 2.h),
                    Text(
                      'Point camera at QR code',
                      style: AppTheme.darkTheme.textTheme.bodyMedium?.copyWith(
                        color: AppTheme.textMediumEmphasis,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(
              'Cancel',
              style: TextStyle(color: AppTheme.textMediumEmphasis),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              // Simulate successful scan
              controller.text = '1A1zP1eP5QGefi2DMPTfTL5SLmv7DivfNa';
              Navigator.of(context).pop();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primary,
              foregroundColor: AppTheme.onPrimary,
            ),
            child: const Text('Simulate Scan'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Recipient Address',
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
                  ? (isValid ? AppTheme.success : AppTheme.error)
                  : AppTheme.dividerDark,
              width: 1,
            ),
          ),
          child: TextField(
  controller: controller,
  focusNode: focusNode,
  style: AppTheme.monoTextStyle(
    isLight: false,
    fontSize: 14,
  ),
  decoration: InputDecoration(
    hintText: 'Enter wallet address or scan QR code',
    hintStyle: AppTheme.darkTheme.textTheme.bodyMedium?.copyWith(
      color: AppTheme.textDisabled,
    ),
    border: InputBorder.none,
    filled: true, // ✅ enable background fill
    fillColor: Colors.transparent, // ✅ make background transparent
    contentPadding: EdgeInsets.all(4.w),
    suffixIcon: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (controller.text.isNotEmpty && isValid)
          Padding(
            padding: EdgeInsets.only(right: 2.w),
            child: CustomIconWidget(
              iconName: 'check_circle',
              color: AppTheme.success,
              size: 20,
            ),
          ),
        IconButton(
          onPressed: _pasteFromClipboard,
          icon: CustomIconWidget(
            iconName: 'content_paste',
            color: AppTheme.textMediumEmphasis,
            size: 20,
          ),
          tooltip: 'Paste',
        ),
        IconButton(
          onPressed: () => _scanQRCode(context),
          icon: CustomIconWidget(
            iconName: 'qr_code_scanner',
            color: AppTheme.primary,
            size: 20,
          ),
          tooltip: 'Scan QR Code',
        ),
      ],
    ),
  ),
  maxLines: 2,
  textInputAction: TextInputAction.next,
),

),
        if (controller.text.isNotEmpty && !isValid) ...[
          SizedBox(height: 1.h),
          Row(
            children: [
              CustomIconWidget(
                iconName: 'error',
                color: AppTheme.error,
                size: 16,
              ),
              SizedBox(width: 1.w),
              Text(
                'Invalid wallet address format',
                style: AppTheme.darkTheme.textTheme.bodySmall?.copyWith(
                  color: AppTheme.error,
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}
