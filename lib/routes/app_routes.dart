import 'package:cryptowallet/presentation/authantication/create_wallet_screen.dart';
import 'package:cryptowallet/presentation/authantication/welcome_screen.dart';
import 'package:flutter/material.dart';
import 'package:cryptowallet/presentation/splash_screen/splash_screen.dart';
import 'package:cryptowallet/presentation/authantication/wallet_setup_screen.dart';
import 'package:cryptowallet/presentation/authantication/loginscreen.dart';
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
  static const String walletsetup = '/walletsetup-screen';
  static const String secretPhraseLogin = '/secret-phrase-login';
  static const String biometricAuthentication = '/biometric-authentication';
  static const String mainWalletDashboard = '/main-wallet-dashboard';
  static const String receiveCryptocurrency = '/receive-cryptocurrency';
  static const String sendCryptocurrency = '/send-cryptocurrency';
  static const String transactionHistory = '/transaction-history';
  static const String tokenDetailScreen = '/token-detail-screen';
  static const String cryptoSwapScreen = '/crypto-swap-screen';
  static const String profileScreen = '/profile-screen';
  static const String sessionInfoScreen = '/session-info-screen';
  static const String createwalletScreen = '/create-wallet';
  static const String welcomeScreen = '/welcome-intro';


  // Routes map
  static Map<String, WidgetBuilder> routes = {
    initial: (context) => const SplashScreen(),
    welcomeScreen: (context) => const WelcomeCarouselScreen(),
    splashScreen: (context) => const SplashScreen(),
    createwalletScreen: (context) => const CreateWalletScreen(),
    walletsetup: (context) => const WalletSetupScreen(),
    secretPhraseLogin: (context) => const WalletOnboardingFlow(),
    biometricAuthentication: (context) => const BiometricAuthentication(),
    mainWalletDashboard: (context) => const MainWalletDashboard(),
    receiveCryptocurrency: (context) => const ReceiveCryptocurrency(),
    sendCryptocurrency: (context) => const SendCryptocurrency(),
    transactionHistory: (context) => const TransactionHistory(),
    tokenDetailScreen: (context) => const TokenDetailScreen(),
    cryptoSwapScreen: (context) => const CryptoSwapScreen(),
    profileScreen: (context) => const ProfileScreen(),
    sessionInfoScreen: (context) {
      final sessionId = ModalRoute.of(context)?.settings.arguments as String;
      return SessionInfoScreen(sessionId: sessionId);
    },
  };
}
