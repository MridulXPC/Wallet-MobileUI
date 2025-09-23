import 'dart:ui' show FontFeature;
import 'package:cryptowallet/core/currency_notifier.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

// NEW: listen & broadcast app-wide currency
import 'package:provider/provider.dart';

class GeneralSettingsScreen extends StatefulWidget {
  const GeneralSettingsScreen({super.key});

  @override
  State<GeneralSettingsScreen> createState() => _GeneralSettingsScreenState();
}

class _GeneralSettingsScreenState extends State<GeneralSettingsScreen> {
  // persisted state
  String _language = 'en-US';
  String _currency = 'USD';
  bool _hidePortfolioBanner = false;

  // notifications (local persisted toggles)
  bool _notifTx = true;
  bool _notifPrice = true;
  bool _notifMarketing = false;

  // theme
  ThemeMode _themeMode = ThemeMode.system;

  // palette tuned to screenshot
  static const _bg = Color(0xFF0B0D1A);
  static const _faint = Color(0xFFBFC5DA);

  // prefs keys
  static const _kLang = 'pref_language';
  static const _kCurr = 'pref_currency';
  static const _kHideBanner = 'pref_hide_portfolio_banner';
  static const _kTheme = 'pref_theme_mode';
  static const _kNtx = 'pref_notif_tx';
  static const _kNprice = 'pref_notif_price';
  static const _kNmk = 'pref_notif_marketing';

  @override
  void initState() {
    super.initState();
    _loadPrefs();
  }

  Future<void> _loadPrefs() async {
    final sp = await SharedPreferences.getInstance();
    setState(() {
      _language = sp.getString(_kLang) ?? _language;
      _currency = sp.getString(_kCurr) ?? _currency;
      _hidePortfolioBanner = sp.getBool(_kHideBanner) ?? _hidePortfolioBanner;
      _notifTx = sp.getBool(_kNtx) ?? _notifTx;
      _notifPrice = sp.getBool(_kNprice) ?? _notifPrice;
      _notifMarketing = sp.getBool(_kNmk) ?? _notifMarketing;

      final savedTheme = sp.getString(_kTheme);
      _themeMode = switch (savedTheme) {
        'light' => ThemeMode.light,
        'dark' => ThemeMode.dark,
        'system' || _ => ThemeMode.system,
      };
    });
  }

  Future<void> _saveString(String key, String value) async {
    final sp = await SharedPreferences.getInstance();
    await sp.setString(key, value);
  }

  Future<void> _saveBool(String key, bool value) async {
    final sp = await SharedPreferences.getInstance();
    await sp.setBool(key, value);
  }

  Future<void> _saveTheme(ThemeMode mode) async {
    final sp = await SharedPreferences.getInstance();
    await sp.setString(
      _kTheme,
      switch (mode) {
        ThemeMode.light => 'light',
        ThemeMode.dark => 'dark',
        ThemeMode.system => 'system',
      },
    );
  }

  // pickers ------------------------------------------------------------------

  Future<void> _pickLanguage() async {
    const langs = <(String code, String label)>[
      ('en-US', 'English (US)'),
      ('en-GB', 'English (UK)'),
      ('es-ES', 'Español (ES)'),
      ('es-419', 'Español (LATAM)'),
      ('fr-FR', 'Français'),
      ('de-DE', 'Deutsch'),
      ('pt-BR', 'Português (BR)'),
      ('hi-IN', 'हिन्दी'),
      ('zh-CN', '简体中文'),
      ('ja-JP', '日本語'),
    ];
    final picked = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _PickerSheet(
        title: 'Select Language',
        options: langs
            .map((e) => PickerItem(value: e.$1, title: e.$2))
            .toList(growable: false),
        selectedValue: _language,
      ),
    );
    if (picked != null && picked != _language) {
      setState(() => _language = picked);
      _saveString(_kLang, picked);
      _snack('Language set to ${langs.firstWhere((e) => e.$1 == picked).$2}');
    }
  }

  Future<void> _pickCurrency() async {
    const fx = <(String code, String label)>[
      ('USD', 'US Dollar'),
      ('EUR', 'Euro'),
      ('GBP', 'British Pound'),
      ('JPY', 'Japanese Yen'),
      ('CNY', 'Chinese Yuan'),
      ('INR', 'Indian Rupee'),
      ('BRL', 'Brazilian Real'),
      ('AUD', 'Australian Dollar'),
      ('CAD', 'Canadian Dollar'),
      ('NGN', 'Nigerian Naira'),
    ];
    final picked = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _PickerSheet(
        title: 'Select Currency',
        options: fx
            .map((e) => PickerItem(value: e.$1, title: '${e.$1} — ${e.$2}'))
            .toList(),
        selectedValue: _currency,
      ),
    );
    if (picked != null && picked != _currency) {
      setState(() => _currency = picked); // local echo
      await _saveString(_kCurr, picked); // persist
      if (mounted) {
        // 🔔 broadcast globally so the whole app rebuilds where needed
        context.read<CurrencyNotifier>().setCurrency(picked);
      }
      _snack('Currency set to $picked');
    }
  }

  Future<void> _pickTheme() async {
    final picked = await showModalBottomSheet<ThemeMode>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _ThemeSheet(current: _themeMode),
    );
    if (picked != null && picked != _themeMode) {
      setState(() => _themeMode = picked);
      await _saveTheme(picked);
      _snack(
        'Theme set to ${switch (picked) {
          ThemeMode.light => 'Light',
          ThemeMode.dark => 'Dark',
          _ => 'System'
        }}',
      );
      // If your app uses a ThemeMode provider globally, you can broadcast here too.
    }
  }

  Future<void> _openNotifications() async {
    final updated = await showModalBottomSheet<_NotifState>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _NotificationsSheet(
        initial: _NotifState(
          tx: _notifTx,
          price: _notifPrice,
          marketing: _notifMarketing,
        ),
      ),
    );

    if (updated != null) {
      setState(() {
        _notifTx = updated.tx;
        _notifPrice = updated.price;
        _notifMarketing = updated.marketing;
      });
      _saveBool(_kNtx, _notifTx);
      _saveBool(_kNprice, _notifPrice);
      _saveBool(_kNmk, _notifMarketing);
      _snack('Notification preferences saved');
    }
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // 👇 Live currency from the global notifier (auto-updates without hot reload)
    final liveCurrency =
        context.select<CurrencyNotifier, String>((fx) => fx.code);

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

          const SizedBox(height: 12),

          // Currency
          _SettingTile.card(
            leading: Icons.attach_money_rounded,
            title: 'Currency',
            subtitle: 'Change your currency',
            // Show the live code from CurrencyNotifier (not just local _currency)
            trailingValue: liveCurrency,
            onTap: _pickCurrency,
          ),
          const SizedBox(height: 12),

          // Push Notifications
          _SettingTile.card(
            leading: Icons.notifications_none_rounded,
            title: 'Push Notifications',
            subtitle: 'Manage your push notifications',
            onTap: _openNotifications,
          ),
          const SizedBox(height: 12),

          // Theme (Beta pill)
          _SettingTile.card(
            leading: Icons.palette_outlined,
            title: 'Theme',
            subtitle: 'Change app appearance',
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
            onTap: _pickTheme,
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

// ==================== Bottom Sheets ====================

class PickerItem {
  final String value;
  final String title;
  const PickerItem({required this.value, required this.title});
}

class _PickerSheet extends StatelessWidget {
  const _PickerSheet({
    required this.title,
    required this.options,
    required this.selectedValue,
  });

  final String title;
  final List<PickerItem> options;
  final String selectedValue;

  static const _bgGrad = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomRight,
    stops: [0.0, 0.55, 1.0],
    colors: [
      Color.fromARGB(255, 6, 11, 33),
      Color.fromARGB(255, 0, 0, 0),
      Color.fromARGB(255, 0, 12, 56),
    ],
  );

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      child: Container(
        decoration: const BoxDecoration(gradient: _bgGrad),
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFF171B2B),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Row(
                children: [
                  Text(title,
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 16)),
                ],
              ),
              const SizedBox(height: 8),
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: options.length,
                  separatorBuilder: (_, __) =>
                      const Divider(color: Colors.white12, height: 1),
                  itemBuilder: (context, i) {
                    final it = options[i];
                    final selected = it.value == selectedValue;
                    return ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      title: Text(it.title,
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight:
                                selected ? FontWeight.w700 : FontWeight.w500,
                          )),
                      trailing: selected
                          ? const Icon(Icons.check_circle,
                              color: Colors.lightBlueAccent)
                          : null,
                      onTap: () => Navigator.pop(context, it.value),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ThemeSheet extends StatelessWidget {
  const _ThemeSheet({required this.current});
  final ThemeMode current;

  static const _bgGrad = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomRight,
    stops: [0.0, 0.55, 1.0],
    colors: [
      Color.fromARGB(255, 6, 11, 33),
      Color.fromARGB(255, 0, 0, 0),
      Color.fromARGB(255, 0, 12, 56),
    ],
  );

  @override
  Widget build(BuildContext context) {
    ThemeMode? picked = current;
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      child: Container(
        decoration: const BoxDecoration(gradient: _bgGrad),
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
        child: SafeArea(
          top: false,
          child: StatefulBuilder(builder: (context, setModal) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF171B2B),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const Row(
                  children: [
                    Text('Theme',
                        style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 16)),
                  ],
                ),
                const SizedBox(height: 8),
                RadioListTile<ThemeMode>(
                  value: ThemeMode.system,
                  groupValue: picked,
                  onChanged: (v) => setModal(() => picked = v),
                  title: const Text('System',
                      style: TextStyle(color: Colors.white)),
                  activeColor: Colors.lightBlueAccent,
                ),
                RadioListTile<ThemeMode>(
                  value: ThemeMode.light,
                  groupValue: picked,
                  onChanged: (v) => setModal(() => picked = v),
                  title: const Text('Light',
                      style: TextStyle(color: Colors.white)),
                  activeColor: Colors.lightBlueAccent,
                ),
                RadioListTile<ThemeMode>(
                  value: ThemeMode.dark,
                  groupValue: picked,
                  onChanged: (v) => setModal(() => picked = v),
                  title:
                      const Text('Dark', style: TextStyle(color: Colors.white)),
                  activeColor: Colors.lightBlueAccent,
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  height: 44,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0E57FF),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      elevation: 0,
                    ),
                    onPressed: () => Navigator.pop(context, picked),
                    child: const Text('Apply',
                        style: TextStyle(
                            color: Colors.white, fontWeight: FontWeight.w700)),
                  ),
                ),
              ],
            );
          }),
        ),
      ),
    );
  }
}

class _NotifState {
  final bool tx;
  final bool price;
  final bool marketing;
  _NotifState({required this.tx, required this.price, required this.marketing});

  _NotifState copyWith({bool? tx, bool? price, bool? marketing}) => _NotifState(
        tx: tx ?? this.tx,
        price: price ?? this.price,
        marketing: marketing ?? this.marketing,
      );
}

class _NotificationsSheet extends StatefulWidget {
  const _NotificationsSheet({required this.initial});
  final _NotifState initial;

  @override
  State<_NotificationsSheet> createState() => _NotificationsSheetState();
}

class _NotificationsSheetState extends State<_NotificationsSheet> {
  late _NotifState state;

  static const _bgGrad = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomRight,
    stops: [0.0, 0.55, 1.0],
    colors: [
      Color.fromARGB(255, 6, 11, 33),
      Color.fromARGB(255, 0, 0, 0),
      Color.fromARGB(255, 0, 12, 56),
    ],
  );

  @override
  void initState() {
    super.initState();
    state = widget.initial;
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      child: Container(
        decoration: const BoxDecoration(gradient: _bgGrad),
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFF171B2B),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const Row(
                children: [
                  Text('Push Notifications',
                      style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 16)),
                ],
              ),
              const SizedBox(height: 8),
              _notifTile(
                title: 'Transaction updates',
                subtitle: 'Incoming/outgoing confirmations & statuses',
                value: state.tx,
                onChanged: (v) => setState(() => state = state.copyWith(tx: v)),
              ),
              _notifTile(
                title: 'Price alerts',
                subtitle: 'Important market moves for your favorites',
                value: state.price,
                onChanged: (v) =>
                    setState(() => state = state.copyWith(price: v)),
              ),
              _notifTile(
                title: 'News & tips',
                subtitle: 'Occasional product updates and tips',
                value: state.marketing,
                onChanged: (v) =>
                    setState(() => state = state.copyWith(marketing: v)),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                height: 44,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0E57FF),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    elevation: 0,
                  ),
                  onPressed: () => Navigator.pop(context, state),
                  child: const Text('Save',
                      style: TextStyle(
                          color: Colors.white, fontWeight: FontWeight.w700)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _notifTile({
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF171B2B),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF3A3D4A)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        color: Colors.white, fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(subtitle,
                    style: const TextStyle(
                        color: Color(0xFFBFC5DA), fontSize: 12)),
              ],
            ),
          ),
          Switch.adaptive(
            value: value,
            activeColor: Colors.white,
            activeTrackColor: const Color(0xFF5660FF),
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}
