import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';

class ReceiveQR extends StatefulWidget {
  /// Big title at the top, e.g. "Your address to receive BTC"
  final String title;

  /// Base address / invoice text
  final String address;

  /// Optional: Coin/network id (e.g. "BTC", "BTC-LN", "USDT-TRX")
  final String? coinId;

  /// Optional: "onchain" | "ln"
  final String? mode;

  /// Optional prefilled sats (as string/int)
  final int? initialSats;

  /// Optional minimum sats for validation (default 25_000 for BTC on-chain)
  final int? minSats;

  const ReceiveQR({
    super.key,
    required this.title,
    required this.address,
    this.coinId,
    this.mode,
    this.initialSats,
    this.minSats,
  });

  @override
  State<ReceiveQR> createState() => _ReceiveQRState();
}

class _ReceiveQRState extends State<ReceiveQR> {
  final GlobalKey _qrKey = GlobalKey();

  // === THEME ===
  static const Color _pageBg = Color(0xFF0B0D1A);
  static const Color _qrCardBg = Colors.white;
  static const Color _addressPill = Color(0xFF1B2037);
  static const Color _copyBtnBg = Color(0xFF262B45);

  // === STATE ===
  late final TextEditingController _satsCtrl;
  bool _expandAmount = true;
  String _qrData = '';
  String _shortAddress = '';
  String get _baseAddress => widget.address;

  // convenience
  bool get _isBtcOnchain =>
      (widget.mode ?? '').toLowerCase() == 'onchain' &&
      (widget.coinId ?? 'BTC').toUpperCase().startsWith('BTC');

  bool get _isLightning =>
      (widget.mode ?? '').toLowerCase() == 'ln' ||
      (widget.coinId ?? '').toUpperCase().startsWith('BTC-LN');

  int get _minSatsDefault => widget.minSats ?? 25000;

  @override
  void initState() {
    super.initState();
    _satsCtrl =
        TextEditingController(text: (widget.initialSats ?? 0).toString());
    _shortAddress = _shorten(widget.address);
    _qrData = _composeQrData();
    _satsCtrl.addListener(_onAmountChanged);
  }

  @override
  void dispose() {
    _satsCtrl.removeListener(_onAmountChanged);
    _satsCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final title =
        widget.title.isEmpty ? 'Your address to receive' : widget.title;
    final minError =
        _isBtcOnchain && _validSats() > 0 && _validSats() < _minSatsDefault;
    final screenWidth = MediaQuery.of(context).size.width;
    final qrSize = (screenWidth * 0.20).clamp(240.0, 300.0);

    return Scaffold(
      backgroundColor: _pageBg,
      body: SafeArea(
        child: Column(
          children: [
            // HEADER
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back_ios_new,
                        color: Colors.white, size: 18),
                    onPressed: () => Navigator.of(context).maybePop(),
                    tooltip: 'Back',
                  ),
                  IconButton(
                    icon:
                        const Icon(Icons.close, color: Colors.white, size: 18),
                    onPressed: () => Navigator.of(context).maybePop(),
                    tooltip: 'Close',
                  ),
                ],
              ),
            ),

            // SCROLLABLE CONTENT
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  children: [
                    // TITLE
                    Text(
                      title,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        height: 1.25,
                      ),
                    ),

                    const SizedBox(height: 10),

                    // QR CODE CARD
                    GestureDetector(
                      onLongPress: _saveQRToGallery,
                      child: Container(
                        decoration: BoxDecoration(
                          color: _qrCardBg,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.15),
                              blurRadius: 6,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: RepaintBoundary(
                          key: _qrKey,
                          child: QrImageView(
                            data: _qrData.isEmpty ? _baseAddress : _qrData,
                            version: QrVersions.auto,
                            gapless: true,
                            size: qrSize,
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

                    const SizedBox(height: 20),

                    // ADDRESS PILL
                    Container(
                      height: 40,
                      decoration: BoxDecoration(
                        color: _addressPill,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      padding: const EdgeInsets.only(left: 16, right: 10),
                      child: Row(
                        children: [
                          Expanded(
                            child: SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              physics: const BouncingScrollPhysics(),
                              child: Text(
                                _shortAddress,
                                style: const TextStyle(
                                  color: Color(0xFFE4E7F5),
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                  letterSpacing: 0.2,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          _CircleIconButton(
                            onTap: _copyAddress,
                            bg: _copyBtnBg,
                            icon: Icons.copy_rounded,
                            iconColor: const Color(0xFFE4E7F5),
                            size: 32,
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 10),

                    // SET AMOUNT HEADER
                    _SetAmountHeader(
                      expanded: _expandAmount,
                      onToggle: () =>
                          setState(() => _expandAmount = !_expandAmount),
                    ),

                    // AMOUNT INPUT SECTION
                    if (_expandAmount) ...[
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Set receiving amount',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 12),
                          _AmountField(
                            controller: _satsCtrl,
                            suffix: _isBtcOnchain || _isLightning ? 'Sats' : '',
                            hint: '0',
                            onChanged: (_) => _onAmountChanged(),
                          ),
                          if (minError) ...[
                            const SizedBox(height: 8),
                            Text(
                              'Minimum amount is ${_formatNumber(_minSatsDefault)} Sats',
                              style: const TextStyle(
                                color: Colors.redAccent,
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],

                    const SizedBox(height: 50),
                  ],
                ),
              ),
            ),

            // BUTTONS - FIXED AT BOTTOM
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: _pageBg,
                border: Border(
                  top: BorderSide(
                    color: Colors.white.withOpacity(0.05),
                    width: 1,
                  ),
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // PRIMARY BUTTON: Share
                  SizedBox(
                    height: 40,
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
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      icon: const Icon(Icons.share_outlined, size: 20),
                      label: const Text('Share'),
                    ),
                  ),

                  // SECONDARY BUTTON: Pay with my BTC account
                  if (_isBtcOnchain) ...[
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 40,
                      width: double.infinity,
                      child: OutlinedButton(
                        onPressed: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                  'Pay with BTC account - feature coming soon'),
                              backgroundColor: Color(0xFF262B45),
                            ),
                          );
                        },
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white,
                          side: const BorderSide(
                              color: Colors.white24, width: 1.5),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(6),
                          ),
                          textStyle: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        child: const Text('Pay with my BTC account'),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // === HELPERS ===

  /// Returns valid sats (>=0) from the text field, or 0 if invalid.
  int _validSats() {
    final raw = _satsCtrl.text.trim();
    if (raw.isEmpty) return 0;
    final n = int.tryParse(raw.replaceAll(',', '')) ?? 0;
    return n < 0 ? 0 : n;
  }

  /// Rebuild the QR payload based on mode/address and current sats.
  String _composeQrData() {
    final sats = _validSats();

    // BTC on-chain → "bitcoin:<addr>?amount=<btc>"
    if (_isBtcOnchain) {
      if (sats > 0) {
        final btc = sats / 100000000.0;
        String amount = btc
            .toStringAsFixed(8)
            .replaceAll(RegExp(r'0+$'), '')
            .replaceAll(RegExp(r'\.$'), '');
        return 'bitcoin:${_baseAddress}?amount=$amount';
      }
      return 'bitcoin:${_baseAddress}';
    }

    // Lightning
    if (_isLightning) {
      if (sats > 0) {
        return 'lightning:${_baseAddress}?amount_sats=$sats';
      }
      return 'lightning:${_baseAddress}';
    }

    // Other coins → just show the address
    return _baseAddress;
  }

  void _onAmountChanged() {
    setState(() {
      _qrData = _composeQrData();
    });
  }

  Future<void> _copyAddress() async {
    await Clipboard.setData(
        ClipboardData(text: _qrData.isNotEmpty ? _qrData : _baseAddress));
    HapticFeedback.selectionClick();
    Fluttertoast.showToast(
      msg: 'Address copied to clipboard',
      backgroundColor: const Color(0xFF262B45),
      textColor: Colors.white,
    );
  }

  Future<void> _share() async {
    final text = _qrData.isNotEmpty ? _qrData : _baseAddress;
    Share.share(text, subject: 'Bitcoin Address');
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
        [XFile.fromData(bytes, name: 'bitcoin_qr.png', mimeType: 'image/png')],
        subject: 'Bitcoin QR Code',
        text: 'Payment QR Code',
      );
      HapticFeedback.mediumImpact();
      Fluttertoast.showToast(
        msg: 'QR code shared successfully',
        backgroundColor: const Color(0xFF262B45),
        textColor: Colors.white,
      );
    } catch (e) {
      Fluttertoast.showToast(
        msg: 'Could not export QR code',
        backgroundColor: Colors.redAccent,
        textColor: Colors.white,
      );
    }
  }

  String _shorten(String v) {
    if (v.length <= 36) return v;
    return '${v.substring(0, 20)}…${v.substring(v.length - 16)}';
  }

  String _formatNumber(int number) {
    return number.toString().replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (Match m) => '${m[1]},',
        );
  }
}

// ===== UI SUBWIDGETS =====

class _SetAmountHeader extends StatelessWidget {
  final bool expanded;
  final VoidCallback onToggle;

  const _SetAmountHeader({
    required this.expanded,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onToggle,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'Set amount to receive',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                fontSize: 16,
              ),
            ),
            const SizedBox(width: 8),
            AnimatedRotation(
              turns: expanded ? 0.5 : 0,
              duration: const Duration(milliseconds: 200),
              child: const Icon(
                Icons.keyboard_arrow_down,
                color: Colors.white,
                size: 24,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AmountField extends StatelessWidget {
  final TextEditingController controller;
  final String suffix;
  final String hint;
  final ValueChanged<String>? onChanged;

  const _AmountField({
    required this.controller,
    required this.suffix,
    required this.hint,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 40,
      decoration: BoxDecoration(
        color: const Color(0xFF15192B),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: Colors.white.withOpacity(0.15),
          width: 1,
        ),
      ),
      child: TextField(
        controller: controller,
        keyboardType: const TextInputType.numberWithOptions(
          signed: false,
          decimal: false,
        ),
        inputFormatters: [
          FilteringTextInputFormatter.digitsOnly,
        ],
        style: const TextStyle(
          color: Colors.white,
          fontSize: 16,
          fontWeight: FontWeight.w500,
        ),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(
            color: Colors.white.withOpacity(0.4),
            fontSize: 16,
          ),
          filled: false,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
          suffixIcon: suffix.isEmpty
              ? null
              : Padding(
                  padding: const EdgeInsets.only(right: 16),
                  child: Center(
                    widthFactor: 1,
                    child: Text(
                      suffix,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ),
          suffixIconConstraints:
              const BoxConstraints(minWidth: 0, minHeight: 0),
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
        ),
        onChanged: onChanged,
      ),
    );
  }
}

class _CircleIconButton extends StatelessWidget {
  final VoidCallback onTap;
  final IconData icon;
  final Color bg;
  final Color iconColor;
  final double size;

  const _CircleIconButton({
    required this.onTap,
    required this.icon,
    required this.bg,
    required this.iconColor,
    this.size = 25,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: bg,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(
          height: size,
          width: size,
          child: Icon(icon, size: 18, color: iconColor),
        ),
      ),
    );
  }
}
