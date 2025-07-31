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

  // Validate phrase format (basic check)
  if (phrase.isEmpty) {
    _showError("Secret Recovery Phrase is required.");
    return;
  }

  // Check if phrase has correct word count (12, 15, 18, 21, or 24 words)
  final words = phrase.split(' ').where((word) => word.isNotEmpty).toList();
  if (![12, 15, 18, 21, 24].contains(words.length)) {
    _showError("Invalid recovery phrase. Please check the word count.");
    return;
  }

  final prefs = await SharedPreferences.getInstance();
  final storedPassword = prefs.getString('wallet_password');

  if (storedPassword == null) {
    _showError("🔒 Password not found. Please create a new wallet.");
    return;
  }

  setState(() => _loading = true);

  try {
    final result = await AuthService.loginUser(
      seedPhrase: phrase,
      password: storedPassword,
    );

    if (result.success && mounted) {
      _showSuccess("✅ Login successful");
      
      // Optional: Save login timestamp
      await prefs.setInt('last_login', DateTime.now().millisecondsSinceEpoch);
      
      Navigator.pushReplacementNamed(context, '/main-wallet-dashboard');
    } else {
      _showError(result.message ?? "❌ Login failed. Please check your recovery phrase.");
    }
  } on ApiException catch (e) {
    debugPrint("❌ API error: $e");
    _showError("❌ ${e.message}");
  } catch (e) {
    debugPrint("❌ Unexpected error: $e");
    _showError("❌ An unexpected error occurred. Please try again.");
  } finally {
    if (mounted) {
      setState(() => _loading = false);
    }
  }
}

// Helper methods for cleaner code
void _showError(String message) {
  if (mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}

void _showSuccess(String message) {
  if (mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
      ),
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
