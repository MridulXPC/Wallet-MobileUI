import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:sizer/sizer.dart';

import '../../core/app_export.dart';
import './widgets/address_display_widget.dart';
import './widgets/asset_selector_widget.dart';
import './widgets/qr_code_widget.dart';
import './widgets/recent_addresses_widget.dart';

class ReceiveCryptocurrency extends StatefulWidget {
  const ReceiveCryptocurrency({super.key});

  @override
  State<ReceiveCryptocurrency> createState() => _ReceiveCryptocurrencyState();
}

class _ReceiveCryptocurrencyState extends State<ReceiveCryptocurrency> {
  // Mock cryptocurrency data
  final List<Map<String, dynamic>> supportedAssets = [
    {
      "id": "bitcoin",
      "name": "Bitcoin",
      "symbol": "BTC",
      "icon": "https://cryptologos.cc/logos/bitcoin-btc-logo.png",
      "balance": "0.00234567",
      "address": "bc1qxy2kgdygjrsqtzq2n0yrf2493p83kkfjhx0wlh",
      "network": "Bitcoin",
      "warning": "Only send Bitcoin to this address"
    },
    {
      "id": "ethereum",
      "name": "Ethereum",
      "symbol": "ETH",
      "icon": "https://cryptologos.cc/logos/ethereum-eth-logo.png",
      "balance": "1.23456789",
      "address": "0x742d35Cc6634C0532925a3b8D4C2E5e2c8b6c8e3",
      "network": "Ethereum",
      "warning": "Only send Ethereum and ERC-20 tokens to this address"
    },
    {
      "id": "binance",
      "name": "Binance Coin",
      "symbol": "BNB",
      "icon": "https://cryptologos.cc/logos/bnb-bnb-logo.png",
      "balance": "5.67890123",
      "address": "bnb1grpf0955h0ykzq3ar5nmum7y6gdfl6lxfn46h2",
      "network": "Binance Smart Chain",
      "warning": "Only send BNB and BEP-20 tokens to this address"
    },
  ];

  final List<Map<String, dynamic>> recentAddresses = [
    {
      "address": "bc1qxy2kgdygjrsqtzq2n0yrf2493p83kkfjhx0wlh",
      "timestamp": "2024-01-15 14:30:00",
      "asset": "BTC",
      "used": true
    },
    {
      "address": "0x742d35Cc6634C0532925a3b8D4C2E5e2c8b6c8e3",
      "timestamp": "2024-01-14 09:15:00",
      "asset": "ETH",
      "used": true
    },
    {
      "address": "bnb1grpf0955h0ykzq3ar5nmum7y6gdfl6lxfn46h2",
      "timestamp": "2024-01-13 16:45:00",
      "asset": "BNB",
      "used": false
    },
  ];

  int selectedAssetIndex = 0;
  bool isHighContrast = false;

  @override
  void initState() {
    super.initState();
    _refreshBalance();
  }

  void _refreshBalance() {
    // Simulate balance refresh
    setState(() {
      // Update balance data
    });
  }

  void _copyToClipboard(String text) {
    Clipboard.setData(ClipboardData(text: text));
    HapticFeedback.lightImpact();
    Fluttertoast.showToast(
      msg: "Address copied to clipboard",
      toastLength: Toast.LENGTH_SHORT,
      gravity: ToastGravity.BOTTOM,
      backgroundColor: AppTheme.darkTheme.colorScheme.surface,
      textColor: AppTheme.darkTheme.colorScheme.onSurface,
    );
  }

  void _shareAddress() {
    final selectedAsset = supportedAssets[selectedAssetIndex];
    final address = selectedAsset["address"] as String;
    final assetName = selectedAsset["name"] as String;

    String shareText = "My \$assetName wallet address:\n\$address";

    // Simulate native share
    Fluttertoast.showToast(
      msg: "Share sheet opened",
      toastLength: Toast.LENGTH_SHORT,
      gravity: ToastGravity.BOTTOM,
      backgroundColor: AppTheme.darkTheme.colorScheme.surface,
      textColor: AppTheme.darkTheme.colorScheme.onSurface,
    );
  }

  void _generateNewAddress() {
    setState(() {
      // Simulate new address generation
      final newAddress = _generateRandomAddress();
      supportedAssets[selectedAssetIndex]["address"] = newAddress;
    });

    Fluttertoast.showToast(
      msg: "New address generated",
      toastLength: Toast.LENGTH_SHORT,
      gravity: ToastGravity.BOTTOM,
      backgroundColor: AppTheme.darkTheme.colorScheme.surface,
      textColor: AppTheme.darkTheme.colorScheme.onSurface,
    );
  }

  String _generateRandomAddress() {
    final selectedAsset = supportedAssets[selectedAssetIndex];
    final symbol = selectedAsset["symbol"] as String;

    switch (symbol) {
      case "BTC":
        return "bc1q${_generateRandomString(39)}";
      case "ETH":
        return "0x${_generateRandomString(40)}";
      case "BNB":
        return "bnb1${_generateRandomString(38)}";
      default:
        return _generateRandomString(42);
    }
  }

  String _generateRandomString(int length) {
    const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
    return String.fromCharCodes(Iterable.generate(
        length,
        (_) => chars.codeUnitAt((chars.length *
                (DateTime.now().millisecondsSinceEpoch % 1000) /
                1000)
            .floor())));
  }

  @override
  Widget build(BuildContext context) {
    final selectedAsset = supportedAssets[selectedAssetIndex];

    return Scaffold(
      backgroundColor: AppTheme.darkTheme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: AppTheme.darkTheme.scaffoldBackgroundColor,
        elevation: 0,
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: CustomIconWidget(
            iconName: 'close',
            color: AppTheme.darkTheme.colorScheme.onSurface,
            size: 24,
          ),
        ),
        title: Text(
          'Receive',
          style: AppTheme.darkTheme.textTheme.titleLarge,
        ),
        centerTitle: true,
        actions: [
          IconButton(
            onPressed: () {
              setState(() {
                isHighContrast = !isHighContrast;
              });
            },
            icon: CustomIconWidget(
              iconName: 'contrast',
              color: AppTheme.darkTheme.colorScheme.onSurface,
              size: 24,
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 2.h),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Asset Selector
              AssetSelectorWidget(
                assets: supportedAssets,
                selectedIndex: selectedAssetIndex,
                onAssetSelected: (index) {
                  setState(() {
                    selectedAssetIndex = index;
                  });
                },
              ),

              SizedBox(height: 3.h),

              // QR Code Section
              QRCodeWidget(
                address: selectedAsset["address"] as String,
                amount: "",
                symbol: selectedAsset["symbol"] as String,
                isHighContrast: isHighContrast,
              ),

              SizedBox(height: 3.h),

              // Address Display
              AddressDisplayWidget(
                address: selectedAsset["address"] as String,
                onCopy: () =>
                    _copyToClipboard(selectedAsset["address"] as String),
                onRefresh: _generateNewAddress,
              ),

              SizedBox(height: 2.h),

              // Share Button
              SizedBox(
                width: double.infinity,
                height: 6.h,
                child: ElevatedButton.icon(
                  onPressed: _shareAddress,
                  icon: CustomIconWidget(
                    iconName: 'share',
                    color: AppTheme.darkTheme.colorScheme.onPrimary,
                    size: 20,
                  ),
                  label: Text(
                    'Share Address',
                    style: AppTheme.darkTheme.textTheme.labelLarge?.copyWith(
                      color: AppTheme.darkTheme.colorScheme.onPrimary,
                    ),
                  ),
                  style: AppTheme.darkTheme.elevatedButtonTheme.style,
                ),
              ),

              SizedBox(height: 3.h),

              // Network Warning
              Container(
                padding: EdgeInsets.all(3.w),
                decoration: BoxDecoration(
                  color: AppTheme.darkTheme.colorScheme.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppTheme.warning.withValues(alpha: 0.3),
                    width: 1,
                  ),
                ),
                child: Row(
                  children: [
                    CustomIconWidget(
                      iconName: 'warning',
                      color: AppTheme.warning,
                      size: 20,
                    ),
                    SizedBox(width: 3.w),
                    Expanded(
                      child: Text(
                        selectedAsset["warning"] as String,
                        style: AppTheme.darkTheme.textTheme.bodySmall?.copyWith(
                          color: AppTheme.warning,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              SizedBox(height: 3.h),

              // Recent Addresses
              RecentAddressesWidget(
                addresses: recentAddresses,
                onCopy: _copyToClipboard,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
