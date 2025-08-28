import 'package:flutter/material.dart';

class SendConfirmationView extends StatelessWidget {
  final String fromAddress;
  final String toAddress;
  final String timeText; // e.g. "11 Aug 2025 05:23:17"
  final String assetSymbol; // e.g. "TRX"

  /// Full amount before fees (e.g. 8.15516)
  final double amount;

  /// Fee taken (e.g. 1.1)
  final double activationFee;

  /// Final amount the receiver gets (e.g. 7.05516)
  final double willReceive;

  /// e.g. "Regular"
  final String feeOption;

  /// e.g. 1.1
  final double estimatedNetworkFee;

  final VoidCallback? onConfirm;
  final VoidCallback? onClose;

  const SendConfirmationView({
    super.key,
    required this.fromAddress,
    required this.toAddress,
    required this.timeText,
    required this.assetSymbol,
    required this.amount,
    required this.activationFee,
    required this.willReceive,
    required this.feeOption,
    required this.estimatedNetworkFee,
    this.onConfirm,
    this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    const bg = Color(0xFF0C0D17);
    const textPrimary = Colors.white;
    const textSecondary = Color(0xFF9DA3AE);
    const divider = Color(0x22FFFFFF);
    const accentNote = Color(0xFFF1DF5A); // yellow note

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  _circleIconButton(
                    context,
                    icon: Icons.arrow_back_ios,
                    onTap: () => Navigator.of(context).maybePop(),
                  ),
                  const Spacer(),
                  const Text(
                    'Send Confirmation',
                    style: TextStyle(
                      color: textPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                ],
              ),
            ),

            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Big amount (top)
                    const Text(
                      'Amount',
                      style: TextStyle(
                        color: textSecondary,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      willReceive.toStringAsFixed(5),
                      style: const TextStyle(
                        color: textPrimary,
                        fontSize: 30,
                        fontWeight: FontWeight.w700,
                        height: 1.1,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      assetSymbol,
                      style: const TextStyle(
                        color: textSecondary,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1.2,
                      ),
                    ),

                    const SizedBox(height: 28),
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Transaction Details',
                        style: TextStyle(
                          color: textPrimary,
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Container(height: 1, color: divider),

                    _kvRow('From', fromAddress),
                    _kvRow('To', toAddress),
                    _kvRow('Time', timeText),
                    _kvRow(
                        'Amount', '${amount.toStringAsFixed(5)} $assetSymbol'),
                    _kvRow('Activation Fee',
                        '(-) ${activationFee.toStringAsFixed(1)} $assetSymbol'),
                    _kvRow('Will Receive',
                        '${willReceive.toStringAsFixed(5)} $assetSymbol',
                        strong: true),
                    const SizedBox(height: 10),

                    // Yellow note (copying screenshot text)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 2.0),
                      child: Text(
                        'The available total will be sent substrasting the fee',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: accentNote,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),

                    const SizedBox(height: 6),
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Fee Details',
                        style: TextStyle(
                          color: textPrimary,
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Container(height: 1, color: divider),
                    const SizedBox(height: 10),
                    _kvRow('Fee Option', feeOption),
                    _kvRow('Estimated Network Fee',
                        '${estimatedNetworkFee.toStringAsFixed(1)} $assetSymbol'),
                    const SizedBox(height: 120),
                  ],
                ),
              ),
            ),

            // Bottom Confirm button
            Padding(
              padding: const EdgeInsets.only(
                  left: 16, right: 16, bottom: 16, top: 0),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: onConfirm,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: const StadiumBorder(),
                    textStyle: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  child: const Text('Confirm'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static Widget _kvRow(String k, String v, {bool strong = false}) {
    const textPrimary = Colors.white;
    const textSecondary = Color(0xFF9DA3AE);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Key
          Expanded(
            flex: 43,
            child: Text(
              k,
              style: const TextStyle(
                color: textSecondary,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          // Value
          Expanded(
            flex: 57,
            child: Text(
              v,
              textAlign: TextAlign.right,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: textPrimary,
                fontSize: 12,
                fontWeight: strong ? FontWeight.w700 : FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  static Widget _circleIconButton(BuildContext context,
      {required IconData icon, VoidCallback? onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(22),
      child: Container(
        height: 36,
        width: 36,
        child: Icon(icon, size: 18, color: Colors.white),
      ),
    );
  }
}
