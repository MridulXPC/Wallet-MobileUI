import 'package:cryptowallet/presentation/bottomnavbar.dart';
import 'package:cryptowallet/routes/app_routes.dart';
import 'package:flutter/material.dart';

class WalletInfoScreen extends StatelessWidget {
  const WalletInfoScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1D29),
       bottomNavigationBar: BottomNavBar(
      selectedIndex: 1,
      onTap: (index) {
        if (index == 1) return; // Stay on profile
        Navigator.pushReplacementNamed(
          context,
          index == 0
              ? AppRoutes.dashboardScreen
              : index == 1
                  ? AppRoutes.dashboardScreen// Use Wallet route if separate
                  : AppRoutes.swapScreen,
        );
      },
    ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            children: [
              // Header
              _buildHeader(),
              
              // Main Content
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _buildWalletIcon(),
                    const SizedBox(height: 32),
                    _buildWelcomeText(),
                    const SizedBox(height: 24),
                    _buildDescriptionText(),
                    const SizedBox(height: 48),
                    _buildCreateWalletButton(context),
                    const SizedBox(height: 16),
                    _buildImportWalletButton(),
                  ],
                ),
              ),
              
              // Footer
              _buildFooterText(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const Text(
          'Wallet',
          style: TextStyle(
            color: Colors.white,
            fontSize: 28,
            fontWeight: FontWeight.bold,
          ),
        ),
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: const Color(0xFF1F1F23),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(
            Icons.settings_outlined,
            color: Color(0xFF6B7280),
            size: 22,
          ),
        ),
      ],
    );
  }

  Widget _buildWalletIcon() {
    return Container(
      width: 120,
      height: 120,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color.fromARGB(255, 100, 162, 228), Color(0xFF1A73E8)],
        ),
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF6366F1).withOpacity(0.3),
            blurRadius: 30,
            offset: const Offset(0, 15),
          ),
        ],
      ),
      child: const Icon(
        Icons.account_balance_wallet_outlined,
        color: Colors.white,
        size: 50,
      ),
    );
  }

  Widget _buildWelcomeText() {
    return const Text(
      'Welcome to CryptoWallet',
      style: TextStyle(
        color: Colors.white,
        fontSize: 24,
        fontWeight: FontWeight.bold,
      ),
      textAlign: TextAlign.center,
    );
  }

  Widget _buildDescriptionText() {
    return const Text(
      'Start your crypto journey by creating\na secure wallet to store, send, and\nreceive digital assets.',
      style: TextStyle(
        color: Color(0xFF6B7280),
        fontSize: 16,
        height: 1.5,
      ),
      textAlign: TextAlign.center,
    );
  }

  Widget _buildCreateWalletButton(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: () {
          // Handle create wallet action
          _showCreateWalletDialog(context);
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ).copyWith(
          backgroundColor: MaterialStateProperty.all(Colors.transparent),
        ),
        child: Ink(
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [Color.fromARGB(255, 100, 162, 228), Color(0xFF1A73E8)],
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Container(
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: const Text(
              'Create New Wallet',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildImportWalletButton() {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton(
        onPressed: () {
          // Handle import wallet action
        },
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 16),
          side: const BorderSide(color: Color(0xFF2D2D32)),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: const Text(
          'Import Existing Wallet',
          style: TextStyle(
            color: Color(0xFF6B7280),
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _buildFooterText() {
    return const Text(
      'Your wallet is secured with advanced\nencryption and stored locally on your device',
      style: TextStyle(
        color: Color(0xFF4B5563),
        fontSize: 12,
        height: 1.4,
      ),
      textAlign: TextAlign.center,
    );
  }

  void _showCreateWalletDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: const Color(0xFF1F1F23),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Create Wallet',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'This will create a new wallet with a unique seed phrase. Make sure to write down your recovery phrase securely.',
                  style: TextStyle(
                    color: Color(0xFF6B7280),
                    fontSize: 14,
                    height: 1.4,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () {
                          Navigator.of(context).pop();
                        },
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Color(0xFF2D2D32)),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: const Text(
                          'Cancel',
                          style: TextStyle(color: Color(0xFF6B7280)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.of(context).pop();
                          // Navigate to wallet creation flow
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF6366F1),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: const Text(
                          'Continue',
                          style: TextStyle(color: Colors.white),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}