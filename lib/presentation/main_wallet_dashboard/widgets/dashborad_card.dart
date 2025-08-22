import 'dart:async';
import 'package:cryptowallet/coin_store.dart';
import 'package:cryptowallet/presentation/main_wallet_dashboard/widgets/action_buttons_grid_widget.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:ui' as ui;
import 'dart:typed_data';
import 'dart:math' as math;

// ✅ New: Provider & CoinStore
import 'package:provider/provider.dart';

class CryptoStatCard extends StatefulWidget {
  /// Canonical coin key from CoinStore, e.g. "BTC", "ETH", "USDT-ETH"
  final String coinId;

  /// Optional title override; if null we’ll use Coin.name from Provider.
  final String? title;

  final double currentPrice;
  final List<double> monthlyData;
  final List<double> todayData;
  final List<double> yearlyData;

  const CryptoStatCard({
    super.key,
    required this.coinId,
    this.title,
    required this.currentPrice,
    required this.monthlyData,
    required this.todayData,
    required this.yearlyData,
  });

  @override
  State<CryptoStatCard> createState() => _CryptoStatCardState();
}

class _CryptoStatCardState extends State<CryptoStatCard> {
  Color _dominantColor = const Color(0xFF1A73E8); // Default blue
  bool _isColorExtracted = false;

  @override
  void initState() {
    super.initState();
    _extractDominantColor();
  }

  @override
  void didUpdateWidget(CryptoStatCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.coinId != widget.coinId || oldWidget.title != widget.title) {
      _extractDominantColor();
    }
  }

  Future<void> _extractDominantColor() async {
    try {
      final store = context.read<CoinStore>();
      final coin = store.getById(widget.coinId);

      // If no coin or asset path, fall back immediately.
      final assetPath = coin?.assetPath;
      if (assetPath == null) {
        if (mounted) {
          setState(() {
            _dominantColor =
                _getDefaultColorForCrypto(widget.title ?? coin?.name ?? '');
            _isColorExtracted = true;
          });
        }
        return;
      }

      // Load the image as bytes
      final ByteData data = await rootBundle.load(assetPath);
      final Uint8List bytes = data.buffer.asUint8List();

      // Decode the image
      final ui.Codec codec = await ui.instantiateImageCodec(bytes);
      final ui.FrameInfo frameInfo = await codec.getNextFrame();
      final ui.Image image = frameInfo.image;

      // Convert to byte data
      final ByteData? byteData =
          await image.toByteData(format: ui.ImageByteFormat.rawRgba);
      if (byteData != null && mounted) {
        final Color extractedColor = _getDominantColorFromBytes(byteData);
        setState(() {
          _dominantColor = extractedColor;
          _isColorExtracted = true;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _dominantColor =
            _getDefaultColorForCrypto(_effectiveTitle(context) ?? '');
        _isColorExtracted = true;
      });
    }
  }

  String? _effectiveTitle(BuildContext context) {
    final coin = context.read<CoinStore>().getById(widget.coinId);
    return widget.title ?? coin?.name;
  }

  String? _effectiveIconPath(BuildContext context) {
    final coin = context.watch<CoinStore>().getById(widget.coinId);
    return coin?.assetPath;
  }

  Color _getDominantColorFromBytes(ByteData byteData) {
    final Uint8List pixels = byteData.buffer.asUint8List();
    final Map<int, int> colorCounts = {};

    // Sample every 4th pixel to improve performance
    for (int i = 0; i < pixels.length; i += 16) {
      if (i + 3 < pixels.length) {
        final int r = pixels[i];
        final int g = pixels[i + 1];
        final int b = pixels[i + 2];
        final int a = pixels[i + 3];

        // Skip transparent pixels
        if (a < 128) continue;

        // Skip very light or very dark colors
        final double luminance = (0.299 * r + 0.587 * g + 0.114 * b) / 255;
        if (luminance > 0.9 || luminance < 0.1) continue;

        final int colorKey = (r << 16) | (g << 8) | b;
        colorCounts[colorKey] = (colorCounts[colorKey] ?? 0) + 1;
      }
    }

    if (colorCounts.isEmpty) {
      return _getDefaultColorForCrypto(_effectiveTitle(context) ?? '');
    }

    // Most common color
    final int dominantColorKey =
        colorCounts.entries.reduce((a, b) => a.value > b.value ? a : b).key;

    final int r = (dominantColorKey >> 16) & 0xFF;
    final int g = (dominantColorKey >> 8) & 0xFF;
    final int b = dominantColorKey & 0xFF;

    return Color.fromRGBO(r, g, b, 1.0);
  }

  Color _getDefaultColorForCrypto(String title) {
    // Fallback colors for common cryptocurrencies
    final Map<String, Color> cryptoColors = {
      'Bitcoin': const Color(0xFFF7931A),
      'Ethereum': const Color(0xFF627EEA),
      'Solana': const Color(0xFF14F195),
      'Tron': const Color(0xFFEB0029),
      'Tether': const Color(0xFF26A17B),
      'BNB': const Color(0xFFF3BA2F),
      'Monero': const Color(0xFFF26822),
    };

    return cryptoColors[title] ?? const Color(0xFF1A73E8);
  }

  LinearGradient _createGradient() {
    if (!_isColorExtracted) {
      return const LinearGradient(
        colors: [Color.fromARGB(255, 100, 162, 228), Color(0xFF1A73E8)],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      );
    }

    // Create a gradient using the dominant color
    final HSLColor hslColor = HSLColor.fromColor(_dominantColor);

    // Create lighter and darker variants
    final Color lightColor = hslColor
        .withLightness(math.min(0.7, hslColor.lightness + 0.2))
        .withSaturation(math.min(1.0, hslColor.saturation + 0.1))
        .toColor();

    final Color darkColor = hslColor
        .withLightness(math.max(0.3, hslColor.lightness - 0.2))
        .withSaturation(math.min(1.0, hslColor.saturation + 0.2))
        .toColor();

    return LinearGradient(
      colors: [lightColor, darkColor],
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
    );
  }

  List<FlSpot> generateSpots(List<double> prices) {
    return List.generate(prices.length, (i) => FlSpot(i.toDouble(), prices[i]));
  }

  double getMinY() {
    final all = [
      ...widget.monthlyData,
      ...widget.todayData,
      ...widget.yearlyData
    ];
    return all.reduce(math.min) * 0.98;
  }

  double getMaxY() {
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
    final iconPath = _effectiveIconPath(context);

    final screenWidth = MediaQuery.of(context).size.width;
    final isTablet = screenWidth > 600;
    final isLargeScreen = screenWidth > 900;

    // Responsive dimensions
    final cardPadding = isLargeScreen ? 24.0 : (isTablet ? 20.0 : 16.0);
    final borderRadius = isLargeScreen ? 24.0 : (isTablet ? 22.0 : 20.0);
    final iconSize = isLargeScreen ? 40.0 : (isTablet ? 36.0 : 32.0);
    final priceTextSize = isLargeScreen ? 32.0 : (isTablet ? 30.0 : 28.0);
    final watermarkSize = isLargeScreen ? 200.0 : (isTablet ? 180.0 : 160.0);
    final horizontalMargin = (screenWidth * 0.02).clamp(8.0, 20.0);

    return Container(
      margin: EdgeInsets.symmetric(
        vertical: 6,
        horizontal: horizontalMargin,
      ),
      padding: EdgeInsets.all(cardPadding),
      decoration: BoxDecoration(
        boxShadow: [
          BoxShadow(
            color: _dominantColor.withOpacity(0.3),
            blurRadius: isLargeScreen ? 12 : 8,
            offset: Offset(isLargeScreen ? 6 : 4, isLargeScreen ? 8 : 6),
          ),
          BoxShadow(
            color: const Color.fromARGB(31, 0, 0, 0),
            blurRadius: isLargeScreen ? 8 : 6,
            offset: Offset(isLargeScreen ? 10 : 8, isLargeScreen ? 10 : 8),
          )
        ],
        gradient: _createGradient(),
        borderRadius: BorderRadius.circular(borderRadius),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          return Stack(
            children: [
              // Watermark icon in the background
              Positioned(
                right: -watermarkSize * 0.3,
                top: -watermarkSize * 0.2,
                child: ColorFiltered(
                  colorFilter: ColorFilter.mode(
                    _dominantColor.withOpacity(0.15),
                    BlendMode.srcIn,
                  ),
                  child: iconPath != null
                      ? Image.asset(
                          iconPath,
                          width: watermarkSize,
                          height: watermarkSize,
                          fit: BoxFit.contain,
                        )
                      : Icon(
                          Icons.currency_bitcoin,
                          color: _dominantColor.withOpacity(0.15),
                          size: watermarkSize,
                        ),
                ),
              ),

              // Main content
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Top Row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Flexible(
                        child: Text(
                          '$title price',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: isLargeScreen ? 16 : (isTablet ? 15 : 14),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      Icon(
                        Icons.qr_code_scanner,
                        color: Colors.white,
                        size: isLargeScreen ? 24 : (isTablet ? 22 : 20),
                      ),
                    ],
                  ),
                  SizedBox(height: isLargeScreen ? 12 : (isTablet ? 10 : 8)),

                  // Price + Icon Row
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      if (iconPath != null)
                        Image.asset(
                          iconPath,
                          width: iconSize,
                          height: iconSize,
                        )
                      else
                        Icon(
                          Icons.currency_bitcoin,
                          color: Colors.white,
                          size: iconSize,
                        ),
                      SizedBox(
                          height: 0,
                          width: isLargeScreen ? 12 : (isTablet ? 10 : 8)),
                      Flexible(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Text(
                            '\$${widget.currentPrice.toStringAsFixed(2)}',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: priceTextSize,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),

                  SizedBox(height: isLargeScreen ? 8 : (isTablet ? 6 : 4)),

                  // Percentage Change (dummy)
                  Text(
                    '▲74.99% (+\$51,176.67)',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: isLargeScreen ? 16 : (isTablet ? 15 : 14),
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                  SizedBox(height: isLargeScreen ? 12 : (isTablet ? 10 : 8)),

                  // Investment text
                  Text(
                    'Start investing – buy your first $title now!',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: isLargeScreen ? 14 : (isTablet ? 17 : 14),
                    ),
                  ),
                  SizedBox(height: isLargeScreen ? 12 : (isTablet ? 10 : 8)),

                  // Amount Buttons - Single row for all devices
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: const [
                      Expanded(
                          child:
                              _AmountButton(amount: '\$100', isLarge: false)),
                      SizedBox(width: 8),
                      Expanded(
                          child:
                              _AmountButton(amount: '\$200', isLarge: false)),
                      SizedBox(width: 8),
                      Expanded(
                          child:
                              _AmountButton(amount: '\$500', isLarge: false)),
                    ],
                  ),

                  SizedBox(height: isLargeScreen ? 12 : (isTablet ? 10 : 8)),

                  // Actions - Your ActionButtonsGridWidget
                  ActionButtonsGridWidget(
                    isLarge: isLargeScreen,
                    isTablet: isTablet,
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}

class CryptoStatsPager extends StatefulWidget {
  const CryptoStatsPager({
    super.key,
    required this.cards, // Pass a list of CryptoStatCard widgets
    this.viewportPeek = 0.95, // 0.85 shows more peek; 1.0 shows full width
    this.height = 340, // Tune to your card’s natural height
    this.showArrows = true,
    this.showDots = true,
    this.scrollable = true, // set false if you want arrows-only
  });

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

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _go(int delta) {
    final next = (_index + delta).clamp(0, widget.cards.length - 1);
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
            itemCount: widget.cards.length,
            itemBuilder: (_, i) => Padding(
              padding: const EdgeInsets.symmetric(horizontal: 0),
              child: widget.cards[i],
            ),
          ),
          if (widget.showArrows && widget.cards.length > 1) ...[
            Positioned(
              left: 0,
              child: _NavArrow(
                enabled: _index > 0,
                onTap: () => _go(-1),
                icon: Icons.chevron_left,
              ),
            ),
            Positioned(
              right: 0,
              child: _NavArrow(
                enabled: _index < widget.cards.length - 1,
                onTap: () => _go(1),
                icon: Icons.chevron_right,
              ),
            ),
          ],
          if (widget.showDots && widget.cards.length > 1)
            Positioned(
              bottom: 8,
              child: Row(
                children: List.generate(widget.cards.length, (i) {
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
