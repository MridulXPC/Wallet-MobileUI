import 'package:cryptowallet/presentation/main_wallet_dashboard/widgets/action_buttons_grid_widget.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:ui' as ui;
import 'dart:typed_data';
import 'dart:math' as math;

class CryptoStatCard extends StatefulWidget {
  final String title;
  final double currentPrice;
  final List<double> monthlyData;
  final List<double> todayData;
  final List<double> yearlyData;
  final String iconPath;

  const CryptoStatCard({
    super.key,
    required this.title,
    required this.currentPrice,
    required this.monthlyData,
    required this.todayData,
    required this.yearlyData,
    required this.iconPath,
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
    if (oldWidget.iconPath != widget.iconPath) {
      _extractDominantColor();
    }
  }

  Future<void> _extractDominantColor() async {
    try {
      // Load the image as bytes
      final ByteData data = await rootBundle.load(widget.iconPath);
      final Uint8List bytes = data.buffer.asUint8List();
      
      // Decode the image
      final ui.Codec codec = await ui.instantiateImageCodec(bytes);
      final ui.FrameInfo frameInfo = await codec.getNextFrame();
      final ui.Image image = frameInfo.image;
      
      // Convert to byte data
      final ByteData? byteData = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
      if (byteData != null) {
        final Color extractedColor = _getDominantColorFromBytes(byteData);
        if (mounted) {
          setState(() {
            _dominantColor = extractedColor;
            _isColorExtracted = true;
          });
        }
      }
    } catch (e) {
      // If extraction fails, use default color based on crypto type
      if (mounted) {
        setState(() {
          _dominantColor = _getDefaultColorForCrypto(widget.title);
          _isColorExtracted = true;
        });
      }
    }
  }

  Color _getDominantColorFromBytes(ByteData byteData) {
    final Uint8List pixels = byteData.buffer.asUint8List();
    Map<int, int> colorCounts = {};
    
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
      return _getDefaultColorForCrypto(widget.title);
    }
    
    // Find the most common color
    int dominantColorKey = colorCounts.entries
        .reduce((a, b) => a.value > b.value ? a : b)
        .key;
    
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
      'Cardano': const Color(0xFF0033AD),
      'Solana': const Color(0xFF14F195),
      'Polygon': const Color(0xFF8247E5),
      'Chainlink': const Color(0xFF375BD2),
      'Dogecoin': const Color(0xFFC2A633),
      'Litecoin': const Color(0xFFBFBFBF),
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
    final all = [...widget.monthlyData, ...widget.todayData, ...widget.yearlyData];
    return all.reduce(math.min) * 0.98;
  }

  double getMaxY() {
    final all = [...widget.monthlyData, ...widget.todayData, ...widget.yearlyData];
    return all.reduce(math.max) * 1.02;
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final isTablet = screenWidth > 600;
    final isLargeScreen = screenWidth > 900;
    
    // Responsive dimensions
    final cardPadding = isLargeScreen ? 24.0 : isTablet ? 20.0 : 16.0;
    final borderRadius = isLargeScreen ? 24.0 : isTablet ? 22.0 : 20.0;
    final iconSize = isLargeScreen ? 40.0 : isTablet ? 36.0 : 32.0;
    final priceTextSize = isLargeScreen ? 32.0 : isTablet ? 30.0 : 28.0;
    final watermarkSize = isLargeScreen ? 200.0 : isTablet ? 180.0 : 160.0;
    
    // Responsive margins
    final horizontalMargin = screenWidth * 0.02; // 2% of screen width
    final verticalMargin = screenHeight * 0.015; // 1.5% of screen height

    return Container(
      margin: EdgeInsets.symmetric(
        horizontal: horizontalMargin.clamp(8.0, 20.0),
        vertical: verticalMargin.clamp(8.0, 16.0),
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
                  child: Image.asset(
                    widget.iconPath,
                    width: watermarkSize,
                    height: watermarkSize,
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => Icon(
                      Icons.currency_bitcoin,
                      color: _dominantColor.withOpacity(0.15),
                      size: watermarkSize,
                    ),
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
                          '${widget.title} price',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: isLargeScreen ? 16 : isTablet ? 15 : 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      Icon(
                        Icons.qr_code_scanner,
                        color: Colors.white,
                        size: isLargeScreen ? 24 : isTablet ? 22 : 20,
                      ),
                    ],
                  ),
                  SizedBox(height: isLargeScreen ? 12 : isTablet ? 10 : 8),
                  
                  // Price + Icon Row
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Image.asset(
                        widget.iconPath,
                        width: iconSize,
                        height: iconSize,
                        errorBuilder: (_, __, ___) => Icon(
                          Icons.currency_bitcoin,
                          color: Colors.white,
                          size: iconSize,
                        ),
                      ),
                      SizedBox(width: isLargeScreen ? 12 : isTablet ? 10 : 8),
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

                  SizedBox(height: isLargeScreen ? 8 : isTablet ? 6 : 4),
                  
                  // Percentage Change
                  Text(
                    '▲74.99% (+\$51,176.67)',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: isLargeScreen ? 16 : isTablet ? 15 : 14,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                  SizedBox(height: isLargeScreen ? 12 : isTablet ? 10 : 8),

                  // Investment text
                  Text(
                    'Start investing – buy your first ${widget.title} now!',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: isLargeScreen ? 14 : isTablet ? 17 : 14,
                    ),
                  ),
                  SizedBox(height: isLargeScreen ? 12 : isTablet ? 10 : 8),

                  // Amount Buttons - Single row for all devices
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: _AmountButton(
                          amount: '\$100',
                          isLarge: isLargeScreen,
                        ),
                      ),
                      SizedBox(width: isLargeScreen ? 12 : isTablet ? 10 : 8),
                      Expanded(
                        child: _AmountButton(
                          amount: '\$200',
                          isLarge: isLargeScreen,
                        ),
                      ),
                      SizedBox(width: isLargeScreen ? 12 : isTablet ? 10 : 8),
                      Expanded(
                        child: _AmountButton(
                          amount: '\$500',
                          isLarge: isLargeScreen,
                        ),
                      ),
                    ],
                  ),

                  SizedBox(height: isLargeScreen ? 12 : isTablet ? 10 : 8),

                  // Actions - Your ActionButtonsGridWidget
                  ActionButtonsGridWidget(isLarge: isLargeScreen, isTablet: isTablet),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}

// Helper widget for amount buttons (you'll need to implement this)
class _AmountButton extends StatelessWidget {
  final String amount;
  final bool isLarge;

  const _AmountButton({
    required this.amount,
    required this.isLarge,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        vertical: isLarge ? 12 : 10,
        horizontal: isLarge ? 16 : 12,
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
            fontSize: isLarge ? 14 : 12,
          ),
        ),
      ),
    );
  }
}