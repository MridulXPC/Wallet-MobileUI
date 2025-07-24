import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/auth_service.dart';

class LoginScreen extends StatefulWidget {
  static const String routeName = '/login';

  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _phraseController = TextEditingController();
  bool _loading = false;

  Future<void> _handleLogin() async {
    final phrase = _phraseController.text.trim();

    if (phrase.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Secret Recovery Phrase is required.")),
      );
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    final storedPassword = prefs.getString('wallet_password');

    if (storedPassword == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("🔒 Password not found. Please create a new wallet."),
        ),
      );
      return;
    }

    setState(() => _loading = true);

    final success = await AuthService.loginUser(
      seedPhrase: phrase,
      password: storedPassword,
    );

    setState(() => _loading = false);

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("✅ Login successful")),
      );
      Navigator.pushReplacementNamed(context, '/main-wallet-dashboard');
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("❌ Login failed. Check your phrase.")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Login')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 40),
            const Text(
              'Enter your Secret Recovery Phrase',
              style: TextStyle(fontSize: 16),
            ),
            TextField(
              controller: _phraseController,
              maxLines: 2,
              decoration: const InputDecoration(
                hintText: 'e.g. gravity tilt method ...',
              ),
            ),
            const SizedBox(height: 30),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _loading ? null : _handleLogin,
                child: _loading
                    ? const CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      )
                    : const Text('Login'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
