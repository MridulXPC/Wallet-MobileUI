import 'package:flutter/material.dart';
import 'package:sizer/sizer.dart';

import '../../core/app_export.dart';
import './widgets/amount_input_widget.dart';
import './widgets/asset_selector_widget.dart';
import './widgets/recipient_address_widget.dart';
import './widgets/review_section_widget.dart';
import './widgets/transaction_fee_widget.dart';

class SendCryptocurrency extends StatefulWidget {
  const SendCryptocurrency({super.key});

  @override
  State<SendCryptocurrency> createState() => _SendCryptocurrencyState();
}

class _SendCryptocurrencyState extends State<SendCryptocurrency> {
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _amountController = TextEditingController();
  final FocusNode _addressFocusNode = FocusNode();
  final FocusNode _amountFocusNode = FocusNode();

  String _selectedAsset = 'Bitcoin';
  String _selectedAssetSymbol = 'BTC';
  double _selectedAssetBalance = 0.5432;
  String _selectedAssetIcon =
      'assets/currencyicons/bitcoin.png';

  bool _isAddressValid = false;
  bool _isAmountValid = false;
  bool _isLoading = false;
  String _feeType = 'Standard';
  double _networkFee = 0.0001;
  double _fiatConversion = 0.0;

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
    "name": "Solana",
    "symbol": "SOL",
    "balance": 15.8934,
    "icon": "assets/currencyicons/currency.png",
    "price": 98.50,
  },
];



  @override
  void initState() {
    super.initState();
    _addressController.addListener(_validateAddress);
    _amountController.addListener(_validateAmount);
  }

  @override
  void dispose() {
    _addressController.dispose();
    _amountController.dispose();
    _addressFocusNode.dispose();
    _amountFocusNode.dispose();
    super.dispose();
  }

  void _validateAddress() {
    final address = _addressController.text.trim();
    setState(() {
      _isAddressValid = address.length >= 26 && address.length <= 62;
    });
  }

  void _validateAmount() {
    final amount = double.tryParse(_amountController.text);
    setState(() {
      _isAmountValid =
          amount != null && amount > 0 && amount <= _selectedAssetBalance;
      if (_isAmountValid) {
        final selectedAsset = _cryptoAssets.firstWhere(
          (asset) => (asset["symbol"] as String) == _selectedAssetSymbol,
        );
        _fiatConversion = amount! * (selectedAsset["price"] as double);
      } else {
        _fiatConversion = 0.0;
      }
    });
  }

  void _onAssetSelected(Map<String, dynamic> asset) {
    setState(() {
      _selectedAsset = asset["name"] as String;
      _selectedAssetSymbol = asset["symbol"] as String;
      _selectedAssetBalance = asset["balance"] as double;
      _selectedAssetIcon = asset["icon"] as String;
    });
    _validateAmount();
  }


  void _onMaxPressed() {
    _amountController.text = _selectedAssetBalance.toString();
    _validateAmount();
  }

  void _onFeeTypeChanged(String feeType) {
    setState(() {
      _feeType = feeType;
      switch (feeType) {
        case 'Fast':
          _networkFee = 0.0003;
          break;
        case 'Standard':
          _networkFee = 0.0001;
          break;
        case 'Slow':
          _networkFee = 0.00005;
          break;
      }
    });
  }

  Future<void> _onSendPressed() async {
    if (!_isFormValid()) return;

    setState(() {
      _isLoading = true;
    });

    // Simulate biometric authentication for amounts > $1000
    final amount = double.parse(_amountController.text);
    final selectedAsset = _cryptoAssets.firstWhere(
      (asset) => (asset["symbol"] as String) == _selectedAssetSymbol,
    );
    final fiatValue = amount * (selectedAsset["price"] as double);

    if (fiatValue > 1000) {
      final biometricResult = await _showBiometricDialog();
      if (!biometricResult) {
        setState(() {
          _isLoading = false;
        });
        return;
      }
    }

    // Simulate transaction processing
    await Future.delayed(const Duration(seconds: 2));

    if (mounted) {
      setState(() {
        _isLoading = false;
      });

      // Show success dialog
      _showSuccessDialog();
    }
  }

  Future<bool> _showBiometricDialog() async {
    return await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            backgroundColor: AppTheme.darkTheme.cardColor,
            title: Text(
              'Biometric Authentication Required',
              style: AppTheme.darkTheme.textTheme.titleMedium?.copyWith(
                color: AppTheme.textHighEmphasis,
              ),
            ),
            content: Text(
              'This transaction requires biometric verification for security.',
              style: AppTheme.darkTheme.textTheme.bodyMedium?.copyWith(
                color: AppTheme.textMediumEmphasis,
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: Text(
                  'Cancel',
                  style: TextStyle(color: AppTheme.textMediumEmphasis),
                ),
              ),
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  foregroundColor: AppTheme.onPrimary,
                ),
                child: const Text('Authenticate'),
              ),
            ],
          ),
        ) ??
        false;
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.darkTheme.cardColor,
        title: Row(
          children: [
            CustomIconWidget(
              iconName: 'check_circle',
              color: AppTheme.success,
              size: 24,
            ),
            SizedBox(width: 2.w),
            Text(
              'Transaction Sent',
              style: AppTheme.darkTheme.textTheme.titleMedium?.copyWith(
                color: AppTheme.textHighEmphasis,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Your transaction has been submitted to the blockchain.',
              style: AppTheme.darkTheme.textTheme.bodyMedium?.copyWith(
                color: AppTheme.textMediumEmphasis,
              ),
            ),
            SizedBox(height: 2.h),
            Container(
              padding: EdgeInsets.all(3.w),
              decoration: BoxDecoration(
                color: AppTheme.surface,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Transaction Hash:',
                    style: AppTheme.darkTheme.textTheme.labelMedium?.copyWith(
                      color: AppTheme.textMediumEmphasis,
                    ),
                  ),
                  SizedBox(height: 1.h),
                  Text(
                    '0x7a8b9c2d3e4f5g6h7i8j9k0l1m2n3o4p5q6r7s8t9u0v1w2x3y4z5a6b7c8d9e0f',
                    style: AppTheme.monoTextStyle(
                      isLight: false,
                      fontSize: 12,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            SizedBox(height: 2.h),
            Text(
              'Estimated confirmation time: 10-15 minutes',
              style: AppTheme.darkTheme.textTheme.bodySmall?.copyWith(
                color: AppTheme.textMediumEmphasis,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.of(context).pop();
            },
            child: Text(
              'View in Explorer',
              style: TextStyle(color: AppTheme.primary),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.of(context).pop();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primary,
              foregroundColor: AppTheme.onPrimary,
            ),
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }

  bool _isFormValid() {
    return _isAddressValid && _isAmountValid && !_isLoading;
  }

  Future<bool> _onWillPop() async {
    if (_addressController.text.isNotEmpty ||
        _amountController.text.isNotEmpty) {
      return await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              backgroundColor: AppTheme.darkTheme.cardColor,
              title: Text(
                'Discard Changes?',
                style: AppTheme.darkTheme.textTheme.titleMedium?.copyWith(
                  color: AppTheme.textHighEmphasis,
                ),
              ),
              content: Text(
                'You have unsaved changes. Are you sure you want to go back?',
                style: AppTheme.darkTheme.textTheme.bodyMedium?.copyWith(
                  color: AppTheme.textMediumEmphasis,
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: Text(
                    'Cancel',
                    style: TextStyle(color: AppTheme.textMediumEmphasis),
                  ),
                ),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  child: Text(
                    'Discard',
                    style: TextStyle(color: AppTheme.error),
                  ),
                ),
              ],
            ),
          ) ??
          false;
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: _onWillPop,
      child: Scaffold(
        backgroundColor: AppTheme.background,
        appBar: AppBar(
          backgroundColor: AppTheme.background,
          elevation: 0,
          leading: IconButton(
            onPressed: () async {
              final shouldPop = await _onWillPop();
              if (shouldPop && mounted) {
                Navigator.of(context).pop();
              }
            },
            icon: CustomIconWidget(
              iconName: 'close',
              color: AppTheme.textHighEmphasis,
              size: 24,
            ),
          ),
          title: Text(
            'Send',
            style: AppTheme.darkTheme.textTheme.titleLarge?.copyWith(
              color: AppTheme.textHighEmphasis,
              fontWeight: FontWeight.w600,
            ),
          ),
          centerTitle: true,
        ),
        body: SafeArea(
          child: 
          Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: EdgeInsets.symmetric(horizontal: 4.w),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(height: 1.h),

                      // Asset Selector
                    AssetSelectorWidget(
  selectedAsset: _selectedAsset,
  selectedAssetSymbol: _selectedAssetSymbol,
  selectedAssetBalance: _selectedAssetBalance,
  selectedAssetIcon: _selectedAssetIcon,
  cryptoAssets: _cryptoAssets,
  onAssetSelected: (selected) {
    _onAssetSelected(selected);
  },
),


                      SizedBox(height: 1.h),

                      // Recipient Address
                      RecipientAddressWidget(
                        controller: _addressController,
                        focusNode: _addressFocusNode,
                        isValid: _isAddressValid,
                      ),

                      SizedBox(height: 1.h),

                      // Amount Input
                      AmountInputWidget(
                        controller: _amountController,
                        focusNode: _amountFocusNode,
                        selectedAssetSymbol: _selectedAssetSymbol,
                        selectedAssetBalance: _selectedAssetBalance,
                        fiatConversion: _fiatConversion,
                        isValid: _isAmountValid,
                        onMaxPressed: _onMaxPressed,
                      ),

                      SizedBox(height: 1.h),

                      // Transaction Fee
                      TransactionFeeWidget(
                        selectedFeeType: _feeType,
                        networkFee: _networkFee,
                        selectedAssetSymbol: _selectedAssetSymbol,
                        onFeeTypeChanged: _onFeeTypeChanged,
                      ),

                      SizedBox(height: 1.h),

                      // Review Section
                      if (_isAddressValid && _isAmountValid) ...[
                        ReviewSectionWidget(
                          recipientAddress: _addressController.text,
                          amount:
                              double.tryParse(_amountController.text) ?? 0.0,
                          assetSymbol: _selectedAssetSymbol,
                          networkFee: _networkFee,
                          fiatConversion: _fiatConversion,
                        ),
                        SizedBox(height: 1.h),
                      ],
                    ],
                  ),
                ),
              ),

              // Send Button
              Container(
                padding: EdgeInsets.all(4.w),
                child: SizedBox(
                  width: double.infinity,
                  height: 6.h,
                  child: ElevatedButton(
                    onPressed: _isFormValid() ? _onSendPressed : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor:
                          _isFormValid() ? AppTheme.primary : AppTheme.surface,
                      foregroundColor: _isFormValid()
                          ? AppTheme.onPrimary
                          : AppTheme.textDisabled,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: _isLoading
                        ? SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                  AppTheme.onPrimary),
                            ),
                          )
                        : Text(
                            'Send',
                            style: AppTheme.darkTheme.textTheme.titleMedium
                                ?.copyWith(
                              color: _isFormValid()
                                  ? AppTheme.onPrimary
                                  : AppTheme.textDisabled,
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
  }
}
