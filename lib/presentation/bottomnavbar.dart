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
    return BottomNavigationBar( backgroundColor: const Color(0xFF1A1D29),
      currentIndex: selectedIndex,
      onTap: (index) {
        if (index == 2) {
          Navigator.pushNamed(context, AppRoutes.swapScreen);
        } else if (index == 3) {
          Navigator.pushNamed(context, AppRoutes.profileScreen);
        } else {
          onTap(index); // Call parent callback to update index
        }
      },
      selectedItemColor: Colors.white,
      unselectedItemColor: const Color.fromARGB(255, 93, 93, 93),
      type: BottomNavigationBarType.fixed,
      items: const [
        BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
        BottomNavigationBarItem(icon: Icon(Icons.wallet), label: 'Wallet'),
        BottomNavigationBarItem(icon: Icon(Icons.swap_horiz), label: 'Swap'),
        BottomNavigationBarItem(icon: Icon(Icons.settings), label: 'Settings'),
      ],
    );
  }
}
