import 'package:cryptowallet/routes/app_routes.dart';
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
  String? _storedPassword;

  @override
  void initState() {
    super.initState();
    _loadStoredPassword();
  }

  Future<void> _loadStoredPassword() async {
    final prefs = await SharedPreferences.getInstance();
    final savedPassword = prefs.getString('wallet_password');

    if (savedPassword == null || savedPassword.isEmpty) {
      Navigator.pushReplacementNamed(context, AppRoutes.welcomeScreen);
    } else {
      setState(() {
        _storedPassword = savedPassword;
      });
    }
  }

  void _verifyPassword() {
    final input = _passwordController.text.trim();
    if (input.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter your password')),
      );
    } else if (input == _storedPassword) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('✅ Wallet unlocked successfully')),
      );
      Navigator.pushReplacementNamed(context, AppRoutes.dashboardScreen);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Incorrect password')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_storedPassword == null) {
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
                  icon: Icon(
                      _showPassword ? Icons.visibility_off : Icons.visibility),
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
