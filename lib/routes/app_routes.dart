import 'package:cryptowallet/presentation/authantication/loginscreen.dart';
import 'package:cryptowallet/presentation/profile_screen/SessionInfoScreen.dart';
import 'package:cryptowallet/presentation/profile_screen/profile_screen.dart';
import 'package:cryptowallet/presentation/swap_screen.dart/swap_screen.dart';
import 'package:flutter/material.dart';
import '../presentation/splash_screen/splash_screen.dart';
import '../presentation/biometric_authentication/biometric_authentication.dart';
import '../presentation/main_wallet_dashboard/main_wallet_dashboard.dart';
import '../presentation/receive_cryptocurrency/receive_cryptocurrency.dart';
import '../presentation/send_cryptocurrency/send_cryptocurrency.dart';
import '../presentation/transaction_history/transaction_history.dart';
import '../presentation/token_detail_screen/token_detail_screen.dart';

class AppRoutes {
  // TODO: Add your routes here
  static const String initial = '/';
  static const String splashScreen = '/splash-screen';
   static const String secretPhraseLogin = '/secret-phrase-login';
  static const String biometricAuthentication = '/biometric-authentication';
  static const String mainWalletDashboard = '/main-wallet-dashboard';
  static const String receiveCryptocurrency = '/receive-cryptocurrency';
  static const String sendCryptocurrency = '/send-cryptocurrency';
  static const String transactionHistory = '/transaction-history';
  static const String tokenDetailScreen = '/token-detail-screen';
  static const String cryptoswapscreen = '/crypto-swap-screen';
  static const String profilescreen = '/profile-screen';
  static const String sessionInfoScreen = '/session-info-screen';


  static Map<String, WidgetBuilder> routes = {
    initial: (context) => const SplashScreen(),
    splashScreen: (context) => const SplashScreen(),
    secretPhraseLogin: (context) => const SecretPhraseLoginScreen(),
    biometricAuthentication: (context) => const BiometricAuthentication(),
    mainWalletDashboard: (context) => const MainWalletDashboard(),
    receiveCryptocurrency: (context) => const ReceiveCryptocurrency(),
    sendCryptocurrency: (context) => const SendCryptocurrency(),
    transactionHistory: (context) => const TransactionHistory(),
    tokenDetailScreen: (context) => const TokenDetailScreen(),
    cryptoswapscreen: (context) => const CryptoSwapScreen(),
    profilescreen: (context) => const ProfileScreen(),
    sessionInfoScreen: (context) => SessionInfoScreen(sessionId: ModalRoute.of(context)?.settings.arguments as String),
    
// TODO: Add your other routes here
  };
}
