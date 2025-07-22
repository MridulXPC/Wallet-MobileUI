import 'package:cryptowallet/core/app_export.dart';
import 'package:flutter/material.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';

class WelcomeCarouselScreen extends StatefulWidget {
  static const String routeName = '/welcome-carousel';

  const WelcomeCarouselScreen({super.key});

  @override
  State<WelcomeCarouselScreen> createState() => _WelcomeCarouselScreenState();
}

class _WelcomeCarouselScreenState extends State<WelcomeCarouselScreen> {
  final PageController _pageController = PageController();
  int currentPage = 0;

  final List<Map<String, String>> slides = [
    {
      'image': 'assets/images/onboarding1.png',
      'title': 'Welcome to MetaWallet',
      'subtitle':
          'Trusted by millions, MetaWallet is a secure wallet making the world of web3 accessible to all.',
    },
    {
      'image': 'assets/images/onboarding2.png',
      'title': 'Control Your Assets',
      'subtitle':
          'Manage your digital identity, tokens and NFTs from one secure place.',
    },
    {
      'image': 'assets/images/onboarding3.png',
      'title': 'Your Keys, Your Wallet',
      'subtitle':
          'Only you have access to your funds. Take full control with self-custody.',
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor:
          AppTheme.darkTheme.scaffoldBackgroundColor, // light green background
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                itemCount: slides.length,
                onPageChanged: (index) {
                  setState(() => currentPage = index);
                },
                itemBuilder: (context, index) {
                  final slide = slides[index];
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24.0),
                    child: Column(
                      children: [
                        const SizedBox(height: 30),
                        Align(
                          alignment: Alignment.centerRight,
                          // child: Image.asset(
                          //   'assets/images/metamask_logo.png', // Update if needed
                          //   height: 32,
                          // ),
                        ),
                        const SizedBox(height: 20),
                        // Image.asset(
                        //   slide['image']!,
                        //   height: 350,
                        // ),
                        const SizedBox(height: 40),
                        // Text(
                        //   slide['title']!,
                        //   textAlign: TextAlign.center,
                        //   style: const TextStyle(
                        //     fontSize: 24,
                        //     fontWeight: FontWeight.bold,
                        //     color: Colors.black87,
                        //   ),
                        // ),
                        const SizedBox(height: 16),
                        // Text(
                        //   slide['subtitle']!,
                        //   textAlign: TextAlign.center,
                        //   style: const TextStyle(
                        //     fontSize: 16,
                        //     color: Colors.black54,
                        //   ),
                        // ),
                      ],
                    ),
                  );
                },
              ),
            ),

            // Smooth page indicator
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: SmoothPageIndicator(
                controller: _pageController,
                count: slides.length,
                effect: const WormEffect(
                  dotHeight: 8,
                  dotWidth: 8,
                  spacing: 8,
                  activeDotColor: Colors.white60,
                  dotColor: Colors.white60,
                ),
              ),
            ),

            // Get Started Button
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pushNamed(context, AppRoutes.walletsetup);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.tealAccent[700],
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Get started',
                    style: TextStyle(fontSize: 16, color: Colors.white),
                  ),
                ),
              ),
            )
          ],
        ),
      ),
    );
  }
}
