import 'package:cryptowallet/core/app_export.dart';
import 'package:flutter/material.dart';

class BottomNavBar extends StatelessWidget {
  final int selectedIndex;
  final Function(int) onTap;

  const BottomNavBar({
    super.key,
    required this.selectedIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Divider(
          height: 1,
          thickness: 1,
          color: Color(0xFF2A2D3A), // subtle grey line
        ),
        BottomNavigationBar(
          backgroundColor: const Color(0xFF0B0D1A),
          currentIndex: selectedIndex,
          onTap: (index) {
            if (index == 2) {
              Navigator.pushNamed(context, AppRoutes.swapScreen);
            } else if (index == 1) {
              Navigator.pushNamed(context, AppRoutes.walletInfoScreen);
            } else if (index == 4) {
              Navigator.pushNamed(context, AppRoutes.profileScreen);
            } else {
              onTap(index);
            }
          },
          selectedItemColor: Colors.white,
          unselectedItemColor: const Color.fromARGB(255, 93, 93, 93),
          type: BottomNavigationBarType.fixed,
          items: const [
            BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
            BottomNavigationBarItem(icon: Icon(Icons.wallet), label: 'Wallet'),
            BottomNavigationBarItem(
                icon: Icon(Icons.swap_horiz), label: 'Swap'),
            BottomNavigationBarItem(
                icon: Icon(Icons.explore), label: 'Explorer'),
            BottomNavigationBarItem(
                icon: Icon(Icons.settings), label: 'Settings'),
          ],
        ),
      ],
    );
  }
}
