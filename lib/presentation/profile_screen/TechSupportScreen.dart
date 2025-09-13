import 'package:flutter/material.dart';
import 'package:flutter/services.dart'
    show rootBundle; // only used if you later load local terms/privacy text

class TechSupportScreen extends StatefulWidget {
  const TechSupportScreen({super.key});

  @override
  State<TechSupportScreen> createState() => _TechSupportScreenState();
}

class _TechSupportScreenState extends State<TechSupportScreen> {
  static const _bg = Color(0xFF0B0D1A);
  static const _card = Color(0xFF171B2B);
  static const _faint = Color(0xFFBFC5DA);

  void _comingSoon() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Open Ticket is coming soon'),
        behavior: SnackBarBehavior.floating,
        duration: Duration(seconds: 2),
      ),
    );
  }

  void _openTerms() {
    Navigator.of(context).push(
      MaterialPageRoute(
          builder: (_) => const _DocScreen(title: 'Terms of Use')),
    );
  }

  void _openPrivacy() {
    Navigator.of(context).push(
      MaterialPageRoute(
          builder: (_) => const _DocScreen(title: 'Privacy Policy')),
    );
  }

  void _openAbout() {
    showAboutDialog(
      context: context,
      applicationName: 'Vault Wallet',
      applicationVersion: '1.0.0',
      applicationLegalese: '© ${DateTime.now().year} Vault, Inc.',
      applicationIcon: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: _card,
          borderRadius: BorderRadius.circular(10),
        ),
        child: const Icon(Icons.account_balance_wallet, color: Colors.white),
      ),
      children: const [
        SizedBox(height: 12),
        Text(
          'Secure non-custodial wallet. This app is provided as-is without warranty.',
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _bg,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: const Text(
          'Tech & Support',
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          const _SectionHeader('Support'),
          const SizedBox(height: 8),

          // Open Ticket — intentionally skipped, shows "coming soon"
          _SettingCard(
            leadingIcon: Icons.chat_bubble_outline,
            title: 'Open Ticket',
            subtitle: 'Report an issue',
            onTap: _comingSoon,
          ),
          const SizedBox(height: 12),

          // Terms of Use
          _SettingCard(
            leadingIcon: Icons.receipt_long_outlined,
            title: 'Terms of Use',
            subtitle: 'Access the terms of use',
            onTap: _openTerms,
          ),
          const SizedBox(height: 12),

          // Privacy Policy
          _SettingCard(
            leadingIcon: Icons.privacy_tip_outlined,
            title: 'Privacy Policy',
            subtitle: 'Access the Privacy Policy',
            onTap: _openPrivacy,
          ),
          const SizedBox(height: 12),

          // About
          _SettingCard(
            leadingIcon: Icons.info_outline,
            title: 'About',
            subtitle: 'App information & licenses',
            onTap: _openAbout,
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.text, {super.key});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        color: _TechSupportScreenState._faint,
        fontWeight: FontWeight.w700,
        fontSize: 14,
        letterSpacing: 0.2,
      ),
    );
  }
}

class _SettingCard extends StatelessWidget {
  const _SettingCard({
    required this.leadingIcon,
    required this.title,
    required this.subtitle,
    this.trailing,
    this.onTap,
    super.key,
  });

  final IconData leadingIcon;
  final String title;
  final String subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: _TechSupportScreenState._card,
      borderRadius: BorderRadius.circular(6),
      child: InkWell(
        borderRadius: BorderRadius.circular(6),
        onTap: onTap,
        child: Container(
          height: 70,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Icon(leadingIcon,
                  color: _TechSupportScreenState._faint, size: 26),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 19,
                          fontWeight: FontWeight.w800,
                        )),
                    if (subtitle.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(subtitle,
                          style: const TextStyle(
                            color: _TechSupportScreenState._faint,
                            fontSize: 14,
                          )),
                    ]
                  ],
                ),
              ),
              const SizedBox(width: 8),
              trailing ??
                  const Icon(Icons.chevron_right,
                      color: _TechSupportScreenState._faint),
            ],
          ),
        ),
      ),
    );
  }
}

/// Simple in-app document screen used for Terms and Privacy.
/// Replace the placeholder text with your actual content, or load from assets.
class _DocScreen extends StatelessWidget {
  const _DocScreen({required this.title});
  final String title;

  static const _bg = Color(0xFF0B0D1A);
  static const _card = Color(0xFF171B2B);
  static const _faint = Color(0xFFBFC5DA);

  // If you want to pull from assets later:
  // Future<String> _loadAsset(String path) => rootBundle.loadString(path);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _bg,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      body: Container(
        margin: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: _card,
          borderRadius: BorderRadius.circular(10),
        ),
        child: const SingleChildScrollView(
          child: Text(
            // Replace this block with real Terms/Privacy content
            '''Last updated: 2025-01-01

This is placeholder content.
Add your real Terms of Use / Privacy Policy here.
You can also load a .md or .txt from assets using rootBundle.loadString().''',
            style: TextStyle(color: _faint, height: 1.4, fontSize: 14),
          ),
        ),
      ),
    );
  }
}
