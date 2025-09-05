// lib/presentation/main_wallet_dashboard/widgets/action_buttons_grid_widget.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sizer/sizer.dart';
import '../../../core/app_export.dart';
import '../../../stores/coin_store.dart';

class ActionButtonsGridWidget extends StatelessWidget {
  final bool isLarge;
  final bool isTablet;
  final String coinId; // <-- NEW: jis coin ki card hai

  const ActionButtonsGridWidget({
    super.key,
    required this.coinId, // <-- REQUIRED
    this.isLarge = false,
    this.isTablet = false,
  });

  @override
  Widget build(BuildContext context) {
    final store = context.watch<CoinStore>();
    final coin = store.getById(coinId);

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
        title: "Activity",
        icon: Icons.history,
        route: AppRoutes.tokenDetail,
        // 👉 TokenDetail ko History tab par le jao + coin context bhejo
        arguments: {
          'initialTab': 1, // History tab
          'symbol': coin?.symbol, // e.g. BTC
          'name': coin?.name, // e.g. Bitcoin
          'icon': coin?.assetPath, // icon path from CoinStore
          // zarurat ho to price/extra fields bhi bhej sakte ho:
          // 'price':  widget.currentPrice  <-- (agar is widget ko pass karna chaho)
        },
      ),
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 20),
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
                arguments: button.arguments, // <-- forward args
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
    Object? arguments, // <-- NEW
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => Navigator.pushNamed(context, route, arguments: arguments),
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
              Icon(icon, color: Colors.white, size: 24),
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
  final Object? arguments; // <-- NEW
  _ActionButton({
    required this.title,
    required this.icon,
    required this.route,
    this.arguments,
  });
}
