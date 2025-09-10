// lib/widgets/wallet_picker_sheet.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cryptowallet/services/api_service.dart'; // AuthService
import 'package:bip39/bip39.dart' as bip39;
import 'package:provider/provider.dart'; // ⬅️ NEW
import 'package:cryptowallet/stores/wallet_store.dart'; // ⬅️ NEW

typedef WalletSelectCallback = void Function(Map<String, dynamic> wallet);

// Shared gradient + styling
const _sheetRadius = Radius.circular(18);
const _sheetGradient = LinearGradient(
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
  colors: [
    Color.fromARGB(255, 6, 11, 33),
    Color.fromARGB(255, 0, 0, 0),
    Color.fromARGB(255, 0, 12, 56),
  ],
);

Future<void> openWalletPickerBottomSheet(
  BuildContext context, {
  String? initialActiveWalletId,
  required WalletSelectCallback onSelectWallet,
}) {
  // ⬇️ If caller forgets to pass active id, pull it from WalletStore
  String? effectiveActiveId = initialActiveWalletId;
  try {
    final ws = context.read<WalletStore>();
    effectiveActiveId ??= ws.activeWalletId;
  } catch (_) {
    // Provider not available here; ignore
  }

  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent, // allow our gradient container
    barrierColor: Colors.black54,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: _sheetRadius),
    ),
    builder: (_) => _WalletPickerSheet(
      onSelectWallet: onSelectWallet,
      initialActiveWalletId: effectiveActiveId, // ⬅️ pass effective id
    ),
  );
}

class _WalletPickerSheet extends StatefulWidget {
  final WalletSelectCallback onSelectWallet;
  final String? initialActiveWalletId;

  const _WalletPickerSheet({
    required this.onSelectWallet,
    this.initialActiveWalletId,
  });

  @override
  State<_WalletPickerSheet> createState() => _WalletPickerSheetState();
}

class _WalletPickerSheetState extends State<_WalletPickerSheet> {
  bool _loading = true;
  bool _creating = false;
  String? _error;
  List<Map<String, dynamic>> _wallets = [];
  String? _selectedWalletId;

  final _mnemonicCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _selectedWalletId = widget.initialActiveWalletId; // preselect active
    _refresh();
  }

  @override
  void dispose() {
    _mnemonicCtrl.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final list = await AuthService.fetchWallets();
      if (!mounted) return;

      setState(() {
        _wallets = list;
        _loading = false;

        // ⬇️ Selection preference order:
        // 1) active id from widget.initialActiveWalletId if present in list
        // 2) keep current _selectedWalletId if still present
        // 3) fall back to first wallet
        final active = widget.initialActiveWalletId;
        final hasActiveInList = active != null &&
            _wallets.any((w) => (w['_id']?.toString()) == active);
        final hasSelectedInList = _selectedWalletId != null &&
            _wallets.any((w) => (w['_id']?.toString()) == _selectedWalletId);

        if (hasActiveInList) {
          _selectedWalletId = active;
        } else if (hasSelectedInList) {
          // keep as-is
        } else {
          _selectedWalletId =
              _wallets.isNotEmpty ? _wallets.first['_id']?.toString() : null;
        }
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Failed to load wallets: $e';
        _loading = false;
      });
    }
  }

  // ---------- UI helpers ----------
  String _walletTitle(Map<String, dynamic> w) {
    final raw = w['name']?.toString().trim();
    if (raw != null && raw.isNotEmpty) return raw;
    final id = w['_id']?.toString();
    if (id != null && id.length > 6) {
      return 'Wallet …${id.substring(id.length - 6)}';
    }
    return 'Wallet';
  }

  String _shortAddress(Map<String, dynamic> w) {
    final chains = (w['chains'] as List?) ?? const [];
    for (final c in chains) {
      if (c is Map) {
        final addr = c['address']?.toString().trim();
        if (addr != null && addr.isNotEmpty) return _mask(addr);
      }
    }
    final rootAddr = w['address']?.toString().trim();
    return (rootAddr != null && rootAddr.isNotEmpty) ? _mask(rootAddr) : '—';
  }

  String _mask(String a) {
    if (a.length <= 12) return a;
    return '${a.substring(0, 8)}…${a.substring(a.length - 6)}';
  }

  // ---------- Create flows ----------
  Future<void> _createWithPhraseDialog() async {
    final phrase = await showDialog<String?>(
      context: context,
      builder: (ctx) => _GradientDialog(
        title: 'Import Wallet with Phrase',
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Enter your 12/24-word recovery phrase (mnemonic).',
              style: TextStyle(color: Colors.white70, fontSize: 13),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _mnemonicCtrl,
              minLines: 2,
              maxLines: 4,
              textInputAction: TextInputAction.done,
              keyboardType: TextInputType.text,
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r"[a-zA-Z\s]"))
              ],
              decoration: _inputDecoration('e.g. ripple lava wagon ...'),
              style: const TextStyle(color: Colors.white),
            ),
          ],
        ),
        primaryText: 'Import',
        onPrimary: () => Navigator.of(ctx).pop(_mnemonicCtrl.text.trim()),
        secondaryText: 'Cancel',
        onSecondary: () => Navigator.of(ctx).pop(null),
      ),
    );

    if (phrase == null || phrase.isEmpty) return;
    await _createWalletWithMnemonic(phrase, label: 'Wallet imported');
  }

  Future<void> _generateAndCreate() async {
    final phrase = bip39.generateMnemonic(strength: 128); // 12 words
    if (!bip39.validateMnemonic(phrase)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Generated phrase is invalid.')),
      );
      return;
    }

    await showDialog<void>(
      context: context,
      builder: (ctx) => _GradientDialog(
        title: 'Generated Recovery Phrase',
        child: SelectableText(
          phrase,
          style: const TextStyle(color: Colors.white, height: 1.4),
        ),
        primaryText: 'OK',
        onPrimary: () => Navigator.of(ctx).pop(),
      ),
    );

    await _createWalletWithMnemonic(phrase, label: 'Wallet created');
  }

  Future<void> _createWalletWithMnemonic(
    String phrase, {
    required String label,
  }) async {
    setState(() => _creating = true);
    try {
      final res = await AuthService.submitRecoveryPhrase(phrase: phrase);
      if (!mounted) return;

      if (res.success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$label successfully')),
        );
        _mnemonicCtrl.clear();
        await _refresh();

        _selectedWalletId ??=
            _wallets.isNotEmpty ? _wallets.first['_id']?.toString() : null;
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(res.message ?? 'Failed to create wallet')),
        );
      }
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    } finally {
      if (mounted) setState(() => _creating = false);
    }
  }

  // ---------- Build ----------
  @override
  Widget build(BuildContext context) {
    final viewInsets = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      decoration: const BoxDecoration(
        gradient: _sheetGradient,
        borderRadius: BorderRadius.vertical(top: _sheetRadius),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.only(
            left: 14,
            right: 14,
            top: 12,
            bottom: viewInsets + 12,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Grabber
              Container(
                width: 42,
                height: 5,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              const SizedBox(height: 14),

              // Header
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Your Wallets',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.refresh, color: Colors.white70),
                    onPressed: _loading ? null : _refresh,
                    tooltip: 'Refresh',
                  ),
                ],
              ),
              const SizedBox(height: 6),

              // Content
              if (_loading) ...[
                const Padding(
                  padding: EdgeInsets.all(20),
                  child: CircularProgressIndicator.adaptive(),
                ),
              ] else if (_error != null) ...[
                _glassCard(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Text(
                      _error!,
                      style: const TextStyle(color: Colors.redAccent),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
              ] else if (_wallets.isEmpty) ...[
                _glassCard(
                  child: const Padding(
                    padding: EdgeInsets.all(14),
                    child: Text(
                      'No wallets found',
                      style: TextStyle(color: Colors.white70),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
              ] else ...[
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: _wallets.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (_, i) {
                      final w = _wallets[i];
                      final id = w['_id']?.toString();
                      final isChecked = id != null && id == _selectedWalletId;

                      return _glassCard(
                        hover: true,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(14),
                          onTap: () => setState(() => _selectedWalletId = id),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 8,
                            ),
                            child: Row(
                              children: [
                                Checkbox(
                                  value: isChecked,
                                  onChanged: (_) =>
                                      setState(() => _selectedWalletId = id),
                                  activeColor: Colors.lightGreenAccent.shade400,
                                  checkColor: Colors.black,
                                  side: const BorderSide(color: Colors.white30),
                                ),
                                const SizedBox(width: 6),
                                const Icon(Icons.account_balance_wallet,
                                    color: Colors.white70),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                              _walletTitle(w),
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontWeight: FontWeight.w700,
                                                fontSize: 14.5,
                                              ),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                          if (widget.initialActiveWalletId !=
                                                  null &&
                                              widget.initialActiveWalletId ==
                                                  id)
                                            Container(
                                              margin: const EdgeInsets.only(
                                                  left: 8),
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                horizontal: 8,
                                                vertical: 2,
                                              ),
                                              decoration: BoxDecoration(
                                                color: Colors.white12,
                                                borderRadius:
                                                    BorderRadius.circular(999),
                                                border: Border.all(
                                                  color: Colors.white24,
                                                ),
                                              ),
                                              child: const Text(
                                                'Active',
                                                style: TextStyle(
                                                  color: Colors.white70,
                                                  fontSize: 11,
                                                ),
                                              ),
                                            ),
                                        ],
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        _shortAddress(w),
                                        style: const TextStyle(
                                          color: Colors.white60,
                                          fontSize: 12,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 8),
              ],

              // Actions
              Row(
                children: [
                  Expanded(
                    child: _primaryButton(
                      icon: const Icon(Icons.check_circle_outline),
                      label: 'Set Active',
                      onPressed: (_selectedWalletId == null || _loading)
                          ? null
                          : () {
                              final picked = _wallets.firstWhere(
                                (w) =>
                                    (w['_id']?.toString()) == _selectedWalletId,
                                orElse: () => {},
                              );
                              if (picked.isNotEmpty) {
                                widget.onSelectWallet(picked);
                                Navigator.of(context).pop();
                              }
                            },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: _primaryButton(
                      icon: _creating
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.auto_fix_high),
                      label: _creating ? 'Working…' : 'Generate & Create',
                      onPressed: _creating ? null : _generateAndCreate,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _outlineButton(
                      icon: const Icon(Icons.import_contacts),
                      label: 'Import with Phrase',
                      onPressed: _creating ? null : _createWithPhraseDialog,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
            ],
          ),
        ),
      ),
    );
  }

  // ---------- Stylish helpers ----------
  static InputDecoration _inputDecoration(String hint) => InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Colors.white38),
        filled: true,
        fillColor: Colors.white.withOpacity(0.06),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.white24),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.white70),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      );

  Widget _glassCard({required Widget child, bool hover = false}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withOpacity(0.12)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.35),
            blurRadius: 22,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: hover
          ? InkWell(
              onTap: () {},
              splashColor: Colors.white10,
              highlightColor: Colors.white.withOpacity(0.04),
              child: child,
            )
          : child,
    );
  }

  Widget _primaryButton({
    required Widget icon,
    required String label,
    required VoidCallback? onPressed,
  }) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: icon,
      label: Text(label),
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.lightBlueAccent.withOpacity(0.18),
        foregroundColor: Colors.white,
        elevation: 0,
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        side: const BorderSide(color: Colors.white24),
      ),
    );
  }

  Widget _outlineButton({
    required Widget icon,
    required String label,
    required VoidCallback? onPressed,
  }) {
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: icon,
      label: Text(label),
      style: OutlinedButton.styleFrom(
        foregroundColor: Colors.white,
        side: const BorderSide(color: Colors.white24),
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}

// ---------- Custom gradient dialog to match the sheet ----------
class _GradientDialog extends StatelessWidget {
  final String title;
  final Widget child;
  final String? primaryText;
  final VoidCallback? onPrimary;
  final String? secondaryText;
  final VoidCallback? onSecondary;

  const _GradientDialog({
    required this.title,
    required this.child,
    this.primaryText,
    this.onPrimary,
    this.secondaryText,
    this.onSecondary,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 22, vertical: 24),
      child: Container(
        decoration: const BoxDecoration(
          gradient: _sheetGradient,
          borderRadius: BorderRadius.all(_sheetRadius),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Title
              Row(
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white60),
                    onPressed: () => Navigator.of(context).pop(),
                    splashRadius: 18,
                  ),
                ],
              ),
              const SizedBox(height: 6),

              // Body (glass)
              Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.06),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.white.withOpacity(0.12)),
                ),
                padding: const EdgeInsets.all(12),
                child: child,
              ),

              const SizedBox(height: 12),
              Row(
                children: [
                  if (secondaryText != null) ...[
                    Expanded(
                      child: OutlinedButton(
                        onPressed: onSecondary,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white,
                          side: const BorderSide(color: Colors.white24),
                          padding: const EdgeInsets.symmetric(
                              vertical: 12, horizontal: 12),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                        child: Text(secondaryText!),
                      ),
                    ),
                    const SizedBox(width: 10),
                  ],
                  if (primaryText != null)
                    Expanded(
                      child: ElevatedButton(
                        onPressed: onPrimary,
                        style: ElevatedButton.styleFrom(
                          backgroundColor:
                              Colors.lightBlueAccent.withOpacity(0.18),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(
                              vertical: 12, horizontal: 12),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                          side: const BorderSide(color: Colors.white24),
                        ),
                        child: Text(primaryText!),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
