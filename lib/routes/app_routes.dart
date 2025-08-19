import 'package:cryptowallet/presentation/walletscreen/wallet_screen.dart';
import 'package:flutter/material.dart';

import 'package:cryptowallet/presentation/splash_screen/splash_screen.dart';
import 'package:cryptowallet/presentation/authantication/welcome_screen.dart';
import 'package:cryptowallet/presentation/authantication/wallet_setup_screen.dart';
import 'package:cryptowallet/presentation/authantication/create_walllet_new.dart';
import 'package:cryptowallet/presentation/authantication/applock_screen.dart';
import 'package:cryptowallet/presentation/authantication/login_screen.dart';
import 'package:cryptowallet/presentation/biometric_authentication/biometric_authentication.dart';

import 'package:cryptowallet/presentation/main_wallet_dashboard/main_wallet_dashboard.dart';
import 'package:cryptowallet/presentation/receive_cryptocurrency/receive_cryptocurrency.dart';
import 'package:cryptowallet/presentation/send_cryptocurrency/send_cryptocurrency.dart';
import 'package:cryptowallet/presentation/transaction_history/transaction_history.dart';
import 'package:cryptowallet/presentation/token_detail_screen/token_detail_screen.dart';
import 'package:cryptowallet/presentation/swap_screen.dart/swap_screen.dart';
import 'package:cryptowallet/presentation/profile_screen/profile_screen.dart';
import 'package:cryptowallet/presentation/profile_screen/SessionInfoScreen.dart';

class AppRoutes {
  // Route names
  static const String initial = '/';
  static const String splashScreen = '/splash-screen';
  static const String welcomeScreen = '/welcome-intro';
  static const String walletSetupScreen = '/wallet-setup';
  static const String createWalletScreen = '/create-wallet';
  static const String loginScreen = '/login';
  static const String biometricAuthScreen = '/biometric-auth';
  static const String appLockScreen = '/app-lock';
  static const String dashboardScreen = '/main-dashboard';

  // Wallet
  static const String receiveCrypto = '/receive';
  static const String sendCrypto = '/send';
  static const String transactionHistory = '/transactions';
  static const String tokenDetail = '/token-details';
  static const String swapScreen = '/swap';
  static const String walletInfoScreen = '/wallet-info';

  // Profile
  static const String profileScreen = '/profile';
  static const String sessionInfoScreen = '/session-info';

  // Routes map
  static final Map<String, WidgetBuilder> routes = {
    initial: (context) => const SplashScreen(),
    splashScreen: (context) => const SplashScreen(),
    welcomeScreen: (context) => const WelcomeCarouselScreen(),
    walletSetupScreen: (context) => const WalletSetupScreen(),
    createWalletScreen: (context) => const WalletOnboardingFlow(),
    loginScreen: (context) => const LoginScreen(),
    biometricAuthScreen: (context) => const BiometricAuthentication(),
    appLockScreen: (context) => const AppLockScreen(),
    dashboardScreen: (context) => const WalletHomeScreen(),

    // Wallet Features
    receiveCrypto: (context) {
      final args = ModalRoute.of(context)?.settings.arguments;
      String title = 'Your address to receive XRP';
      String address = '';
      if (args is Map) {
        title = (args['title'] as String?) ?? title;
        address = (args['address'] as String?) ?? address;
      }
      return ReceiveQR(title: title, address: address);
    },

    sendCrypto: (context) => const SendCryptocurrency(),
    transactionHistory: (context) => const TransactionHistory(),
    tokenDetail: (context) => const TokenDetailScreen(),
    swapScreen: (context) => const SwapScreen(),
    walletInfoScreen: (context) => WalletInfoScreen(),

    // Profile
    profileScreen: (context) => const ProfileScreen(),
  };

  // Handle routes needing arguments
  static Route<dynamic>? onGenerateRoute(RouteSettings settings) {
    switch (settings.name) {
      case sessionInfoScreen:
        final args = settings.arguments;
        if (args is String) {
          return MaterialPageRoute(
              builder: (_) => SessionInfoScreen(sessionId: args));
        }
        return _errorRoute();
      default:
        return null;
    }
  }

  static Route<dynamic> _errorRoute() {
    return MaterialPageRoute(
      builder: (_) => const Scaffold(
        body: Center(child: Text('404 - Page not found')),
      ),
    );
  }
}
