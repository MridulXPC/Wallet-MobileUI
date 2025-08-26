// Updated ActionButtonsGridWidget with full-width alignment to match container layout

import 'package:flutter/material.dart';
import 'package:sizer/sizer.dart';

import '../../../core/app_export.dart';

class ActionButtonsGridWidget extends StatelessWidget {
  final bool isLarge;
  final bool isTablet;

  const ActionButtonsGridWidget({
    super.key,
    this.isLarge = false,
    this.isTablet = false,
  });

  @override
  Widget build(BuildContext context) {
    final List<_ActionButton> actionButtons = [
      _ActionButton(
        title: "Send",
        icon: Icons.send,
        route: AppRoutes.sendCrypto,
      ),
      _ActionButton(
        title: "Receive",
        icon: Icons.call_received,
        route: AppRoutes.receiveCrypto,
      ),
      _ActionButton(
        title: "Swap",
        icon: Icons.swap_horiz,
        route: AppRoutes.swapScreen,
      ),
      _ActionButton(
        title: "Bridge",
        icon: Icons.compare_arrows,
        route: "/bridge-cryptocurrency",
      ),
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: actionButtons.map((button) {
          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: _buildActionButton(
                context,
                title: button.title,
                icon: button.icon,
                route: button.route,
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildActionButton(
    BuildContext context, {
    required String title,
    required IconData icon,
    required String route,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => Navigator.pushNamed(context, route),
        borderRadius: BorderRadius.circular(6),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.2),
            borderRadius: BorderRadius.circular(6),
          ),
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                color: Colors.white,
                size: 24,
              ),
              SizedBox(height: 6),
              Text(
                title,
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 11.sp,
                ),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ActionButton {
  final String title;
  final IconData icon;
  final String route;

  _ActionButton({required this.title, required this.icon, required this.route});
}
