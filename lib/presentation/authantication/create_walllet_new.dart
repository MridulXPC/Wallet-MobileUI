import 'package:cryptowallet/core/app_export.dart';
import 'package:cryptowallet/services/api_service.dart';
import 'package:flutter/material.dart';
import 'package:bip39/bip39.dart' as bip39;
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

class WalletOnboardingFlow extends StatefulWidget {
  static const String routeName = '/wallet-onboarding';

  const WalletOnboardingFlow({super.key});

  @override
  State<WalletOnboardingFlow> createState() => _WalletOnboardingFlowState();
}

class _WalletOnboardingFlowState extends State<WalletOnboardingFlow> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  void _nextPage() {
    if (_currentPage < 2) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
      setState(() => _currentPage++);
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  static const Color kBg = Color(0xFF0B0D1A);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBg,
      body: PageView(
        controller: _pageController,
        physics: const NeverScrollableScrollPhysics(),
        onPageChanged: (index) => setState(() => _currentPage = index),
        children: [
          Step1PasswordScreen(onNext: _nextPage),
          Step2SecureWalletScreen(onNext: _nextPage),
          const Step3RecoveryPhraseScreen(),
        ],
      ),
    );
  }
}

// Common white input decoration
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

ButtonStyle _whiteButtonStyle(Color darkFg) {
  return ElevatedButton.styleFrom(
    backgroundColor: Colors.white,
    foregroundColor: darkFg,
    minimumSize: const Size.fromHeight(50),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    elevation: 2,
  );
}

// Step 1: Create Password
class Step1PasswordScreen extends StatefulWidget {
  final VoidCallback onNext;

  const Step1PasswordScreen({super.key, required this.onNext});

  @override
  State<Step1PasswordScreen> createState() => _Step1PasswordScreenState();
}

class _Step1PasswordScreenState extends State<Step1PasswordScreen> {
  static const Color kBg = Color(0xFF0B0D1A);

  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmController = TextEditingController();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  bool _useBiometrics = false;
  bool _acceptedWarning = false;
  bool _showPassword = false;
  bool _showConfirm = false;
  bool _isLoading = false;

  final Uuid uuid = const Uuid();

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  // Password validation
  bool get _isPasswordValid {
    final password = _passwordController.text;
    return password.length >= 8 &&
        password.contains(RegExp(r'[A-Z]')) &&
        password.contains(RegExp(r'[a-z]')) &&
        password.contains(RegExp(r'[0-9]'));
  }

  bool get _isFormValid {
    return _passwordController.text.isNotEmpty &&
        _confirmController.text.isNotEmpty &&
        _passwordController.text == _confirmController.text &&
        _isPasswordValid &&
        _acceptedWarning;
  }

  String? _validatePassword(String? value) {
    if (value == null || value.isEmpty) return 'Password is required';
    if (value.length < 8) return 'Password must be at least 8 characters';
    if (!value.contains(RegExp(r'[A-Z]'))) {
      return 'Password must contain an uppercase letter';
    }
    if (!value.contains(RegExp(r'[a-z]'))) {
      return 'Password must contain a lowercase letter';
    }
    if (!value.contains(RegExp(r'[0-9]'))) {
      return 'Password must contain a number';
    }
    return null;
  }

  String? _validateConfirmPassword(String? value) {
    if (value == null || value.isEmpty) return 'Please confirm your password';
    if (value != _passwordController.text) return 'Passwords do not match';
    return null;
  }

  Future<void> _handleContinue() async {
    if (!_formKey.currentState!.validate()) return;
    if (!_acceptedWarning) {
      _showSnackBar("Please acknowledge the warning.");
      return;
    }

    setState(() => _isLoading = true);

    try {
      final prefs = await SharedPreferences.getInstance();
      final String sessionId = uuid.v4();
      final password = _passwordController.text.trim();

      await Future.wait([
        prefs.setString('wallet_password', password),
        prefs.setBool('use_biometrics', _useBiometrics),
        prefs.setString('session_id', sessionId),
      ]);

      await AuthService.registerSession(
        password: password,
        sessionId: sessionId,
      );

      if (mounted) widget.onNext();
    } catch (e) {
      debugPrint("❌ Error: $e");
      if (mounted) {
        _showSnackBar("Failed to create password. Please try again.");
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  Widget _buildRequirement(String text, bool isValid) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Icon(
            isValid ? Icons.check_circle : Icons.radio_button_unchecked,
            size: 16,
            color: isValid ? Colors.green : Colors.grey.shade400,
          ),
          const SizedBox(width: 8),
          Text(
            text,
            style: TextStyle(
              fontSize: 12,
              color: isValid ? Colors.green : Colors.grey.shade300,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBg,
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20.0),
          child: Form(
            key: _formKey,
            child: DefaultTextStyle(
              style: const TextStyle(color: Colors.white),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 20),

                  // Header
                  Text('Step 1 of 3',
                      style:
                          TextStyle(color: Colors.grey.shade300, fontSize: 14)),
                  const SizedBox(height: 10),
                  const Text('Create Wallet Password',
                      style:
                          TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                  Text(
                    'This password unlocks your wallet on this device only.',
                    style: TextStyle(color: Colors.grey.shade300, fontSize: 16),
                  ),
                  const SizedBox(height: 30),

                  const Text('Create Password',
                      style: TextStyle(
                          fontWeight: FontWeight.w500, color: Colors.white)),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _passwordController,
                    obscureText: !_showPassword,
                    validator: _validatePassword,
                    onChanged: (_) => setState(() {}),
                    cursorColor: kBg,
                    style: const TextStyle(color: Colors.black87),
                    decoration: _whiteFieldDecoration(
                      hint: 'Enter password',
                      suffixIcon: IconButton(
                        icon: Icon(
                          _showPassword
                              ? Icons.visibility_off
                              : Icons.visibility,
                          color: Colors.grey.shade700,
                        ),
                        onPressed: () =>
                            setState(() => _showPassword = !_showPassword),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  const Text('Confirm Password',
                      style: TextStyle(
                          fontWeight: FontWeight.w500, color: Colors.white)),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _confirmController,
                    obscureText: !_showConfirm,
                    validator: _validateConfirmPassword,
                    onChanged: (_) => setState(() {}),
                    cursorColor: kBg,
                    style: const TextStyle(color: Colors.black87),
                    decoration: _whiteFieldDecoration(
                      hint: 'Re-enter password',
                      suffixIcon: IconButton(
                        icon: Icon(
                          _showConfirm
                              ? Icons.visibility_off
                              : Icons.visibility,
                          color: Colors.grey.shade700,
                        ),
                        onPressed: () =>
                            setState(() => _showConfirm = !_showConfirm),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  if (_passwordController.text.isNotEmpty) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.06),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.white24),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Password must contain:',
                              style: TextStyle(
                                  fontWeight: FontWeight.w500,
                                  color: Colors.white)),
                          const SizedBox(height: 8),
                          _buildRequirement('At least 8 characters',
                              _passwordController.text.length >= 8),
                          _buildRequirement(
                              'One uppercase letter',
                              _passwordController.text
                                  .contains(RegExp(r'[A-Z]'))),
                          _buildRequirement(
                              'One lowercase letter',
                              _passwordController.text
                                  .contains(RegExp(r'[a-z]'))),
                          _buildRequirement(
                              'One number',
                              _passwordController.text
                                  .contains(RegExp(r'[0-9]'))),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],

                  // Warning Checkbox
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Checkbox(
                        value: _acceptedWarning,
                        onChanged: (val) =>
                            setState(() => _acceptedWarning = val ?? false),
                        checkColor: kBg,
                        activeColor: Colors.white,
                        side: const BorderSide(color: Colors.white70),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'I understand that if I forget this password, Crypto Wallet cannot recover it for me.',
                          style: TextStyle(
                              color: Colors.grey.shade200, fontSize: 14),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Biometrics Switch
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.06),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white24),
                    ),
                    child: Row(
                      children: [
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Unlock with Face ID / Biometrics',
                                  style: TextStyle(
                                      fontWeight: FontWeight.w500,
                                      color: Colors.white)),
                              Text('Use biometrics for quick access',
                                  style: TextStyle(
                                      color: Colors.white70, fontSize: 12)),
                            ],
                          ),
                        ),
                        Switch(
                          value: _useBiometrics,
                          onChanged: (val) =>
                              setState(() => _useBiometrics = val),
                          activeColor: kBg,
                          activeTrackColor: Colors.white,
                          inactiveThumbColor: Colors.white70,
                          inactiveTrackColor: Colors.white24,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 30),

                  // Create Button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed:
                          _isFormValid && !_isLoading ? _handleContinue : null,
                      style: _whiteButtonStyle(kBg).copyWith(
                        // Dim when disabled
                        backgroundColor: MaterialStateProperty.resolveWith((s) {
                          if (s.contains(MaterialState.disabled)) {
                            return Colors.white.withOpacity(0.5);
                          }
                          return Colors.white;
                        }),
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                    Colors.black87),
                              ),
                            )
                          : const Text(
                              'Create Password',
                              style: TextStyle(
                                  fontSize: 16, fontWeight: FontWeight.w600),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// Step 2: Security Education
class Step2SecureWalletScreen extends StatelessWidget {
  final VoidCallback onNext;
  static const Color kBg = Color(0xFF0B0D1A);

  const Step2SecureWalletScreen({super.key, required this.onNext});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: DefaultTextStyle(
            style: const TextStyle(color: Colors.white),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 40),
                Text('Step 2 of 3',
                    style:
                        TextStyle(color: Colors.grey.shade300, fontSize: 14)),
                const SizedBox(height: 10),
                const Text('Secure Your Wallet',
                    style:
                        TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                const SizedBox(height: 20),

                // Security Info (white card on dark bg)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      const Icon(Icons.security,
                          size: 48, color: Colors.black87),
                      const SizedBox(height: 16),
                      const Text(
                        "Don't risk losing your funds!",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        "Protect your wallet by saving your Secret Recovery Phrase in a secure place you trust. This is the only way to recover your wallet.",
                        style: TextStyle(fontSize: 14, color: Colors.black54),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),

                const Spacer(),

                // Button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: onNext,
                    style: _whiteButtonStyle(kBg),
                    child: const Text('Get Started'),
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

// Step 3: Recovery Phrase
class Step3RecoveryPhraseScreen extends StatefulWidget {
  const Step3RecoveryPhraseScreen({super.key});

  @override
  State<Step3RecoveryPhraseScreen> createState() =>
      _Step3RecoveryPhraseScreenState();
}

class _Step3RecoveryPhraseScreenState extends State<Step3RecoveryPhraseScreen> {
  static const Color kBg = Color(0xFF0B0D1A);

  late final String mnemonic;
  late final List<String> phrases;
  bool _isLoading = false;
  bool _isPhraseRevealed = false;

  @override
  void initState() {
    super.initState();
    mnemonic = bip39.generateMnemonic();
    phrases = mnemonic.split(' ');
    debugPrint('🔐 Generated Mnemonic: $mnemonic');
  }

  Future<void> _handleContinue() async {
    setState(() => _isLoading = true);

    try {
      final prefs = await SharedPreferences.getInstance();
      final password = prefs.getString('wallet_password');
      final token = prefs.getString('jwt_token');

      if (token == null || password == null) {
        _showSnackBar('❌ Session expired. Please start over.');
        return;
      }

      final result = await AuthService.submitRecoveryPhrase(
        phrase: mnemonic,
        token: token,
      );

      if (result.success && mounted) {
        await prefs.setBool('is_first_launch', false);
        Navigator.pushReplacementNamed(context, AppRoutes.dashboardScreen);
      } else {
        _showSnackBar(
          result.message ??
              '❌ Failed to submit recovery phrase. Please try again.',
        );
      }
    } catch (e) {
      debugPrint('❌ Error: $e');
      _showSnackBar('❌ An error occurred. Please try again.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  void _copyToClipboard() {
    Clipboard.setData(ClipboardData(text: mnemonic));
    _showSnackBar('✅ Recovery phrase copied to clipboard');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: DefaultTextStyle(
            style: const TextStyle(color: Colors.white),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 40),
                Text('Step 3 of 3',
                    style:
                        TextStyle(color: Colors.grey.shade300, fontSize: 14)),
                const SizedBox(height: 10),
                const Text('Save Your Recovery Phrase',
                    style:
                        TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                const SizedBox(height: 20),

                // Warning (white card with red accent)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.red.shade200),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.warning, color: Colors.red.shade700),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Text(
                          "Write this down and keep it safe. Don't share it with anyone, ever!",
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: Colors.black87,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Reveal/Copy
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    ElevatedButton.icon(
                      onPressed: () => setState(
                          () => _isPhraseRevealed = !_isPhraseRevealed),
                      icon: Icon(
                        _isPhraseRevealed
                            ? Icons.visibility_off
                            : Icons.visibility,
                        color: Colors.black87,
                      ),
                      label: Text(
                        _isPhraseRevealed ? 'Hide' : 'Reveal Phrase',
                        style: const TextStyle(color: Colors.black87),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: Colors.black87,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        elevation: 2,
                      ),
                    ),
                    if (_isPhraseRevealed)
                      TextButton.icon(
                        onPressed: _copyToClipboard,
                        icon: const Icon(Icons.copy, color: Colors.white),
                        label: const Text("Copy",
                            style: TextStyle(color: Colors.white)),
                      ),
                  ],
                ),
                const SizedBox(height: 16),

                // Phrase Display (white card when revealed)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color:
                        Colors.white.withOpacity(_isPhraseRevealed ? 1 : 0.06),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: _isPhraseRevealed ? Colors.white : Colors.white24,
                    ),
                  ),
                  child: _isPhraseRevealed
                      ? Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: phrases.asMap().entries.map((entry) {
                            return Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: Colors.black12),
                              ),
                              child: Text(
                                '${entry.key + 1}. ${entry.value}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: Colors.black87,
                                ),
                              ),
                            );
                          }).toList(),
                        )
                      : SizedBox(
                          height: 100,
                          child: Center(
                            child: Text(
                              'Tap "Reveal Phrase" to show your recovery phrase',
                              style: TextStyle(color: Colors.grey.shade300),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                ),

                const Spacer(),

                // Continue
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isPhraseRevealed && !_isLoading
                        ? _handleContinue
                        : null,
                    style: _whiteButtonStyle(kBg).copyWith(
                      backgroundColor: MaterialStateProperty.resolveWith((s) {
                        if (s.contains(MaterialState.disabled)) {
                          return Colors.white.withOpacity(0.5);
                        }
                        return Colors.white;
                      }),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor:
                                  AlwaysStoppedAnimation<Color>(Colors.black87),
                            ),
                          )
                        : const Text('Complete Setup'),
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
