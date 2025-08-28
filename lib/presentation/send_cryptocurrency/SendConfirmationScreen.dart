import 'package:cryptowallet/presentation/send_cryptocurrency/SendConfirmationView.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sizer/sizer.dart';
import 'package:intl/intl.dart';

class SendConfirmationScreen extends StatefulWidget {
  final String amount; // string amount user typed, e.g. "8.15516"
  final String assetSymbol; // e.g. "TRX"
  final String assetName;
  final String assetIconPath;
  final double assetPrice; // fiat price of 1 unit (for fee estimate display)
  final double usdValue; // not used here but kept for compatibility

  const SendConfirmationScreen({
    super.key,
    required this.amount,
    required this.assetSymbol,
    required this.assetName,
    required this.assetIconPath,
    required this.assetPrice,
    required this.usdValue,
  });

  @override
  State<SendConfirmationScreen> createState() => _SendConfirmationScreenState();
}

class _SendConfirmationScreenState extends State<SendConfirmationScreen> {
  final TextEditingController _addressController = TextEditingController();
  bool _saveAsContact = false;
  bool _isAddressValid = false;
  String _addressType = 'Unknown';

  // TODO: replace with your real wallet address (from provider/state)
  final String _myWalletAddress = 'TAJ6r4Ph2i4JHNs8Pkpysn7wQBnot372GF';

  @override
  void initState() {
    super.initState();
    _addressController.addListener(_validateAddress);
  }

  @override
  void dispose() {
    _addressController.dispose();
    super.dispose();
  }

  void _validateAddress() {
    final address = _addressController.text.trim();
    setState(() {
      if (address.isEmpty) {
        _isAddressValid = false;
        _addressType = 'Unknown';
      } else if (address.startsWith('T') && address.length >= 34) {
        // TRON (basic)
        _isAddressValid = true;
        _addressType = 'TRON Address';
      } else if (address.startsWith('0x') && address.length == 42) {
        // Ethereum (basic)
        _isAddressValid = true;
        _addressType = 'Ethereum Address';
      } else if ((address.startsWith('1') ||
              address.startsWith('3') ||
              address.startsWith('bc1')) &&
          address.length >= 26) {
        // Bitcoin (basic)
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

  // ---- NAVIGATE TO CONFIRMATION ----
  void _proceedToNext() {
    final to = _addressController.text.trim();
    final double amount = double.tryParse(widget.amount) ?? 0;

    // Use a dynamic fee based on asset
    final double fee = _calculateNetworkFee();
    final double willReceive = (amount - fee).clamp(0, double.infinity);

    final String timeText =
        DateFormat('dd MMM yyyy HH:mm:ss').format(DateTime.now());

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SendConfirmationView(
          fromAddress: _myWalletAddress,
          toAddress: to,
          timeText: timeText,
          assetSymbol: widget.assetSymbol, // e.g. TRX
          amount: amount, // before fees
          activationFee: fee,
          willReceive: double.parse(willReceive.toStringAsFixed(5)),
          feeOption: 'Regular',
          estimatedNetworkFee: fee,
          onConfirm: () => _sendTransaction(to, amount),
        ),
      ),
    );
  }

  Future<void> _sendTransaction(String to, double amount) async {
    // TODO: integrate your send/broadcast API
    // final txId = await wallet.send(asset: widget.assetSymbol, to: to, amount: amount);
    if (mounted) Navigator.pop(context);
  }

  String _formatAddress(String address) {
    if (address.length > 10) {
      return '${address.substring(0, 6)}...${address.substring(address.length - 4)}';
    }
    return address;
  }

  double _calculateNetworkFee() {
    switch (widget.assetSymbol.toUpperCase()) {
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

  @override
  Widget build(BuildContext context) {
    final networkFee = _calculateNetworkFee();
    final fiatFee = networkFee * widget.assetPrice;

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
                          widget.amount,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 28,
                            fontWeight: FontWeight.w300,
                          ),
                        ),
                        Text(
                          widget.assetSymbol,
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
                        '${networkFee.toStringAsFixed(4)} ${widget.assetSymbol} ≈ \$${fiatFee.toStringAsFixed(4)}',
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
                  'Some of your ${widget.assetSymbol} will be discounted to activate the receiving account',
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
