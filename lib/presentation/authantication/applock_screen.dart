import 'package:cryptowallet/routes/app_routes.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppLockScreen extends StatefulWidget {
  const AppLockScreen({super.key});

  @override
  State<AppLockScreen> createState() => _AppLockScreenState();
}

class _AppLockScreenState extends State<AppLockScreen> {
  static const Color kBg = Color(0xFF0B0D1A);

  final TextEditingController _passwordController = TextEditingController();
  bool _showPassword = false;
  String? _storedPassword;

  @override
  void initState() {
    super.initState();
    _loadStoredPassword();
  }

  @override
  void dispose() {
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _loadStoredPassword() async {
    final prefs = await SharedPreferences.getInstance();
    final savedPassword = prefs.getString('wallet_password');

    if (!mounted) return;

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
    // Loading state
    if (_storedPassword == null) {
      return const Scaffold(
        backgroundColor: kBg,
        body: Center(
          child: CircularProgressIndicator(color: Colors.white),
        ),
      );
    }

    return Scaffold(
      backgroundColor: kBg, // ← Dark app background
      appBar: AppBar(
        backgroundColor: kBg,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text('App Lock'),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text(
                  "Enter your wallet password",
                  style: TextStyle(
                    color: Colors.white, // ← White text for visibility
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: _passwordController,
                  obscureText: !_showPassword,
                  cursorColor: kBg,
                  style: const TextStyle(color: Colors.black87),
                  decoration: InputDecoration(
                    labelText: 'Password',
                    labelStyle: TextStyle(color: Colors.grey.shade700),
                    filled: true,
                    fillColor: Colors.white, // ← White field on dark bg
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 14),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _showPassword ? Icons.visibility_off : Icons.visibility,
                        color: Colors.grey.shade700,
                      ),
                      onPressed: () =>
                          setState(() => _showPassword = !_showPassword),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _verifyPassword,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white, // ← White button
                      foregroundColor: kBg, // ← Dark text/icon
                      minimumSize: const Size.fromHeight(48),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 2,
                    ),
                    child: const Text(
                      'Unlock Wallet',
                      style: TextStyle(fontWeight: FontWeight.w600),
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
