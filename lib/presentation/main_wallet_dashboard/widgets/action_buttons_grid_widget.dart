// lib/presentation/main_wallet_dashboard/widgets/action_buttons_grid_widget.dart
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sizer/sizer.dart';

import '../../../core/app_export.dart';
import '../../../stores/coin_store.dart';

class ActionButtonsGridWidget extends StatelessWidget {
  final bool isLarge;
  final bool isTablet;

  /// Coin/card id from CoinStore — e.g. "BTC", "BTC-LN", "USDT-TRX", "ETH-ETH"
  final String coinId;

  /// Optional: override tap for Receive button (e.g., to open the correct chain address)
  final FutureOr<void> Function()? onReceive;

  const ActionButtonsGridWidget({
    super.key,
    required this.coinId,
    this.isLarge = false,
    this.isTablet = false,
    this.onReceive, // <-- NEW
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
        onTapOverride: onReceive, // <-- use your callback if provided
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
        // Open TokenDetail in History tab and pass coin context
        arguments: {
          'initialTab': 1, // History tab
          'symbol': coin?.symbol, // e.g. BTC
          'name': coin?.name, // e.g. Bitcoin
          'icon': coin?.assetPath, // icon path from CoinStore
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
                arguments: button.arguments,
                onTapOverride: button.onTapOverride,
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
    Object? arguments,
    FutureOr<void> Function()? onTapOverride,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () async {
          if (onTapOverride != null) {
            await onTapOverride();
          } else {
            Navigator.pushNamed(context, route, arguments: arguments);
          }
        },
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
              const SizedBox(height: 6),
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
  final Object? arguments;
  final FutureOr<void> Function()? onTapOverride;
  _ActionButton({
    required this.title,
    required this.icon,
    required this.route,
    this.arguments,
    this.onTapOverride,
  });
}
