// lib/presentation/receive_cryptocurrency/receive_qr.dart
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';

class ReceiveQRbtclightning extends StatefulWidget {
  final String title; // "Charge"
  final String accountLabel; // "LN - Main Account" / "Main Account"
  final String coinName; // "Bitcoin"
  final String iconAsset; // asset path for coin icon
  final bool isLightning; // purple Lightning chip if true

  // Amount info
  final String amount; // "0.01"
  final String symbol; // "BTC"
  final double fiatValue; // 1087.28

  // What to encode in the QR (here: amount only)
  final String qrData;

  const ReceiveQRbtclightning({
    super.key,
    required this.title,
    required this.accountLabel,
    required this.coinName,
    required this.iconAsset,
    required this.isLightning,
    required this.amount,
    required this.symbol,
    required this.fiatValue,
    required this.qrData,
  });

  @override
  State<ReceiveQRbtclightning> createState() => _ReceiveQRbtclightningState();
}

class _ReceiveQRbtclightningState extends State<ReceiveQRbtclightning> {
  final GlobalKey _qrKey = GlobalKey();

  static const Color _pageBg = Color(0xFF0B0D1A); // deep navy bg
  static const Color _chipBg = Color(0xFF1F2431); // account row chip bg
  static const Color _purple = Color(0xFF7C3AED); // lightning pill

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _pageBg,
      body: SafeArea(
        child: Column(
          children: [
            // ===== Header =====
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back_ios_new,
                        color: Colors.white, size: 20),
                    onPressed: () => Navigator.of(context).maybePop(),
                    tooltip: 'Back',
                  ),
                  Text(
                    widget.title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  IconButton(
                    icon:
                        const Icon(Icons.close, color: Colors.white, size: 24),
                    onPressed: () => Navigator.of(context).maybePop(),
                    tooltip: 'Close',
                  ),
                ],
              ),
            ),

            // ===== Account Row (icon + label + Lightning) =====
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: _chipBg,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  children: [
                    // coin icon
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: Image.asset(
                        widget.iconAsset,
                        width: 36,
                        height: 36,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => const CircleAvatar(
                          backgroundColor: Color(0xFF2A2D3A),
                          radius: 18,
                          child: Icon(Icons.currency_bitcoin,
                              color: Colors.white, size: 18),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),

                    // Labels
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  widget.accountLabel,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 8),
                              if (widget.isLightning)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: _purple,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: const [
                                      Icon(Icons.bolt,
                                          size: 14, color: Colors.white),
                                      SizedBox(width: 4),
                                      Text('Lightning',
                                          style: TextStyle(
                                              color: Colors.white,
                                              fontSize: 11)),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                          Text(
                            widget.coinName,
                            style: const TextStyle(
                              color: Color(0xFF9CA3AF),
                              fontSize: 12,
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Right side balance (static here to match screenshot)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: const [
                        Text(
                          '0.00',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                        Text(
                          '= 0.00 USD',
                          style: TextStyle(
                            color: Color(0xFF9CA3AF),
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 20),

            // ===== Payment Title =====
            const Text(
              'Payment',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                letterSpacing: 0.2,
              ),
            ),
            const SizedBox(height: 8),

            // ===== Big Amount =====
            Text(
              '${_fmt(widget.amount)} ${widget.symbol}',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 32,
                fontWeight: FontWeight.w800,
                height: 1.1,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Text(
              '= ${_usd(widget.fiatValue)} USD',
              style: const TextStyle(
                color: Color(0xFF9CA3AF),
                fontSize: 14,
              ),
            ),

            const SizedBox(height: 32),

            // ===== QR =====
            GestureDetector(
              onLongPress: _saveQRToGallery,
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: RepaintBoundary(
                  key: _qrKey,
                  child: QrImageView(
                    data: widget.qrData,
                    version: QrVersions.auto,
                    size: 200,
                    gapless: true,
                    eyeStyle: const QrEyeStyle(
                      eyeShape: QrEyeShape.square,
                      color: Colors.black,
                    ),
                    dataModuleStyle: const QrDataModuleStyle(
                      dataModuleShape: QrDataModuleShape.square,
                      color: Colors.black,
                    ),
                    backgroundColor: Colors.white,
                  ),
                ),
              ),
            ),

            // Spacer to push buttons to bottom
            const Spacer(),

            // ===== Bottom Action Buttons =====
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
              child: Row(
                children: [
                  // Share button (expanded)
                  Expanded(
                    child: SizedBox(
                      height: 52,
                      child: ElevatedButton(
                        onPressed: _share,
                        style: ElevatedButton.styleFrom(
                          elevation: 0,
                          backgroundColor: Colors.white,
                          foregroundColor: _pageBg,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(6),
                          ),
                          textStyle: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        child: const Text('Share'),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Copy button
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(6),
                      onTap: _copyAmount,
                      child: Container(
                        height: 52,
                        width: 52,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                        child: const Icon(
                          Icons.copy_rounded,
                          color: Colors.white,
                          size: 22,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _fmt(String v) {
    // normalize strings like "0.01000000" -> "0.01"
    final d = double.tryParse(v) ?? 0.0;
    var s = d.toStringAsFixed(8);
    s = s.replaceAll(RegExp(r'0+$'), '').replaceAll(RegExp(r'\.$'), '');
    return s.isEmpty ? '0' : s;
  }

  static String _usd(double v) => v.toStringAsFixed(2);

  Future<void> _copyAmount() async {
    final text = '${_fmt(widget.amount)} ${widget.symbol}';
    await Clipboard.setData(ClipboardData(text: text));
    HapticFeedback.selectionClick();
    Fluttertoast.showToast(msg: 'Amount copied');
  }

  Future<void> _share() async {
    // Share amount + symbol. If later you generate an LN invoice string,
    // replace with that instead.
    final text = '${_fmt(widget.amount)} ${widget.symbol}';
    await Share.share(text);
  }

  Future<void> _saveQRToGallery() async {
    try {
      final boundary =
          _qrKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) return;

      final ui.Image image = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      final bytes = byteData?.buffer.asUint8List();
      if (bytes == null) return;

      await Share.shareXFiles(
        [XFile.fromData(bytes, name: 'amount_qr.png', mimeType: 'image/png')],
        subject: 'Charge QR',
        text: 'Scan to pay amount',
      );
      HapticFeedback.mediumImpact();
      Fluttertoast.showToast(msg: 'Long-press: share/save QR');
    } catch (_) {
      Fluttertoast.showToast(msg: 'Couldn’t export QR');
    }
  }
}
