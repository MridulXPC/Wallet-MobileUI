import 'package:cryptowallet/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class SecretPhraseLoginScreen extends StatefulWidget {
  static const String routeName = '/secret-phrase-login';

  const SecretPhraseLoginScreen({super.key});

  @override
  State<SecretPhraseLoginScreen> createState() => _SecretPhraseLoginScreenState();
}

class _SecretPhraseLoginScreenState extends State<SecretPhraseLoginScreen> {
  final TextEditingController _phraseController = TextEditingController();
  bool _loading = false;
  String? _errorMessage;

  Future<void> _loginWithSecretPhrase() async {
    final phrase = _phraseController.text.trim();
    if (phrase.split(' ').length < 12) {
      setState(() => _errorMessage = 'Enter a valid 12 or 24-word phrase.');
      return;
    }

    setState(() {
      _loading = true;
      _errorMessage = null;
    });

    try {
      final response = await http.post(
        Uri.parse('https://your-backend.com/api/auth/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'secretPhrase': phrase}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        debugPrint('🔐 Logged in successfully: ${data['token']}');

        // Navigate to your main dashboard
        Navigator.pushReplacementNamed(context, '/main-wallet-dashboard');
      } else {
        setState(() {
          _errorMessage = jsonDecode(response.body)['error'] ?? 'Login failed.';
        });
      }
    } catch (e) {
      setState(() => _errorMessage = 'An error occurred. Please try again.');
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _phraseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final Color bgColor = AppTheme.darkTheme.scaffoldBackgroundColor;
    final Color inputColor = Colors.white70;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: bgColor,
        title: const Text('Access Your Wallet',style: TextStyle(color: AppTheme.textMediumEmphasis),),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            const Text(
              'Enter your 12 or 24-word Secret Recovery Phrase',
              style: TextStyle(fontSize: 16, color: Colors.white70),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _phraseController,
              maxLines: 4,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                filled: true,
                fillColor: Colors.white10,
                hintText: 'e.g. fox slot mobile ...',
                hintStyle: TextStyle(color: inputColor),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                errorText: _errorMessage,
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _loading ? null : _loginWithSecretPhrase,
                icon: _loading
                    ? const SizedBox(
                        height: 16,
                        width: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.login),
                label: const Text('Login'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.tealAccent[700],
                  foregroundColor: Colors.black,
                  minimumSize: const Size.fromHeight(50),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
