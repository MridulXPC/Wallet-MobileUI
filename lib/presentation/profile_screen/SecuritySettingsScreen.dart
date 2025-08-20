import 'package:flutter/material.dart';

class SecuritySettingsScreen extends StatefulWidget {
  const SecuritySettingsScreen({super.key});

  @override
  State<SecuritySettingsScreen> createState() => _SecuritySettingsScreenState();
}

class _SecuritySettingsScreenState extends State<SecuritySettingsScreen> {
  // mock state (wire these to your real settings)
  String _autoLock = '1 minute';
  bool _biometrics = false;

  // palette tuned to the screenshot
  static const _bg = Color(0xFF0B0D1A);
  static const _card = Color(0xFF171B2B);
  static const _faint = Color(0xFFBFC5DA);
  static const _danger = Color(0xFFED3B3B);

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
          'Security Settings',
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
          const _SectionHeader('General Security'),
          const SizedBox(height: 8),

          // Auto Lock
          _SettingCard(
            leadingIcon: Icons.lock_clock_outlined,
            title: 'Auto Lock',
            subtitle: 'Chose your auto lock timer',
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(_autoLock,
                    style: const TextStyle(color: _faint, fontSize: 14)),
                const SizedBox(width: 8),
                const Icon(Icons.chevron_right, color: _faint),
              ],
            ),
            onTap: () async {
              // TODO: present your time picker/bottom sheet
              // demo toggle:
              setState(() {
                _autoLock = _autoLock == '1 minute' ? '5 minutes' : '1 minute';
              });
            },
          ),
          const SizedBox(height: 12),

          // Biometrics switch
          _SettingCard(
            leadingIcon: Icons.fingerprint_outlined,
            title: 'Activate Biometrics',
            subtitle: 'Activate your biometrics',
            trailing: Switch.adaptive(
              value: _biometrics,
              activeColor: Colors.white,
              activeTrackColor: const Color(0xFF5660FF),
              onChanged: (v) => setState(() => _biometrics = v),
            ),
          ),

          const SizedBox(height: 24),
          const _SectionHeader('Security'),
          const SizedBox(height: 8),

          _SettingCard(
            leadingIcon: Icons.fact_check_outlined,
            title: 'Validate Seed',
            subtitle: 'Enhance your wallet security',
            onTap: () {
              // TODO: route to seed validation flow
            },
          ),
          const SizedBox(height: 12),

          _SettingCard(
            leadingIcon: Icons.backup_outlined,
            title: 'Backup Wallet',
            subtitle: 'Create an encrypted file',
            onTap: () {
              // TODO: route to backup flow
            },
          ),

          const SizedBox(height: 24),
          const _SectionHeader('Critical Actions'),
          const SizedBox(height: 8),

          _SettingCard(
            leadingIcon: Icons.remove_red_eye_outlined,
            title: 'Reveal seed phrase',
            subtitle: 'Reveal your seed phrase',
            onTap: () {
              // TODO: route with biometric/auth gate
            },
          ),
          const SizedBox(height: 12),

          _SettingCard(
            leadingIcon: Icons.key_outlined,
            title: 'Reveal private key',
            subtitle: 'Reveal your PK from any account',
            onTap: () {
              // TODO: route with biometric/auth gate
            },
          ),
          const SizedBox(height: 12),

          // Destructive action
          _SettingCard.danger(
            leadingIcon: Icons.cancel_outlined,
            title: 'Reset Wallet',
            subtitle: 'Reset wallet',
            onTap: () async {
              // TODO: confirm destructive action
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
        color: _SecuritySettingsScreenState._faint,
        fontWeight: FontWeight.w700,
        fontSize: 14,
        letterSpacing: 0.2,
      ),
    );
    // ignore: dead_code
  }
}

class _SettingCard extends StatelessWidget {
  const _SettingCard({
    required this.leadingIcon,
    required this.title,
    required this.subtitle,
    this.trailing,
    this.onTap,
    this.isDanger = false,
    super.key,
  });

  final IconData leadingIcon;
  final String title;
  final String subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool isDanger;

  factory _SettingCard.danger({
    required IconData leadingIcon,
    required String title,
    required String subtitle,
    VoidCallback? onTap,
  }) {
    return _SettingCard(
      leadingIcon: leadingIcon,
      title: title,
      subtitle: subtitle,
      onTap: onTap,
      isDanger: true,
    );
  }

  @override
  Widget build(BuildContext context) {
    final titleStyle = TextStyle(
      color: isDanger ? _SecuritySettingsScreenState._danger : Colors.white,
      fontSize: 19,
      fontWeight: FontWeight.w800,
    );
    final subtitleStyle = TextStyle(
      color: isDanger
          ? _SecuritySettingsScreenState._danger
          : _SecuritySettingsScreenState._faint,
      fontSize: 14,
    );

    return Material(
      color: _SecuritySettingsScreenState._card,
      borderRadius: BorderRadius.circular(6),
      child: InkWell(
        borderRadius: BorderRadius.circular(6),
        onTap: onTap,
        child: Container(
          height: 70,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Icon(
                leadingIcon,
                color: isDanger
                    ? _SecuritySettingsScreenState._danger
                    : _SecuritySettingsScreenState._faint,
                size: 26,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: titleStyle),
                    const SizedBox(height: 4),
                    Text(subtitle, style: subtitleStyle),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              trailing ??
                  const Icon(Icons.chevron_right,
                      color: _SecuritySettingsScreenState._faint),
            ],
          ),
        ),
      ),
    );
  }
}
