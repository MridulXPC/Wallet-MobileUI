// lib/presentation/main_wallet_dashboard/widgets/crypto_stat_card.dart
import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:cryptowallet/presentation/receive_cryptocurrency/receive_cryptocurrency.dart';
import 'package:cryptowallet/stores/coin_store.dart';
import 'package:cryptowallet/presentation/main_wallet_dashboard/QrScannerScreen.dart';
import 'package:cryptowallet/presentation/main_wallet_dashboard/widgets/action_buttons_grid_widget.dart';
import 'package:cryptowallet/presentation/profile_screen/SessionInfoScreen.dart';
import 'package:cryptowallet/presentation/send_cryptocurrency/send_cryptocurrency.dart';
// <-- adjust path if different
import 'package:cryptowallet/services/api_service.dart';

import 'package:flutter/foundation.dart' show compute;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

class CryptoStatCard extends StatefulWidget {
  /// Canonical coin key from CoinStore, e.g. "BTC", "ETH", "USDT-ETH"
  final String coinId;

  /// Optional title override; if null we’ll use Coin.name from Provider.
  final String? title;

  /// Cards with the same colorKey will be considered the "same color".
  /// Recommended: the icon assetPath.
  final String? colorKey;

  /// Fallback price (used before first WS tick arrives)
  final double currentPrice;

  /// Kept for compatibility with your current API (unused by live block)
  final List<double> monthlyData;
  final List<double> todayData;
  final List<double> yearlyData;

  const CryptoStatCard({
    super.key,
    required this.coinId,
    this.title,
    this.colorKey,
    required this.currentPrice,
    required this.monthlyData,
    required this.todayData,
    required this.yearlyData,
  });

  @override
  State<CryptoStatCard> createState() => _CryptoStatCardState();
}

class _CryptoStatCardState extends State<CryptoStatCard> {
  // ===== Asset provider cache (fast icon reuse) =====
  static final Map<String, AssetImage> _assetProviderCache = {};
  AssetImage? _getAssetProvider(String key, String? assetPath) {
    if (assetPath == null || assetPath.isEmpty) return null;
    final cached = _assetProviderCache[key];
    if (cached != null && cached.assetName == assetPath) return cached;
    final created = AssetImage(assetPath);
    _assetProviderCache[key] = created;
    return created;
  }

  // ===== Dominant color cache: assetOrNameKey -> Color =====
  static final Map<String, Color> _dominantColorCache = {};

  String _colorCacheKey({String? assetPath, required String nameOrId}) {
    return (assetPath != null && assetPath.isNotEmpty)
        ? 'asset:$assetPath'
        : 'name:$nameOrId';
  }

  Color _dominantColor = const Color(0xFF1A73E8); // default blue
  bool _isColorReady = false;
  Timer? _debounce;

  // ===== Live price from Binance WS =====
  WebSocketChannel? _ws;
  StreamSubscription? _wsSub;
  Timer? _reconnectTimer;

  double? _livePrice; // "c" — last price (used for the main price UI)
  double? _changePercent24; // "P" — 24h % change
  double? _changeAbs24; // "p" — 24h absolute change (USD)

  @override
  void initState() {
    super.initState();

    // Provide an immediate coin-specific fallback so there’s no shared “blue flash”.
    final store = context.read<CoinStore>();
    final coin = store.getById(widget.coinId);
    final initial = _fallbackColor(widget.title ?? coin?.name ?? widget.coinId);
    _dominantColor = initial;
    _isColorReady = true;

    _resolveDominantColor();
    _connectTickerIfSupported();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Precache small icon for the current coin
    final coin = context.read<CoinStore>().getById(widget.coinId);
    final assetPath = coin?.assetPath;
    final provider = _getAssetProvider(widget.coinId, assetPath);
    if (provider != null) {
      precacheImage(provider, context);
    }

    // Precache BIG, soft watermark
    final bg = context.read<CoinStore>().cardAssetFor(widget.coinId);
    if (bg != null) precacheImage(AssetImage(bg), context);
  }

  @override
  void didUpdateWidget(CryptoStatCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.coinId != widget.coinId ||
        oldWidget.title != widget.title ||
        oldWidget.colorKey != widget.colorKey) {
      final coin = context.read<CoinStore>().getById(widget.coinId);
      final assetPath = coin?.assetPath;
      final provider = _getAssetProvider(widget.coinId, assetPath);
      if (provider != null) {
        precacheImage(provider, context);
      }
      final bg = context.read<CoinStore>().cardAssetFor(widget.coinId);
      if (bg != null) precacheImage(AssetImage(bg), context);

      _resolveDominantColor();

      // Reconnect WS for the new coin
      _disposeWs();
      _connectTickerIfSupported();
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _disposeWs();
    super.dispose();
  }

  // ------------------- Dominant color helpers -------------------
  void _resolveDominantColor() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 40), _extractDominantColor);
  }

  Future<void> _extractDominantColor() async {
    final store = context.read<CoinStore>();
    final coin = store.getById(widget.coinId);
    final assetPath = coin?.assetPath;
    final nameOrId = widget.title ?? coin?.name ?? widget.coinId;

    final cacheKey = _colorCacheKey(assetPath: assetPath, nameOrId: nameOrId);

    final cached = _dominantColorCache[cacheKey];
    if (cached != null) {
      if (!mounted) return;
      setState(() {
        _dominantColor = cached;
        _isColorReady = true;
      });
      return;
    }

    if (assetPath == null || assetPath.isEmpty) {
      _dominantColorCache[cacheKey] = _dominantColor;
      return;
    }

    try {
      final ByteData data = await rootBundle.load(assetPath);
      final Uint8List bytes = data.buffer.asUint8List();

      final ui.Codec codec = await ui.instantiateImageCodec(bytes,
          targetWidth: 48, targetHeight: 48);
      final ui.FrameInfo frame = await codec.getNextFrame();
      final ui.Image img = frame.image;
      final ByteData? rgba =
          await img.toByteData(format: ui.ImageByteFormat.rawRgba);
      if (rgba == null) throw StateError('rgba null');

      final int rgb = await compute(
          _dominantColorFromRgbaIsolate, rgba.buffer.asUint8List());

      final color = Color(0xFF000000 | rgb);
      if (!mounted) return;
      setState(() {
        _dominantColor = color;
        _isColorReady = true;
      });
      _dominantColorCache[cacheKey] = color;
    } catch (_) {
      _dominantColorCache[cacheKey] = _dominantColor;
    }
  }

  static int _dominantColorFromRgbaIsolate(Uint8List pixels) {
    // Returns 0xRRGGBB
    final Map<int, int> counts = {};
    for (int i = 0; i + 3 < pixels.length; i += 64) {
      final int r = pixels[i];
      final int g = pixels[i + 1];
      final int b = pixels[i + 2];
      final int a = pixels[i + 3];
      if (a < 128) continue;

      final double lum = (0.299 * r + 0.587 * g + 0.114 * b) / 255.0;
      if (lum > 0.92 || lum < 0.08) continue;

      final int key = (r << 16) | (g << 8) | b;
      counts[key] = (counts[key] ?? 0) + 1;
    }
    if (counts.isEmpty) return 0x1A73E8;
    return counts.entries.reduce((a, b) => a.value > b.value ? a : b).key;
  }

  Color _fallbackColor(String nameOrSymbol) {
    const fallback = Color(0xFF1A73E8);
    const map = <String, Color>{
      'Bitcoin': Color(0xFFF7931A),
      'BTC': Color(0xFFF7931A),
      'Ethereum': Color(0xFF627EEA),
      'ETH': Color(0xFF627EEA),
      'Solana': Color(0xFF14F195),
      'SOL': Color(0xFF14F195),
      'Tron': Color(0xFFEB0029),
      'TRX': Color(0xFFEB0029),
      'Tether': Color(0xFF26A17B),
      'USDT': Color(0xFF26A17B),
      'BNB': Color(0xFFF3BA2F),
      'Monero': Color(0xFFF26822),
      'XMR': Color(0xFFF26822),
    };
    return map[nameOrSymbol] ?? fallback;
  }

  LinearGradient _gradient() {
    if (!_isColorReady) {
      return const LinearGradient(
        colors: [Color.fromARGB(255, 100, 162, 228), Color(0xFF1A73E8)],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      );
    }
    final hsl = HSLColor.fromColor(_dominantColor);
    final light = hsl
        .withLightness(math.min(0.72, hsl.lightness + 0.22))
        .withSaturation(math.min(1.0, hsl.saturation + 0.08))
        .toColor();
    final dark = hsl
        .withLightness(math.max(0.28, hsl.lightness - 0.22))
        .withSaturation(math.min(1.0, hsl.saturation + 0.18))
        .toColor();
    return LinearGradient(
      colors: [light, dark],
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
    );
  }

  // ------------------- Binance WebSocket -------------------
  String? _binanceSymbolFor(String coinId) {
    // Collapse networked IDs to base symbol
    final base = coinId.contains('-') ? coinId.split('-').first : coinId;
    switch (base.toUpperCase()) {
      case 'BTC':
        return 'btcusdt';
      case 'ETH':
        return 'ethusdt';
      case 'BNB':
        return 'bnbusdt';
      case 'SOL':
        return 'solusdt';
      case 'TRX':
        return 'trxusdt';
      case 'XMR':
        return 'xmrusdt';
      // USDT is the quote currency; skip live feed for it
      case 'USDT':
        return null;
      default:
        return null;
    }
  }

  void _connectTickerIfSupported() {
    final sym = _binanceSymbolFor(widget.coinId);
    if (sym == null) return;

    final url = 'wss://stream.binance.com:9443/ws/$sym@ticker';

    _disposeWs();
    try {
      _ws = WebSocketChannel.connect(Uri.parse(url));
      _wsSub = _ws!.stream.listen(
        (raw) {
          try {
            final data = jsonDecode(raw as String) as Map<String, dynamic>;
            final last =
                double.tryParse(data['c']?.toString() ?? ''); // last price
            final pct =
                double.tryParse(data['P']?.toString() ?? ''); // % change 24h
            final abs =
                double.tryParse(data['p']?.toString() ?? ''); // abs change 24h

            if (last != null) {
              if (!mounted) return;
              setState(() {
                _livePrice = last;
                _changePercent24 = pct ?? _changePercent24;
                _changeAbs24 = abs ?? _changeAbs24;
              });
            }
          } catch (_) {}
        },
        onDone: _scheduleReconnect,
        onError: (_) => _scheduleReconnect(),
        cancelOnError: true,
      );
    } catch (_) {
      _scheduleReconnect();
    }
  }

  void _scheduleReconnect() {
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(const Duration(seconds: 3), () {
      if (!mounted) return;
      _connectTickerIfSupported();
    });
  }

  void _disposeWs() {
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _wsSub?.cancel();
    _wsSub = null;
    _ws?.sink.close();
    _ws = null;
  }

  // ------------------- UI helpers -------------------
  // Always show at least 4 decimals for the last price.
  String _formatLastPrice(double v) => v.toStringAsFixed(4);

  // ------------------- Actions -------------------

  // Choose mode for ReceiveQR from coinId (Lightning vs on-chain BTC vs others)
  String? _modeForCoinId(String coinId) {
    final up = coinId.toUpperCase();
    if (up.endsWith('-LN') || up.contains('-LN')) return 'ln'; // BTC-LN etc.
    if (up.startsWith('BTC')) return 'onchain'; // BTC on-chain
    return null; // other chains (ETH/TRX/BNB/SOL/XMR/USDT-TRX, etc.)
  }

  void _openReceive() {
    final coin = context.read<CoinStore>().getById(widget.coinId);
    final pretty = coin?.name ?? widget.coinId;
    final mode = _modeForCoinId(widget.coinId);

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ReceiveQR(
          title: 'Your address to receive $pretty',
          address: '', // let ReceiveQR use active wallet & chain
          coinId: widget.coinId, // pass SAME coinId as the card
          mode: mode, // 'ln' / 'onchain' / null
        ),
      ),
    );
  }

  Future<void> _openQRScanner() async {
    final status = await Permission.camera.request();

    if (status.isGranted) {
      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => QRScannerScreen(
            onScan: (code) async {
              try {
                String? token = await AuthService.getStoredToken();

                if (token == null) {
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                          '❌ Authentication required. Please login first.'),
                    ),
                  );
                  Navigator.pop(context);
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
                          result.message ?? '❌ Failed to authorize session'),
                    ),
                  );
                  Navigator.pop(context);
                }
              } catch (_) {
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                      content:
                          Text('❌ An error occurred during authorization')),
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
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Camera permission is required.')),
      );
    }
  }

  // Open Send screen with USD prefill
  void _openSendWithUsd(double usd) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SendCryptocurrency(
          title: 'Insert Amount',
          initialCoinId: widget.coinId, // preselect same coin as the card
          startInUsd: true, // USD tab selected
          initialUsd: usd, // prefill amount
        ),
      ),
    );
  }

  // Diagonal helper: true => topRight -> bottomLeft, false => opposite
  Alignment _diag({bool topRightToBottomLeft = true, double k = 1.15}) =>
      topRightToBottomLeft ? Alignment(-k, k) : Alignment(k, -k);

  BoxDecoration _cardDecoration({required double radius, String? assetPath}) {
    return BoxDecoration(
      gradient: _gradient(),
      borderRadius: BorderRadius.circular(radius), // radius = 6
      image: (assetPath == null)
          ? null
          : DecorationImage(
              image: AssetImage(assetPath),
              fit: BoxFit.contain,
              alignment: _diag(topRightToBottomLeft: true, k: 1.2),
              colorFilter: ColorFilter.mode(
                _dominantColor.withOpacity(0.55), // soft watermark
                BlendMode.srcATop,
              ),
            ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final coin = context.watch<CoinStore>().getById(widget.coinId);
    final title = widget.title ?? coin?.name ?? 'Unknown';
    final screenWidth = MediaQuery.of(context).size.width;
    final dpr = MediaQuery.of(context).devicePixelRatio;
    final isTablet = screenWidth > 600;
    final isLarge = screenWidth > 900;

    // Auto-compact if device is short or text scale is large
    final textScale = MediaQuery.of(context).textScaleFactor;
    final compact = MediaQuery.of(context).size.height < 600 || textScale > 1.1;
    SizedBox gap(double tight, double roomy) =>
        SizedBox(height: compact ? tight : roomy);

    // Responsive dims
    final cardPadH = compact ? 10.0 : 12.0;
    final radius = 6.0;
    final iconSize = isLarge ? 40.0 : (isTablet ? 36.0 : 32.0);
    final priceFs = isLarge ? 32.0 : (isTablet ? 30.0 : 28.0);
    final hMargin = (screenWidth * 0.02).clamp(8.0, 20.0);
    final cacheW = (iconSize * dpr).round();
    final cacheH = (iconSize * dpr).round();

    final cardAssetPath = context.select<CoinStore, String?>(
      (s) => s.cardAssetFor(widget.coinId),
    );

    // Live or fallback price
    final livePrice = _livePrice ?? widget.currentPrice;

    // Compose “▲/▼X.XX% (+$Y.YYYY)” from P and p
    final pct = _changePercent24; // 24h % change
    final abs = _changeAbs24; // 24h absolute change ($)
    final isUp = (pct ?? 0) >= 0;

    String changeLine;
    if (pct == null && abs == null) {
      changeLine = '—';
    } else {
      final pctPart = (pct == null)
          ? '—'
          : '${isUp ? '▲' : '▼'}${pct.abs().toStringAsFixed(2)}%';

      // four decimals for the +/- $ value
      final absPart = (abs == null)
          ? ''
          : ' (${abs >= 0 ? '+' : '-'}\$${abs.abs().toStringAsFixed(4)})';

      changeLine = '$pctPart$absPart';
    }

    return Container(
      margin:
          EdgeInsets.symmetric(vertical: compact ? 0 : 0, horizontal: hMargin),
      padding: EdgeInsets.symmetric(vertical: 0, horizontal: cardPadH),
      decoration: _cardDecoration(radius: radius, assetPath: cardAssetPath),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Text(
                  '$title price',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: isLarge ? 16 : (isTablet ? 15 : 14),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.qr_code_scanner, color: Colors.white),
                onPressed: _openQRScanner,
                tooltip: 'Scan',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),

          // Price row with small coin icon
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Selector<CoinStore, String?>(
                selector: (_, s) => s.getById(widget.coinId)?.assetPath,
                builder: (context, assetPath, _) {
                  final provider = _getAssetProvider(widget.coinId, assetPath);
                  if (provider == null) {
                    return Icon(Icons.currency_bitcoin,
                        color: Colors.white, size: iconSize);
                  }
                  return Image.asset(
                    assetPath!,
                    width: iconSize,
                    height: iconSize,
                    gaplessPlayback: true,
                    filterQuality: FilterQuality.low,
                    cacheWidth: cacheW,
                    cacheHeight: cacheH,
                  );
                },
              ),
              const SizedBox(width: 8),
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    '\$${_formatLastPrice(livePrice)}', // <-- 4 decimals
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: priceFs,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
          gap(4, 6),

          // Change line
          Text(
            changeLine,
            style: TextStyle(
              color: pct == null
                  ? Colors.white70
                  : (isUp ? Colors.greenAccent : Colors.redAccent),
              fontSize: isLarge ? 16 : (isTablet ? 15 : 14),
              fontWeight: FontWeight.w500,
            ),
          ),
          gap(8, 10),

          // CTA line
          Text(
            'Start investing – buy your first $title now!',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: isLarge ? 14 : (isTablet ? 17 : 14),
            ),
          ),
          gap(8, 10),

          // Amount chips → open Send with USD prefill
          Row(
            children: [
              Expanded(
                child: _AmountButton(
                  amount: '\$100',
                  isLarge: false,
                  onTap: () => _openSendWithUsd(100),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _AmountButton(
                  amount: '\$200',
                  isLarge: false,
                  onTap: () => _openSendWithUsd(200),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _AmountButton(
                  amount: '\$500',
                  isLarge: false,
                  onTap: () => _openSendWithUsd(500),
                ),
              ),
            ],
          ),

          // Actions row
          gap(8, 10),
          ActionButtonsGridWidget(
            isLarge: isLarge,
            isTablet: isTablet,
            coinId: widget.coinId,
            onReceive: _openReceive, // <-- wire Receive to correct chain
          ),
        ],
      ),
    );
  }
}

class CryptoStatsPager extends StatefulWidget {
  const CryptoStatsPager({
    super.key,
    required this.cards,
    this.viewportPeek = 0.95,
    this.height = 360,
    this.showArrows = true,
    this.showDots = true,
    this.scrollable = true,
  });

  /// May contain duplicates or mixed widgets.
  /// This widget guarantees only ONE card per color (when CryptoStatCard.colorKey is provided).
  final List<Widget> cards;
  final double viewportPeek;
  final double height;
  final bool showArrows;
  final bool showDots;
  final bool scrollable;

  @override
  State<CryptoStatsPager> createState() => _CryptoStatsPagerState();
}

class _CryptoStatsPagerState extends State<CryptoStatsPager> {
  late final PageController _controller;
  int _index = 0;

  @override
  void initState() {
    super.initState();
    _controller = PageController(viewportFraction: widget.viewportPeek);
  }

  Object _identityFor(Widget w) {
    if (w is CryptoStatCard) {
      if (w.colorKey != null && w.colorKey!.isNotEmpty) {
        return 'color:${w.colorKey}';
      }
      return 'coin:${w.coinId}';
    }
    final k = w.key;
    if (k is ValueKey) {
      return k.value ?? '${w.runtimeType}-${w.toStringShort()}';
    }
    return '${w.runtimeType}-${w.toStringShort()}';
  }

  List<Widget> _dedupeByIdentity(List<Widget> cards) {
    final seen = <Object>{};
    final out = <Widget>[];
    for (final w in cards) {
      final id = _identityFor(w);
      if (seen.add(id)) out.add(w);
    }
    return out;
  }

  void _go(int delta, int maxIndex) {
    final next = (_index + delta).clamp(0, maxIndex);
    if (next == _index) return;
    setState(() => _index = next);
    _controller.animateToPage(
      next,
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final uniqueCards = _dedupeByIdentity(widget.cards);

    final maxIndex = (uniqueCards.length - 1).clamp(0, uniqueCards.length - 1);
    if (_index > maxIndex) {
      _index = maxIndex;
    }

    if (uniqueCards.isEmpty) {
      return SizedBox(
        height: widget.height,
        child: const Center(
          child: Text('No coins to display',
              style: TextStyle(color: Colors.white70)),
        ),
      );
    }

    return SizedBox(
      height: widget.height,
      child: Stack(
        alignment: Alignment.center,
        children: [
          PageView.builder(
            controller: _controller,
            padEnds: false,
            physics: widget.scrollable
                ? const BouncingScrollPhysics()
                : const NeverScrollableScrollPhysics(),
            onPageChanged: (i) => setState(() => _index = i),
            itemCount: uniqueCards.length,
            itemBuilder: (_, i) => Padding(
              padding: const EdgeInsets.symmetric(horizontal: 0),
              child: uniqueCards[i],
            ),
          ),
          if (widget.showArrows && uniqueCards.length > 1) ...[
            Positioned(
              left: 0,
              child: _NavArrow(
                enabled: _index > 0,
                onTap: () => _go(-1, uniqueCards.length - 1),
                icon: Icons.chevron_left,
              ),
            ),
            Positioned(
              right: 0,
              child: _NavArrow(
                enabled: _index < uniqueCards.length - 1,
                onTap: () => _go(1, uniqueCards.length - 1),
                icon: Icons.chevron_right,
              ),
            ),
          ],
          if (widget.showDots && uniqueCards.length > 1)
            Positioned(
              bottom: 8,
              child: Row(
                children: List.generate(uniqueCards.length, (i) {
                  final active = i == _index;
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    height: 6,
                    width: active ? 14 : 6,
                    decoration: BoxDecoration(
                      color: active ? Colors.white : Colors.white38,
                      borderRadius: BorderRadius.circular(8),
                    ),
                  );
                }),
              ),
            ),
        ],
      ),
    );
  }
}

class _NavArrow extends StatelessWidget {
  const _NavArrow({
    required this.enabled,
    required this.onTap,
    required this.icon,
  });

  final bool enabled;
  final VoidCallback onTap;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: enabled ? 1 : 0.35,
      child: Material(
        color: const Color(0x33000000),
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: enabled ? onTap : null,
          child: SizedBox(
            height: 36,
            width: 36,
            child: Icon(icon, color: Colors.white),
          ),
        ),
      ),
    );
  }
}

class _AmountButton extends StatelessWidget {
  final String amount;
  final bool isLarge;
  final VoidCallback? onTap;

  const _AmountButton({
    required this.amount,
    required this.isLarge,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isTablet = MediaQuery.of(context).size.width > 600;
    return InkWell(
      borderRadius: BorderRadius.circular(isLarge ? 12 : 10),
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(
          vertical: isLarge ? 12 : 10,
          horizontal: isLarge ? 10 : 10,
        ),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.2),
          borderRadius: BorderRadius.circular(isLarge ? 12 : 10),
          border: Border.all(
            color: Colors.white.withOpacity(0.3),
            width: 1,
          ),
        ),
        child: Center(
          child: Text(
            amount,
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: isTablet ? 14 : 12,
            ),
          ),
        ),
      ),
    );
  }
}
