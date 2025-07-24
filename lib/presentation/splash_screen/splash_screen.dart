import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sizer/sizer.dart';

import '../../core/app_export.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late AnimationController _logoAnimationController;
  late AnimationController _loadingAnimationController;
  late Animation<double> _logoScaleAnimation;
  late Animation<double> _logoFadeAnimation;
  late Animation<double> _loadingFadeAnimation;

  bool _showRetryOption = false;
  bool _isInitializing = true;

  final LocalAuthentication _auth = LocalAuthentication();

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _initializeApp();
  }

  void _initializeAnimations() {
    _logoAnimationController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    _loadingAnimationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _logoScaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(
        parent: _logoAnimationController,
        curve: Curves.elasticOut,
      ),
    );

    _logoFadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _logoAnimationController,
        curve: const Interval(0.0, 0.6, curve: Curves.easeIn),
      ),
    );

    _loadingFadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _loadingAnimationController,
        curve: Curves.easeIn,
      ),
    );

    _logoAnimationController.forward();
    Future.delayed(const Duration(milliseconds: 800), () {
      if (mounted) _loadingAnimationController.forward();
    });
  }

  Future<void> _initializeApp() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('jwt_token');

      if (token != null && token.isNotEmpty) {
        debugPrint("🔐 Token found. Attempting biometric auth...");
        final bool isAuthenticated = await _authenticateUser();

        if (isAuthenticated) {
          debugPrint("✅ Biometric success → Dashboard");
          _navigateToDashboard();
        } else {
          debugPrint("❌ Biometric failed → Welcome");
          _navigateToWelcome();
        }
      } else {
        debugPrint("🛑 No token found → Welcome");
        _navigateToWelcome();
      }
    } catch (e) {
      debugPrint("🚨 Error in splash init: $e");
      setState(() {
        _isInitializing = false;
        _showRetryOption = true;
      });
    }
  }

  Future<bool> _authenticateUser() async {
    try {
      final canCheck = await _auth.canCheckBiometrics;
      final isSupported = await _auth.isDeviceSupported();

      if (canCheck && isSupported) {
        return await _auth.authenticate(
          localizedReason: 'Authenticate to access your wallet',
          options: const AuthenticationOptions(
            biometricOnly: true,
            stickyAuth: true,
          ),
        );
      }
    } catch (e) {
      debugPrint("🚨 Biometric error: $e");
    }
    return false;
  }

  void _navigateToDashboard() {
    Navigator.of(context).pushReplacementNamed(AppRoutes.dashboardScreen);
  }

  void _navigateToWelcome() {
    Navigator.of(context).pushReplacementNamed(AppRoutes.welcomeScreen);
  }

  void _retryInitialization() {
    setState(() {
      _showRetryOption = false;
      _isInitializing = true;
    });
    _initializeApp();
  }

  @override
  void dispose() {
    _logoAnimationController.dispose();
    _loadingAnimationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: AnnotatedRegion<SystemUiOverlayStyle>(
        value: const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.light,
          statusBarBrightness: Brightness.dark,
          systemNavigationBarColor: Colors.black,
          systemNavigationBarIconBrightness: Brightness.light,
        ),
        child: SafeArea(
          child: SizedBox(
            width: double.infinity,
            height: double.infinity,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Spacer(flex: 2),
                AnimatedBuilder(
                  animation: _logoAnimationController,
                  builder: (context, child) {
                    return Transform.scale(
                      scale: _logoScaleAnimation.value,
                      child: Opacity(
                        opacity: _logoFadeAnimation.value,
                        child: _buildLogo(),
                      ),
                    );
                  },
                ),
                SizedBox(height: 8.h),
                AnimatedBuilder(
                  animation: _loadingAnimationController,
                  builder: (context, child) {
                    return Opacity(
                      opacity: _loadingFadeAnimation.value,
                      child: _buildLoadingSection(),
                    );
                  },
                ),
                const Spacer(flex: 3),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLogo() {
    return Container(
      width: 25.w,
      height: 25.w,
      decoration: BoxDecoration(
        color: AppTheme.primary,
        borderRadius: BorderRadius.circular(6.w),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primary.withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CustomIconWidget(
              iconName: 'account_balance_wallet',
              color: AppTheme.onPrimary,
              size: 8.w,
            ),
            SizedBox(height: 1.h),
            Text(
              'CW',
              style: AppTheme.darkTheme.textTheme.titleLarge?.copyWith(
                color: AppTheme.onPrimary,
                fontWeight: FontWeight.bold,
                fontSize: 4.w,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingSection() {
    if (_showRetryOption) return _buildRetrySection();

    return Column(
      children: [
        SizedBox(
          width: 6.w,
          height: 6.w,
          child: CircularProgressIndicator(
            strokeWidth: 2.5,
            valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primary),
            backgroundColor: AppTheme.primary.withOpacity(0.2),
          ),
        ),
        SizedBox(height: 3.h),
        Text(
          'Initializing Wallet...',
          style: AppTheme.darkTheme.textTheme.bodyMedium?.copyWith(
            color: AppTheme.textMediumEmphasis,
            fontSize: 3.5.w,
          ),
        ),
        SizedBox(height: 1.h),
        Text(
          _getLoadingStatusText(),
          style: AppTheme.darkTheme.textTheme.bodySmall?.copyWith(
            color: AppTheme.textDisabled,
            fontSize: 3.w,
          ),
        ),
      ],
    );
  }

  Widget _buildRetrySection() {
    return Column(
      children: [
        Container(
          width: 12.w,
          height: 12.w,
          decoration: BoxDecoration(
            color: AppTheme.error.withOpacity(0.1),
            borderRadius: BorderRadius.circular(6.w),
          ),
          child: Center(
            child: CustomIconWidget(
              iconName: 'error_outline',
              color: AppTheme.error,
              size: 6.w,
            ),
          ),
        ),
        SizedBox(height: 3.h),
        Text(
          'Connection Failed',
          style: AppTheme.darkTheme.textTheme.titleMedium?.copyWith(
            color: AppTheme.textHighEmphasis,
            fontSize: 4.w,
          ),
        ),
        SizedBox(height: 1.h),
        Text(
          'Unable to initialize app',
          style: AppTheme.darkTheme.textTheme.bodySmall?.copyWith(
            color: AppTheme.textMediumEmphasis,
            fontSize: 3.w,
          ),
          textAlign: TextAlign.center,
        ),
        SizedBox(height: 4.h),
        ElevatedButton(
          onPressed: _retryInitialization,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.primary,
            foregroundColor: AppTheme.onPrimary,
            padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 2.h),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(3.w),
            ),
          ),
          child: Text(
            'Retry',
            style: AppTheme.darkTheme.textTheme.labelLarge?.copyWith(
              color: AppTheme.onPrimary,
              fontSize: 3.5.w,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  String _getLoadingStatusText() {
    if (!_isInitializing) return '';
    final states = [
      'Checking authentication...',
      'Loading wallet keys...',
      'Fetching crypto prices...',
      'Preparing portfolio...',
    ];
    return states[DateTime.now().millisecond % states.length];
  }
}
