import 'package:cryptowallet/presentation/authantication/loginscreen.dart';
import 'package:flutter/material.dart';
import 'package:cryptowallet/theme/app_theme.dart';

class WelcomeScreen extends StatelessWidget {
  static const String routeName = '/welcome-screen';

  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final Color bgColor = AppTheme.darkTheme.scaffoldBackgroundColor;

    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // App Logo
              
                const SizedBox(height: 40),

                const Text(
                  'Welcome to CryptoWallet',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textHighEmphasis,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                const Text(
                  'Securely manage your digital assets',
                  style: TextStyle(
                    fontSize: 16,
                    color: AppTheme.textMediumEmphasis,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 40),

                // Access Wallet Button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pushNamed(context, SecretPhraseLoginScreen.routeName);
                    },
                    child: const Text('Access Existing Wallet'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.tealAccent[700],
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // Create New Wallet Button
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: () {
                      Navigator.pushNamed(context, '/create-wallet');
                    },
                    child: const Text('Create New Wallet'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white70,
                      side: const BorderSide(color: Colors.white30),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
