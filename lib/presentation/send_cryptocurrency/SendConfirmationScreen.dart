// lib/presentation/send_cryptocurrency/SendConfirmationScreen.dart
import 'package:cryptowallet/presentation/send_cryptocurrency/SendConfirmationView.dart';

import 'package:cryptowallet/presentation/send_cryptocurrency/send_cryptocurrency.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sizer/sizer.dart';

class SendConfirmationScreen extends StatefulWidget {
  /// Pass the flow data from Screen 1 (SendCryptocurrency)
  final SendFlowData flowData;

  const SendConfirmationScreen({
    super.key,
    required this.flowData,
  });

  @override
  State<SendConfirmationScreen> createState() => _SendConfirmationScreenState();
}

class _SendConfirmationScreenState extends State<SendConfirmationScreen> {
  final TextEditingController _addressController = TextEditingController();
  bool _saveAsContact = false;
  bool _isAddressValid = false;
  String _addressType = 'Unknown';

  @override
  void initState() {
    super.initState();
    // prefill if the previous step already had an address (rare)
    _addressController.text = widget.flowData.toAddress ?? '';
    _addressController.addListener(_validateAddress);
    _validateAddress();
  }

  @override
  void dispose() {
    _addressController.dispose();
    super.dispose();
  }

  // --------- Helpers ---------
  String get _assetSymbol => widget.flowData.assetSymbol;
  String get _assetName => widget.flowData.assetName;
  double get _assetPrice => widget.flowData.usdValue > 0
      ? (widget.flowData.usdValue /
          (double.tryParse(widget.flowData.amount) ?? 1.0)
              .clamp(0.00000001, double.infinity))
      : widget.flowData.amount.isNotEmpty
          ? widget
              .flowData.usdValue // may be zero; only used for fiat fee approx
          : 0.0;

  double _calculateNetworkFee() {
    // Same logic you had, but based on flowData.assetSymbol.
    switch (_assetSymbol.toUpperCase()) {
      case 'TRX':
        return 1.1; // example TRX fee
      case 'BTC':
        return 0.0001; // example BTC fee
      case 'ETH':
        return 0.002; // example ETH fee
      default:
        return 1.0;
    }
  }

  void _validateAddress() {
    final address = _addressController.text.trim();
    setState(() {
      if (address.isEmpty) {
        _isAddressValid = false;
        _addressType = 'Unknown';
      } else if (address.startsWith('T') && address.length >= 34) {
        _isAddressValid = true;
        _addressType = 'TRON Address';
      } else if (address.startsWith('0x') && address.length == 42) {
        _isAddressValid = true;
        _addressType = 'Ethereum Address';
      } else if ((address.startsWith('1') ||
              address.startsWith('3') ||
              address.startsWith('bc1')) &&
          address.length >= 26) {
        _isAddressValid = true;
        _addressType = 'Bitcoin Address';
      } else {
        _isAddressValid = address.length > 10;
        _addressType = 'Unknown';
      }
    });
  }

  Future<void> _pasteFromClipboard() async {
    final clipboardData = await Clipboard.getData('text/plain');
    if (clipboardData != null && clipboardData.text != null) {
      _addressController.text = clipboardData.text!;
    }
  }

  void _scanQRCode() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('QR Code scanner would open here'),
        backgroundColor: Color(0xFF4C5563),
      ),
    );
  }

  void _openAddressBook() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Address book would open here'),
        backgroundColor: Color(0xFF4C5563),
      ),
    );
  }

  String _formatAddress(String address) {
    if (address.length > 10) {
      return '${address.substring(0, 6)}...${address.substring(address.length - 4)}';
    }
    return address;
  }

  // ---- NAVIGATE TO REVIEW (Screen 2) ----
  void _proceedToNext() {
    final enteredAddress = _addressController.text.trim();

    if (!_isAddressValid) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a valid address'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Take the flowData from Screen 1 and attach the entered address
    final flowDataWithAddress = widget.flowData.copyWith(
      toAddress: enteredAddress,
    );

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SendConfirmationView(
          flowData: flowDataWithAddress,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final amountStr = widget.flowData.amount; // crypto amount as string
    final networkFee = _calculateNetworkFee();
    // If you want to show fiat fee: use explicit price if you have it.
    // Here we fallback to 0 if price is unknown.
    final fiatFee = _assetPrice > 0 ? networkFee * _assetPrice : 0.0;

    return Scaffold(
      backgroundColor: const Color(0xFF0B0D1A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0B0D1A),
        elevation: 0,
        leading: IconButton(
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white, size: 16),
        ),
        title: const Text(
          'Send',
          style: TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
      ),
      body: Column(
        children: [
          // Scrollable content
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.symmetric(horizontal: 2.w),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Amount Display
                  Center(
                    child: Column(
                      children: [
                        const Text(
                          'Amount',
                          style: TextStyle(
                            color: Color(0xFF9CA3AF),
                            fontSize: 16,
                          ),
                        ),
                        SizedBox(height: 1.h),
                        Text(
                          amountStr,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 28,
                            fontWeight: FontWeight.w300,
                          ),
                        ),
                        Text(
                          _assetSymbol,
                          style: const TextStyle(
                            color: Color(0xFF9CA3AF),
                            fontSize: 16,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 2.h),

                  // To Address Section
                  const Text(
                    'To',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                  SizedBox(height: 1.h),

                  // Address Input Field
                  Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFF2A2D3A),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: _isAddressValid
                            ? Colors.green.withOpacity(0.5)
                            : const Color(0xFF404453),
                        width: 1,
                      ),
                    ),
                    child: Padding(
                      padding:
                          EdgeInsets.symmetric(horizontal: 2.w, vertical: 1.h),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Left: Type + TextField
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _addressType,
                                  style: TextStyle(
                                    color: _isAddressValid
                                        ? Colors.green
                                        : const Color(0xFF9CA3AF),
                                    fontSize: 12,
                                    fontWeight: FontWeight.w400,
                                  ),
                                ),
                                SizedBox(height: 0.5.h),
                                TextField(
                                  controller: _addressController,
                                  style: const TextStyle(
                                      color: Colors.white, fontSize: 16),
                                  maxLines: null,
                                  decoration: const InputDecoration(
                                    hintText: '',
                                    border: InputBorder.none,
                                    contentPadding: EdgeInsets.zero,
                                    isDense: true,
                                  ),
                                ),
                              ],
                            ),
                          ),

                          // Right: preview + clear
                          if (_addressController.text.isNotEmpty)
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  _formatAddress(_addressController.text),
                                  style: const TextStyle(
                                    color: Color(0xFF9CA3AF),
                                    fontSize: 14,
                                  ),
                                ),
                                SizedBox(height: 0.5.h),
                                GestureDetector(
                                  onTap: () => _addressController.clear(),
                                  child: const Icon(
                                    Icons.close,
                                    color: Color(0xFF9CA3AF),
                                    size: 20,
                                  ),
                                ),
                              ],
                            ),
                        ],
                      ),
                    ),
                  ),

                  SizedBox(height: 1.h),

                  // Action Buttons Row
                  Row(
                    children: [
                      Expanded(
                        child: _buildActionButton(
                          icon: Icons.content_paste_outlined,
                          onTap: _pasteFromClipboard,
                        ),
                      ),
                      SizedBox(width: 1.w),
                      Expanded(
                        child: _buildActionButton(
                          icon: Icons.qr_code_scanner_outlined,
                          onTap: _scanQRCode,
                        ),
                      ),
                      SizedBox(width: 1.w),
                      Expanded(
                        child: _buildActionButton(
                          icon: Icons.import_contacts_outlined,
                          onTap: _openAddressBook,
                        ),
                      ),
                    ],
                  ),

                  SizedBox(height: 4.h),

                  // Save as Contact Toggle
                  Row(
                    children: [
                      GestureDetector(
                        onTap: () {
                          setState(() {
                            _saveAsContact = !_saveAsContact;
                          });
                        },
                        child: Container(
                          width: 40,
                          height: 22,
                          padding: const EdgeInsets.all(2),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(14),
                            color: _saveAsContact
                                ? Colors.white
                                : const Color(0xFF4A4D5A),
                          ),
                          child: AnimatedAlign(
                            duration: const Duration(milliseconds: 200),
                            alignment: _saveAsContact
                                ? Alignment.centerRight
                                : Alignment.centerLeft,
                            child: Container(
                              width: 16,
                              height: 18,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: _saveAsContact
                                    ? const Color(0xFF0B0D1A)
                                    : Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ),
                      SizedBox(width: 2.w),
                      const Expanded(
                        child: Text(
                          'Save as a contact in my Address Book',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                      ),
                    ],
                  ),

                  SizedBox(height: 2.h),

                  // Fee estimate (fiat)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Estimated FIAT value',
                        style: TextStyle(
                          color: Color(0xFF9CA3AF),
                          fontSize: 16,
                        ),
                      ),
                      Text(
                        '${_calculateNetworkFee().toStringAsFixed(4)} $_assetSymbol'
                        ' ≈ \$${fiatFee.toStringAsFixed(4)}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // Fixed bottom section with warning and button
          Column(
            children: [
              // Warning Message
              Container(
                margin: EdgeInsets.symmetric(horizontal: 1.w),
                padding: EdgeInsets.all(3.w),
                decoration: BoxDecoration(
                  color: const Color(0xFFEF6727),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  'Some of your $_assetSymbol will be discounted to activate the receiving account',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.w400,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),

              // Next Button
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 2.h),
                child: Container(
                  width: double.infinity,
                  height: 6.h,
                  decoration: BoxDecoration(
                    color: _isAddressValid
                        ? Colors.white
                        : const Color(0xFF4C5563),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: _isAddressValid ? _proceedToNext : null,
                      borderRadius: BorderRadius.circular(30),
                      child: Center(
                        child: Text(
                          'Next',
                          style: TextStyle(
                            color: _isAddressValid
                                ? const Color(0xFF0B0D1A)
                                : const Color(0xFF9CA3AF),
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 4.h,
        decoration: BoxDecoration(
          color: const Color(0xFF2A2D3A),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Center(
          child: Icon(
            icon,
            color: Colors.white,
            size: 24,
          ),
        ),
      ),
    );
  }
}
