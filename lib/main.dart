import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';
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

  final initialRoute = await _determineStartRoute();

  runApp(MyApp(initialRoute: initialRoute));
}

Future<String> _determineStartRoute() async {
  final prefs = await SharedPreferences.getInstance();
  final isFirstLaunch = prefs.getBool('is_first_launch') ?? true;
  final hasPassword = prefs.getString('wallet_password') != null;
  final useBiometrics = prefs.getBool('use_biometrics') ?? false;

  if (isFirstLaunch) {
    return AppRoutes.welcomeScreen; // 👈 Go to welcome/onboarding
  }

  if (hasPassword) {
    if (useBiometrics) {
      try {
        final auth = LocalAuthentication();
        final isSupported = await auth.isDeviceSupported();
        final canCheck = await auth.canCheckBiometrics;

        if (isSupported && canCheck) {
          final authenticated = await auth.authenticate(
            localizedReason: 'Please authenticate to access your wallet',
            options: const AuthenticationOptions(
              biometricOnly: true,
              stickyAuth: true,
            ),
          );

          if (authenticated) {
            return AppRoutes.dashboardScreen;
          } else {
            return AppRoutes.appLockScreen;
          }
        } else {
          return AppRoutes.appLockScreen;
        }
      } catch (e) {
        print('🔐 Biometric check failed: $e');
        return AppRoutes.appLockScreen;
      }
    } else {
      return AppRoutes.appLockScreen;
    }
  }

  return AppRoutes.welcomeScreen;
}

class MyApp extends StatelessWidget {
  final String initialRoute;

  const MyApp({super.key, required this.initialRoute});

  @override
  Widget build(BuildContext context) {
    return Sizer(
      builder: (context, orientation, deviceType) {
        return MaterialApp(
          title: 'CryptoWallet',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: ThemeMode.light,
          builder: (context, child) {
            return MediaQuery(
              data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(1.0)),
              child: child!,
            );
          },
          initialRoute: initialRoute,
          routes: AppRoutes.routes,
        );
      },
    );
  }
}
