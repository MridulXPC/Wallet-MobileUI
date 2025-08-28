// lib/main.dart
import 'package:cryptowallet/coin_store.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart'; // ✅ Provider
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sizer/sizer.dart';

import '../core/app_export.dart'; // Contains AppTheme and AppRoutes
import '../widgets/custom_error_widget.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 🚨 CRITICAL: Custom error handling - DO NOT REMOVE
  ErrorWidget.builder = (FlutterErrorDetails details) {
    return CustomErrorWidget(errorDetails: details);
  };

  // 🚨 CRITICAL: Device orientation lock - DO NOT REMOVE
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

  runApp(
    // ✅ Provide CoinStore globally so any screen can read coin icons/names
    ChangeNotifierProvider(
      create: (_) => CoinStore(),
      child: const MyApp(),
    ),
  );
}

Future<String> determineNextRoute() async {
  final prefs = await SharedPreferences.getInstance();
  final isFirstLaunch = prefs.getBool('is_first_launch') ?? true;
  final hasPassword = prefs.getString('wallet_password') != null;

  if (isFirstLaunch) {
    return AppRoutes.welcomeScreen;
  }

  if (hasPassword) {
    return AppRoutes.appLockScreen;
  }

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
            textTheme: GoogleFonts
                .interTextTheme(), // applies Inter to all text styles
          ),
          builder: (context, child) {
            final base = Theme.of(context).textTheme;
            return MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: const TextScaler.linear(1.0)),
              child: DefaultTextStyle.merge(
                style: GoogleFonts.interTextTheme(base).bodyMedium!,
                child: child!,
              ),
            );
          },

          initialRoute: AppRoutes.splashScreen, // Always start with splash
          routes: AppRoutes.routes,
        );
      },
    );
  }
}
