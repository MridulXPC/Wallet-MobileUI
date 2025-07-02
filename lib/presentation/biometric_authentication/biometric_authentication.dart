import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sizer/sizer.dart';

import '../../core/app_export.dart';

class BiometricAuthentication extends StatefulWidget {
  const BiometricAuthentication({super.key});

  @override
  State<BiometricAuthentication> createState() =>
      _BiometricAuthenticationState();
}

class _BiometricAuthenticationState extends State<BiometricAuthentication>
    with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late AnimationController _loadingController;
  late Animation<double> _pulseAnimation;
  late Animation<double> _rotationAnimation;

  bool _isLoading = false;
  bool _showError = false;
  String _errorMessage = '';
  int _failedAttempts = 0;
  bool _isCooldownActive = false;
  int _cooldownSeconds = 30;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
  }

  void _initializeAnimations() {
    _pulseController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );

    _loadingController = AnimationController(
      duration: const Duration(seconds: 1),
      vsync: this,
    );

    _pulseAnimation = Tween<double>(
      begin: 1.0,
      end: 1.1,
    ).animate(CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    ));

    _rotationAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _loadingController,
      curve: Curves.linear,
    ));

    _pulseController.repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _loadingController.dispose();
    super.dispose();
  }

  void _startBiometricAuthentication() async {
    if (_isCooldownActive) return;

    setState(() {
      _isLoading = true;
      _showError = false;
    });

    _loadingController.repeat();
    HapticFeedback.lightImpact();

    // Simulate biometric authentication process
    await Future.delayed(const Duration(seconds: 2));

    // Simulate random success/failure for demo
    final bool isSuccess = DateTime.now().millisecond % 3 != 0;

    if (isSuccess) {
      _handleAuthenticationSuccess();
    } else {
      _handleAuthenticationFailure();
    }
  }

  void _handleAuthenticationSuccess() {
    _loadingController.stop();
    HapticFeedback.heavyImpact();

    setState(() {
      _isLoading = false;
      _showError = false;
      _failedAttempts = 0;
    });

    // Navigate to main wallet dashboard
    Navigator.pushReplacementNamed(context, '/main-wallet-dashboard');
  }

  void _handleAuthenticationFailure() {
    _loadingController.stop();
    HapticFeedback.heavyImpact();

    setState(() {
      _isLoading = false;
      _failedAttempts++;
      _showError = true;
      _errorMessage = 'Authentication failed. Please try again.';
    });

    if (_failedAttempts >= 3) {
      _startCooldown();
    }
  }

  void _startCooldown() {
    setState(() {
      _isCooldownActive = true;
      _cooldownSeconds = 30;
      _errorMessage =
          'Too many failed attempts. Please wait $_cooldownSeconds seconds.';
    });

    _runCooldownTimer();
  }

  void _runCooldownTimer() {
    Future.delayed(const Duration(seconds: 1), () {
      if (_isCooldownActive && _cooldownSeconds > 0) {
        setState(() {
          _cooldownSeconds--;
          _errorMessage =
              'Too many failed attempts. Please wait $_cooldownSeconds seconds.';
        });
        _runCooldownTimer();
      } else if (_cooldownSeconds <= 0) {
        setState(() {
          _isCooldownActive = false;
          _failedAttempts = 0;
          _showError = false;
        });
      }
    });
  }

  void _usePasscode() {
    // Navigate to passcode entry (placeholder for now)
    Navigator.pushNamed(context, '/splash-screen');
  }

  void _forgotPasscode() {
    // Navigate to account recovery (placeholder for now)
    Navigator.pushNamed(context, '/splash-screen');
  }

  void _exitApp() {
    SystemNavigator.pop();
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        _exitApp();
        return false;
      },
      child: Scaffold(
        backgroundColor: AppTheme.background,
        body: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                AppTheme.background,
                AppTheme.background.withValues(alpha: 0.8),
                AppTheme.secondary.withValues(alpha: 0.3),
              ],
            ),
          ),
          child: SafeArea(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 4.h),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Spacer(flex: 2),
                  _buildHeader(),
                  SizedBox(height: 6.h),
                  _buildBiometricPromptArea(),
                  SizedBox(height: 4.h),
                  _buildErrorMessage(),
                  SizedBox(height: 4.h),
                  _buildAlternativeOptions(),
                  const Spacer(flex: 3),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      children: [
        Text(
          'Unlock Your Wallet',
          style: AppTheme.darkTheme.textTheme.headlineMedium?.copyWith(
            color: AppTheme.textHighEmphasis,
            fontWeight: FontWeight.w600,
          ),
          textAlign: TextAlign.center,
        ),
        SizedBox(height: 2.h),
        Text(
          'Use your biometric authentication to securely access your cryptocurrency wallet',
          style: AppTheme.darkTheme.textTheme.bodyLarge?.copyWith(
            color: AppTheme.textMediumEmphasis,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildBiometricPromptArea() {
    return GestureDetector(
      onTap: _startBiometricAuthentication,
      child: Container(
        width: 40.w,
        height: 40.w,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: AppTheme.surface,
          border: Border.all(
            color: _isCooldownActive
                ? AppTheme.textDisabled
                : AppTheme.primary.withValues(alpha: 0.3),
            width: 2,
          ),
          boxShadow: [
            BoxShadow(
              color: AppTheme.primary.withValues(alpha: 0.1),
              blurRadius: 20,
              spreadRadius: 5,
            ),
          ],
        ),
        child: _isLoading ? _buildLoadingIcon() : _buildBiometricIcon(),
      ),
    );
  }

  Widget _buildBiometricIcon() {
    return AnimatedBuilder(
      animation: _pulseAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: _isCooldownActive ? 1.0 : _pulseAnimation.value,
          child: Center(
            child: CustomIconWidget(
              iconName: 'fingerprint',
              color:
                  _isCooldownActive ? AppTheme.textDisabled : AppTheme.primary,
              size: 15.w,
            ),
          ),
        );
      },
    );
  }

  Widget _buildLoadingIcon() {
    return AnimatedBuilder(
      animation: _rotationAnimation,
      builder: (context, child) {
        return Transform.rotate(
          angle: _rotationAnimation.value * 2 * 3.14159,
          child: Center(
            child: CustomIconWidget(
              iconName: 'lock',
              color: AppTheme.primary,
              size: 15.w,
            ),
          ),
        );
      },
    );
  }

  Widget _buildErrorMessage() {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      height: _showError ? null : 0,
      child: _showError
          ? Container(
              padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 2.h),
              decoration: BoxDecoration(
                color: AppTheme.error.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppTheme.error.withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                children: [
                  CustomIconWidget(
                    iconName: 'error_outline',
                    color: AppTheme.error,
                    size: 5.w,
                  ),
                  SizedBox(width: 3.w),
                  Expanded(
                    child: Text(
                      _errorMessage,
                      style: AppTheme.darkTheme.textTheme.bodyMedium?.copyWith(
                        color: AppTheme.error,
                      ),
                    ),
                  ),
                ],
              ),
            )
          : const SizedBox.shrink(),
    );
  }

  Widget _buildAlternativeOptions() {
    return Column(
      children: [
        TextButton(
          onPressed: _isCooldownActive ? null : _usePasscode,
          style: TextButton.styleFrom(
            padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 2.h),
          ),
          child: Text(
            'Use Passcode',
            style: AppTheme.darkTheme.textTheme.bodyLarge?.copyWith(
              color:
                  _isCooldownActive ? AppTheme.textDisabled : AppTheme.primary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        SizedBox(height: 2.h),
        TextButton(
          onPressed: _forgotPasscode,
          style: TextButton.styleFrom(
            padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 1.h),
          ),
          child: Text(
            'Forgot Passcode?',
            style: AppTheme.darkTheme.textTheme.bodyMedium?.copyWith(
              color: AppTheme.textMediumEmphasis,
              decoration: TextDecoration.underline,
            ),
          ),
        ),
      ],
    );
  }
}
