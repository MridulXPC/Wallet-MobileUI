import 'package:flutter/material.dart';
import 'package:sizer/sizer.dart';

import '../../../core/app_export.dart';

class AddressDisplayWidget extends StatelessWidget {
  final String address;
  final VoidCallback onCopy;
  final VoidCallback onRefresh;

  const AddressDisplayWidget({
    super.key,
    required this.address,
    required this.onCopy,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(2.w),
      decoration: BoxDecoration(
        
                    boxShadow: const [
          BoxShadow(
            color: Color.fromARGB(31, 0, 0, 0),
            blurRadius: 6,
            offset: Offset(0, 10),
          )
        ],
        
        color: AppTheme.onSurface,
        borderRadius: BorderRadius.circular(16),
         border: Border.all(
          color: AppTheme.onPrimary,
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Wallet Address',
                style: AppTheme.lightTheme.textTheme.titleMedium,
              ),
              IconButton(
                onPressed: onRefresh,
                icon: CustomIconWidget(
                  iconName: 'refresh',
                  color: AppTheme.info,
                  size: 20,
                ),
                tooltip: 'Generate new address',
              ),
            ],
          ),
       

          // Address Container
          Container(
            padding: EdgeInsets.all(3.w),
            decoration: BoxDecoration(
              color: AppTheme.darkTheme.scaffoldBackgroundColor,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: AppTheme.lightTheme.colorScheme.outline,
                width: 1,
              ),
            ),
            child: Column(
              children: [
                // Address Text
                SelectableText(
                  address,
                  style: AppTheme.monoTextStyle(
                    isLight: false,
                    fontSize: 12.sp,
                    fontWeight: FontWeight.w400,
                  ),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 2.h),

                // Copy Button
                SizedBox(
                  width: double.infinity,
                  height: 6.h,
                  child: OutlinedButton.icon(
                    onPressed: onCopy,
                    icon: CustomIconWidget(
                      iconName: 'content_copy',
                      color: AppTheme.info,
                      size: 18,
                    ),
                    label: Text(
                      'Copy Address',
                      style: AppTheme.lightTheme.textTheme.labelLarge?.copyWith(
                        color: AppTheme.info,
                      ),
                    ),
                 
                  ),
                ),
              ],
            ),
          ),

          SizedBox(height: 1.h),

          // Address Info
          Row(
            children: [
              CustomIconWidget(
                iconName: 'info_outline',
                color: AppTheme.info,
                size: 16,
              ),
              SizedBox(width: 2.w),
              Expanded(
                child: Text(
                  'This address can be used multiple times. Tap refresh for a new address.',
                  style: AppTheme.lightTheme.textTheme.bodySmall,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
