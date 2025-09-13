import 'dart:ui' show FontFeature;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cryptowallet/services/api_service.dart';

class SecuritySettingsScreen extends StatefulWidget {
  const SecuritySettingsScreen({super.key});

  @override
  State<SecuritySettingsScreen> createState() => _SecuritySettingsScreenState();
}

class _SecuritySettingsScreenState extends State<SecuritySettingsScreen> {
  // persisted state
  String _autoLock = '1 minute';
  bool _biometrics = false;

  // palette tuned to the screenshot
  static const _bg = Color(0xFF0B0D1A);
  static const _card = Color(0xFF171B2B);
  static const _faint = Color(0xFFBFC5DA);
  static const _danger = Color(0xFFED3B3B);

  // prefs keys (align with the rest of your app)
  static const _kAutoLock = 'pref_auto_lock';
  static const _kBiometrics = 'use_biometrics';

  final LocalAuthentication _auth = LocalAuthentication();

  @override
  void initState() {
    super.initState();
    _loadPrefs();
  }

  Future<void> _loadPrefs() async {
    final sp = await SharedPreferences.getInstance();
    setState(() {
      _autoLock = sp.getString(_kAutoLock) ?? _autoLock;
      _biometrics = sp.getBool(_kBiometrics) ?? _biometrics;
    });
  }

  Future<void> _saveAutoLock(String v) async {
    final sp = await SharedPreferences.getInstance();
    await sp.setString(_kAutoLock, v);
  }

  Future<void> _saveBiometrics(bool v) async {
    final sp = await SharedPreferences.getInstance();
    await sp.setBool(_kBiometrics, v);
  }

  // ---------- Helpers ----------

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

  Future<bool> _deviceSupportsBiometrics() async {
    try {
      final canCheck = await _auth.canCheckBiometrics;
      final isSupported = await _auth.isDeviceSupported();
      return canCheck && isSupported;
    } catch (_) {
      return false;
    }
  }

  Future<bool> _authenticate(
      {String reason = 'Authenticate to continue'}) async {
    try {
      final ok = await _auth.authenticate(
        localizedReason: reason,
        options: const AuthenticationOptions(
          biometricOnly: true,
          stickyAuth: true,
          useErrorDialogs: true,
        ),
      );
      return ok;
    } catch (e) {
      _snack('Authentication failed');
      return false;
    }
  }

  Future<void> _pickAutoLock() async {
    const options = <String>[
      '30 seconds',
      '1 minute',
      '5 minutes',
      '10 minutes',
      '30 minutes',
      'Never',
    ];

    final picked = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _PickerSheet(
        title: 'Auto Lock',
        options: options,
        selected: _autoLock,
      ),
    );

    if (picked != null && picked != _autoLock) {
      setState(() => _autoLock = picked);
      await _saveAutoLock(picked);
      _snack('Auto lock set to $picked');
    }
  }

  Future<void> _toggleBiometrics(bool enable) async {
    if (enable) {
      final supported = await _deviceSupportsBiometrics();
      if (!supported) {
        _snack('Biometrics not available on this device');
        return;
      }
      final ok = await _authenticate(reason: 'Enable Biometrics');
      if (!ok) return;
    }
    setState(() => _biometrics = enable);
    await _saveBiometrics(enable);
    _snack(enable ? 'Biometrics enabled' : 'Biometrics disabled');
  }

  // ---------- Critical flows ----------

  Future<void> _validateSeed() async {
    final ok = await _authenticate(reason: 'Validate your seed');
    if (!ok) return;
    if (!mounted) return;
    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _InfoSheet(
        title: 'Validate Seed',
        body:
            'Great! This would start your seed validation flow (12/24-word check). You can plug your existing screen here.',
        primaryText: 'Start',
        onPrimary: () => Navigator.pop(context),
      ),
    );
  }

  Future<void> _backupWallet() async {
    final ok = await _authenticate(reason: 'Backup your wallet');
    if (!ok) return;
    if (!mounted) return;
    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _InfoSheet(
        title: 'Backup Wallet',
        body:
            'We will create an encrypted backup file of your wallet metadata. Store it safely.\n\nHook your real export here.',
        primaryText: 'Start Backup',
        onPrimary: () {
          Navigator.pop(context);
          _snack('Backup started…');
        },
      ),
    );
  }

  Future<void> _revealSeed() async {
    final ok = await _authenticate(reason: 'Reveal seed phrase');
    if (!ok) return;
    if (!mounted) return;
    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _SecretSheet(
        title: 'Seed Phrase',
        secret:
            'abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about',
      ),
    );
  }

  Future<void> _revealPrivateKey() async {
    final ok = await _authenticate(reason: 'Reveal private key');
    if (!ok) return;
    if (!mounted) return;
    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => const _SecretSheet(
        title: 'Private Key',
        secret: '0x1c0ffee0babe...deadbeefcafefeed0123456789abcdef',
      ),
    );
  }

  Future<void> _resetWallet() async {
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const _ResetDialog(),
    );
    if (confirmed != true) return;

    final ok = await _authenticate(reason: 'Confirm wallet reset');
    if (!ok) return;

    // Clear app auth/session (uses your existing helper)
    try {
      await AuthService.logout();
    } catch (_) {}

    if (!mounted) return;
    _snack('Wallet reset');
    // Navigate to your onboarding/login root.
    Navigator.of(context).popUntil((route) => route.isFirst);
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
            subtitle: 'Choose your auto lock timer',
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(_autoLock,
                    style: const TextStyle(color: _faint, fontSize: 14)),
                const SizedBox(width: 8),
                const Icon(Icons.chevron_right, color: _faint),
              ],
            ),
            onTap: _pickAutoLock,
          ),
          const SizedBox(height: 12),

          // Biometrics switch
          _SettingCard(
            leadingIcon: Icons.fingerprint_outlined,
            title: 'Activate Biometrics',
            subtitle: 'Use Face ID / Touch ID',
            trailing: Switch.adaptive(
              value: _biometrics,
              activeColor: Colors.white,
              activeTrackColor: const Color(0xFF5660FF),
              onChanged: _toggleBiometrics,
            ),
          ),

          const SizedBox(height: 24),
          const _SectionHeader('Security'),
          const SizedBox(height: 8),

          _SettingCard(
            leadingIcon: Icons.fact_check_outlined,
            title: 'Validate Seed',
            subtitle: 'Enhance your wallet security',
            onTap: _validateSeed,
          ),
          const SizedBox(height: 12),

          _SettingCard(
            leadingIcon: Icons.backup_outlined,
            title: 'Backup Wallet',
            subtitle: 'Create an encrypted file',
            onTap: _backupWallet,
          ),

          const SizedBox(height: 24),
          const _SectionHeader('Critical Actions'),
          const SizedBox(height: 8),

          _SettingCard(
            leadingIcon: Icons.remove_red_eye_outlined,
            title: 'Reveal seed phrase',
            subtitle: 'Reveal your seed phrase',
            onTap: _revealSeed,
          ),
          const SizedBox(height: 12),

          _SettingCard(
            leadingIcon: Icons.key_outlined,
            title: 'Reveal private key',
            subtitle: 'Reveal your PK from any account',
            onTap: _revealPrivateKey,
          ),
          const SizedBox(height: 12),

          // Destructive action
          _SettingCard.danger(
            leadingIcon: Icons.cancel_outlined,
            title: 'Reset Wallet',
            subtitle: 'This will clear local data',
            onTap: _resetWallet,
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

// ==================== Sheets & Dialogs ====================

class _PickerSheet extends StatelessWidget {
  const _PickerSheet({
    required this.title,
    required this.options,
    required this.selected,
  });

  final String title;
  final List<String> options;
  final String selected;

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
                    final value = options[i];
                    final isSel = value == selected;
                    return ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        value,
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: isSel ? FontWeight.w700 : FontWeight.w500,
                        ),
                      ),
                      trailing: isSel
                          ? const Icon(Icons.check_circle,
                              color: Colors.lightBlueAccent)
                          : null,
                      onTap: () => Navigator.pop(context, value),
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

class _InfoSheet extends StatelessWidget {
  const _InfoSheet({
    required this.title,
    required this.body,
    required this.primaryText,
    required this.onPrimary,
  });

  final String title;
  final String body;
  final String primaryText;
  final VoidCallback onPrimary;

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
              const SizedBox(height: 10),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  body,
                  style: const TextStyle(
                      color: _SecuritySettingsScreenState._faint),
                ),
              ),
              const SizedBox(height: 14),
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
                  onPressed: onPrimary,
                  child: Text(primaryText,
                      style: const TextStyle(
                          color: Colors.white, fontWeight: FontWeight.w700)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SecretSheet extends StatefulWidget {
  const _SecretSheet({required this.title, required this.secret});

  final String title;
  final String secret;

  @override
  State<_SecretSheet> createState() => _SecretSheetState();
}

class _SecretSheetState extends State<_SecretSheet> {
  bool _revealed = false;

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
                  Text(widget.title,
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 16)),
                  const Spacer(),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close, color: Colors.white),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFF111524),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF3A3D4A)),
                ),
                child: SelectableText(
                  _revealed ? widget.secret : '•••• •••• •••• •••• •••• ••••',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    letterSpacing: 0.5,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Colors.white24),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: () async {
                        await Clipboard.setData(
                            ClipboardData(text: widget.secret));
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content: Text('Copied to clipboard'),
                                duration: Duration(seconds: 1)),
                          );
                        }
                      },
                      icon: const Icon(Icons.copy, color: Colors.white),
                      label: const Text('Copy',
                          style: TextStyle(color: Colors.white)),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0E57FF),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        elevation: 0,
                      ),
                      onPressed: () {
                        setState(() => _revealed = !_revealed);
                      },
                      icon: Icon(
                        _revealed ? Icons.visibility_off : Icons.visibility,
                        color: Colors.white,
                      ),
                      label: Text(_revealed ? 'Hide' : 'Reveal',
                          style: const TextStyle(color: Colors.white)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              const Text(
                'Never share this with anyone. Anyone with this can access your funds.',
                style: TextStyle(
                    color: _SecuritySettingsScreenState._faint, fontSize: 12),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}

class _ResetDialog extends StatefulWidget {
  const _ResetDialog();

  @override
  State<_ResetDialog> createState() => _ResetDialogState();
}

class _ResetDialogState extends State<_ResetDialog> {
  final TextEditingController _c = TextEditingController();
  bool _ok = false;

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: _SecuritySettingsScreenState._card,
      title: const Text('Reset Wallet', style: TextStyle(color: Colors.white)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'This will clear local wallet data from this device. Type RESET to confirm.',
            style: TextStyle(color: _SecuritySettingsScreenState._faint),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _c,
            onChanged: (v) =>
                setState(() => _ok = v.trim().toUpperCase() == 'RESET'),
            decoration: const InputDecoration(
              hintText: 'Type RESET',
              hintStyle: TextStyle(color: Colors.white38),
              enabledBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: Colors.white24),
              ),
              focusedBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: Colors.white54),
              ),
            ),
            style: const TextStyle(color: Colors.white),
            textCapitalization: TextCapitalization.characters,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancel', style: TextStyle(color: Colors.white70)),
        ),
        TextButton(
          onPressed: _ok ? () => Navigator.pop(context, true) : null,
          child: const Text('Reset', style: TextStyle(color: Colors.redAccent)),
        ),
      ],
    );
  }
}
