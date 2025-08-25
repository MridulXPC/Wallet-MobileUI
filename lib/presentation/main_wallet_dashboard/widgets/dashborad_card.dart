// lib/presentation/main_wallet_dashboard/widgets/crypto_stat_card.dart
import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:cryptowallet/coin_store.dart';

import 'package:cryptowallet/presentation/main_wallet_dashboard/widgets/action_buttons_grid_widget.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/foundation.dart' show compute;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

class CryptoStatCard extends StatefulWidget {
  /// Canonical coin key from CoinStore, e.g. "BTC", "ETH", "USDT-ETH"
  final String coinId;

  /// Optional title override; if null we’ll use Coin.name from Provider.
  final String? title;

  /// Cards with the same colorKey will be considered the "same color"
  /// for deduping in the pager. Recommended: the icon assetPath.
  final String? colorKey;

  final double currentPrice;
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
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Precache current coin icon
    final coin = context.read<CoinStore>().getById(widget.coinId);
    final assetPath = coin?.assetPath;
    final provider = _getAssetProvider(widget.coinId, assetPath);
    if (provider != null) {
      precacheImage(provider, context);
    }
  }

  @override
  void didUpdateWidget(CryptoStatCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.coinId != widget.coinId ||
        oldWidget.title != widget.title ||
        oldWidget.colorKey != widget.colorKey) {
      // Precache icon for the new coin
      final coin = context.read<CoinStore>().getById(widget.coinId);
      final assetPath = coin?.assetPath;
      final provider = _getAssetProvider(widget.coinId, assetPath);
      if (provider != null) {
        precacheImage(provider, context);
      }
      _resolveDominantColor();
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  void _resolveDominantColor() {
    _debounce?.cancel();
    // Small debounce to collapse rapid page changes
    _debounce = Timer(const Duration(milliseconds: 40), _extractDominantColor);
  }

  Future<void> _extractDominantColor() async {
    final store = context.read<CoinStore>();
    final coin = store.getById(widget.coinId);
    final assetPath = coin?.assetPath;
    final nameOrId = widget.title ?? coin?.name ?? widget.coinId;

    final cacheKey = _colorCacheKey(assetPath: assetPath, nameOrId: nameOrId);

    // 1) If cached, use it immediately
    final cached = _dominantColorCache[cacheKey];
    if (cached != null) {
      if (!mounted) return;
      setState(() {
        _dominantColor = cached;
        _isColorReady = true;
      });
      return;
    }

    // 2) If no icon, keep the good fallback we set in initState — also cache it
    if (assetPath == null || assetPath.isEmpty) {
      _dominantColorCache[cacheKey] = _dominantColor;
      return;
    }

    try {
      // 3) Load bytes (assets are instant after first read), then decode small
      final ByteData data = await rootBundle.load(assetPath);
      final Uint8List bytes = data.buffer.asUint8List();

      // Decode icon to tiny size — super fast
      final ui.Codec codec = await ui.instantiateImageCodec(
        bytes,
        targetWidth: 48,
        targetHeight: 48,
      );
      final ui.FrameInfo frame = await codec.getNextFrame();
      final ui.Image img = frame.image;
      final ByteData? rgba =
          await img.toByteData(format: ui.ImageByteFormat.rawRgba);
      if (rgba == null) throw StateError('rgba null');

      // 4) Compute dominant color off the UI thread
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
      // Keep fallback and cache it
      _dominantColorCache[cacheKey] = _dominantColor;
    }
  }

  static int _dominantColorFromRgbaIsolate(Uint8List pixels) {
    // Returns 0xRRGGBB
    final Map<int, int> counts = {};
    // sample roughly every 4th pixel (16 bytes/px RGBA => step 16*4 = 64)
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
    if (counts.isEmpty) {
      // mid-blue default if nothing suitable
      return 0x1A73E8;
    }
    return counts.entries.reduce((a, b) => a.value > b.value ? a : b).key;
  }

  Color _fallbackColor(String nameOrSymbol) {
    // Per-coin deterministic fallbacks to avoid repeated default color.
    const fallback = Color(0xFF1A73E8);
    const map = <String, Color>{
      'Bitcoin': Color(0xFFF7931A),
      'Ethereum': Color(0xFF627EEA),
      'ETH': Color(0xFF627EEA),
      'Solana': Color(0xFF14F195),
      'SOL': Color(0xFF14F195),
      'Tron': Color(0xFFEB0029),
      'Tether': Color(0xFF26A17B),
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

  List<FlSpot> _spots(List<double> prices) =>
      List.generate(prices.length, (i) => FlSpot(i.toDouble(), prices[i]));

  double _minY() {
    final all = [
      ...widget.monthlyData,
      ...widget.todayData,
      ...widget.yearlyData
    ];
    return all.reduce(math.min) * 0.98;
  }

  double _maxY() {
    final all = [
      ...widget.monthlyData,
      ...widget.todayData,
      ...widget.yearlyData
    ];
    return all.reduce(math.max) * 1.02;
  }

  @override
  Widget build(BuildContext context) {
    final coin = context.watch<CoinStore>().getById(widget.coinId);
    final title = widget.title ?? coin?.name ?? 'Unknown';
    final screenWidth = MediaQuery.of(context).size.width;
    final dpr = MediaQuery.of(context).devicePixelRatio;
    final isTablet = screenWidth > 600;
    final isLarge = screenWidth > 900;

    // Responsive dims
    final cardPad = isLarge ? 24.0 : (isTablet ? 20.0 : 16.0);
    final radius = isLarge ? 24.0 : (isTablet ? 22.0 : 20.0);
    final iconSize = isLarge ? 40.0 : (isTablet ? 36.0 : 32.0);
    final priceFs = isLarge ? 32.0 : (isTablet ? 30.0 : 28.0);
    final watermarkSize = isLarge ? 200.0 : (isTablet ? 180.0 : 160.0);
    final hMargin = (screenWidth * 0.02).clamp(8.0, 20.0);
    final cacheW = (iconSize * dpr).round();
    final cacheH = (iconSize * dpr).round();
    final watermarkCacheW = (watermarkSize * dpr).round();

    return Container(
      margin: EdgeInsets.symmetric(vertical: 6, horizontal: hMargin),
      padding: EdgeInsets.all(cardPad),
      decoration: BoxDecoration(
        boxShadow: [
          BoxShadow(
            color: _dominantColor.withOpacity(0.28),
            blurRadius: isLarge ? 12 : 8,
            offset: Offset(isLarge ? 6 : 4, isLarge ? 8 : 6),
          ),
          const BoxShadow(
            color: Color.fromARGB(31, 0, 0, 0),
            blurRadius: 8,
            offset: Offset(8, 10),
          ),
        ],
        gradient: _gradient(),
        borderRadius: BorderRadius.circular(radius),
      ),
      child: Stack(
        children: [
          Positioned(
            right: -watermarkSize * 0.3,
            top: -watermarkSize * 0.2,
            child: Selector<CoinStore, String?>(
              selector: (_, s) => s.getById(widget.coinId)?.assetPath,
              builder: (context, assetPath, _) {
                final provider = _getAssetProvider(widget.coinId, assetPath);
                if (provider == null) {
                  return Icon(
                    Icons.currency_bitcoin,
                    color: _dominantColor.withOpacity(0.0),
                    size: watermarkSize,
                  );
                }
                return ColorFiltered(
                  colorFilter: ColorFilter.mode(
                    _dominantColor.withOpacity(0.12), // subtle tint
                    BlendMode.srcIn,
                  ),
                  child: Image.asset(
                    assetPath!,
                    width: watermarkSize,
                    height: watermarkSize,
                    fit: BoxFit.contain,
                    cacheWidth: watermarkCacheW,
                  ),
                );
              },
            ),
          ),

          // ===== Main content
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top row
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
                  Icon(
                    Icons.qr_code_scanner,
                    color: Colors.white,
                    size: isLarge ? 24 : (isTablet ? 22 : 20),
                  ),
                ],
              ),
              SizedBox(height: isLarge ? 12 : (isTablet ? 10 : 8)),

              // Price row with icon (Selector to avoid full rebuilds)
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Selector<CoinStore, String?>(
                    selector: (_, s) => s.getById(widget.coinId)?.assetPath,
                    builder: (context, assetPath, _) {
                      final provider =
                          _getAssetProvider(widget.coinId, assetPath);
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
                  SizedBox(width: isLarge ? 12 : (isTablet ? 10 : 8)),
                  Flexible(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        '\$${widget.currentPrice.toStringAsFixed(2)}',
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

              SizedBox(height: isLarge ? 8 : (isTablet ? 6 : 4)),

              // Dummy change
              Text(
                '▲74.99% (+\$51,176.67)',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: isLarge ? 16 : (isTablet ? 15 : 14),
                  fontWeight: FontWeight.w400,
                ),
              ),
              SizedBox(height: isLarge ? 12 : (isTablet ? 10 : 8)),

              Text(
                'Start investing – buy your first $title now!',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: isLarge ? 14 : (isTablet ? 17 : 14),
                ),
              ),
              SizedBox(height: isLarge ? 12 : (isTablet ? 10 : 8)),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: const [
                  Expanded(
                      child: _AmountButton(amount: '\$100', isLarge: false)),
                  SizedBox(width: 8),
                  Expanded(
                      child: _AmountButton(amount: '\$200', isLarge: false)),
                  SizedBox(width: 8),
                  Expanded(
                      child: _AmountButton(amount: '\$500', isLarge: false)),
                ],
              ),
              SizedBox(height: isLarge ? 12 : (isTablet ? 10 : 8)),

              // Actions row
              ActionButtonsGridWidget(
                isLarge: isLarge,
                isTablet: isTablet,
              ),
            ],
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
    this.height = 340,
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
    // Prefer color-based dedupe when possible.
    if (w is CryptoStatCard) {
      if (w.colorKey != null && w.colorKey!.isNotEmpty) {
        return 'color:${w.colorKey}';
      }
      // Fallback: dedupe by coin id if no colorKey provided.
      return 'coin:${w.coinId}';
    }
    // Otherwise, try key; else type+toStringShort.
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

    // If the list shrank after dedupe, clamp the index.
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
          child: const SizedBox(
            height: 36,
            width: 36,
            child: Icon(Icons.chevron_left, color: Colors.white),
          ),
        ),
      ),
    );
  }
}

class _AmountButton extends StatelessWidget {
  final String amount;
  final bool isLarge;

  const _AmountButton({
    required this.amount,
    required this.isLarge,
  });

  @override
  Widget build(BuildContext context) {
    final isTablet = MediaQuery.of(context).size.width > 600;
    return Container(
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
    );
  }
}
