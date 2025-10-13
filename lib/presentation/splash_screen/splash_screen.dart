import 'package:cryptowallet/routes/app_routes.dart';
import 'package:cryptowallet/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _navigateToNextScreen();
  }

  Future<void> _navigateToNextScreen() async {
    // Display splash at least 2 seconds
    await Future.delayed(const Duration(seconds: 2));

    final prefs = await SharedPreferences.getInstance();

    final isFirstLaunch = prefs.getBool('is_first_launch') ?? true;
    final walletPassword = prefs.getString('wallet_password');
    final walletId = prefs.getString('wallet_id');

    String nextRoute;

    if (walletPassword != null &&
        walletPassword.isNotEmpty &&
        walletId != null &&
        walletId.isNotEmpty) {
      // ✅ Existing wallet found → App Lock screen
      nextRoute = AppRoutes.appLockScreen;
    } else if (isFirstLaunch) {
      // 🆕 First time user → Welcome/setup flow
      nextRoute = AppRoutes.welcomeScreen;
    } else {
      // 🧩 Edge case (user skipped confirm phrase or partial setup)
      nextRoute = AppRoutes.walletSetupScreen;
    }

    if (!mounted) return;
    Navigator.pushReplacementNamed(context, nextRoute);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.darkTheme.scaffoldBackgroundColor,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.account_balance_wallet,
              size: 100,
              color: Theme.of(context).primaryColor,
            ),
            const SizedBox(height: 20),
            Text(
              'CryptoWallet',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).primaryColor,
              ),
            ),
            const SizedBox(height: 40),
            const CircularProgressIndicator(color: Colors.white),
          ],
        ),
      ),
    );
  }
}
