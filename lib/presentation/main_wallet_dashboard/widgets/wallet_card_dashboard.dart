import 'dart:ui';
import 'package:cryptowallet/routes/app_routes.dart';
import 'package:flutter/material.dart';

class VaultHeaderCard extends StatefulWidget {
  final String totalValue;
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

  @override
  Widget build(BuildContext context) {
    final masked = _hidden ? '•••••••' : widget.totalValue;

    return GestureDetector(
      onTap: widget.onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
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
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
                              SizedBox(width: 4),
                              _EyeButton(
                                hidden: _hidden,
                                onPressed: () =>
                                    setState(() => _hidden = !_hidden),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Expanded(
                                child: Text(
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
                              ),
                              const SizedBox(width: 8),
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

// Alternative Dark Theme Version
class VaultHeaderCardDark extends StatefulWidget {
  final String totalValue;
  final String vaultName;
  final VoidCallback onTap;
  final VoidCallback onChangeWallet;
  final VoidCallback? onActivities; // optional

  const VaultHeaderCardDark({
    super.key,
    required this.totalValue,
    required this.vaultName,
    required this.onTap,
    required this.onChangeWallet,
    this.onActivities,
  });

  @override
  State<VaultHeaderCardDark> createState() => _VaultHeaderCardDarkState();
}

class _VaultHeaderCardDarkState extends State<VaultHeaderCardDark> {
  bool _hidden = false;

  @override
  Widget build(BuildContext context) {
    final masked = _hidden ? '•••••••' : widget.totalValue;

    return GestureDetector(
      onTap: widget.onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Colors.grey.shade800.withOpacity(0.3),
                    Colors.grey.shade900.withOpacity(0.2),
                  ],
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: Colors.white.withOpacity(0.1),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.3),
                    blurRadius: 30,
                    spreadRadius: 2,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  children: [
                    // Left
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Total Portfolio Value",
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey.shade400,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  masked,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              _EyeButton(
                                hidden: _hidden,
                                onPressed: () =>
                                    setState(() => _hidden = !_hidden),
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
                      navContext: context,
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
          case 'change_wallet':
            onChangeWallet();
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
