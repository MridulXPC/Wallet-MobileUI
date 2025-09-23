import 'package:cryptowallet/core/currency_notifier.dart';
import 'package:cryptowallet/stores/balance_store.dart';
import 'package:cryptowallet/stores/coin_store.dart';
import 'package:cryptowallet/stores/wallet_store.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sizer/sizer.dart';

import '../core/app_export.dart';
import '../widgets/custom_error_widget.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Critical: custom error handling
  ErrorWidget.builder = (FlutterErrorDetails details) {
    return CustomErrorWidget(errorDetails: details);
  };

  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

  // Bootstrap currency so first frame is correct
  final currency = CurrencyNotifier();
  await currency.bootstrap();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<CurrencyNotifier>.value(value: currency),
        ChangeNotifierProvider(create: (_) => CoinStore()),
        ChangeNotifierProvider(create: (_) => WalletStore()),
        ChangeNotifierProvider(create: (_) => BalanceStore()),
      ],
      child: const MyApp(),
    ),
  );
}

Future<String> determineNextRoute() async {
  final prefs = await SharedPreferences.getInstance();
  final isFirstLaunch = prefs.getBool('is_first_launch') ?? true;
  final hasPassword = prefs.getString('wallet_password') != null;

  if (isFirstLaunch) return AppRoutes.welcomeScreen;
  if (hasPassword) return AppRoutes.appLockScreen;
  return AppRoutes.welcomeScreen;
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Sizer(
      builder: (context, orientation, deviceType) {
        return MaterialApp(
          title: 'CryptoWallet',
          debugShowCheckedModeBanner: false,
          theme: ThemeData(
            textTheme: GoogleFonts.interTextTheme(),
          ),
          builder: (context, child) {
            final base = Theme.of(context).textTheme;
            return MediaQuery(
              data: MediaQuery.of(context).copyWith(
                textScaler: const TextScaler.linear(1.0),
              ),
              child: DefaultTextStyle.merge(
                style: GoogleFonts.interTextTheme(base).bodyMedium!,
                child: child!,
              ),
            );
          },
          initialRoute: AppRoutes.splashScreen,
          routes: AppRoutes.routes,
        );
      },
    );
  }
}
