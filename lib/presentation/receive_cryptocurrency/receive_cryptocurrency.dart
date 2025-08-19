// lib/presentation/receive_cryptocurrency/receive_cryptocurrency.dart
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';

class ReceiveQR extends StatefulWidget {
  final String title; // e.g. "Your address to receive XRP"
  final String address; // wallet address text

  const ReceiveQR({
    super.key,
    required this.title,
    required this.address,
  });

  @override
  State<ReceiveQR> createState() => _ReceiveQRState();
}

class _ReceiveQRState extends State<ReceiveQR> {
  final GlobalKey _qrKey = GlobalKey();

  // Colors tuned to match the screenshot
  static const Color _pageBg = Color(0xFF0B0D1A); // deep navy
  static const Color _qrCardBg = Colors.white;
  static const Color _addressPill = Color(0xFF1B2037); // bluish pill
  static const Color _copyBtnBg = Color(0xFF262B45); // slightly brighter circle

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        backgroundColor: _pageBg,
        body: SafeArea(
          bottom: false,
          child: Column(
            children: [
              // ======= HEADER =======
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back_ios_new,
                          color: Colors.white, size: 22),
                      onPressed: () => Navigator.of(context).maybePop(),
                      tooltip: 'Back',
                    ),
                    IconButton(
                      icon: const Icon(Icons.close,
                          color: Colors.white, size: 26),
                      onPressed: () => Navigator.of(context).maybePop(),
                      tooltip: 'Close',
                    ),
                  ],
                ),
              ),

              // ======= TITLE =======
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                child: Text(
                  widget.title.isEmpty
                      ? 'Your address to receive XRP'
                      : widget.title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    height: 1.25,
                  ),
                ),
              ),

              const SizedBox(height: 22),

              // QR card (with save on long-press)
              GestureDetector(
                onLongPress: _saveQRToGallery,
                child: Container(
                  margin: const EdgeInsets.symmetric(
                    horizontal: 100,
                  ),
                  decoration: BoxDecoration(
                    color: _qrCardBg,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: RepaintBoundary(
                    key: _qrKey,
                    child: Container(
                      color: _qrCardBg,
                      child: Center(
                        child: QrImageView(
                          data: widget.address.isEmpty
                              ? 'rKXxQ9AmpYKWDHECvERVfduRefDh21e3VF'
                              : widget.address,
                          version: QrVersions.auto,
                          gapless: true,
                          size:
                              190, // 👈 reduce this value (default: fills parent)
                          eyeStyle: const QrEyeStyle(
                            eyeShape: QrEyeShape.square,
                            color: Colors.black,
                          ),
                          dataModuleStyle: const QrDataModuleStyle(
                            dataModuleShape: QrDataModuleShape.square,
                            color: Colors.black,
                          ),
                          backgroundColor: _qrCardBg,
                        ),
                      ),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // Address pill with circular copy icon at the right
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Container(
                  height: 50,
                  decoration: BoxDecoration(
                    color: _addressPill,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      Expanded(
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          physics: const BouncingScrollPhysics(),
                          child: Text(
                            widget.address.isEmpty
                                ? 'rKXxQ9AmpYKWDHECvERVfduRefDh21e3VF'
                                : widget.address,
                            style: const TextStyle(
                              color: Color(0xFFE4E7F5),
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      _CircleIconButton(
                        onTap: _copyAddress,
                        bg: _copyBtnBg,
                        icon: Icons.copy_rounded,
                        iconColor: const Color(0xFFE4E7F5),
                      ),
                    ],
                  ),
                ),
              ),

              // Spacer to push the button to the bottom like the screenshot
              const Spacer(),

              // Big rounded white Share button
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                child: SizedBox(
                  height: 50,
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _share,
                    style: ElevatedButton.styleFrom(
                      elevation: 0,
                      backgroundColor: Colors.white,
                      foregroundColor: _pageBg,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(6),
                      ),
                      textStyle: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    icon: const Icon(Icons.share, size: 22),
                    label: const Text('Share'),
                  ),
                ),
              ),

              // home indicator spacing
              const SizedBox(height: 8),
            ],
          ),
        ));
  }

  Future<void> _copyAddress() async {
    final text = widget.address.isEmpty
        ? 'rKXxQ9AmpYKWDHECvERVfduRefDh21e3VF'
        : widget.address;
    await Clipboard.setData(ClipboardData(text: text));
    HapticFeedback.selectionClick();
    Fluttertoast.showToast(msg: 'Address copied');
  }

  Future<void> _share() async {
    final text = widget.address.isEmpty
        ? 'rKXxQ9AmpYKWDHECvERVfduRefDh21e3VF'
        : widget.address;
    Share.share(text);
  }

  Future<void> _saveQRToGallery() async {
    // Renders the QR area as PNG bytes and puts it in Photo/Downloads via share sheet.
    try {
      final boundary =
          _qrKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) return;

      final ui.Image image = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      final bytes = byteData?.buffer.asUint8List();
      if (bytes == null) return;

      // Use share sheet for a frictionless “Save Image” on iOS; or connect your gallery saver.
      await Share.shareXFiles(
        [XFile.fromData(bytes, name: 'receive_qr.png', mimeType: 'image/png')],
        subject: 'Wallet QR',
        text: 'Wallet address QR',
      );
      HapticFeedback.mediumImpact();
      Fluttertoast.showToast(msg: 'Long‑press: share/save QR');
    } catch (_) {
      Fluttertoast.showToast(msg: 'Couldn’t export QR');
    }
  }
}

class _CircleIconButton extends StatelessWidget {
  final VoidCallback onTap;
  final IconData icon;
  final Color bg;
  final Color iconColor;

  const _CircleIconButton({
    required this.onTap,
    required this.icon,
    required this.bg,
    required this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: bg,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: const SizedBox(
          height: 40,
          width: 40,
          child: Icon(Icons.copy_rounded, size: 16, color: Color(0xFFE4E7F5)),
        ),
      ),
    );
  }
}
