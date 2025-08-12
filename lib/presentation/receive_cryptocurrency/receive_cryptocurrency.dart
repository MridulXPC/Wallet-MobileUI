import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:sizer/sizer.dart';

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
  
  // Address lengths for different cryptocurrencies

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



  void _showRecentAddressesBottomSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.7,
          decoration: const BoxDecoration(
            color: Color(0xFF1A1D29),
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              // Handle bar
              Container(
                margin: const EdgeInsets.only(top: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            
              Expanded(
                child: RecentAddressesWidget(
                  addresses: _recentAddresses.map((addr) => {
                    "address": addr.address,
                    "timestamp": addr.timestamp,
                    "asset": addr.asset,
                    "used": addr.used,
                  }).toList(),
                  onCopy: _copyToClipboard,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  CryptocurrencyAsset get _selectedAsset => _supportedAssets[_selectedAssetIndex];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Scaffold(
      backgroundColor: const Color(0xFF1A1D29),
      appBar: _buildAppBar(theme),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 0.0.h),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
             
              _buildMergedQRAndAddressSection(),
              SizedBox(height: 2.h),
              _buildShareButton(theme),
       
            ],
          ),
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(ThemeData theme) {
    return AppBar(
      backgroundColor: const Color(0xFF1A1D29),
      elevation: 0,
      leading: IconButton(
        onPressed: () => Navigator.pop(context),
        icon: const Icon(
          Icons.arrow_back_ios,
          color: Colors.white,
          size: 20,
        ),
      ),
      title: const Text(
        'Receive',
        style: TextStyle(
          color: Colors.white,
          fontSize: 20,
          fontWeight: FontWeight.w600,
        ),
      ),
      centerTitle: true,
      actions: [
        IconButton(
          onPressed: _showRecentAddressesBottomSheet,
          icon: const Icon(
            Icons.history,
            color: Colors.white70,
            size: 24,
          ),
          tooltip: 'Recent Addresses',
        ),
       
      ],
    );
  }


  Widget _buildMergedQRAndAddressSection() {
    return Container(
    
      padding: const EdgeInsets.all(8),
      child: Column(
        children: [
          // QR Code Section
          QRCodeWidget(
            address: _selectedAsset.address,
            amount: "",
            symbol: _selectedAsset.symbol,
            isHighContrast: _isHighContrast,
          ),
          const SizedBox(height: 24),
          
          // Address Display Section
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Wallet Address',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 12),
              
              // Address container
              Container(
          
                child: Column(
                  children: [
                    Text(
                      _selectedAsset.address,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        letterSpacing: 0.5,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    
                    // Action buttons
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () => _copyToClipboard(_selectedAsset.address),
                            icon: const Icon(Icons.copy, size: 18),
                            label: const Text('Copy'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF4A4D5A),
                              foregroundColor: Colors.white70,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                          ),
                        ),
                  
                     
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildShareButton(ThemeData theme) {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color.fromARGB(255, 100, 162, 228), Color(0xFF1A73E8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF4F46E5).withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      width: double.infinity,
      height: 56,
      child: ElevatedButton.icon(
        onPressed: _shareAddress,
        icon: const Icon(
          Icons.share,
          color: Colors.white,
          size: 20,
        ),
        label: const Text(
          'Share Address',
          style: TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
    );
  }

}