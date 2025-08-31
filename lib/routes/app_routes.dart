import 'package:cryptowallet/presentation/profile_screen/GeneralSettingsScreen.dart';
import 'package:cryptowallet/presentation/profile_screen/SecuritySettingsScreen.dart';
import 'package:cryptowallet/presentation/profile_screen/TechSupportScreen.dart';
import 'package:cryptowallet/presentation/profile_screen/adressbook.dart';

import 'package:cryptowallet/presentation/receive_cryptocurrency/receive_btclightning.dart';
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
  static const String swaphistory = '/';

  // Wallet
  static const String receiveCrypto = '/receive';
  static const String receiveBTCLightning = '/receive-btc-lightning';
  static const String sendCrypto = '/send';
  static const String transactionHistory = '/transactions';
  static const String tokenDetail = '/token-details';
  static const String swapScreen = '/swap';
  static const String walletInfoScreen = '/wallet-info';

  // Profile
  static const String profileScreen = '/profile';
  static const String sessionInfoScreen = '/session-info';
  static const String generalSettingsScreen = '/general-settings';
  static const String walletSettingsScreen = '/wallet-settings';
  static const String securitysettingscreen = '/security-settings';
  static const String techSupportScreen = '/tech-support';
  static const String addressbook = '/address-book';

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
    generalSettingsScreen: (context) => const GeneralSettingsScreen(),

    addressbook: (context) => const AddressBookScreen(),
    securitysettingscreen: (context) => const SecuritySettingsScreen(),
    techSupportScreen: (context) => const TechSupportScreen(),

    // Wallet Features
// Helper: turn "BTC-LN" -> "BTC"
    receiveCrypto: (context) {
      final args = ModalRoute.of(context)?.settings.arguments;

      // defaults
      String? coinId; // e.g. "BTC", "BTC-LN"
      String? mode; // "onchain" | "invoice" | "ln" | "lightning"
      String? titleOverride; // optional explicit title

      if (args is Map) {
        coinId = args['coinId'] as String?;
        mode = args['mode'] as String?;
        titleOverride = args['title'] as String?;
      }

      // Normalize coin id & symbol
      final id = (coinId ?? 'BTC').toUpperCase(); // "BTC-LN" -> "BTC-LN"
      final symbol = id.split('-').first; // "BTC-LN" -> "BTC"

      // Normalize mode; default by coin
      late final String normalizedMode;
      if (mode != null) {
        final m = mode!.toLowerCase();
        normalizedMode = (m == 'invoice' || m == 'ln' || m == 'lightning')
            ? 'invoice'
            : 'onchain';
      } else {
        normalizedMode = id.startsWith('BTC-LN') ? 'invoice' : 'onchain';
      }

      // Title
      final computedTitle = titleOverride ??
          (normalizedMode == 'invoice'
              ? 'Set amount to receive $symbol'
              : 'Your address to receive $symbol');

      // Optional min sats for BTC on-chain
      final int? minSats =
          (normalizedMode == 'onchain' && symbol == 'BTC') ? 25000 : null;

      return ReceiveQR(
        title: "Your address to receive BTC",
        address: "bc1pht4p7c7gxqjlpkf28t3n...04uvww6jlq5n373aqt8amed",
        coinId: "BTC",
        mode: "onchain",
        initialSats: 0,
        minSats: 25000,
      );
    },

    receiveBTCLightning: (context) {
      final raw = ModalRoute.of(context)?.settings.arguments;

      // Safe map extraction
      final Map<String, dynamic> args =
          (raw is Map) ? Map<String, dynamic>.from(raw) : const {};

      // ---- Back-compat (old) ----
      // If someone still passes { title, address }, we’ll treat `address` as the QR data.
      final String? legacyAddress = args['address'] as String?;

      // ---- New fields (for the Charge / invoice flow) ----
      final String title = (args['title'] as String?) ?? 'Charge';
      final String accountLabel =
          (args['accountLabel'] as String?) ?? 'LN - Main Account';
      final String coinName = (args['coinName'] as String?) ?? 'Bitcoin';
      final String iconAsset =
          (args['iconAsset'] as String?) ?? 'assets/currencyicons/bitcoin.png';
      final bool isLightning = (args['isLightning'] as bool?) ?? true;

      final String amount = (args['amount'] as String?) ?? '0';
      final String symbol = (args['symbol'] as String?) ?? 'BTC';
      final double fiatValue = (args['fiatValue'] is num)
          ? (args['fiatValue'] as num).toDouble()
          : 0.0;

      // What to encode in the QR. In the new flow this should be the amount (or LN invoice later).
      final String qrData = (args['qrData'] as String?) ??
          legacyAddress // fallback to legacy
          ??
          amount; // final fallback

      return ReceiveQRbtclightning(
        title: title,
        accountLabel: accountLabel,
        coinName: coinName,
        iconAsset: iconAsset,
        isLightning: isLightning,
        amount: amount,
        symbol: symbol,
        fiatValue: fiatValue,
        qrData: qrData,
      );
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
