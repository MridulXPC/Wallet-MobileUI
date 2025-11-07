import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class TransactionSuccessScreen extends StatelessWidget {
  final String? txId;
  final String assetSymbol;
  final double amount;
  final double fee;
  final String toAddress;

  const TransactionSuccessScreen({
    super.key,
    required this.txId,
    required this.assetSymbol,
    required this.amount,
    required this.fee,
    required this.toAddress,
  });

  // ✅ Define colors here (accessible across methods)
  static const Color bg = Color(0xFF0C0D17);
  static const Color textPrimary = Colors.white;
  static const Color textSecondary = Color(0xFF9DA3AE);
  static const Color accent = Color(0xFFF1DF5A);

  @override
  Widget build(BuildContext context) {
    final time = DateFormat('dd MMM yyyy HH:mm:ss').format(DateTime.now());

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text(
          "Transaction Successful",
          style: TextStyle(color: textPrimary),
        ),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Center(
              child: Icon(Icons.check_circle, color: accent, size: 80),
            ),
            const SizedBox(height: 20),
            Center(
              child: Text(
                'Transfer Completed',
                style: const TextStyle(
                  color: textPrimary,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 40),
            _infoRow("To Address", toAddress),
            _infoRow("Asset", assetSymbol),
            _infoRow("Amount Sent", "$amount $assetSymbol"),
            _infoRow("Network Fee", "$fee $assetSymbol"),
            if (txId != null) _infoRow("Transaction ID", txId!),
            _infoRow("Date", time),
            const Spacer(),
            Center(
              child: ElevatedButton(
                onPressed: () {
                  Navigator.of(context).popUntil((route) => route.isFirst);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.black,
                  shape: const StadiumBorder(),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 60, vertical: 14),
                ),
                child: const Text(
                  "Done",
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ✅ Works now because colors are static fields
  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Expanded(
            flex: 40,
            child: Text(
              label,
              style: const TextStyle(
                color: textSecondary,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            flex: 60,
            child: SelectableText(
              value,
              textAlign: TextAlign.right,
              style: const TextStyle(
                color: textPrimary,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
