import 'package:flutter/material.dart';

class GeneralSettingsScreen extends StatefulWidget {
  const GeneralSettingsScreen({super.key});

  @override
  State<GeneralSettingsScreen> createState() => _GeneralSettingsScreenState();
}

class _GeneralSettingsScreenState extends State<GeneralSettingsScreen> {
  // fake state
  String _language = 'en-us';
  String _currency = 'USD';
  bool _hidePortfolioBanner = false;

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
          'General Settings',
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
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8.0),
            child: Text(
              'App Preferences',
              style: TextStyle(
                color: _faint,
                fontWeight: FontWeight.w700,
                fontSize: 14,
                letterSpacing: 0.2,
              ),
            ),
          ),

          // Language
          _SettingTile.card(
            leading: Icons.translate_rounded,
            title: 'Language',
            subtitle: 'Change your app language',
            trailingValue: _language,
            onTap: () async {
              // TODO: open selector
            },
          ),
          const SizedBox(height: 12),

          // Currency
          _SettingTile.card(
            leading: Icons.attach_money_rounded,
            title: 'Currency',
            subtitle: 'Change your currency',
            trailingValue: _currency,
            onTap: () async {
              // TODO: open selector
            },
          ),
          const SizedBox(height: 12),

          // Hide portfolio banner (switch)
          _SettingTile.card(
            leading: Icons.style_rounded,
            title: 'Hide portfolio banner',
            subtitle: 'Hide all banners in the app',
            trailing: Switch.adaptive(
              value: _hidePortfolioBanner,
              activeColor: Colors.white,
              activeTrackColor: const Color(0xFF5660FF),
              onChanged: (v) => setState(() => _hidePortfolioBanner = v),
            ),
          ),
          const SizedBox(height: 12),

          // Push Notifications
          _SettingTile.card(
            leading: Icons.notifications_none_rounded,
            title: 'Push Notifications',
            subtitle: 'Manage your push notifications',
            onTap: () {
              // TODO: route to notifications
            },
          ),
          const SizedBox(height: 12),

          // Theme (Beta pill)
          _SettingTile.card(
            leading: Icons.palette_outlined,
            title: 'Theme',
            subtitle: 'Change app appearence',
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0E57FF),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.science_rounded,
                          size: 14, color: Colors.white),
                      SizedBox(width: 4),
                      Text('Beta',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w700)),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                const Icon(Icons.chevron_right, color: _faint),
              ],
            ),
            onTap: () {
              // TODO: open theme settings
            },
          ),
        ],
      ),
    );
  }
}

class _SettingTile extends StatelessWidget {
  const _SettingTile._({
    required this.leadingIcon,
    required this.title,
    required this.subtitle,
    this.trailing,
    this.trailingValue,
    this.onTap,
  });

  final IconData leadingIcon;
  final String title;
  final String subtitle;
  final Widget? trailing;
  final String? trailingValue;
  final VoidCallback? onTap;

  // factory for the rounded “card” style tile
  factory _SettingTile.card({
    required IconData leading,
    required String title,
    required String subtitle,
    VoidCallback? onTap,
    Widget? trailing,
    String? trailingValue,
  }) {
    return _SettingTile._(
      leadingIcon: leading,
      title: title,
      subtitle: subtitle,
      trailing: trailing,
      trailingValue: trailingValue,
      onTap: onTap,
    );
  }

  static const _card = Color(0xFF171B2B);
  static const _faint = Color(0xFFBFC5DA);

  @override
  Widget build(BuildContext context) {
    return Material(
      color: _card,
      borderRadius: BorderRadius.circular(6),
      child: InkWell(
        borderRadius: BorderRadius.circular(6),
        onTap: onTap,
        child: Container(
          height: 70,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Icon(leadingIcon, color: _faint, size: 24),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w800)),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: const TextStyle(color: _faint, fontSize: 14),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              // trailing priority: custom trailing widget -> value + chevron -> chevron
              if (trailing != null)
                trailing!
              else if (trailingValue != null)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      trailingValue!,
                      style: const TextStyle(
                          color: _faint,
                          fontSize: 14,
                          fontFeatures: [FontFeature.tabularFigures()]),
                    ),
                    const SizedBox(width: 8),
                    const Icon(Icons.chevron_right, color: _faint),
                  ],
                )
              else
                const Icon(Icons.chevron_right, color: _faint),
            ],
          ),
        ),
      ),
    );
  }
}
