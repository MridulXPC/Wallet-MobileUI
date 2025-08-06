import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sizer/sizer.dart';

import '../../../core/app_export.dart';

class RecipientAddressWidget extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final bool isValid;
  final VoidCallback? onChanged;

  const RecipientAddressWidget({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.isValid,
    this.onChanged,
  });

  Future<void> _pasteFromClipboard() async {
    try {
      final clipboardData = await Clipboard.getData(Clipboard.kTextPlain);
      if (clipboardData?.text?.isNotEmpty == true) {
        controller.text = clipboardData!.text!;
        onChanged?.call();
      }
    } catch (e) {
      // Handle clipboard access error silently
    }
  }

  void _scanQRCode(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.darkTheme.cardColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: Text(
          'QR Scanner',
          style: AppTheme.darkTheme.textTheme.titleMedium?.copyWith(
            color: AppTheme.textHighEmphasis,
            fontWeight: FontWeight.w600,
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
                  color: AppTheme.info, // Changed to AppTheme.info
                  width: 2,
                ),
              ),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CustomIconWidget(
                      iconName: 'qr_code_scanner',
                      color: AppTheme.info, // Changed to AppTheme.info
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
              controller.text = '1A1zP1eP5QGefi2DMPTfTL5SLmv7DivfNa';
              Navigator.of(context).pop();
              onChanged?.call();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.info, // Changed to AppTheme.info
              foregroundColor: AppTheme.onPrimary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text('Simulate Scan'),
          ),
        ],
      ),
    );
  }

  Color _getBorderColor(bool isFocused) {
    if (isFocused) {
      return AppTheme.info; // Border color when focused/selected
    }
    if (controller.text.isEmpty) {
      return AppTheme.dividerDark; // Default border color when not selected
    }
    return isValid ? AppTheme.success : AppTheme.error;
  }


  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Recipient Address',
          style:   TextStyle(
            color: const Color.fromARGB(255, 93, 93, 93),
            fontSize: 12.sp,
            fontWeight: FontWeight.w500,
          ),
        ),
        SizedBox(height: 1.h),
        AnimatedBuilder(
          animation: focusNode,
          builder: (context, child) {
            final bool isFocused = focusNode.hasFocus;
            
            return Container(
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
                  color: _getBorderColor(isFocused),
                
                ),
              ),
              child: TextField(
                controller: controller,
                focusNode: focusNode,
                onChanged: (_) => onChanged?.call(),
                style: AppTheme.monoTextStyle(
                  isLight: false,
                  fontSize: 12,
                ),
                decoration: InputDecoration(
                  hintText: 'Enter wallet address or scan QR code',
                  hintStyle: AppTheme.darkTheme.textTheme.bodyMedium?.copyWith(
                  color: Colors.white70,
                  ),
                  border: InputBorder.none,
                  filled: true,
                  fillColor: Colors.transparent,
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
                         color: Colors.white70,
                          size: 20,
                        ),
                        tooltip: 'Paste from clipboard',
                        splashRadius: 20,
                      ),
                      IconButton(
                        onPressed: () => _scanQRCode(context),
                        icon: CustomIconWidget(
                          iconName: 'qr_code_scanner',
                          color: AppTheme.info,
                          size: 20,
                        ),
                        tooltip: 'Scan QR Code',
                        splashRadius: 20,
                      ),
                    ],
                  ),
                ),
                maxLines: 2,
                textInputAction: TextInputAction.next,
              ),
            );
          },
        ),
        if (controller.text.isNotEmpty && !isValid) ...[
          SizedBox(height: 1.h),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 2.w, vertical: 0.5.h),
            decoration: BoxDecoration(
              color: AppTheme.error.withOpacity(0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(
              children: [
                CustomIconWidget(
                  iconName: 'error',
                  color: AppTheme.error,
                  size: 16,
                ),
                SizedBox(width: 2.w),
                Expanded(
                  child: Text(
                    'Invalid wallet address format',
                    style: AppTheme.darkTheme.textTheme.bodySmall?.copyWith(
                      color: AppTheme.error,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}