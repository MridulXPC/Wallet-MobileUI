import 'package:cryptowallet/routes/app_routes.dart';
import 'package:flutter/material.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppLockScreen extends StatefulWidget {
  const AppLockScreen({super.key});

  @override
  State<AppLockScreen> createState() => _AppLockScreenState();
}

class _AppLockScreenState extends State<AppLockScreen>
    with SingleTickerProviderStateMixin {
  static const Color kBg = Color(0xFF0B0D1A);

  final TextEditingController _passwordController = TextEditingController();
  bool _showPassword = false;
  String? _storedPassword;
  bool _useBiometrics = false;
  bool _isVerifying = false;

  final LocalAuthentication _auth = LocalAuthentication();

  late AnimationController _animController;
  late Animation<Offset> _shakeAnimation;

  @override
  void initState() {
    super.initState();
    _loadStoredData();

    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );

    _shakeAnimation = Tween<Offset>(
      begin: Offset.zero,
      end: const Offset(0.04, 0.0),
    ).chain(CurveTween(curve: Curves.elasticIn)).animate(_animController);
  }

  @override
  void dispose() {
    _passwordController.dispose();
    _animController.dispose();
    super.dispose();
  }

  Future<void> _loadStoredData() async {
    final prefs = await SharedPreferences.getInstance();
    final savedPassword = prefs.getString('wallet_password');
    final useBiometric = prefs.getBool('use_biometrics') ?? false;

    if (!mounted) return;

    if (savedPassword == null || savedPassword.isEmpty) {
      Navigator.pushReplacementNamed(context, AppRoutes.welcomeScreen);
      return;
    }

    setState(() {
      _storedPassword = savedPassword;
      _useBiometrics = useBiometric;
    });

    // If biometrics is enabled, prompt automatically
    if (useBiometric) {
      Future.delayed(const Duration(milliseconds: 600), _authenticateBiometric);
    }
  }

  /// 🔐 Authenticate via Biometrics
  Future<void> _authenticateBiometric() async {
    try {
      final canCheck = await _auth.canCheckBiometrics;
      final isSupported = await _auth.isDeviceSupported();

      if (!canCheck || !isSupported) return;

      final didAuthenticate = await _auth.authenticate(
        localizedReason: 'Unlock your wallet',
        options: const AuthenticationOptions(
          biometricOnly: true,
          stickyAuth: true,
          useErrorDialogs: true,
        ),
      );

      if (didAuthenticate && mounted) {
        _showSnack('✅ Wallet unlocked via biometrics');
        Navigator.pushReplacementNamed(context, AppRoutes.dashboardScreen);
      }
    } catch (e) {
      debugPrint('⚠️ Biometric auth error: $e');
    }
  }

  Future<void> _verifyPassword() async {
    if (_storedPassword == null) return;

    final input = _passwordController.text.trim();
    if (input.isEmpty) {
      _showSnack('Please enter your password');
      return;
    }

    setState(() => _isVerifying = true);
    await Future.delayed(const Duration(milliseconds: 250));

    if (input == _storedPassword) {
      _showSnack('✅ Wallet unlocked successfully');
      if (!mounted) return;
      Navigator.pushReplacementNamed(context, AppRoutes.dashboardScreen);
    } else {
      _animController.forward(from: 0);
      _showSnack('Incorrect password');
    }

    setState(() => _isVerifying = false);
  }

  void _showSnack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), behavior: SnackBarBehavior.floating),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_storedPassword == null) {
      return const Scaffold(
        backgroundColor: kBg,
        body: Center(
          child: CircularProgressIndicator(color: Colors.white),
        ),
      );
    }

    return Scaffold(
      backgroundColor: kBg,
      appBar: AppBar(
        backgroundColor: kBg,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text('App Lock'),
        actions: [
          if (_useBiometrics)
            IconButton(
              icon: const Icon(Icons.fingerprint, color: Colors.white70),
              onPressed: _authenticateBiometric,
            ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: SlideTransition(
              position: _shakeAnimation,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // 🖼️ App Logo at top
                  Image.asset(
                    'assets/Zayralogopng.png',
                    height: 100,
                    width: 100,
                    fit: BoxFit.contain,
                  ),
                  const SizedBox(height: 24),

                  const Text(
                    "Enter your wallet password",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Password input
                  TextField(
                    controller: _passwordController,
                    obscureText: !_showPassword,
                    cursorColor: kBg,
                    style: const TextStyle(color: Colors.black87),
                    enabled: !_isVerifying,
                    decoration: InputDecoration(
                      labelText: 'Password',
                      labelStyle: TextStyle(color: Colors.grey.shade700),
                      filled: true,
                      fillColor: Colors.white,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 14),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
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
                  const SizedBox(height: 24),

                  // Unlock button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isVerifying ? null : _verifyPassword,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: kBg,
                        minimumSize: const Size.fromHeight(48),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 2,
                      ),
                      child: _isVerifying
                          ? const SizedBox(
                              height: 22,
                              width: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.black,
                              ),
                            )
                          : const Text('Unlock Wallet',
                              style: TextStyle(fontWeight: FontWeight.w600)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (_useBiometrics)
                    TextButton.icon(
                      onPressed: _authenticateBiometric,
                      icon:
                          const Icon(Icons.fingerprint, color: Colors.white54),
                      label: const Text(
                        'Use Biometrics',
                        style: TextStyle(color: Colors.white54),
                      ),
                    ),
                  TextButton(
                    onPressed: () => _showSnack(
                        "If you forgot your password, restore using your recovery phrase."),
                    child: const Text(
                      'Forgot password?',
                      style: TextStyle(color: Colors.white54),
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
