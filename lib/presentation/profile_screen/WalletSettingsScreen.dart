import 'package:flutter/material.dart';

class WalletSettingsScreen extends StatelessWidget {
  const WalletSettingsScreen({super.key});

  // palette tuned to screenshot
  static const _bg = Color(0xFF0B0D1A);
  static const _card = Color(0xFF171B2B);
  static const _faint = Color(0xFFBFC5DA);

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
          'Wallet Settings',
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: const [
          _SectionHeader('General Wallet'),
          SizedBox(height: 8),
          _SettingCard(
            leadingIcon: Icons.contact_page_outlined,
            title: 'Address Book',
            subtitle: 'Manage your addresses and contacts',
          ),
          SizedBox(height: 18),
          _SectionHeader('DeFi'),
          SizedBox(height: 8),
          _SettingCard(
            leadingIcon: Icons.waves_outlined, // walletconnect-ish glyph
            title: 'WalletConnect',
            subtitle: 'WalletConnect settings',
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        color: WalletSettingsScreen._faint,
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
    this.onTap,
  });

  final IconData leadingIcon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: WalletSettingsScreen._card,
      borderRadius: BorderRadius.circular(6),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          height: 70, // matches the tall rounded tiles in the screenshot
          padding: const EdgeInsets.symmetric(horizontal: 6),
          child: Row(
            children: [
              Icon(leadingIcon, color: WalletSettingsScreen._faint, size: 26),
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
                    const SizedBox(height: 4),
                    Text(subtitle,
                        style: const TextStyle(
                          color: WalletSettingsScreen._faint,
                          fontSize: 14,
                        )),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right,
                  color: WalletSettingsScreen._faint),
            ],
          ),
        ),
      ),
    );
  }
}
