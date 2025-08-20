import 'package:flutter/material.dart';

class TechSupportScreen extends StatefulWidget {
  const TechSupportScreen({super.key});

  @override
  State<TechSupportScreen> createState() => _TechSupportScreenState();
}

class _TechSupportScreenState extends State<TechSupportScreen> {
  bool stakingBeta = false;

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
          _SettingCard(
            leadingIcon: Icons.chat_bubble_outline,
            title: 'Open Ticket',
            subtitle: 'Report an issue',
            onTap: () {
              // TODO: navigate to ticket screen
            },
          ),
          const SizedBox(height: 12),
          _SettingCard(
            leadingIcon: Icons.receipt_long_outlined,
            title: 'Terms of Use',
            subtitle: 'Access the terms of use',
            onTap: () {
              // TODO: open terms
            },
          ),
          const SizedBox(height: 12),
          _SettingCard(
            leadingIcon: Icons.privacy_tip_outlined,
            title: 'Privacy Policy',
            subtitle: 'Access the Privacy Policy',
            onTap: () {
              // TODO: open privacy
            },
          ),
          const SizedBox(height: 12),
          _SettingCard(
            leadingIcon: Icons.info_outline,
            title: 'About',
            subtitle: 'Access the terms of use',
            onTap: () {
              // TODO: open about
            },
          ),
          const SizedBox(height: 24),
          const _SectionHeader('User Experience'),
          const SizedBox(height: 8),
          _SettingCard(
            leadingIcon: Icons.favorite_outline,
            title: 'Feature Suggestion',
            subtitle: 'Help us to improve Klever Wallet',
            onTap: () {
              // TODO: feature suggestion flow
            },
          ),
          const SizedBox(height: 12),
          _SettingCard(
            leadingIcon: Icons.wb_sunny_outlined,
            title: 'Enable staking beta',
            subtitle: '',
            trailing: Switch.adaptive(
              value: stakingBeta,
              activeColor: Colors.white,
              activeTrackColor: const Color(0xFF5660FF),
              onChanged: (val) => setState(() => stakingBeta = val),
            ),
          ),
          const SizedBox(height: 24),
          const _SectionHeader('Community'),
          const SizedBox(height: 8),
          _SettingCard(
            leadingIcon: Icons.camera_alt_outlined,
            title: 'Instagram',
            subtitle: '',
            onTap: () {
              // TODO: launch instagram link
            },
          ),
          const SizedBox(height: 12),
          _SettingCard(
            leadingIcon: Icons.play_circle_outline,
            title: 'YouTube',
            subtitle: '',
            onTap: () {
              // TODO: launch youtube link
            },
          ),
          const SizedBox(height: 12),
          _SettingCard(
            leadingIcon: Icons.work_outline,
            title: 'LinkedIn',
            subtitle: '',
            onTap: () {
              // TODO: launch linkedin link
            },
          ),
          const SizedBox(height: 12),
          _SettingCard(
            leadingIcon: Icons.facebook_outlined,
            title: 'Facebook',
            subtitle: '',
            onTap: () {
              // TODO: launch facebook link
            },
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
