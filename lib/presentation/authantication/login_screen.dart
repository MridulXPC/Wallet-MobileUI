import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/api_service.dart';

class LoginScreen extends StatefulWidget {
  static const String routeName = '/login';

  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  static const Color kBg = Color(0xFF0B0D1A);

  final TextEditingController _phraseController = TextEditingController();
  bool _loading = false;

  @override
  void dispose() {
    _phraseController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    final phrase = _phraseController.text.trim();

    if (phrase.isEmpty) {
      _showError("Secret Recovery Phrase is required.");
      return;
    }

    final words = phrase.split(' ').where((w) => w.isNotEmpty).toList();
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
        await prefs.setInt('last_login', DateTime.now().millisecondsSinceEpoch);
        Navigator.pushReplacementNamed(context, '/main-wallet-dashboard');
      } else {
        _showError(result.message ??
            "❌ Login failed. Please check your recovery phrase.");
      }
    } on ApiException catch (e) {
      debugPrint("❌ API error: $e");
      _showError("❌ ${e.message}");
    } catch (e) {
      debugPrint("❌ Unexpected error: $e");
      _showError("❌ An unexpected error occurred. Please try again.");
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // ---- UI helpers ----
  InputDecoration _whiteFieldDecoration({
    String? hint,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: Colors.black45),
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      suffixIcon: suffixIcon,
    );
  }

  ButtonStyle _whiteButtonStyle() {
    return ElevatedButton.styleFrom(
      backgroundColor: Colors.white,
      foregroundColor: kBg,
      minimumSize: const Size.fromHeight(50),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 2,
    );
  }

  // ---- snackbars ----
  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showSuccess(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBg,
      appBar: AppBar(
        backgroundColor: kBg,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text('Login'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: DefaultTextStyle(
          style: const TextStyle(color: Colors.white),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 24),
              Text(
                'Enter your Secret Recovery Phrase',
                style: TextStyle(fontSize: 16, color: Colors.grey.shade200),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _phraseController,
                maxLines: 3,
                cursorColor: kBg,
                style: const TextStyle(color: Colors.black87),
                decoration: _whiteFieldDecoration(
                  hint: 'e.g. gravity tilt method ...',
                  suffixIcon: IconButton(
                    icon: Icon(Icons.clear, color: Colors.grey.shade700),
                    onPressed: () => _phraseController.clear(),
                  ),
                ),
              ),
              const SizedBox(height: 30),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _loading ? null : _handleLogin,
                  style: _whiteButtonStyle().copyWith(
                    backgroundColor: MaterialStateProperty.resolveWith((s) {
                      if (s.contains(MaterialState.disabled)) {
                        return Colors.white.withOpacity(0.5);
                      }
                      return Colors.white;
                    }),
                  ),
                  child: _loading
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor:
                                AlwaysStoppedAnimation<Color>(Colors.black87),
                          ),
                        )
                      : const Text('Login'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
