// lib/presentation/receive_cryptocurrency/receive_cryptocurrency.dart
import 'dart:ui' as ui;

import 'package:cryptowallet/services/api_service.dart';
import 'package:cryptowallet/stores/wallet_store.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';

// 👇 currency support
import 'package:cryptowallet/core/currency_notifier.dart';
import 'package:cryptowallet/core/currency_adapter.dart';

class ReceiveQR extends StatefulWidget {
  /// Big title at the top, e.g. "Your address to receive BTC"
  final String title;

  /// Base address / invoice text. If empty, we’ll fetch from API.
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

  // Heuristic address validators used by _findAddressForChain/_findAnyAddress
  bool _looksLike(String chain, String addr) {
    final a = addr.trim();

    switch (chain) {
      case 'ETH': // EVM (ETH)
      case 'BNB': // EVM (BSC)
        // 0x + 40 hex chars
        return a.startsWith('0x') &&
            a.length == 42 &&
            RegExp(r'^0x[0-9a-fA-F]{40}$').hasMatch(a);

      case 'TRX':
        // Tron mainnet Base58, typically 34 chars, starts with T
        return a.startsWith('T') && a.length >= 30 && a.length <= 36;

      case 'BTC':
        // Very loose: legacy 1/3 or bech32 bc1
        return a.startsWith('bc1') || a.startsWith('1') || a.startsWith('3');

      case 'SOL':
        // Quick base58-ish check for Solana (no 0/O/I/l), 32–44 chars, not hex
        if (a.startsWith('0x')) return false;
        if (a.length < 32 || a.length > 44) return false;
        return RegExp(r'^[1-9A-HJ-NP-Za-km-z]+$').hasMatch(a);

      case 'XMR':
        // Standard address ~95 chars (integrated ~106), starts with 4 or 8
        return (a.startsWith('4') || a.startsWith('8')) && a.length >= 90;

      case 'LN':
        // Bech32 invoice (lnbc…/lntb…) or lightning address (user@domain)
        final lower = a.toLowerCase();
        return lower.startsWith('ln') || a.contains('@');

      default:
        return a.isNotEmpty;
    }
  }

  // === THEME ===
  static const Color _pageBg = Color(0xFF0B0D1A);
  static const Color _qrCardBg = Colors.white;
  static const Color _addressPill = Color(0xFF1B2037);
  static const Color _copyBtnBg = Color(0xFF262B45);

  // === STATE ===
  late final TextEditingController _satsCtrl;
  bool _expandAmount = true;

  // Address state (may be resolved from API)
  String? _address; // final resolved address to show
  String _shortAddress = '';
  String _qrData = '';

  bool _loadingWallet = false;
  String? _loadErr;

  // Spot price (USD per base asset, e.g., BTC). Used only for fiat preview.
  double _spotUsd = 0.0;
  bool _loadingSpot = false;

  // convenience getters
  String get _baseAddress =>
      (_address?.isNotEmpty ?? false) ? _address! : widget.address;

  bool get _isBtcOnchain =>
      (widget.mode ?? '').toLowerCase() == 'onchain' &&
      (widget.coinId ?? 'BTC').toUpperCase().startsWith('BTC');

  bool get _isLightning =>
      (widget.mode ?? '').toLowerCase() == 'ln' ||
      (widget.coinId ?? '').toUpperCase().startsWith('BTC-LN');

  int get _minSatsDefault => widget.minSats ?? 25000;

  /// Base symbol for price lookup (e.g., "BTC" for BTC/BTC-LN)
  String get _baseSymbolForPrice {
    final id = (widget.coinId ?? '').toUpperCase().trim();
    if (_isLightning) return 'BTC';
    if (id.isEmpty) return 'BTC';
    return id.contains('-') ? id.split('-').first : id;
  }

  @override
  void initState() {
    super.initState();
    _satsCtrl =
        TextEditingController(text: (widget.initialSats ?? 0).toString());
    _satsCtrl.addListener(_onAmountChanged);

    // If an explicit address was passed, use it; else fetch from API
    if (widget.address.trim().isNotEmpty) {
      _address = widget.address.trim();
      _shortAddress = _shorten(_address!);
      _qrData = _composeQrData();
    } else {
      // fetch wallets after first frame (Provider is available)
      WidgetsBinding.instance.addPostFrameCallback((_) => _resolveAddress());
    }

    // Fetch spot price once (USD). Rendering converts to selected currency.
    WidgetsBinding.instance.addPostFrameCallback((_) => _ensureSpotLoaded());
  }

  @override
  void dispose() {
    _satsCtrl.removeListener(_onAmountChanged);
    _satsCtrl.dispose();
    super.dispose();
  }

  // ---------------- Wallet helpers ----------------

  Future<void> _resolveAddress() async {
    setState(() {
      _loadingWallet = true;
      _loadErr = null;
    });

    try {
      // 1) get all wallets
      final wallets = await AuthService.fetchWallets();

      if (wallets.isEmpty) {
        throw Exception('No wallets found for this account.');
      }

      // 2) pick active wallet if available, else first
      String? activeId;
      try {
        activeId = context.read<WalletStore>().activeWalletId;
      } catch (_) {
        // WalletStore not wired — OK: we’ll just use first wallet
      }

      final wallet = _pickWallet(wallets, activeId);

      // 3) choose chain code from coinId/mode
      final chainCode = _preferredChainCode(widget.coinId, widget.mode);

      // 4) extract address for that chain, with generous fallbacks
      String? addr = _findAddressForChain(wallet, chainCode);

      // Last-resort: any address we can find in wallet
      addr ??= _findAnyAddress(wallet, chainCode);

      if (addr == null || addr.isEmpty) {
        // Do not throw; keep screen usable and show a friendly error
        setState(() {
          _loadErr = 'Could not find an address for $chainCode in this wallet.';
        });
        return;
      }

      _address = addr;
      _shortAddress = _shorten(addr);
      _qrData = _composeQrData();
    } catch (e) {
      _loadErr = e.toString();
    } finally {
      if (mounted) {
        setState(() => _loadingWallet = false);
      }
    }
  }

  Map<String, dynamic> _pickWallet(
      List<Map<String, dynamic>> wallets, String? activeId) {
    if (activeId != null && activeId.isNotEmpty) {
      final found = wallets.firstWhere(
        (w) => (w['_id']?.toString() ?? '') == activeId,
        orElse: () => const <String, dynamic>{},
      );
      if (found.isNotEmpty) return found;
    }
    return wallets.first;
  }

  String _preferredChainCode(String? coinId, String? mode) {
    // mode beats coinId for Lightning/on-chain hint
    final m = (mode ?? '').toLowerCase();
    if (m == 'ln') return 'LN';

    // derive from coinId (e.g. "USDT-TRX", "BTC-LN", "ETH", "TRX-TRX")
    final id = (coinId ?? '').toUpperCase().trim();
    if (id.contains('-')) {
      final parts = id.split('-');
      if (parts.length >= 2) {
        final chain = parts.last.trim();
        if (chain.isNotEmpty) return _normalizeChain(chain);
      }
    }

    // single symbol → treat symbol as chain
    if (id.isNotEmpty) return _normalizeChain(id);

    // fallback to BTC if nothing provided
    return 'BTC';
  }

  String _normalizeChain(String chain) {
    final u = chain.toUpperCase();
    switch (u) {
      case 'ETHEREUM':
        return 'ETH';
      case 'TRON':
        return 'TRX';
      case 'BSC':
      case 'BNB CHAIN':
      case 'BNB-CHAIN':
        return 'BNB';
      case 'SOLANA':
        return 'SOL';
      case 'LIGHTNING':
      case 'LN':
        return 'LN';
      default:
        return u; // BTC, ETH, TRX, BNB, SOL, XMR, etc.
    }
  }

  String? _findAddressForChain(Map<String, dynamic> wallet, String chainCode) {
    String norm(String? s) => _normalizeChain((s ?? '').toString());

    String? byKeys(List<String> keys, {bool Function(String)? accept}) {
      for (final k in keys) {
        final v = wallet[k];
        if (v is String) {
          final s = v.trim();
          if (s.isEmpty) continue;
          if (accept == null || accept(s)) return s;
        }
      }
      return null;
    }

    // 1) Prefer chains[] entries
    final chains = (wallet['chains'] as List?) ?? const [];
    for (final c in chains) {
      if (c is! Map) continue;
      final chain = norm(c['chain']?.toString());
      final addr = (c['address']?.toString() ?? '').trim();
      if (chain == chainCode &&
          addr.isNotEmpty &&
          _looksLike(chainCode, addr)) {
        return addr;
      }
    }

    // 2) Flat fields per chain (with validation)
    switch (chainCode) {
      case 'LN':
        return byKeys(
          ['lightningAddress', 'lnInvoice', 'lnurl', 'invoice', 'lightning'],
          accept: (s) => _looksLike('LN', s),
        );

      case 'BTC':
        return byKeys(
          [
            'btcAddress',
            'bitcoinAddress',
            'address_btc',
            'onchainAddress',
            'address'
          ],
          accept: (s) => _looksLike('BTC', s),
        );

      case 'ETH':
        return byKeys(
          [
            'erc20Address',
            'ethAddress',
            'address_eth',
            'evmAddress',
            'address',
            'publicKey'
          ],
          accept: (s) => _looksLike('ETH', s),
        );

      case 'BNB':
        return byKeys(
          [
            'bep20Address',
            'bscAddress',
            'bnbAddress',
            'address_bnb',
            'address',
            'publicKey'
          ],
          accept: (s) => _looksLike('BNB', s), // EVM format
        );

      case 'TRX':
        return byKeys(
          ['trc20Address', 'trxAddress', 'address_trx'],
          accept: (s) => _looksLike('TRX', s),
        );

      case 'SOL':
        return byKeys(
          ['solAddress', 'solanaAddress', 'address_sol'],
          accept: (s) => _looksLike('SOL', s),
        );

      case 'XMR':
        return byKeys(
          ['xmrAddress', 'moneroAddress', 'address_xmr'],
          accept: (s) => _looksLike('XMR', s),
        );

      default:
        return null;
    }
  }

  /// Last-resort fallback to extract any address-looking field from a wallet.
  String? _findAnyAddress(Map<String, dynamic> wallet, String chainCode) {
    // Scan obvious flat fields first
    for (final entry in wallet.entries) {
      final v = entry.value;
      if (v is String) {
        final s = v.trim();
        if (s.isEmpty) continue;
        if (_looksLike(chainCode, s)) return s;
      }
    }

    // Then scan chains[] again (already filtered by _looksLike)
    final chains = (wallet['chains'] as List?) ?? const [];
    for (final c in chains) {
      if (c is! Map) continue;
      final addr = (c['address']?.toString() ?? '').trim();
      final chain = _normalizeChain((c['chain']?.toString() ?? ''));
      if (_looksLike(chainCode, addr) && chain == chainCode) return addr;
    }
    return null;
  }

  // ---------------- Spot price (USD) ----------------

  Future<void> _ensureSpotLoaded() async {
    if (_loadingSpot || _spotUsd > 0) return;
    setState(() => _loadingSpot = true);
    try {
      final sym = _baseSymbolForPrice;
      final map = await AuthService.fetchSpotPrices(symbols: [sym]);
      final v = map[sym] ?? 0.0;
      if (!mounted) return;
      setState(() => _spotUsd = v);
    } catch (_) {
      if (!mounted) return;
      setState(() => _spotUsd = 0.0);
    } finally {
      if (mounted) setState(() => _loadingSpot = false);
    }
  }

  // ---------------- UI ----------------

  @override
  Widget build(BuildContext context) {
    // 👇 adapter rebuilds when user changes currency
    final fx = FxAdapter(context.watch<CurrencyNotifier>());

    final title =
        widget.title.isEmpty ? 'Your address to receive' : widget.title;
    final minError =
        _isBtcOnchain && _validSats() > 0 && _validSats() < _minSatsDefault;
    final screenWidth = MediaQuery.of(context).size.width;
    final qrSize = (screenWidth * 0.20).clamp(240.0, 300.0);

    final isReady =
        (_address?.isNotEmpty ?? false) || widget.address.isNotEmpty;

    // Fiat estimate (selected currency) for sats input (BTC/LN only)
    String? fiatPreview;
    if ((_isBtcOnchain || _isLightning) && _spotUsd > 0) {
      final sats = _validSats();
      if (sats > 0) {
        final btc = sats / 100000000.0;
        final usd = btc * _spotUsd;
        fiatPreview = fx.formatFromUsd(usd);
      }
    }

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

                    if (!isReady || _loadingWallet) ...[
                      const SizedBox(height: 120),
                      const CircularProgressIndicator.adaptive(),
                      const SizedBox(height: 12),
                      if (_loadErr != null)
                        Text(_loadErr!,
                            style: const TextStyle(
                                color: Colors.redAccent, fontSize: 12)),
                      const SizedBox(height: 40),
                    ] else ...[
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
                                  _shortAddress.isNotEmpty
                                      ? _shortAddress
                                      : _shorten(_baseAddress),
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
                              suffix:
                                  _isBtcOnchain || _isLightning ? 'Sats' : '',
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
                            // 👇 Live fiat preview (selected currency) for BTC/LN
                            if (fiatPreview != null) ...[
                              const SizedBox(height: 8),
                              Text(
                                '≈ $fiatPreview',
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],

                      const SizedBox(height: 50),
                    ],
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
                      onPressed: isReady ? _share : null,
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
                        onPressed: isReady
                            ? () {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                        'Pay with BTC account - feature coming soon'),
                                    backgroundColor: Color(0xFF262B45),
                                  ),
                                );
                              }
                            : null,
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
      if (_baseAddress.isEmpty) return '';
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
      if (_baseAddress.isEmpty) return '';
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
      // no need to store fiat; we compute it in build for currency reactivity
    });
  }

  Future<void> _copyAddress() async {
    final text = _qrData.isNotEmpty ? _qrData : _baseAddress;
    if (text.isEmpty) return;
    await Clipboard.setData(ClipboardData(text: text));
    HapticFeedback.selectionClick();
    Fluttertoast.showToast(
      msg: 'Address copied to clipboard',
      backgroundColor: const Color(0xFF262B45),
      textColor: Colors.white,
    );
  }

  Future<void> _share() async {
    final text = _qrData.isNotEmpty ? _qrData : _baseAddress;
    if (text.isEmpty) return;
    Share.share(text, subject: 'Receive Address');
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
        [XFile.fromData(bytes, name: 'receive_qr.png', mimeType: 'image/png')],
        subject: 'Receive QR Code',
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
