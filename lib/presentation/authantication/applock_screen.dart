import 'package:cryptowallet/routes/app_routes.dart';
import 'package:cryptowallet/services/bio_matric_helper.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppLockScreen extends StatefulWidget {
  const AppLockScreen({super.key});

  @override
  State<AppLockScreen> createState() => _AppLockScreenState();
}

class _AppLockScreenState extends State<AppLockScreen> {
  final TextEditingController _passwordController = TextEditingController();
  bool _showPassword = false;
  bool _biometricTried = false;
  String? _storedPassword;

  @override
  void initState() {
    super.initState();
    _attemptBiometricOrFallback();
  }

Future<void> _attemptBiometricOrFallback() async {
  final prefs = await SharedPreferences.getInstance();
  final useBiometrics = prefs.getBool('use_biometrics') ?? false;
  final savedPassword = prefs.getString('wallet_password');

  if (savedPassword == null || savedPassword.isEmpty) {
    Navigator.pushReplacementNamed(context, '/wallet-onboarding');
    return;
  }

  _storedPassword = savedPassword;

  if (useBiometrics) {
    final isAvailable = await BiometricHelper.isBiometricAvailable();
    if (isAvailable) {
      final success = await BiometricHelper.authenticate();
      if (success) {
        Navigator.pushReplacementNamed(context, AppRoutes.dashboardScreen);
        return;
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Biometric authentication failed')),
        );
      }
    } else {
      debugPrint('⚠️ Biometrics not available on this device');
    }
  }

  // Either biometrics not enabled or unavailable
  setState(() => _biometricTried = true);
}


  void _verifyPassword() {
    if (_passwordController.text.trim() == _storedPassword) {
    Navigator.pushReplacementNamed(context, AppRoutes.dashboardScreen);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('✅ Wallet unlocked successfully')),
      );
    } else if (_passwordController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter your password')),
      );

    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Incorrect password')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_biometricTried) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('App Lock')),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              "Enter your wallet password",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _passwordController,
              obscureText: !_showPassword,
              decoration: InputDecoration(
                labelText: 'Password',
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  icon: Icon(_showPassword
                      ? Icons.visibility_off
                      : Icons.visibility),
                  onPressed: () =>
                      setState(() => _showPassword = !_showPassword),
                ),
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _verifyPassword,
              child: const Text('Unlock Wallet'),
            ),
          ],
        ),
      ),
    );
  }
}
