import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:sizer/sizer.dart';

import '../../core/app_export.dart';
import './widgets/address_display_widget.dart';
import './widgets/asset_selector_widget.dart';
import './widgets/qr_code_widget.dart';
import './widgets/recent_addresses_widget.dart';

// Models for better type safety
class CryptocurrencyAsset {
  final String id;
  final String name;
  final String symbol;
  final String icon;
  final String balance;
  String address;
  final String network;
  final String warning;

  CryptocurrencyAsset({
    required this.id,
    required this.name,
    required this.symbol,
    required this.icon,
    required this.balance,
    required this.address,
    required this.network,
    required this.warning,
  });
}

class RecentAddress {
  final String address;
  final String timestamp;
  final String asset;
  final bool used;

  const RecentAddress({
    required this.address,
    required this.timestamp,
    required this.asset,
    required this.used,
  });
}

class ReceiveCryptocurrency extends StatefulWidget {
  const ReceiveCryptocurrency({super.key});

  @override
  State<ReceiveCryptocurrency> createState() => _ReceiveCryptocurrencyState();
}

class _ReceiveCryptocurrencyState extends State<ReceiveCryptocurrency> {
  // Constants for better maintainability
  static const String _btcAddressPrefix = 'bc1q';
  static const String _ethAddressPrefix = '0x';
  static const String _bnbAddressPrefix = 'bnb1';
  static const String _addressChars = 'abcdefghijklmnopqrstuvwxyz0123456789';
  
  // Address lengths for different cryptocurrencies
  static const Map<String, int> _addressLengths = {
    'BTC': 39,
    'ETH': 40,
    'BNB': 38,
  };

  // Cached data - using models for type safety
  List<CryptocurrencyAsset> _supportedAssets = [];
  List<RecentAddress> _recentAddresses = [];
  
  int _selectedAssetIndex = 0;
  bool _isHighContrast = false;

  @override
  void initState() {
    super.initState();
    _initializeData();
    _refreshBalance();
  }

  void _initializeData() {
    _supportedAssets = [
      CryptocurrencyAsset(
        id: "bitcoin",
        name: "Bitcoin",
        symbol: "BTC",
        icon: "assets/currencyicons/bitcoin.png",
        balance: "0.00234567",
        address: "bc1qxy2kgdygjrsqtzq2n0yrf2493p83kkfjhx0wlh",
        network: "Bitcoin",
        warning: "Only send Bitcoin to this address",
      ),
      CryptocurrencyAsset(
        id: "ethereum",
        name: "Ethereum",
        symbol: "ETH",
        icon: "assets/currencyicons/ethereum.png",
        balance: "1.23456789",
        address: "0x742d35Cc6634C0532925a3b8D4C2E5e2c8b6c8e3",
        network: "Ethereum",
        warning: "Only send Ethereum and ERC-20 tokens to this address",
      ),
    ];

    _recentAddresses = const [
      RecentAddress(
        address: "bc1qxy2kgdygjrsqtzq2n0yrf2493p83kkfjhx0wlh",
        timestamp: "2024-01-15 14:30:00",
        asset: "BTC",
        used: true,
      ),
      RecentAddress(
        address: "0x742d35Cc6634C0532925a3b8D4C2E5e2c8b6c8e3",
        timestamp: "2024-01-14 09:15:00",
        asset: "ETH",
        used: true,
      ),
      RecentAddress(
        address: "bnb1grpf0955h0ykzq3ar5nmum7y6gdfl6lxfn46h2",
        timestamp: "2024-01-13 16:45:00",
        asset: "BNB",
        used: false,
      ),
    ];
  }

  Future<void> _refreshBalance() async {
    // Simulate async balance refresh
    // In real implementation, this would call an API
    await Future.delayed(const Duration(milliseconds: 100));
    if (mounted) {
      setState(() {
        // Update balance data
      });
    }
  }

  Future<void> _copyToClipboard(String text) async {
    try {
      await Clipboard.setData(ClipboardData(text: text));
      if (mounted) {
        HapticFeedback.lightImpact();
        _showToast("Address copied to clipboard");
      }
    } catch (e) {
      if (mounted) {
        _showToast("Failed to copy address");
      }
    }
  }

  void _shareAddress() {
    // In real implementation, use share_plus package
    _showToast("Share sheet opened");
  }

  void _generateNewAddress() {
    final newAddress = _generateRandomAddress();
    setState(() {
      _supportedAssets[_selectedAssetIndex].address = newAddress;
    });
    _showToast("New address generated");
  }

  String _generateRandomAddress() {
    final selectedAsset = _supportedAssets[_selectedAssetIndex];
    final symbol = selectedAsset.symbol;
    final length = _addressLengths[symbol] ?? 42;

    switch (symbol) {
      case "BTC":
        return "$_btcAddressPrefix${_generateRandomString(length)}";
      case "ETH":
        return "$_ethAddressPrefix${_generateRandomString(length)}";
      case "BNB":
        return "$_bnbAddressPrefix${_generateRandomString(length)}";
      default:
        return _generateRandomString(length);
    }
  }

  String _generateRandomString(int length) {
    // More random generation using system time and hash
    final random = DateTime.now().microsecondsSinceEpoch;
    return String.fromCharCodes(
      Iterable.generate(
        length,
        (index) => _addressChars.codeUnitAt(
          (random + index) % _addressChars.length,
        ),
      ),
    );
  }

  void _showToast(String message) {
    final theme = Theme.of(context);
    Fluttertoast.showToast(
      msg: message,
      toastLength: Toast.LENGTH_SHORT,
      gravity: ToastGravity.BOTTOM,
      backgroundColor: theme.colorScheme.surface,
      textColor: theme.colorScheme.onSurface,
    );
  }

  void _onAssetSelected(int index) {
    if (_selectedAssetIndex != index) {
      setState(() {
        _selectedAssetIndex = index;
      });
    }
  }

  void _toggleHighContrast() {
    setState(() {
      _isHighContrast = !_isHighContrast;
    });
  }
           
  CryptocurrencyAsset get _selectedAsset => _supportedAssets[_selectedAssetIndex];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: _buildAppBar(theme),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 0.h),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildAssetSelector(),
              SizedBox(height: 1.h),
              _buildQRCodeSection(),
              SizedBox(height: 1.h),
              _buildAddressDisplay(),
              SizedBox(height: 1.h),
              _buildShareButton(theme),
              SizedBox(height: 1.h),
              _buildNetworkWarning(theme),
              SizedBox(height: 1.h),
              _buildRecentAddresses(),
            ],
          ),
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(ThemeData theme) {
    return AppBar(
      backgroundColor: theme.scaffoldBackgroundColor,
      elevation: 0,
      leading: IconButton(
        onPressed: () => Navigator.pop(context),
        icon: CustomIconWidget(
          iconName: 'close',
          color: theme.colorScheme.onSurface,
          size: 24,
        ),
      ),
      title: Text(
        'Receive',
        style: theme.textTheme.titleLarge,
      ),
      centerTitle: true,
      actions: [
        IconButton(
          onPressed: _toggleHighContrast,
          icon: CustomIconWidget(
            iconName: 'contrast',
            color: theme.colorScheme.onSurface,
            size: 24,
          ),
        ),
      ],
    );
  }

  Widget _buildAssetSelector() {
    return AssetSelectorWidget(
      assets: _supportedAssets.map((asset) => {
        "id": asset.id,
        "name": asset.name,
        "symbol": asset.symbol,
        "icon": asset.icon,
        "balance": asset.balance,
        "address": asset.address,
        "network": asset.network,
        "warning": asset.warning,
      }).toList(),
      selectedIndex: _selectedAssetIndex,
      onAssetSelected: _onAssetSelected,
    );
  }

  Widget _buildQRCodeSection() {
    return QRCodeWidget(
      address: _selectedAsset.address,
      amount: "",
      symbol: _selectedAsset.symbol,
      isHighContrast: _isHighContrast,
    );
  }

  Widget _buildAddressDisplay() {
    return AddressDisplayWidget(
      address: _selectedAsset.address,
      onCopy: () => _copyToClipboard(_selectedAsset.address),
      onRefresh: _generateNewAddress,
    );
  }

  Widget _buildShareButton(ThemeData theme) {
    return SizedBox(
      width: double.infinity,
      height: 6.h,
      child: ElevatedButton.icon(
        onPressed: _shareAddress,
        icon: CustomIconWidget(
          iconName: 'share',
          color: theme.colorScheme.onPrimary,
          size: 20,
        ),
        label: Text(
          'Share Address',
          style: theme.textTheme.labelLarge?.copyWith(
            color: theme.colorScheme.onPrimary,
          ),
        ),
        style: theme.elevatedButtonTheme.style,
      ),
    );
  }

  Widget _buildNetworkWarning(ThemeData theme) {
    return Container(
      padding: EdgeInsets.all(3.w),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
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
              _selectedAsset.warning,
              style: theme.textTheme.bodySmall?.copyWith(
                color: AppTheme.warning,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecentAddresses() {
    return RecentAddressesWidget(
      addresses: _recentAddresses.map((addr) => {
        "address": addr.address,
        "timestamp": addr.timestamp,
        "asset": addr.asset,
        "used": addr.used,
      }).toList(),
      onCopy: _copyToClipboard,
    );
  }
}