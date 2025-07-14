import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _initializeApp();
  }

  void _initializeAnimations() {
    // Logo animation controller
    _logoAnimationController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    // Loading animation controller
    _loadingAnimationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    // Logo scale animation
    _logoScaleAnimation = Tween<double>(
      begin: 0.8,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _logoAnimationController,
      curve: Curves.elasticOut,
    ));

    // Logo fade animation
    _logoFadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _logoAnimationController,
      curve: const Interval(0.0, 0.6, curve: Curves.easeIn),
    ));

    // Loading fade animation
    _loadingFadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _loadingAnimationController,
      curve: Curves.easeIn,
    ));

    // Start animations
    _logoAnimationController.forward();
    Future.delayed(const Duration(milliseconds: 800), () {
      if (mounted) {
        _loadingAnimationController.forward();
      }
    });
  }

  Future<void> _initializeApp() async {
    try {
      // Simulate app initialization tasks
      await Future.wait([
        _checkWalletAuthentication(),
        _loadEncryptedKeys(),
        _fetchCryptoPrices(),
        _prepareCachedData(),
      ]);

      // Add minimum splash duration
      await Future.delayed(const Duration(milliseconds: 2500));

      if (mounted) {
        _navigateToNextScreen();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isInitializing = false;
          _showRetryOption = true;
        });

        // Auto retry after 5 seconds
        Future.delayed(const Duration(seconds: 5), () {
          if (mounted && _showRetryOption) {
            _retryInitialization();
          }
        });
      }
    }
  }

  Future<void> _checkWalletAuthentication() async {
    // Simulate checking wallet authentication
    await Future.delayed(const Duration(milliseconds: 500));
  }

  Future<void> _loadEncryptedKeys() async {
    // Simulate loading encrypted keys from secure storage
    await Future.delayed(const Duration(milliseconds: 300));
  }

  Future<void> _fetchCryptoPrices() async {
    // Simulate fetching real-time crypto prices
    await Future.delayed(const Duration(milliseconds: 800));
  }

  Future<void> _prepareCachedData() async {
    // Simulate preparing cached portfolio data
    await Future.delayed(const Duration(milliseconds: 400));
  }

void _navigateToNextScreen() {
  HapticFeedback.lightImpact();

  WidgetsBinding.instance.addPostFrameCallback((_) {
    debugPrint('✅ Navigating to welcome screen...');
    Navigator.of(context).pushReplacementNamed(AppRoutes.welcomeScreen);
  });
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
        value: SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.light,
          statusBarBrightness: Brightness.dark,
          systemNavigationBarColor: AppTheme.background,
          systemNavigationBarIconBrightness: Brightness.light,
        ),
        child: SafeArea(
          child: SizedBox(
            width: double.infinity,
            height: double.infinity,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Spacer to push content to center
                const Spacer(flex: 2),

                // Animated Logo Section
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

                // Loading Section
                AnimatedBuilder(
                  animation: _loadingAnimationController,
                  builder: (context, child) {
                    return Opacity(
                      opacity: _loadingFadeAnimation.value,
                      child: _buildLoadingSection(),
                    );
                  },
                ),

                // Spacer to maintain center alignment
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
            color: AppTheme.primary.withValues(alpha: 0.3),
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
    if (_showRetryOption) {
      return _buildRetrySection();
    }

    return Column(
      children: [
        // Loading indicator
        SizedBox(
          width: 6.w,
          height: 6.w,
          child: CircularProgressIndicator(
            strokeWidth: 2.5,
            valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primary),
            backgroundColor: AppTheme.primary.withValues(alpha: 0.2),
          ),
        ),

        SizedBox(height: 3.h),

        // Loading text
        Text(
          'Initializing Wallet...',
          style: AppTheme.darkTheme.textTheme.bodyMedium?.copyWith(
            color: AppTheme.textMediumEmphasis,
            fontSize: 3.5.w,
          ),
        ),

        SizedBox(height: 1.h),

        // Status text
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
        // Error icon
        Container(
          width: 12.w,
          height: 12.w,
          decoration: BoxDecoration(
            color: AppTheme.error.withValues(alpha: 0.1),
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

        // Error message
        Text(
          'Connection Failed',
          style: AppTheme.darkTheme.textTheme.titleMedium?.copyWith(
            color: AppTheme.textHighEmphasis,
            fontSize: 4.w,
          ),
        ),

        SizedBox(height: 1.h),

        Text(
          'Unable to connect to crypto services',
          style: AppTheme.darkTheme.textTheme.bodySmall?.copyWith(
            color: AppTheme.textMediumEmphasis,
            fontSize: 3.w,
          ),
          textAlign: TextAlign.center,
        ),

        SizedBox(height: 4.h),

        // Retry button
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

    // Simulate different loading states
    final loadingStates = [
      'Checking authentication...',
      'Loading wallet keys...',
      'Fetching crypto prices...',
      'Preparing portfolio...',
    ];

    // Return a random loading state for demo
    return loadingStates[DateTime.now().millisecond % loadingStates.length];
  }
}
