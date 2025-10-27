// lib/presentation/profile_screen/profile_screen.dart
import 'package:cryptowallet/presentation/bottomnavbar.dart';
import 'package:cryptowallet/presentation/main_wallet_dashboard/QrScannerScreen.dart';
import 'package:cryptowallet/presentation/profile_screen/SessionInfoScreen.dart';
import 'package:cryptowallet/routes/app_routes.dart';
import 'package:cryptowallet/services/api_service.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  // ===== Colors tuned to the screenshot =====
  static const Color _pageBg = Color(0xFF0B0D1A);
  static const Color _card = Color(0xFF171B2B);
  static const Color _stroke = Color(0xFF272C42);
  static const Color _faint = Color(0xFFBFC5DA);

  Future<void> _openQRScanner() async {
    final status = await Permission.camera.request();

    if (status.isGranted) {
      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => QRScannerScreen(
            onScan: (code) async {
              // Handle the scanned session id
              try {
                // ✅ Only use the stored token set at registration/login
                final String? token = await AuthService.getStoredToken();

                if (!mounted) return;
                if (token == null || token.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        '❌ Authentication required. Please log in first.',
                      ),
                    ),
                  );
                  Navigator.pop(context); // close scanner
                  return;
                }

                final result = await AuthService.authorizeWebSession(
                  sessionId: code,
                  token: token,
                );

                if (!mounted) return;
                if (result.success) {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                      builder: (_) => SessionInfoScreen(sessionId: code),
                    ),
                  );
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        result.message ?? '❌ Failed to authorize session',
                      ),
                    ),
                  );
                  Navigator.pop(context); // close scanner
                }
              } catch (e) {
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      '❌ An error occurred during authorization',
                    ),
                  ),
                );
                Navigator.pop(context); // close scanner
              }
            },
          ),
        ),
      );
    } else if (status.isPermanentlyDenied) {
      openAppSettings();
    } else {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Camera permission is required.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _pageBg,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          children: [
            // Title
            const Text(
              'Profile',
              style: TextStyle(
                color: Colors.white,
                fontSize: 28,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 14),

            // Search bar
            Container(
              height: 48,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: _card,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: _stroke, width: 1),
              ),
              child: const Row(
                children: [
                  Icon(Icons.search, color: Color(0xFF8E94AA)),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Search',
                      style: TextStyle(
                        color: Color(0xFF8E94AA),
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // 2 x 2 grid of setting cards
            Row(
              children: [
                Expanded(
                  child: _HubSquareCard(
                    icon: Icons.settings_outlined,
                    title: 'General\nSettings',
                    onTap: () {
                      Navigator.pushNamed(
                          context, AppRoutes.generalSettingsScreen);
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _HubSquareCard(
                    icon: Icons.contact_page_outlined,
                    title: 'Address Book',
                    onTap: () {
                      // Navigator.pushNamed(context, AppRoutes.addressbook);
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _HubSquareCard(
                    icon: Icons.lock_outline,
                    title: 'Security\nSettings',
                    onTap: () {
                      Navigator.pushNamed(
                          context, AppRoutes.securitysettingscreen);
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _HubSquareCard(
                    icon: Icons.help_outline,
                    title: 'Tech &\nSupport',
                    onTap: () {
                      Navigator.pushNamed(context, AppRoutes.techSupportScreen);
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Link Web Session
            _HubListTile(
              leadingIcon: Icons.qr_code_scanner,
              title: 'Link Web Session',
              subtitle: 'Authorize your browser with a QR',
              onTap: _openQRScanner,
            ),

            const SizedBox(height: 72), // bottom spacing
          ],
        ),
      ),
      bottomNavigationBar: BottomNavBar(
        selectedIndex: 4,
        onTap: (index) {
          if (index == 4) return; // stay here
          Navigator.pushReplacementNamed(
            context,
            index == 0
                ? AppRoutes.dashboardScreen
                : index == 1
                    ? AppRoutes.dashboardScreen
                    : AppRoutes.swapScreen,
          );
        },
      ),
    );
  }
}

/// Square cards in the 2x2 grid
class _HubSquareCard extends StatelessWidget {
  const _HubSquareCard({
    required this.icon,
    required this.title,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: _ProfileScreenState._card,
      borderRadius: BorderRadius.circular(6),
      child: InkWell(
        borderRadius: BorderRadius.circular(6),
        onTap: onTap,
        child: Container(
          height: 110,
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 2),
              Icon(icon, color: _ProfileScreenState._faint, size: 28),
              const Spacer(),
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  height: 1.2,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// List row styled like the screenshot’s “Buy Crypto” row
class _HubListTile extends StatelessWidget {
  const _HubListTile({
    required this.leadingIcon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData leadingIcon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: _ProfileScreenState._card,
      borderRadius: BorderRadius.circular(6),
      child: InkWell(
        borderRadius: BorderRadius.circular(6),
        onTap: onTap,
        child: Container(
          height: 70,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          margin: const EdgeInsets.only(bottom: 12),
          child: Row(
            children: [
              Icon(leadingIcon, color: _ProfileScreenState._faint, size: 22),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w700)),
                    const SizedBox(height: 2),
                    Text(subtitle,
                        style: const TextStyle(
                            color: _ProfileScreenState._faint, fontSize: 14)),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right,
                  color: _ProfileScreenState._faint),
            ],
          ),
        ),
      ),
    );
  }
}

// =================== QR Scanner ===================

class CornerFramePainter extends CustomPainter {
  final Paint _paint = Paint()
    ..color = Colors.cyanAccent
    ..strokeWidth = 4
    ..style = PaintingStyle.stroke;

  @override
  void paint(Canvas canvas, Size size) {
    const double length = 30;

    // TL
    canvas.drawLine(const Offset(0, 0), const Offset(length, 0), _paint);
    canvas.drawLine(const Offset(0, 0), const Offset(0, length), _paint);
    // TR
    canvas.drawLine(
        Offset(size.width, 0), Offset(size.width - length, 0), _paint);
    canvas.drawLine(Offset(size.width, 0), Offset(size.width, length), _paint);
    // BL
    canvas.drawLine(
        Offset(0, size.height), Offset(length, size.height), _paint);
    canvas.drawLine(
        Offset(0, size.height), Offset(0, size.height - length), _paint);
    // BR
    canvas.drawLine(Offset(size.width, size.height),
        Offset(size.width - length, size.height), _paint);
    canvas.drawLine(Offset(size.width, size.height),
        Offset(size.width, size.height - length), _paint);
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}
