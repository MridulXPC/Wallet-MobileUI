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
  bool isScanning = false;

  Future<bool> _authorizeWebSession(String sessionCode) async { 
    try {
      final response = await http.post(
        Uri.parse('https://yourbackend.com/api/link-web-session'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'session_code': sessionCode,
          'user_token': 'mock-mobile-user-token', // Replace with real token
        }),
      );
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  Future<void> _openQRScanner() async {
    final status = await Permission.camera.request();

    if (status.isGranted) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => QRScannerScreen(
            onScan: (code) async {
              final result = await _authorizeWebSession(code);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    result
                        ? '✅ Web session authorized!'
                        : '❌ Failed to authorize session',
                  ),
                ),
              );
              Navigator.pop(context);
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
    final code = capture.barcodes.firstOrNull?.rawValue;
    if (code != null) {
      _hasScanned = true;
      widget.onScan(code);
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

          // Top bar with back and flash
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

          // Scan frame
          Center(
            child: SizedBox(
              width: 260,
              height: 260,
              child: CustomPaint(painter: CornerFramePainter()),
            ),
          ),

          // Instruction
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

    // Top left
    canvas.drawLine(Offset(0, 0), Offset(length, 0), _paint);
    canvas.drawLine(Offset(0, 0), Offset(0, length), _paint);

    // Top right
    canvas.drawLine(Offset(size.width, 0), Offset(size.width - length, 0), _paint);
    canvas.drawLine(Offset(size.width, 0), Offset(size.width, length), _paint);

    // Bottom left
    canvas.drawLine(Offset(0, size.height), Offset(length, size.height), _paint);
    canvas.drawLine(Offset(0, size.height), Offset(0, size.height - length), _paint);

    // Bottom right
    canvas.drawLine(Offset(size.width, size.height), Offset(size.width - length, size.height), _paint);
    canvas.drawLine(Offset(size.width, size.height), Offset(size.width, size.height - length), _paint);
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}