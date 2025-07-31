import 'package:cryptowallet/core/app_export.dart';
import 'package:cryptowallet/services/auth_service.dart';
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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

// Step 1: Create Password
class Step1PasswordScreen extends StatefulWidget {
  final VoidCallback onNext;

  const Step1PasswordScreen({super.key, required this.onNext});

  @override
  State<Step1PasswordScreen> createState() => _Step1PasswordScreenState();
}

class _Step1PasswordScreenState extends State<Step1PasswordScreen> {
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
           password.contains(RegExp(r'[A-Z]')) && // Uppercase
           password.contains(RegExp(r'[a-z]')) && // Lowercase
           password.contains(RegExp(r'[0-9]'));   // Number
  }

  bool get _isFormValid {
    return _passwordController.text.isNotEmpty &&
           _confirmController.text.isNotEmpty &&
           _passwordController.text == _confirmController.text &&
           _isPasswordValid &&
           _acceptedWarning;
  }

  String? _validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Password is required';
    }
    if (value.length < 8) {
      return 'Password must be at least 8 characters';
    }
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
    if (value == null || value.isEmpty) {
      return 'Please confirm your password';
    }
    if (value != _passwordController.text) {
      return 'Passwords do not match';
    }
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

      // Save to local storage
      await Future.wait([
        prefs.setString('wallet_password', password),
        prefs.setBool('use_biometrics', _useBiometrics),
        prefs.setString('session_id', sessionId),
      ]);

      debugPrint("✅ Password saved");
      debugPrint("🧾 Session ID: $sessionId");
      debugPrint(_useBiometrics ? '🔓 Biometrics ON' : '🔒 Biometrics OFF');

      // Register session with API
      await AuthService.registerSession(
        password: password,
        sessionId: sessionId,
      );

      if (mounted) {
        widget.onNext();
      }
    } catch (e) {
      debugPrint("❌ Error: $e");
      if (mounted) {
        _showSnackBar("Failed to create password. Please try again.");
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showSnackBar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 20),
                
                // Header
                const Text(
                  'Step 1 of 3',
                  style: TextStyle(color: Colors.grey, fontSize: 14),
                ),
                const SizedBox(height: 10),
                const Text(
                  'Create Wallet Password',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
                const Text(
                  'This password unlocks your wallet on this device only.',
                  style: TextStyle(color: Colors.grey, fontSize: 16),
                ),
                const SizedBox(height: 30),

                // Password Field
                const Text('Create Password', style: TextStyle(fontWeight: FontWeight.w500)),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _passwordController,
                  obscureText: !_showPassword,
                  validator: _validatePassword,
                  onChanged: (_) => setState(() {}), // Update button state
                  decoration: InputDecoration(
                    hintText: 'Enter password',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    suffixIcon: IconButton(
                      icon: Icon(_showPassword ? Icons.visibility_off : Icons.visibility),
                      onPressed: () => setState(() => _showPassword = !_showPassword),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Confirm Password Field
                const Text('Confirm Password', style: TextStyle(fontWeight: FontWeight.w500)),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _confirmController,
                  obscureText: !_showConfirm,
                  validator: _validateConfirmPassword,
                  onChanged: (_) => setState(() {}), // Update button state
                  decoration: InputDecoration(
                    hintText: 'Re-enter password',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    suffixIcon: IconButton(
                      icon: Icon(_showConfirm ? Icons.visibility_off : Icons.visibility),
                      onPressed: () => setState(() => _showConfirm = !_showConfirm),
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // Password Requirements
                if (_passwordController.text.isNotEmpty) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Password must contain:', style: TextStyle(fontWeight: FontWeight.w500)),
                        const SizedBox(height: 8),
                        _buildRequirement('At least 8 characters', _passwordController.text.length >= 8),
                        _buildRequirement('One uppercase letter', _passwordController.text.contains(RegExp(r'[A-Z]'))),
                        _buildRequirement('One lowercase letter', _passwordController.text.contains(RegExp(r'[a-z]'))),
                        _buildRequirement('One number', _passwordController.text.contains(RegExp(r'[0-9]'))),
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
                      onChanged: (val) => setState(() => _acceptedWarning = val ?? false),
                    ),
                    const Expanded(
                      child: Text(
                        'I understand that if I forget this password, Crypto Wallet cannot recover it for me.',
                        style: TextStyle(fontSize: 14),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Biometrics Switch
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Unlock with Face ID / Biometrics', 
                                 style: TextStyle(fontWeight: FontWeight.w500)),
                            Text('Use biometrics for quick access', 
                                 style: TextStyle(color: Colors.grey, fontSize: 12)),
                          ],
                        ),
                      ),
                      Switch(
                        value: _useBiometrics,
                        onChanged: (val) => setState(() => _useBiometrics = val),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 30),

                // Create Button
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _isFormValid && !_isLoading ? _handleContinue : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _isFormValid ? Theme.of(context).primaryColor : Colors.grey,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : const Text(
                            'Create Password',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
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

  Widget _buildRequirement(String text, bool isValid) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Icon(
            isValid ? Icons.check_circle : Icons.radio_button_unchecked,
            size: 16,
            color: isValid ? Colors.green : Colors.grey,
          ),
          const SizedBox(width: 8),
          Text(
            text,
            style: TextStyle(
              fontSize: 12,
              color: isValid ? Colors.green : Colors.grey,
            ),
          ),
        ],
      ),
    );
  }
}

// Step 2: Security Education (Optimized)
class Step2SecureWalletScreen extends StatelessWidget {
  final VoidCallback onNext;

  const Step2SecureWalletScreen({super.key, required this.onNext});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 40),
              const Text(
                'Step 2 of 3',
                style: TextStyle(color: Colors.grey, fontSize: 14),
              ),
              const SizedBox(height: 10),
              const Text(
                'Secure Your Wallet',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 20),
              
              // Security Info
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: const Column(
                  children: [
                    Icon(Icons.security, size: 48, color: Colors.blue),
                    SizedBox(height: 16),
                    Text(
                      "Don't risk losing your funds!",
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(height: 8),
                    Text(
                      "Protect your wallet by saving your Secret Recovery Phrase in a secure place you trust. This is the only way to recover your wallet.",
                      style: TextStyle(fontSize: 14, color: Colors.grey),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
              
              const Spacer(),
              
              // Buttons
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: onNext,
                  child: const Text('Get Started'),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: OutlinedButton(
                  onPressed: () {
                    // Handle remind me later
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Please secure your wallet now for safety')),
                    );
                  },
                  child: const Text('Remind Me Later'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Step 3: Recovery Phrase (Optimized)
class Step3RecoveryPhraseScreen extends StatefulWidget {
  const Step3RecoveryPhraseScreen({super.key});

  @override
  State<Step3RecoveryPhraseScreen> createState() => _Step3RecoveryPhraseScreenState();
}

class _Step3RecoveryPhraseScreenState extends State<Step3RecoveryPhraseScreen> {
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
      _showSnackBar(result.message ?? '❌ Failed to submit recovery phrase. Please try again.');
    }
  } catch (e) {
    debugPrint('❌ Error: $e');
    _showSnackBar('❌ An error occurred. Please try again.');
  } finally {
    if (mounted) {
      setState(() => _isLoading = false);
    }
  }
}
  void _showSnackBar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
      );
    }
  }

  void _copyToClipboard() {
    Clipboard.setData(ClipboardData(text: mnemonic));
    _showSnackBar('✅ Recovery phrase copied to clipboard');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 40),
              const Text(
                'Step 3 of 3',
                style: TextStyle(color: Colors.grey, fontSize: 14),
              ),
              const SizedBox(height: 10),
              const Text(
                'Save Your Recovery Phrase',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 20),
              
              // Warning
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.red.shade200),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.warning, color: Colors.red),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        "Write this down and keep it safe. Don't share it with anyone, ever!",
                        style: TextStyle(fontWeight: FontWeight.w500),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Reveal/Copy Button
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  ElevatedButton.icon(
                    onPressed: () => setState(() => _isPhraseRevealed = !_isPhraseRevealed),
                    icon: Icon(_isPhraseRevealed ? Icons.visibility_off : Icons.visibility),
                    label: Text(_isPhraseRevealed ? 'Hide' : 'Reveal Phrase'),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.grey.shade200),
                  ),
                  if (_isPhraseRevealed)
                    TextButton.icon(
                      onPressed: _copyToClipboard,
                      icon: const Icon(Icons.copy),
                      label: const Text("Copy"),
                    ),
                ],
              ),
              const SizedBox(height: 16),

              // Recovery Phrase Display
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: _isPhraseRevealed
                    ? Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: phrases.asMap().entries.map((entry) {
                          return Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: Colors.blue.shade50,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: Colors.blue.shade200),
                            ),
                            child: Text(
                              '${entry.key + 1}. ${entry.value}',
                              style: const TextStyle(fontWeight: FontWeight.w500),
                            ),
                          );
                        }).toList(),
                      )
                    : const SizedBox(
                        height: 100,
                        child: Center(
                          child: Text(
                            'Tap "Reveal Phrase" to show your recovery phrase',
                            style: TextStyle(color: Colors.grey),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
              ),
              
              const Spacer(),
              
              // Continue Button
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _isPhraseRevealed && !_isLoading ? _handleContinue : null,
                  child: _isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : const Text('Complete Setup'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}