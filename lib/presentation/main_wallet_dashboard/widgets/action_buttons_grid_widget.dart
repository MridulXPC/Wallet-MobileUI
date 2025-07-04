import 'package:flutter/material.dart';
import 'package:sizer/sizer.dart';

import '../../../core/app_export.dart';

class ActionButtonsGridWidget extends StatelessWidget {
  const ActionButtonsGridWidget({super.key});

  @override
  Widget build(BuildContext context) {
    final List<Map<String, dynamic>> actionButtons = [
      {
        "title": "Send",
        "icon": "send",
        "route": "/send-cryptocurrency",
        "color": AppTheme.primary,
      },
      {
        "title": "Receive",
        "icon": "call_received",
        "route": "/receive-cryptocurrency",
        "color": AppTheme.primary,
      },
      {
        "title": "Swap",
        "icon": "swap_horiz",
        "route": "/transaction-history",
        "color": AppTheme.primary,
      },
    ];

    return Container(
      margin: EdgeInsets.symmetric(horizontal: 4.w),
      child: GridView.count(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisCount: 3,
        crossAxisSpacing: 3.w,
        mainAxisSpacing: 2.h,
        childAspectRatio: 1.2,
        children: actionButtons.map((button) {
          return _buildActionButton(
            context,
            title: button["title"] as String,
            icon: button["icon"] as String,
            route: button["route"] as String,
            color: button["color"] as Color,
          );
        }).toList(),
      ),
    );
  }

  Widget _buildActionButton(
    BuildContext context, {
    required String title,
    required String icon,
    required String route,
    required Color color,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          Navigator.pushNamed(context, route);
        },
        borderRadius: BorderRadius.circular(8),
        child: Container(
          decoration: BoxDecoration(
            color: AppTheme.darkTheme.colorScheme.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color:
                  AppTheme.darkTheme.colorScheme.outline.withValues(alpha: 0.3),
              width: 1,
            ),
          ),
          child: Padding(
            padding: EdgeInsets.all(3.w),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Center(
                  child: CustomIconWidget(
                    iconName: icon,
                    color: color,
                    size: 24,
                  ),
                ),
                SizedBox(height: 2.h),
                Text(
                  title,
                  style: AppTheme.darkTheme.textTheme.bodyMedium?.copyWith(
                    color: AppTheme.darkTheme.colorScheme.onSurface,
                    fontWeight: FontWeight.w600,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
