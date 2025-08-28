import 'package:cryptowallet/presentation/send_cryptocurrency/SendConfirmationScreen.dart';
import 'package:flutter/material.dart';
import 'package:sizer/sizer.dart';
import 'package:provider/provider.dart';

import 'package:cryptowallet/coin_store.dart'; // ✅ Provider source of truth

// 1. IMAGE CACHE MANAGER
class ImageCacheManager {
  static final Map<String, ImageProvider> _cachedImages = {};

  static ImageProvider getCachedImage(String assetPath) {
    if (!_cachedImages.containsKey(assetPath)) {
      _cachedImages[assetPath] = AssetImage(assetPath);
    }
    return _cachedImages[assetPath]!;
  }

  static void preloadImages(List<String> assetPaths, BuildContext context) {
    for (String path in assetPaths) {
      precacheImage(AssetImage(path), context).catchError((error) {
        // Silently handle preload errors
        debugPrint('Failed to preload image: $path');
      });
    }
  }

  static void clearCache() {
    _cachedImages.clear();
  }
}

// 2. OPTIMIZED COIN ICON WIDGET
class OptimizedCoinIcon extends StatelessWidget {
  final String assetPath;
  final double size;

  const OptimizedCoinIcon({
    Key? key,
    required this.assetPath,
    this.size = 40,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        color: Color(0xFF1F2431),
      ),
      clipBehavior: Clip.antiAlias,
      child: Image(
        image: ImageCacheManager.getCachedImage(assetPath),
        fit: BoxFit.cover,
        width: size,
        height: size,
        frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
          if (wasSynchronouslyLoaded) {
            return child;
          }
          return AnimatedOpacity(
            opacity: frame == null ? 0 : 1,
            duration: const Duration(milliseconds: 150),
            curve: Curves.easeOut,
            child: child,
          );
        },
        errorBuilder: (context, error, stackTrace) => Container(
          color: const Color(0xFF1F2431),
          child: Icon(
            Icons.currency_bitcoin,
            color: Colors.white,
            size: size * 0.6,
          ),
        ),
        gaplessPlayback: true,
      ),
    );
  }
}

// 3. OPTIMIZED LIST TILE WIDGET
class OptimizedAssetListTile extends StatelessWidget {
  final Coin coin;
  final double price;
  final double balance;
  final VoidCallback onTap;

  const OptimizedAssetListTile({
    Key? key,
    required this.coin,
    required this.price,
    required this.balance,
    required this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        splashColor: Colors.white.withOpacity(0.1),
        highlightColor: Colors.white.withOpacity(0.05),
        child: Container(
          height: 72,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              // Use optimized icon widget
              OptimizedCoinIcon(
                assetPath: coin.assetPath,
                size: 40,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      '${coin.symbol} - ${coin.name}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Balance: ${balance.toStringAsFixed(4)}',
                      style: const TextStyle(
                        color: Color(0xFF9CA3AF),
                        fontSize: 14,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Text(
                '\$${price.toStringAsFixed(2)}',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w500,
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class SendCryptocurrency extends StatefulWidget {
  const SendCryptocurrency({super.key});

  @override
  State<SendCryptocurrency> createState() => _SendCryptocurrencyState();
}

class _SendCryptocurrencyState extends State<SendCryptocurrency> {
  String _currentAmount = '0';
  bool _isCryptoSelected = true;
  double _usdValue = 0.00;
  bool _isImagesPreloaded = false;

  // Selected asset properties (derived from CoinStore)
  String _selectedAsset = 'Bitcoin';
  String _selectedAssetSymbol = 'BTC';
  double _selectedAssetBalance = 0.00;
  String _selectedAssetIconPath = 'assets/currencyicons/bitcoin.png';
  double _selectedAssetPrice = 30000.00;

  // Dummy prices/balances (plug your API later)
  final Map<String, double> _dummyPrices = const {
    'BTC': 43825.67,
    'BTC-LN': 43825.67,
    'ETH': 2641.25,
    'BNB': 580.00,
    'SOL': 148.12,
    'TRX': 0.13,
    'USDT': 1.00,
    'USDT-ETH': 1.00,
    'USDT-TRX': 1.00,
    'BNB-BNB': 580.00,
    'ETH-ETH': 2641.25,
    'SOL-SOL': 148.12,
    'TRX-TRX': 0.13,
    'XMR': 168.00,
    'XMR-XMR': 168.00,
  };

  final Map<String, double> _dummyBalances = const {
    'BTC': 500.0,
    'BTC-LN': 0.0,
    'ETH': 0.0,
    'BNB': 0.0,
    'SOL': 0.0,
    'TRX': 0.0,
    'USDT': 0.0,
    'USDT-ETH': 0.0,
    'USDT-TRX': 0.0,
    'BNB-BNB': 0.0,
    'ETH-ETH': 0.0,
    'SOL-SOL': 0.0,
    'TRX-TRX': 0.0,
    'XMR': 0.0,
    'XMR-XMR': 0.0,
  };

  @override
  void dispose() {
    // Clear image cache when widget is disposed to free memory
    ImageCacheManager.clearCache();
    super.dispose();
  }

  // ---------- Amount helpers ----------
  void _onNumberPressed(String number) {
    setState(() {
      if (_currentAmount == '0') {
        _currentAmount = number;
      } else {
        _currentAmount += number;
      }
      _calculateUSDValue();
    });
  }

  void _onDecimalPressed() {
    setState(() {
      if (!_currentAmount.contains('.')) {
        _currentAmount += '.';
      }
    });
  }

  void _onBackspacePressed() {
    setState(() {
      if (_currentAmount.length > 1) {
        _currentAmount = _currentAmount.substring(0, _currentAmount.length - 1);
      } else {
        _currentAmount = '0';
      }
      _calculateUSDValue();
    });
  }

  void _onPercentagePressed(double percentage) {
    setState(() {
      final amt = _selectedAssetBalance * percentage;
      _currentAmount = amt
          .toStringAsFixed(8)
          .replaceAll(RegExp(r'0*$'), '')
          .replaceAll(RegExp(r'\.$'), '');
      if (_currentAmount.isEmpty) _currentAmount = '0';
      _calculateUSDValue();
    });
  }

  void _calculateUSDValue() {
    final amount = double.tryParse(_currentAmount) ?? 0.0;
    _usdValue = amount * _selectedAssetPrice;
  }

// Add this method to your _SendCryptocurrencyState class
  void _onNextPressed() {
    if (_currentAmount == '0' || double.tryParse(_currentAmount) == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter an amount greater than 0'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final amount = double.tryParse(_currentAmount) ?? 0.0;
    if (amount > _selectedAssetBalance) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Insufficient balance'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SendConfirmationScreen(
          amount: _currentAmount,
          assetSymbol: _selectedAssetSymbol,
          assetName: _selectedAsset,
          assetIconPath: _selectedAssetIconPath,
          assetPrice: _selectedAssetPrice,
          usdValue: _usdValue,
        ),
      ),
    );
  }

  // ---------- Selector & state updates ----------
  void _onAssetSelected(Coin coin) {
    final symbol = coin.symbol;
    final price = _dummyPrices[symbol] ?? _dummyPrices[coin.id] ?? 1.0;
    final balance = _dummyBalances[symbol] ?? _dummyBalances[coin.id] ?? 0.0;

    setState(() {
      _selectedAsset = coin.name;
      _selectedAssetSymbol = symbol;
      _selectedAssetBalance = balance;
      _selectedAssetIconPath = coin.assetPath;
      _selectedAssetPrice = price;
    });
    _calculateUSDValue();
  }

  void _showAssetSelector() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      enableDrag: true,
      builder: (context) {
        final coins = context.read<CoinStore>().coins.values.toList()
          ..sort((a, b) => a.symbol.compareTo(b.symbol));

        // Build chip list
        final baseSet = <String>{};
        for (final c in coins) {
          final base = _baseSymbol(c.id);
          baseSet.add(base);
        }
        final chips = ['ALL', ...baseSet.toList()..sort()];

        String search = '';
        String chip = 'ALL';

        return StatefulBuilder(
          builder: (context, setModalState) {
            final filtered = coins.where((c) {
              final q = search.trim().toLowerCase();
              final matchesSearch = q.isEmpty ||
                  c.symbol.toLowerCase().contains(q) ||
                  c.name.toLowerCase().contains(q) ||
                  c.id.toLowerCase().contains(q);
              final matchesChip = chip == 'ALL' || _baseSymbol(c.id) == chip;
              return matchesSearch && matchesChip;
            }).toList();

            return ClipRRect(
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(20)),
              child: Container(
                height: MediaQuery.of(context).size.height * 0.85,
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomRight,
                    stops: [0.0, 0.55, 1.0],
                    colors: [
                      Color.fromARGB(255, 6, 11, 33),
                      Color.fromARGB(255, 0, 0, 0),
                      Color.fromARGB(255, 0, 12, 56),
                    ],
                  ),
                ),
                child: SafeArea(
                  top: false,
                  child: Column(
                    children: [
                      // Handle bar
                      Container(
                        margin: const EdgeInsets.symmetric(vertical: 10),
                        height: 4,
                        width: 40,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.25),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),

                      // Title
                      const Padding(
                        padding: EdgeInsets.all(16.0),
                        child: Text(
                          'Select Asset',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),

                      // Search field
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: TextField(
                          style: const TextStyle(color: Colors.white),
                          decoration: InputDecoration(
                            hintText: 'Search symbol, name, or network',
                            hintStyle: const TextStyle(color: Colors.white54),
                            prefixIcon:
                                const Icon(Icons.search, color: Colors.white54),
                            filled: true,
                            fillColor: Color(0xFF1F2431),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: BorderSide.none,
                            ),
                          ),
                          onChanged: (v) => setModalState(() => search = v),
                        ),
                      ),

                      const SizedBox(height: 10),

                      // Filter chips
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Row(
                          children: chips
                              .map(
                                (f) => Padding(
                                  padding:
                                      const EdgeInsets.symmetric(horizontal: 6),
                                  child: ChoiceChip(
                                    label: Text(f),
                                    selected: chip == f,
                                    onSelected: (_) =>
                                        setModalState(() => chip = f),
                                    selectedColor: Colors.blue,
                                    labelStyle: TextStyle(
                                      color: chip == f
                                          ? Colors.white
                                          : Colors.white70,
                                    ),
                                    backgroundColor: const Color(0xFF1F2431),
                                  ),
                                ),
                              )
                              .toList(),
                        ),
                      ),

                      const SizedBox(height: 8),

                      // Optimized list view
                      Expanded(
                        child: ListView.builder(
                          physics: const ClampingScrollPhysics(),
                          cacheExtent: 500,
                          itemExtent: 72,
                          itemCount: filtered.length,
                          itemBuilder: (context, i) {
                            final coin = filtered[i];
                            final price = _dummyPrices[coin.symbol] ??
                                _dummyPrices[coin.id] ??
                                1.0;
                            final balance = _dummyBalances[coin.symbol] ??
                                _dummyBalances[coin.id] ??
                                0.0;

                            return OptimizedAssetListTile(
                              coin: coin,
                              price: price,
                              balance: balance,
                              onTap: () {
                                _onAssetSelected(coin);
                                Navigator.pop(context);
                              },
                            );
                          },
                        ),
                      ),

                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  String _baseSymbol(String coinId) {
    final dash = coinId.indexOf('-');
    return dash == -1 ? coinId : coinId.substring(0, dash);
  }

  Widget _iconCircle(String assetPath, double size) {
    return OptimizedCoinIcon(assetPath: assetPath, size: size);
  }

  void _toggleCurrency() {
    setState(() {
      _isCryptoSelected = !_isCryptoSelected;
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    if (!_isImagesPreloaded) {
      // Preload all coin images for better performance
      final coins = context.read<CoinStore>().coins.values.toList();
      final imagePaths = coins.map((coin) => coin.assetPath).toList();
      ImageCacheManager.preloadImages(imagePaths, context);
      _isImagesPreloaded = true;
    }

    // Initialize selection from Provider the first time
    final coins = context.read<CoinStore>().coins.values.toList()
      ..sort((a, b) => a.symbol.compareTo(b.symbol));
    if (coins.isNotEmpty) {
      final initial = coins.firstWhere(
        (c) => c.symbol == _selectedAssetSymbol,
        orElse: () => coins.first,
      );
      _onAssetSelected(initial);
    }
  }

  @override
  Widget build(BuildContext context) {
    // ensure rebuilds if coins update (icons/names)
    context.watch<CoinStore>();

    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenHeight < 0.6 * screenWidth;
    final isTablet = screenWidth > 600;

    return Scaffold(
      backgroundColor: Color(0xFF0B0D1A),
      appBar: AppBar(
        backgroundColor: Color(0xFF0B0D1A),
        elevation: 0,
        leading: IconButton(
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white, size: 16),
        ),
        title: Text(
          'Insert Amount',
          style: TextStyle(
            color: Colors.white,
            fontSize: isTablet ? 20 : 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: IntrinsicHeight(
                  child: Column(
                    children: [
                      SizedBox(height: 1.h),

                      // Account Card (tap to select asset)
                      GestureDetector(
                        onTap: _showAssetSelector,
                        child: Container(
                          margin: EdgeInsets.symmetric(horizontal: 4.w),
                          padding: EdgeInsets.all(isSmallScreen ? 3.w : 2.w),
                          decoration: BoxDecoration(
                            color: Colors.transparent,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: const Color.fromARGB(255, 170, 171, 177),
                              width: 1.2,
                            ),
                          ),
                          child: Row(
                            children: [
                              // Asset Icon (optimized)
                              _iconCircle(_selectedAssetIconPath, 40),

                              SizedBox(width: 3.w),

                              // Account Details
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '$_selectedAssetSymbol - Main Account',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: isSmallScreen ? 14 : 14,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    Text(
                                      _selectedAsset,
                                      style: TextStyle(
                                        color: const Color(0xFF9CA3AF),
                                        fontSize: isSmallScreen ? 12 : 14,
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                              // Balance
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    _selectedAssetBalance.toStringAsFixed(4),
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: isSmallScreen ? 14 : 14,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  Text(
                                    '≈ \$${(_selectedAssetBalance * _selectedAssetPrice).toStringAsFixed(2)}',
                                    style: TextStyle(
                                      color: const Color(0xFF9CA3AF),
                                      fontSize: isSmallScreen ? 10 : 12,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),

                      SizedBox(height: isSmallScreen ? 2.h : 2.h),

                      // Currency Toggle Buttons
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          GestureDetector(
                            onTap: () {
                              if (!_isCryptoSelected) _toggleCurrency();
                            },
                            child: Container(
                              padding: EdgeInsets.symmetric(
                                  horizontal: 4.w, vertical: 0.3.h),
                              decoration: BoxDecoration(
                                color: _isCryptoSelected
                                    ? const Color(0xFF4C5563)
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: const Color(0xFF4C5563),
                                  width: 1,
                                ),
                              ),
                              child: Text(
                                _selectedAssetSymbol,
                                style: TextStyle(
                                  color: _isCryptoSelected
                                      ? Colors.white
                                      : const Color(0xFF9CA3AF),
                                  fontSize: isSmallScreen ? 14 : 16,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ),
                          SizedBox(width: 4.w),
                          GestureDetector(
                            onTap: () {
                              if (_isCryptoSelected) _toggleCurrency();
                            },
                            child: Container(
                              padding: EdgeInsets.symmetric(
                                  horizontal: 4.w, vertical: 0.3.h),
                              decoration: BoxDecoration(
                                color: !_isCryptoSelected
                                    ? const Color(0xFF4C5563)
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: const Color(0xFF4C5563),
                                  width: 1,
                                ),
                              ),
                              child: Text(
                                'USD',
                                style: TextStyle(
                                  color: !_isCryptoSelected
                                      ? Colors.white
                                      : const Color(0xFF9CA3AF),
                                  fontSize: isSmallScreen ? 14 : 16,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),

                      SizedBox(height: isSmallScreen ? 2.h : 1.h),

                      // Amount Display
                      Column(
                        children: [
                          Text(
                            'Amount',
                            style: TextStyle(
                              color: const Color(0xFF9CA3AF),
                              fontSize: isSmallScreen ? 14 : 14,
                            ),
                          ),
                          SizedBox(height: 0.5.h),
                          Text(
                            _currentAmount,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 28,
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          SizedBox(height: 0.5.h),
                          Text(
                            '≈ \$${_usdValue.toStringAsFixed(2)} USD',
                            style: TextStyle(
                              color: const Color(0xFF9CA3AF),
                              fontSize: isSmallScreen ? 14 : 16,
                            ),
                          ),
                        ],
                      ),

                      SizedBox(height: 2.w),

                      // Percentage Buttons
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 4.w),
                        child: Row(
                          children: [
                            _buildPercentageButton('25%', 0.25, isSmallScreen),
                            SizedBox(width: 2.w),
                            _buildPercentageButton('50%', 0.50, isSmallScreen),
                            SizedBox(width: 2.w),
                            _buildPercentageButton('75%', 0.75, isSmallScreen),
                            SizedBox(width: 2.w),
                            _buildPercentageButton('100%', 1.00, isSmallScreen),
                          ],
                        ),
                      ),

                      // Number Pad
                      Padding(
                        padding: EdgeInsets.symmetric(
                            horizontal: 4.w, vertical: 2.h),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            _buildNumberRow(['1', '2', '3'], isSmallScreen),
                            SizedBox(height: 1.h),
                            _buildNumberRow(['4', '5', '6'], isSmallScreen),
                            SizedBox(height: 1.h),
                            _buildNumberRow(['7', '8', '9'], isSmallScreen),
                            SizedBox(height: 1.h),
                            _buildNumberRow(
                                ['.', '0', 'backspace'], isSmallScreen),
                          ],
                        ),
                      ),

                      const Spacer(),

                      // Next Button
                      Container(
                        margin: EdgeInsets.all(4.w),
                        width: double.infinity,
                        height: isSmallScreen ? 5.h : 6.h,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: ElevatedButton(
                          onPressed:
                              _onNextPressed, // Changed from Navigator.of(context).pop()
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            shadowColor: Colors.transparent,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          child: Text(
                            'Next',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: isSmallScreen ? 16 : 18,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildPercentageButton(
      String text, double percentage, bool isSmallScreen) {
    return Expanded(
      child: GestureDetector(
        onTap: () => _onPercentagePressed(percentage),
        child: Container(
          padding: EdgeInsets.symmetric(vertical: 0.5.h),
          decoration: BoxDecoration(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: const Color(0xFF3A3D4A), width: 1),
          ),
          child: Center(
            child: Text(
              text,
              style: TextStyle(
                color: Colors.white,
                fontSize: isSmallScreen ? 14 : 16,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNumberRow(List<String> numbers, bool isSmallScreen) {
    return Row(
      children:
          numbers.map((n) => _buildNumberButton(n, isSmallScreen)).toList(),
    );
  }

  Widget _buildNumberButton(String number, bool isSmallScreen) {
    return Expanded(
      child: GestureDetector(
        onTap: () {
          if (number == 'backspace') {
            _onBackspacePressed();
          } else if (number == '.') {
            _onDecimalPressed();
          } else {
            _onNumberPressed(number);
          }
        },
        child: Container(
          margin: EdgeInsets.symmetric(horizontal: 1.w),
          height: isSmallScreen ? 2.h : 5.h,
          decoration: BoxDecoration(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(35),
            border: Border.all(color: const Color(0xFF3A3D4A), width: 1),
          ),
          child: Center(
            child: number == 'backspace'
                ? Icon(Icons.backspace_outlined,
                    color: Colors.white, size: isSmallScreen ? 20 : 24)
                : Text(
                    number,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: isSmallScreen ? 20 : 24,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}
