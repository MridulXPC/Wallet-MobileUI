import 'dart:ui';
import 'package:cryptowallet/presentation/main_wallet_dashboard/widgets/wallet_picker_sheet.dart';
import 'package:cryptowallet/routes/app_routes.dart';
import 'package:cryptowallet/stores/wallet_store.dart';
import 'package:flutter/material.dart';

import 'dart:ui';
import 'package:cryptowallet/services/api_service.dart'; // ← add
import 'package:intl/intl.dart'; // ← add
import 'package:cryptowallet/routes/app_routes.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class VaultHeaderCard extends StatefulWidget {
  final String totalValue; // fallback / initial display
  final String vaultName;
  final VoidCallback onTap;
  final VoidCallback onChangeWallet;
  final VoidCallback? onActivities; // optional

  const VaultHeaderCard({
    super.key,
    required this.totalValue,
    required this.vaultName,
    required this.onTap,
    required this.onChangeWallet,
    this.onActivities, // optional
  });

  @override
  State<VaultHeaderCard> createState() => _VaultHeaderCardState();
}

class _VaultHeaderCardState extends State<VaultHeaderCard> {
  bool _hidden = false;

  // live-computed total (USD-formatted)
  String? _computedTotal;
  bool _loadingTotal = false;

  @override
  void initState() {
    super.initState();
    _loadTotalFromWallets();
  }

  Future<void> _loadTotalFromWallets() async {
    setState(() => _loadingTotal = true);
    try {
      final wallets = await AuthService.fetchWallets();
      final totalUsd = _sumAllWalletsUsd(wallets);
      final formatted = _formatUsd(totalUsd);
      if (!mounted) return;
      setState(() => _computedTotal = formatted);
    } catch (_) {
      // keep fallback widget.totalValue on error
    } finally {
      if (mounted) setState(() => _loadingTotal = false);
    }
  }

  // -------- Aggregation helpers (robust to varied shapes) --------

  double _sumAllWalletsUsd(List<Map<String, dynamic>> wallets) {
    double total = 0.0;
    for (final w in wallets) {
      total += _walletUsd(w);
    }
    return total;
  }

  double _walletUsd(Map<String, dynamic> w) {
    // If chains exist, sum chain values; else use wallet-level usd/fiat
    final chains = (w['chains'] as List?) ?? const [];
    if (chains.isNotEmpty) {
      double sum = 0.0;
      for (final c in chains) {
        if (c is! Map) continue;
        final m = c.cast<String, dynamic>();
        // prefer direct USD/fiat fields
        final usdDirect = _asDouble(m['fiatValue']) ??
            _asDouble(m['usdValue']) ??
            _asDouble(m['balanceUSD']);
        if (usdDirect != null) {
          sum += usdDirect;
          continue;
        }
        // fallback: balance * price
        final bal = _asDouble(m['balance']) ?? _asDouble(m['amount']);
        final price = _asDouble(m['priceUsd']) ??
            _asDouble(m['usdPrice']) ??
            _asDouble(m['price']);
        if (bal != null && price != null) {
          sum += bal * price;
        }
      }
      return sum;
    }

    // wallet-level fallback
    return _asDouble(w['fiatValue']) ??
        _asDouble(w['usdValue']) ??
        _asDouble(w['totalUsd']) ??
        _asDouble(w['total']) ??
        0.0;
  }

  double? _asDouble(dynamic v) {
    if (v == null) return null;
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v);
    return null;
  }

  String _formatUsd(double value) {
    final f = NumberFormat.currency(symbol: '\$', decimalDigits: 2);
    return f.format(value);
  }

  @override
  Widget build(BuildContext context) {
    final display = _computedTotal ?? widget.totalValue;
    final masked = _hidden ? '•••••••' : display;

    return GestureDetector(
      onTap: widget.onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Colors.white.withOpacity(0.15),
                    Colors.white.withOpacity(0.05),
                  ],
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: Colors.white.withOpacity(0.2),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 20,
                    spreadRadius: 1,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                child: Row(
                  children: [
                    // Left: text block
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                "Total Portfolio Value",
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.white.withOpacity(0.7),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(width: 4),
                              _EyeButton(
                                hidden: _hidden,
                                onPressed: () =>
                                    setState(() => _hidden = !_hidden),
                              ),
                              if (_loadingTotal) ...[
                                const SizedBox(width: 6),
                                const SizedBox(
                                  width: 14,
                                  height: 14,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                ),
                              ],
                            ],
                          ),
                          Row(
                            children: [
                              Text(
                                masked,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                  shadows: [
                                    Shadow(
                                      color: Colors.black26,
                                      offset: Offset(0, 1),
                                      blurRadius: 3,
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.refresh,
                                    color: Colors.white70, size: 20),
                                tooltip: 'Recalculate',
                                onPressed: _loadingTotal
                                    ? null
                                    : _loadTotalFromWallets,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    // Right: 3-dots menu
                    _VaultMenuButton(
                      title: widget.vaultName,
                      onChangeWallet: widget.onChangeWallet,
                      onActivities: widget.onActivities,
                      navContext: context, // <-- pass parent context
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Reusable small eye/eye-off button (keeps tap target comfy)
class _EyeButton extends StatelessWidget {
  final bool hidden;
  final VoidCallback onPressed;

  const _EyeButton({
    required this.hidden,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkResponse(
        onTap: onPressed,
        radius: 18,
        child: Padding(
          padding: const EdgeInsets.all(4.0),
          child: Icon(
            hidden ? Icons.visibility_off : Icons.visibility,
            size: 20,
            color: Colors.white70,
          ),
        ),
      ),
    );
  }
}

/// Reusable three-dots popup with "Change wallet" and "Activities"
/// - No dividers
/// - Shows the current wallet name as a subtitle on each option
/// - Uses root navigator so the route always resolves
class _VaultMenuButton extends StatelessWidget {
  final String title; // current wallet name
  final VoidCallback onChangeWallet;
  final VoidCallback? onActivities; // optional
  final BuildContext navContext; // parent context for safe navigation

  const _VaultMenuButton({
    required this.title,
    required this.onChangeWallet,
    this.onActivities,
    required this.navContext,
  });

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      tooltip: 'More',
      offset: const Offset(0, 28),
      color: const Color(0xFF1F2431),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      icon: const Icon(Icons.more_vert, color: Colors.white),
      onSelected: (value) {
        switch (value) {
          // inside your _VaultMenuButton onSelected handler
          case 'change_wallet':
            openWalletPickerBottomSheet(
              navContext,
              initialActiveWalletId:
                  navContext.read<WalletStore>().activeWalletId,
              onSelectWallet: (wallet) async {
                await navContext.read<WalletStore>().setActive(wallet['_id']);
                ScaffoldMessenger.of(navContext).showSnackBar(
                  SnackBar(
                      content: Text('Active: ${wallet['name'] ?? 'Wallet'}')),
                );
              },
            );

            break;

          case 'activities':
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (onActivities != null) {
                onActivities!();
              } else {
                Navigator.of(navContext, rootNavigator: true)
                    .pushNamed(AppRoutes.transactionHistory);
              }
            });
            break;
        }
      },
      itemBuilder: (context) => [
        PopupMenuItem(
          value: 'change_wallet',
          child: _MenuTile(
            icon: Icons.swap_horiz,
            title: 'Change wallet',
            subtitle: title,
          ),
        ),
        PopupMenuItem(
          value: 'activities',
          child: _MenuTile(
            icon: Icons.history,
            title: 'Activities',
            subtitle: title,
          ),
        ),
      ],
    );
  }
}

class _MenuTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _MenuTile({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: Colors.white70, size: 20),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  )),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: const TextStyle(
                  color: Colors.white54,
                  fontSize: 12,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
