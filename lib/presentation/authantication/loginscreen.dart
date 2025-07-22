import 'package:flutter/material.dart';
import 'package:bip39/bip39.dart' as bip39;
import 'package:flutter/services.dart';

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
          duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
    }
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
  final TextEditingController _password = TextEditingController();
  final TextEditingController _confirm = TextEditingController();

  bool _useBiometrics = false;
  bool _checkbox = false;
  bool _showPassword = false;
  bool _showConfirm = false;

  void _handleContinue() {
    if (_password.text != _confirm.text) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Passwords do not match.")),
      );
      return;
    }

    if (!_checkbox) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please acknowledge the warning.")),
      );
      return;
    }

    widget.onNext();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 20),
              const Text('Step 1 of 3', style: TextStyle(color: Colors.grey)),
              const SizedBox(height: 10),
              const Text('Crypto Wallet password',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
              const Text(
                'Unlocks Crypto Wallet on this device only.',
                style: TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 20),
              const Text('Create new password'),
              TextField(
                controller: _password,
                obscureText: !_showPassword,
                decoration: InputDecoration(
                  hintText: 'Enter password',
                  suffixIcon: IconButton(
                    icon: Icon(_showPassword
                        ? Icons.visibility_off
                        : Icons.visibility),
                    onPressed: () =>
                        setState(() => _showPassword = !_showPassword),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              const Text('Confirm password'),
              TextField(
                controller: _confirm,
                obscureText: !_showConfirm,
                decoration: InputDecoration(
                  hintText: 'Re-enter password',
                  suffixIcon: IconButton(
                    icon: Icon(_showConfirm
                        ? Icons.visibility_off
                        : Icons.visibility),
                    onPressed: () =>
                        setState(() => _showConfirm = !_showConfirm),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Checkbox(
                    value: _checkbox,
                    onChanged: (val) =>
                        setState(() => _checkbox = val ?? false),
                  ),
                  const Expanded(
                    child: Text(
                      'If I forget this password, Crypto Wallet can\'t recover it for me.',
                    ),
                  ),
                ],
              ),
              Row(
                children: [
                  const Text('Unlock with Face ID?'),
                  const Spacer(),
                  Switch(
                    value: _useBiometrics,
                    onChanged: (val) =>
                        setState(() => _useBiometrics = val),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _handleContinue,
                  style: ElevatedButton.styleFrom(
                      minimumSize: const Size.fromHeight(50)),
                  child: const Text('Create password'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Step 2: Security Education
class Step2SecureWalletScreen extends StatelessWidget {
  final VoidCallback onNext;

  const Step2SecureWalletScreen({super.key, required this.onNext});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 40),
          const Text('Step 2 of 3', style: TextStyle(color: Colors.grey)),
          const SizedBox(height: 10),
          const Text('Secure your wallet',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
          const SizedBox(height: 20),
          const Text(
              "Don't risk losing your funds. Protect your wallet by saving your Secret Recovery Phrase in a place you trust."),
          const Spacer(),
          ElevatedButton(
            onPressed: onNext,
            style: ElevatedButton.styleFrom(
                minimumSize: const Size.fromHeight(50)),
            child: const Text('Get started'),
          ),
          const SizedBox(height: 10),
          OutlinedButton(
            onPressed: () {},
            style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(50)),
            child: const Text('Remind me later'),
          ),
        ],
      ),
    );
  }
}

// Step 3: Display Recovery Phrase
class Step3RecoveryPhraseScreen extends StatefulWidget {
  const Step3RecoveryPhraseScreen({super.key});

  @override
  State<Step3RecoveryPhraseScreen> createState() =>
      _Step3RecoveryPhraseScreenState();
}

class _Step3RecoveryPhraseScreenState extends State<Step3RecoveryPhraseScreen> {
  late final String mnemonic;
  late final List<String> phrases;

  @override
  void initState() {
    super.initState();
    mnemonic = bip39.generateMnemonic();
    phrases = mnemonic.split(' ');
    print('🔐 Generated Mnemonic: $mnemonic');
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 40),
          const Text('Step 3 of 3', style: TextStyle(color: Colors.grey)),
          const SizedBox(height: 10),
          const Text(
            'Save your Secret Recovery Phrase',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 20),
          const Text(
            "This is your Secret Recovery Phrase. Write it down in the correct order and keep it safe.\nDon't share it with anyone, ever.",
          ),
          const SizedBox(height: 20),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: () {
                Clipboard.setData(ClipboardData(text: mnemonic));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Secret phrase copied to clipboard'),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              },
              icon: const Icon(Icons.copy),
              label: const Text("Copy"),
            ),
          ),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: phrases.asMap().entries.map((entry) {
              return Chip(label: Text('${entry.key + 1}. ${entry.value}'));
            }).toList(),
          ),
          const Spacer(),
          ElevatedButton(
            onPressed: () =>
                Navigator.pushNamed(context, '/main-wallet-dashboard'),
            style: ElevatedButton.styleFrom(
              minimumSize: const Size.fromHeight(50),
            ),
            child: const Text('Continue'),
          ),
        ],
      ),
    );
  }
}
