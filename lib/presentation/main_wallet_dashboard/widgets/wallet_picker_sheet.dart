// lib/widgets/wallet_picker_sheet.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cryptowallet/services/api_service.dart'; // AuthService
import 'package:bip39/bip39.dart' as bip39;
import 'package:provider/provider.dart'; // ⬅️ Provider kept
import 'package:cryptowallet/stores/wallet_store.dart'; // ⬅️ Store kept

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
  String? _selectedWalletId; // ✅ always the UUID (walletId)

  final _mnemonicCtrl = TextEditingController();
  final _importNameCtrl = TextEditingController(); // ⬅️ NEW (import name)
  final _genNameCtrl = TextEditingController(); // ⬅️ NEW (generate name)

  @override
  void initState() {
    super.initState();
    _selectedWalletId = widget.initialActiveWalletId; // preselect active
    _refresh();
  }

  @override
  void dispose() {
    _mnemonicCtrl.dispose();
    _importNameCtrl.dispose();
    _genNameCtrl.dispose();
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

        // Always keep the active wallet selected if present.
        final active = widget.initialActiveWalletId;
        bool containsId(String? id) =>
            id != null && _wallets.any((w) => AuthService.walletIdOf(w) == id);

        if (containsId(active)) {
          _selectedWalletId = active;
        } else if (containsId(_selectedWalletId)) {
          // keep current selection if it still exists
        } else {
          _selectedWalletId = _wallets.isNotEmpty
              ? AuthService.walletIdOf(_wallets.first)
              : null;
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

  // ---------- Rename (unchanged look) ----------
  Future<void> _promptRename(Map<String, dynamic> wallet) async {
    final id = AuthService.walletIdOf(wallet); // ✅ UUID walletId
    if (id.isEmpty) return;

    final controller =
        TextEditingController(text: (wallet['name'] ?? '').toString().trim());
    bool saving = false;

    await showDialog<void>(
      context: context,
      barrierDismissible: !saving,
      builder: (dctx) {
        return StatefulBuilder(builder: (dctx, setD) {
          Future<void> submit() async {
            final newName = controller.text.trim();
            if (newName.isEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Enter a wallet name')),
              );
              return;
            }
            setD(() => saving = true);
            try {
              await AuthService.updateWalletName(
                  walletId: id, walletName: newName);

              // Update in-place for immediate UI
              final idx =
                  _wallets.indexWhere((w) => AuthService.walletIdOf(w) == id);
              if (idx != -1) {
                final updated = Map<String, dynamic>.from(_wallets[idx]);
                updated['name'] = newName;
                updated['walletName'] = newName;
                setState(() => _wallets[idx] = updated);
              }

              if (mounted) {
                Navigator.of(dctx).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Wallet renamed to "$newName"')),
                );
              }
            } catch (e) {
              setD(() => saving = false);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Rename failed: $e')),
              );
            }
          }

          return Dialog(
            backgroundColor: Colors.transparent,
            insetPadding:
                const EdgeInsets.symmetric(horizontal: 22, vertical: 24),
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
                    Row(
                      children: [
                        const Expanded(
                          child: Text(
                            'Edit wallet name',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                              fontSize: 16,
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, color: Colors.white60),
                          onPressed:
                              saving ? null : () => Navigator.of(dctx).pop(),
                          splashRadius: 18,
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.06),
                        borderRadius: BorderRadius.circular(14),
                        border:
                            Border.all(color: Colors.white.withOpacity(0.12)),
                      ),
                      padding: const EdgeInsets.all(12),
                      child: TextField(
                        controller: controller,
                        enabled: !saving,
                        decoration: _inputDecoration('Enter wallet name'),
                        style: const TextStyle(color: Colors.white),
                        textInputAction: TextInputAction.done,
                        onSubmitted: (_) => submit(),
                        autofocus: true,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed:
                                saving ? null : () => Navigator.of(dctx).pop(),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.white,
                              side: const BorderSide(color: Colors.white24),
                              padding: const EdgeInsets.symmetric(
                                  vertical: 12, horizontal: 12),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12)),
                            ),
                            child: const Text('Cancel'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: saving ? null : submit,
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
                            child: saving
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2))
                                : const Text('Save'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        });
      },
    );
  }

  // ---------- Create flows (NOW REQUIRE NAME) ----------

  /// Import with mnemonic -> dialog has 2 fields (mnemonic + wallet name)
  Future<void> _createWithPhraseDialog() async {
    _mnemonicCtrl.clear();
    _importNameCtrl.clear();

    final result = await showDialog<Map<String, String>?>(
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
              textInputAction: TextInputAction.next,
              keyboardType: TextInputType.text,
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r"[a-zA-Z\s]"))
              ],
              decoration: _inputDecoration('e.g. ripple lava wagon ...'),
              style: const TextStyle(color: Colors.white),
            ),
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerLeft,
              child: Text('Wallet Name (required)',
                  style: TextStyle(
                      color: Colors.white70.withOpacity(0.9), fontSize: 12)),
            ),
            const SizedBox(height: 6),
            TextField(
              controller: _importNameCtrl,
              textInputAction: TextInputAction.done,
              decoration: _inputDecoration('e.g. Main Wallet'),
              style: const TextStyle(color: Colors.white),
            ),
          ],
        ),
        primaryText: 'Import',
        onPrimary: () {
          final phrase = _mnemonicCtrl.text.trim();
          final name = _importNameCtrl.text.trim();
          if (phrase.isEmpty || name.isEmpty) {
            ScaffoldMessenger.of(ctx).showSnackBar(
              const SnackBar(content: Text('Phrase and name are required')),
            );
            return;
          }
          Navigator.of(ctx).pop({'phrase': phrase, 'name': name});
        },
        secondaryText: 'Cancel',
        onSecondary: () => Navigator.of(ctx).pop(null),
      ),
    );

    if (result == null) return;
    await _createWalletWithMnemonic(
      result['phrase']!,
      walletName: result['name']!,
      label: 'Wallet imported',
    );
  }

  /// Generate -> show phrase, then prompt for required name
  Future<void> _generateAndCreate() async {
    final phrase = bip39.generateMnemonic(strength: 128); // 12 words
    if (!bip39.validateMnemonic(phrase)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Generated phrase is invalid.')),
      );
      return;
    }

    // Show generated phrase (read only)
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

    // Ask for required name
    _genNameCtrl.clear();
    final name = await showDialog<String?>(
      context: context,
      builder: (ctx) => _GradientDialog(
        title: 'Name your wallet',
        child: TextField(
          controller: _genNameCtrl,
          autofocus: true,
          decoration: _inputDecoration('e.g. Main Wallet'),
          style: const TextStyle(color: Colors.white),
          textInputAction: TextInputAction.done,
          onSubmitted: (_) {
            final v = _genNameCtrl.text.trim();
            if (v.isEmpty) {
              ScaffoldMessenger.of(ctx).showSnackBar(
                const SnackBar(content: Text('Wallet name is required')),
              );
              return;
            }
            Navigator.of(ctx).pop(v);
          },
        ),
        primaryText: 'Save',
        onPrimary: () {
          final v = _genNameCtrl.text.trim();
          if (v.isEmpty) {
            ScaffoldMessenger.of(ctx).showSnackBar(
              const SnackBar(content: Text('Wallet name is required')),
            );
            return;
          }
          Navigator.of(ctx).pop(v);
        },
        secondaryText: 'Cancel',
        onSecondary: () => Navigator.of(ctx).pop(null),
      ),
    );

    if (name == null || name.trim().isEmpty) return;

    await _createWalletWithMnemonic(
      phrase,
      walletName: name.trim(),
      label: 'Wallet created',
    );
  }

  /// Create wallet, then immediately name it via PUT /api/wallet/name/:walletId
  Future<void> _createWalletWithMnemonic(
    String phrase, {
    required String walletName,
    required String label,
  }) async {
    setState(() => _creating = true);
    try {
      final res = await AuthService.submitRecoveryPhrase(phrase: phrase);
      if (!mounted) return;

      if (!res.success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(res.message ?? 'Failed to create wallet')),
        );
        setState(() => _creating = false);
        return;
      }

      // Try to read the created walletId from response
      String createdId = '';
      final d = res.data;
      try {
        createdId = (d?['walletId'] ??
                    d?['data']?['walletId'] ??
                    d?['wallet']?['walletId'] ??
                    d?['wallet']?['_id'] ??
                    d?['_id'])
                ?.toString() ??
            '';
      } catch (_) {}

      // If still empty, fallback to last stored id
      if (createdId.isEmpty) {
        createdId = (await AuthService.getStoredWalletId()) ?? '';
      }

      // Set the name (required)
      await AuthService.updateWalletName(
        walletId: createdId,
        walletName: walletName,
      );

      // Refresh and keep active wallet selected by default
      await _refresh();

      // Also update row name locally if we can find this new wallet
      if (createdId.isNotEmpty) {
        final idx =
            _wallets.indexWhere((w) => AuthService.walletIdOf(w) == createdId);
        if (idx != -1) {
          final updated = Map<String, dynamic>.from(_wallets[idx]);
          updated['name'] = walletName;
          updated['walletName'] = walletName;
          setState(() => _wallets[idx] = updated);
        }
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$label successfully')),
      );

      // Do NOT change selection — keep active wallet selected as requested.
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
                      final id = AuthService.walletIdOf(w); // ✅ UUID
                      final isChecked = id == _selectedWalletId;

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
                                          // ✏️ edit button
                                          IconButton(
                                            tooltip: 'Edit name',
                                            icon: const Icon(Icons.edit,
                                                color: Colors.white70,
                                                size: 18),
                                            onPressed: () => _promptRename(w),
                                            splashRadius: 18,
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
                                    AuthService.walletIdOf(w) ==
                                    _selectedWalletId,
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
