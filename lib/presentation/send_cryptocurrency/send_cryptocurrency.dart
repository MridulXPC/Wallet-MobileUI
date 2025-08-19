import 'package:flutter/material.dart';
import 'package:sizer/sizer.dart';

class SendCryptocurrency extends StatefulWidget {
  const SendCryptocurrency({super.key});

  @override
  State<SendCryptocurrency> createState() => _SendCryptocurrencyState();
}

class _SendCryptocurrencyState extends State<SendCryptocurrency> {
  String _currentAmount = '0';
  bool _isADASelected = true;
  double _usdValue = 0.00;

  // Selected asset properties
  String _selectedAsset = 'Cardano';
  String _selectedAssetSymbol = 'ADA';
  double _selectedAssetBalance = 0.00;
  String _selectedAssetIcon = 'assets/currencyicons/cardano.png';
  double _selectedAssetPrice = 0.45;

  // Mock cryptocurrency data
  final List<Map<String, dynamic>> _cryptoAssets = [
    {
      "name": "Bitcoin",
      "symbol": "BTC",
      "balance": 0.5432,
      "icon": "assets/currencyicons/bitcoin.png",
      "price": 43250.00,
    },
    {
      "name": "Ethereum",
      "symbol": "ETH",
      "balance": 2.1567,
      "icon": "assets/currencyicons/ethereum.png",
      "price": 2650.00,
    },
    {
      "name": "Cardano",
      "symbol": "ADA",
      "balance": 0.00,
      "icon": "assets/currencyicons/cardano.png",
      "price": 0.45,
    },
    {
      "name": "Solana",
      "symbol": "SOL",
      "balance": 15.8934,
      "icon": "assets/currencyicons/solana.png",
      "price": 98.50,
    },
  ];

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
      double amount = _selectedAssetBalance * percentage;
      _currentAmount = amount.toStringAsFixed(8);
      // Remove trailing zeros
      _currentAmount = _currentAmount
          .replaceAll(RegExp(r'0*$'), '')
          .replaceAll(RegExp(r'\.$'), '');
      if (_currentAmount.isEmpty) _currentAmount = '0';
      _calculateUSDValue();
    });
  }

  void _calculateUSDValue() {
    double amount = double.tryParse(_currentAmount) ?? 0.0;
    _usdValue = amount * _selectedAssetPrice;
  }

  void _onAssetSelected(Map<String, dynamic> asset) {
    setState(() {
      _selectedAsset = asset["name"] as String;
      _selectedAssetSymbol = asset["symbol"] as String;
      _selectedAssetBalance = asset["balance"] as double;
      _selectedAssetIcon = asset["icon"] as String;
      _selectedAssetPrice = asset["price"] as double;
    });
    _calculateUSDValue();
  }

  void _showAssetSelector() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Color(0xFF2A2D3A),
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              margin: const EdgeInsets.symmetric(vertical: 10),
              height: 4,
              width: 40,
              decoration: BoxDecoration(
                color: Colors.grey[600],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
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
            ...(_cryptoAssets.map((asset) => ListTile(
                  leading: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: _getAssetColor(asset["name"]),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.currency_bitcoin,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                  title: Text(
                    '${asset["symbol"]} - ${asset["name"]}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  subtitle: Text(
                    'Balance: ${(asset["balance"] as double).toStringAsFixed(4)}',
                    style: const TextStyle(
                      color: Color(0xFF9CA3AF),
                    ),
                  ),
                  trailing: Text(
                    '\$${(asset["price"] as double).toStringAsFixed(2)}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  onTap: () {
                    _onAssetSelected(asset);
                    Navigator.pop(context);
                  },
                ))).toList(),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Color _getAssetColor(String assetName) {
    final Map<String, Color> colors = {
      'Bitcoin': const Color(0xFFF7931A),
      'Ethereum': const Color(0xFF627EEA),
      'Cardano': const Color(0xFF0033AD),
      'Solana': const Color(0xFF14F195),
    };
    return colors[assetName] ?? const Color(0xFF1A73E8);
  }

  void _toggleCurrency() {
    setState(() {
      _isADASelected = !_isADASelected;
    });
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenHeight < 0.6 * screenWidth;
    final isTablet = screenWidth > 600;

    return Scaffold(
      backgroundColor: const Color(0xFF1A1D29),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A1D29),
        elevation: 0,
        leading: IconButton(
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(
            Icons.arrow_back_ios,
            color: Colors.white,
            size: 20,
          ),
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
                constraints: BoxConstraints(
                  minHeight: constraints.maxHeight,
                ),
                child: IntrinsicHeight(
                  child: Column(
                    children: [
                      SizedBox(height: 1.h),

                      // Account Card - Now Interactive
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
                              // Asset Icon
                              Container(
                                width: isSmallScreen ? 40 : 40,
                                height: isSmallScreen ? 40 : 40,
                                decoration: BoxDecoration(
                                  color: _getAssetColor(_selectedAsset),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Center(
                                  child: Icon(
                                    Icons.currency_bitcoin,
                                    color: Colors.white,
                                    size: isSmallScreen ? 20 : 24,
                                  ),
                                ),
                              ),
                              SizedBox(width: 3.w),

                              // Account Details - Now Dynamic
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
                                    '≈ ${(_selectedAssetBalance * _selectedAssetPrice).toStringAsFixed(2)} USD',
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
                              if (!_isADASelected) _toggleCurrency();
                            },
                            child: Container(
                              padding: EdgeInsets.symmetric(
                                  horizontal: 4.w, vertical: 0.3.h),
                              decoration: BoxDecoration(
                                color: _isADASelected
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
                                  color: _isADASelected
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
                              if (_isADASelected) _toggleCurrency();
                            },
                            child: Container(
                              padding: EdgeInsets.symmetric(
                                  horizontal: 4.w, vertical: 0.3.h),
                              decoration: BoxDecoration(
                                color: !_isADASelected
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
                                  color: !_isADASelected
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

                      // Amount Display Section
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
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 28,
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          SizedBox(height: 0.5.h),
                          Text(
                            '≈ ${_usdValue.toStringAsFixed(2)} USD',
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
                            _buildPercentageButton('25%', 0.0, isSmallScreen),
                            SizedBox(width: 2.w),
                            _buildPercentageButton('50%', 0.0, isSmallScreen),
                            SizedBox(width: 2.w),
                            _buildPercentageButton('75%', 0.0, isSmallScreen),
                            SizedBox(width: 2.w),
                            _buildPercentageButton('100%', 0.0, isSmallScreen),
                          ],
                        ),
                      ),

                      // Number Pad - Flexible to take remaining space
                      Flexible(
                        flex: 0,
                        child: Padding(
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
                      ),
                      Spacer(),
                      // Next Button - Always at bottom
                      Container(
                        margin: EdgeInsets.all(4.w),
                        width: double.infinity,
                        height: isSmallScreen ? 5.h : 6.h,
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [
                                Color(0xFF6366F1),
                                Color(0xFF8B5CF6),
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: ElevatedButton(
                            onPressed: () {
                              Navigator.of(context).pop();
                            },
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
            border: Border.all(
              color: const Color(0xFF3A3D4A),
              width: 1,
            ),
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
      children: numbers
          .map((number) => _buildNumberButton(number, isSmallScreen))
          .toList(),
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
            border: Border.all(
              color: const Color(0xFF3A3D4A),
              width: 1,
            ),
          ),
          child: Center(
            child: number == 'backspace'
                ? Icon(
                    Icons.backspace_outlined,
                    color: Colors.white,
                    size: isSmallScreen ? 20 : 24,
                  )
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
