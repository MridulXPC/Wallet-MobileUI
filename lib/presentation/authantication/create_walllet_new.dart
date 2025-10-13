import 'package:cryptowallet/core/app_export.dart';
import 'package:cryptowallet/services/api_service.dart';
import 'package:flutter/material.dart';
import 'package:bip39/bip39.dart' as bip39;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

/// Root onboarding flow controller
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
    if (_currentPage < 3) {
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
          Step3RecoveryPhraseScreen(onNext: _nextPage),
          const Step4ConfirmRecoveryPhraseScreen(),
        ],
      ),
    );
  }
}

// ---------- Shared ----------
InputDecoration _whiteFieldDecoration({String? hint, Widget? suffixIcon}) {
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

// ---------- Step 1 ----------
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

  bool get _isPasswordValid {
    final p = _passwordController.text;
    return p.length >= 8 &&
        p.contains(RegExp(r'[A-Z]')) &&
        p.contains(RegExp(r'[a-z]')) &&
        p.contains(RegExp(r'[0-9]'));
  }

  bool get _isFormValid =>
      _passwordController.text == _confirmController.text &&
      _isPasswordValid &&
      _acceptedWarning;

  String? _validatePassword(String? v) {
    if (v == null || v.isEmpty) return 'Password required';
    if (v.length < 8) return 'Minimum 8 characters';
    if (!v.contains(RegExp(r'[A-Z]'))) return 'Add uppercase letter';
    if (!v.contains(RegExp(r'[a-z]'))) return 'Add lowercase letter';
    if (!v.contains(RegExp(r'[0-9]'))) return 'Add number';
    return null;
  }

  Future<void> _handleContinue() async {
    if (!_formKey.currentState!.validate()) return;
    if (!_acceptedWarning) {
      _snack('Please acknowledge the warning.');
      return;
    }

    setState(() => _isLoading = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      final sessionId = uuid.v4();
      await prefs.setString('wallet_password', _passwordController.text.trim());
      await prefs.setString('session_id', sessionId);

      await AuthService.registerSession(
        password: _passwordController.text.trim(),
        sessionId: sessionId,
      );
      if (mounted) widget.onNext();
    } catch (_) {
      _snack('Error creating password. Try again.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg), behavior: SnackBarBehavior.floating));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBg,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: DefaultTextStyle(
              style: const TextStyle(color: Colors.white),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 20),
                  Text('Step 1 of 4',
                      style:
                          TextStyle(color: Colors.grey.shade300, fontSize: 14)),
                  const SizedBox(height: 10),
                  const Text('Create Wallet Password',
                      style:
                          TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 30),
                  const Text('Create Password',
                      style: TextStyle(fontWeight: FontWeight.w500)),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _passwordController,
                    obscureText: !_showPassword,
                    validator: _validatePassword,
                    onChanged: (_) => setState(() {}),
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
                      style: TextStyle(fontWeight: FontWeight.w500)),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _confirmController,
                    obscureText: !_showConfirm,
                    validator: (v) => v != _passwordController.text
                        ? 'Passwords do not match'
                        : null,
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
                  Row(
                    children: [
                      Checkbox(
                        value: _acceptedWarning,
                        onChanged: (v) =>
                            setState(() => _acceptedWarning = v ?? false),
                        activeColor: Colors.white,
                        checkColor: Colors.black,
                        side: const BorderSide(color: Colors.white70),
                      ),
                      const Expanded(
                        child: Text(
                          'I understand that if I forget this password, it cannot be recovered.',
                          style: TextStyle(fontSize: 13, color: Colors.white70),
                        ),
                      )
                    ],
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed:
                        _isFormValid && !_isLoading ? _handleContinue : null,
                    style: _whiteButtonStyle(kBg),
                    child: _isLoading
                        ? const CircularProgressIndicator(color: Colors.black)
                        : const Text('Create Password'),
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

// ---------- Step 2 ----------
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
          padding: const EdgeInsets.all(20),
          child: DefaultTextStyle(
            style: const TextStyle(color: Colors.white),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 40),
                Text('Step 2 of 4',
                    style:
                        TextStyle(color: Colors.grey.shade300, fontSize: 14)),
                const SizedBox(height: 10),
                const Text('Secure Your Wallet',
                    style:
                        TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Column(
                    children: [
                      Icon(Icons.security, color: Colors.black87, size: 48),
                      SizedBox(height: 12),
                      Text(
                        "Don't risk losing your funds!",
                        style: TextStyle(
                          color: Colors.black,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        "Protect your wallet by saving your Secret Recovery Phrase securely. It’s the only way to restore your wallet.",
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.black54, fontSize: 14),
                      )
                    ],
                  ),
                ),
                const Spacer(),
                ElevatedButton(
                  onPressed: onNext,
                  style: _whiteButtonStyle(kBg),
                  child: const Text('Get Started'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ---------- Step 3 ----------
class Step3RecoveryPhraseScreen extends StatefulWidget {
  final VoidCallback onNext;
  const Step3RecoveryPhraseScreen({super.key, required this.onNext});

  @override
  State<Step3RecoveryPhraseScreen> createState() =>
      _Step3RecoveryPhraseScreenState();
}

class _Step3RecoveryPhraseScreenState extends State<Step3RecoveryPhraseScreen> {
  static const Color kBg = Color(0xFF0B0D1A);
  late final String mnemonic;
  late final List<String> phrases;
  bool _isPhraseRevealed = false;
  bool _isCreatingWallet = false;
  bool _apiFailed = false;

  @override
  void initState() {
    super.initState();
    mnemonic = bip39.generateMnemonic();
    phrases = mnemonic.split(' ');
    _saveMnemonic();
    _submitRecoveryPhraseToServer();
  }

  Future<void> _saveMnemonic() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('recovery_phrase', mnemonic);
  }

  Future<void> _submitRecoveryPhraseToServer() async {
    setState(() {
      _isCreatingWallet = true;
      _apiFailed = false;
    });
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('jwt_token');
      if (token == null || token.isEmpty) {
        debugPrint('❌ No jwt_token found');
        return;
      }

      final res = await AuthService.submitRecoveryPhrase(
        phrase: mnemonic,
        token: token,
      );

      if (res.success) {
        debugPrint('✅ Wallet created successfully');
        final walletId = res.data?['walletId'] ?? '';
        if (walletId.toString().isNotEmpty) {
          await prefs.setString('wallet_id', walletId.toString());
        }
      } else {
        _apiFailed = true;
        debugPrint('⚠️ submitRecoveryPhrase failed: ${res.message}');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(res.message ?? 'Failed to create wallet'),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    } catch (e) {
      _apiFailed = true;
      debugPrint('⚠️ API error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Failed to submit recovery phrase: $e'),
          behavior: SnackBarBehavior.floating,
        ));
      }
    } finally {
      if (mounted) setState(() => _isCreatingWallet = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: DefaultTextStyle(
            style: const TextStyle(color: Colors.white),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 40),
                Text('Step 3 of 4',
                    style:
                        TextStyle(color: Colors.grey.shade300, fontSize: 14)),
                const SizedBox(height: 10),
                const Text('Save Your Recovery Phrase',
                    style:
                        TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.redAccent),
                  ),
                  child: Row(
                    children: const [
                      Icon(Icons.warning, color: Colors.red),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          "Write this down and store it safely. Don’t share it with anyone!",
                          style: TextStyle(
                            color: Colors.black,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                if (_isCreatingWallet)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    ),
                  ),
                if (_apiFailed)
                  Center(
                    child: TextButton.icon(
                      onPressed: _submitRecoveryPhraseToServer,
                      icon: const Icon(Icons.refresh, color: Colors.white70),
                      label: const Text(
                        'Retry Wallet Creation',
                        style: TextStyle(color: Colors.white70),
                      ),
                    ),
                  ),
                if (!_isCreatingWallet) ...[
                  ElevatedButton.icon(
                    onPressed: () =>
                        setState(() => _isPhraseRevealed = !_isPhraseRevealed),
                    icon: Icon(
                      _isPhraseRevealed
                          ? Icons.visibility_off
                          : Icons.visibility,
                      color: Colors.black,
                    ),
                    label: Text(
                      _isPhraseRevealed ? 'Hide' : 'Reveal Phrase',
                      style: const TextStyle(color: Colors.black),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color:
                            _isPhraseRevealed ? Colors.white : Colors.white10,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.white30),
                      ),
                      child: _isPhraseRevealed
                          ? GridView.builder(
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: phrases.length,
                              gridDelegate:
                                  const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 3,
                                mainAxisSpacing: 8,
                                crossAxisSpacing: 8,
                                childAspectRatio: 2.8,
                              ),
                              itemBuilder: (context, i) {
                                return Container(
                                  decoration: BoxDecoration(
                                    color: Colors.grey[100],
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: Colors.black12),
                                  ),
                                  alignment: Alignment.center,
                                  child: Text(
                                    '${i + 1}. ${phrases[i]}',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                      color: Colors.black87,
                                    ),
                                  ),
                                );
                              },
                            )
                          : const Center(
                              child: Text(
                                'Tap "Reveal Phrase" to view your recovery phrase',
                                textAlign: TextAlign.center,
                                style: TextStyle(color: Colors.white70),
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: !_isCreatingWallet && _isPhraseRevealed
                        ? widget.onNext
                        : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: kBg,
                      minimumSize: const Size.fromHeight(50),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text('Continue'),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ---------- Step 4 ----------
class Step4ConfirmRecoveryPhraseScreen extends StatefulWidget {
  const Step4ConfirmRecoveryPhraseScreen({super.key});

  @override
  State<Step4ConfirmRecoveryPhraseScreen> createState() =>
      _Step4ConfirmRecoveryPhraseScreenState();
}

class _Step4ConfirmRecoveryPhraseScreenState
    extends State<Step4ConfirmRecoveryPhraseScreen> {
  static const Color kBg = Color(0xFF0B0D1A);
  final List<TextEditingController> _controllers =
      List.generate(12, (_) => TextEditingController());
  final List<FocusNode> _focusNodes = List.generate(12, (_) => FocusNode());
  bool _isLoading = false;

  @override
  void dispose() {
    for (final c in _controllers) c.dispose();
    for (final f in _focusNodes) f.dispose();
    super.dispose();
  }

  Future<void> _handleContinue() async {
    setState(() => _isLoading = true);
    final prefs = await SharedPreferences.getInstance();
    final saved = (prefs.getString('recovery_phrase') ?? '').trim();
    final entered = _controllers.map((c) => c.text.trim()).join(' ').trim();

    if (entered == saved && entered.isNotEmpty) {
      await prefs.setBool('is_first_launch', false);
      if (mounted) {
        Navigator.pushReplacementNamed(context, AppRoutes.dashboardScreen);
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Incorrect recovery phrase. Please check all words.'),
        behavior: SnackBarBehavior.floating,
      ));
    }
    if (mounted) setState(() => _isLoading = false);
  }

  void _showSkipSheet() {
    bool agree = false;
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E2235),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setSheet) {
            return Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 40,
                    height: 5,
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  const Icon(Icons.warning,
                      color: Colors.orangeAccent, size: 40),
                  const SizedBox(height: 12),
                  const Text(
                    'Skip Account Security?',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    "If you lose this secret phrase, you won’t be able to access this wallet.",
                    style: TextStyle(color: Colors.white70),
                    textAlign: TextAlign.center,
                  ),
                  Row(
                    children: [
                      Checkbox(
                        value: agree,
                        onChanged: (v) => setSheet(() => agree = v ?? false),
                        activeColor: Colors.tealAccent[700],
                        checkColor: Colors.black,
                      ),
                      const Expanded(
                        child: Text(
                          'I understand this risk',
                          style: TextStyle(color: Colors.white70),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(context),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Colors.white24),
                            foregroundColor: Colors.white70,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                          child: const Text('Secure Now'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: agree
                              ? () {
                                  Navigator.pop(context);
                                  Navigator.pushReplacementNamed(
                                      context, AppRoutes.dashboardScreen);
                                }
                              : null,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: agree
                                ? Colors.tealAccent[700]
                                : Colors.grey[700],
                            foregroundColor: Colors.black,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                          child: const Text('Skip'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildPhraseField(int index) {
    return TextField(
      controller: _controllers[index],
      focusNode: _focusNodes[index],
      textAlign: TextAlign.center,
      style: const TextStyle(color: Colors.white, fontSize: 14),
      textInputAction:
          index == 11 ? TextInputAction.done : TextInputAction.next,
      onChanged: (value) {
        // Auto advance on space
        if (value.endsWith(' ') && index < 11) {
          _focusNodes[index + 1].requestFocus();
          _controllers[index].text = value.trim();
          _controllers[index].selection = TextSelection.fromPosition(
            TextPosition(offset: _controllers[index].text.length),
          );
        }
      },
      decoration: InputDecoration(
        // hintText: '${index + 1}',
        hintStyle: const TextStyle(color: Colors.white30),
        filled: true,
        fillColor: Colors.white.withOpacity(0.08),
        contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Colors.white24),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Colors.tealAccent),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: DefaultTextStyle(
            style: const TextStyle(color: Colors.white),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 40),
                Text('Step 4 of 4',
                    style:
                        TextStyle(color: Colors.grey.shade300, fontSize: 14)),
                const SizedBox(height: 10),
                const Text(
                  'Confirm Your Recovery Phrase',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Enter each word of your 12-word recovery phrase below to confirm.',
                  style: TextStyle(color: Colors.white70, fontSize: 14),
                ),
                const SizedBox(height: 24),
                Expanded(
                  child: GridView.builder(
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: 12,
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      crossAxisSpacing: 10,
                      mainAxisSpacing: 12,
                      childAspectRatio: 2.8,
                    ),
                    itemBuilder: (context, i) => _buildPhraseField(i),
                  ),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: !_isLoading ? _handleContinue : null,
                  style: _whiteButtonStyle(kBg),
                  child: _isLoading
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.black,
                          ),
                        )
                      : const Text('Confirm & Continue'),
                ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: _showSkipSheet,
                  child: const Text(
                    'Remind Me Later',
                    style: TextStyle(color: Colors.white54),
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
