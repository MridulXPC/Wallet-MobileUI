import 'package:cryptowallet/presentation/profile_screen/SessionInfoScreen.dart';
import 'package:cryptowallet/services/auth_service.dart';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:permission_handler/permission_handler.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {


Future<void> _openQRScanner() async {
  final status = await Permission.camera.request();

  if (status.isGranted) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => QRScannerScreen(
          onScan: (code) async {
            debugPrint('📦 Scanned session ID: $code');

            const String token = 'YOUR_JWT_TOKEN_HERE'; // Replace with actual secure token

            final result = await AuthService.authorizeWebSession(
              sessionId: code,
              token: token,
            );

            if (result) {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (_) => SessionInfoScreen(sessionId: code),
                ),
              );
            } else {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('❌ Failed to authorize session')),
              );
              Navigator.pop(context);
            }
          },
        ),
      ),
    );
  } else if (status.isPermanentlyDenied) {
    openAppSettings();
  } else {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Camera permission is required.')),
    );
  }
}

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: Center(
        child: ElevatedButton.icon(
          onPressed: _openQRScanner,
          icon: const Icon(Icons.qr_code_scanner),
          label: const Text("Link Web Session"),
        ),
      ),
    );
  }
}

class QRScannerScreen extends StatefulWidget {
  final Function(String code) onScan;

  const QRScannerScreen({super.key, required this.onScan});

  @override
  State<QRScannerScreen> createState() => _QRScannerScreenState();
}

class _QRScannerScreenState extends State<QRScannerScreen> {
  bool _hasScanned = false;
  bool _flashOn = false;
  final MobileScannerController _controller = MobileScannerController();

  void _handleDetection(BarcodeCapture capture) {
    if (_hasScanned) return;

    for (final barcode in capture.barcodes) {
      final code = barcode.rawValue;
      final format = barcode.format;

      if (code != null) {
        _hasScanned = true;
        debugPrint('📦 Scanned Code: $code,',);
   debugPrint(code.runtimeType.toString());
        debugPrint('🔍 Format: $format');
        try {

          debugPrint('📦 Attempting to parse JSON from QR code...');
          // final Map<String, dynamic> data = jsonDecode(code);
          final sessionId = code;

          debugPrint('📦 Extracted session ID: $sessionId');
          widget.onScan(sessionId);
                } catch (e) {
          debugPrint('❌ Invalid QR content: $e');
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Invalid QR code format.')),
          );
          Navigator.pop(context);
        }
        break;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          MobileScanner(
            controller: _controller,
            onDetect: _handleDetection,
          ),
          Positioned(
            top: 48,
            left: 20,
            right: 20,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white),
                  onPressed: () => Navigator.pop(context),
                ),
                IconButton(
                  icon: Icon(
                    _flashOn ? Icons.flash_on : Icons.flash_off,
                    color: Colors.white,
                  ),
                  onPressed: () {
                    _flashOn = !_flashOn;
                    _controller.toggleTorch();
                    setState(() {});
                  },
                ),
              ],
            ),
          ),
          Center(
            child: SizedBox(
              width: 260,
              height: 260,
              child: CustomPaint(painter: CornerFramePainter()),
            ),
          ),
          const Positioned(
            bottom: 100,
            left: 0,
            right: 0,
            child: Center(
              child: Text(
                "Align QR within frame",
                style: TextStyle(color: Colors.white70, fontSize: 16),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class CornerFramePainter extends CustomPainter {
  final Paint _paint = Paint()
    ..color = Colors.cyanAccent
    ..strokeWidth = 4
    ..style = PaintingStyle.stroke;

  @override
  void paint(Canvas canvas, Size size) {
    double length = 30;

    canvas.drawLine(Offset(0, 0), Offset(length, 0), _paint);
    canvas.drawLine(Offset(0, 0), Offset(0, length), _paint);

    canvas.drawLine(Offset(size.width, 0), Offset(size.width - length, 0), _paint);
    canvas.drawLine(Offset(size.width, 0), Offset(size.width, length), _paint);

    canvas.drawLine(Offset(0, size.height), Offset(length, size.height), _paint);
    canvas.drawLine(Offset(0, size.height), Offset(0, size.height - length), _paint);

    canvas.drawLine(Offset(size.width, size.height), Offset(size.width - length, size.height), _paint);
    canvas.drawLine(Offset(size.width, size.height), Offset(size.width, size.height - length), _paint);
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}