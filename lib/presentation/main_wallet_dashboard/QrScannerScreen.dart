import 'package:cryptowallet/presentation/profile_screen/profile_screen.dart';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

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
        debugPrint('📦 Scanned Code: $code');
        debugPrint('🔍 Format: $format');

        try {
          // If your QR contains JSON, parse it here;
          // otherwise, we assume it’s the session id directly.
          final sessionId = code;
          widget.onScan(sessionId);
        } catch (e) {
          debugPrint('❌ Invalid QR content: $e');
          if (!mounted) return;
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
