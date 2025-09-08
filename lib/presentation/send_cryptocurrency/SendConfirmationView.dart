// lib/presentation/send_cryptocurrency/SendConfirmationView.dart
import 'package:cryptowallet/presentation/send_cryptocurrency/send_cryptocurrency.dart';
import 'package:cryptowallet/services/api_service.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
// SendFlowData

class SendConfirmationView extends StatefulWidget {
  final SendFlowData flowData; // must include toAddress from Screen 2

  const SendConfirmationView({super.key, required this.flowData});

  @override
  State<SendConfirmationView> createState() => _SendConfirmationViewState();
}

class _SendConfirmationViewState extends State<SendConfirmationView> {
  late String _priority; // "yes" | "no"
  bool _submitting = false;
  String? _error;

  // local preview-only fees
  double _activationFee = 0.0;
  double _networkFee = 0.0;

  @override
  void initState() {
    super.initState();
    _priority = widget.flowData.priority; // default from earlier
    _recalcFees();
  }

  // -------- helpers --------
  String get _assetSymbol => widget.flowData.assetSymbol;
  double get _amountCrypto => double.tryParse(widget.flowData.amount) ?? 0.0;

  double get _willReceive {
    final v = _amountCrypto - _activationFee;
    return v < 0 ? 0.0 : v;
  }

  String get _timeText {
    final now = DateTime.now();
    return DateFormat('dd MMM yyyy HH:mm:ss').format(now);
  }

  void _recalcFees() {
    final base = _baseFeeForSymbol(_assetSymbol);
    _networkFee = _priority == "yes" ? base * 1.5 : base; // High = more
    _activationFee = _networkFee; // keep rows consistent in UI
    setState(() {});
  }

  double _baseFeeForSymbol(String sym) {
    switch (sym.toUpperCase()) {
      case 'BTC':
      case 'BTC-LN':
        return 0.00015;
      case 'ETH':
      case 'USDT-ETH':
        return 0.0012;
      case 'SOL':
      case 'SOL-SOL':
        return 0.00005;
      case 'BNB':
      case 'BNB-BNB':
        return 0.0003;
      case 'TRX':
      case 'USDT-TRX':
      case 'TRX-TRX':
        return 1.1; // demo preview for TRX units
      default:
        return 0.0001;
    }
  }

  Future<void> _confirmAndSend() async {
    // 1) Validate recipient & amount
    if ((widget.flowData.toAddress ?? '').isEmpty) {
      setState(() => _error = 'Missing recipient address.');
      return;
    }
    final amt = double.tryParse(widget.flowData.amount) ?? 0;
    if (amt <= 0) {
      setState(() => _error = 'Amount must be greater than 0.');
      return;
    }

    setState(() {
      _submitting = true;
      _error = null;
    });

    try {
      // 2) Resolve userId from /api/auth/me (cached if already fetched)
      final userId = await AuthService.getOrFetchUserId();
      if (userId == null || userId.isEmpty) {
        setState(() => _error = 'Unable to resolve user ID.');
        return;
      }

      // 3) Resolve walletId from /api/wallet/get-wallets (cached; chain-aware)
      //    If you already have a walletId in flowData, you can prefer it,
      //    but here we always resolve from API to stay in sync with backend.
      final walletId = await AuthService.getOrFetchWalletId(
        chain: widget.flowData.chain,
      );
      if (walletId == null || walletId.isEmpty) {
        setState(() => _error = 'Unable to resolve wallet ID.');
        return;
      }

      // 4) Send transaction
      final res = await AuthService.sendTransaction(
        userId: userId,
        walletId: walletId,
        toAddress: widget.flowData.toAddress!,
        amount: widget.flowData.amount, // string
        chain: widget.flowData.chain, // e.g. "BTC", "ETH", "TRX"
        priority: _priority, // "yes" | "no"
      );

      if (!mounted) return;

      if (res.success) {
        final txId = _extractTxId(res.data);
        await _showSuccessDialog(context, txId);

        // Close the 3-step flow
        if (mounted) {
          Navigator.of(context).popUntil((route) => route.isFirst);
        }
      } else {
        setState(() => _error = res.message ?? 'Transaction failed.');
      }
    } catch (e) {
      setState(() => _error = 'Transaction error: $e');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  String? _extractTxId(Map<String, dynamic>? data) {
    if (data == null) return null;
    final keys = ['txId', 'txid', 'hash', 'transactionHash', 'id'];
    for (final k in keys) {
      final v = data[k];
      if (v is String && v.isNotEmpty) return v;
    }
    final nested = (data['data'] ?? data['result']);
    if (nested is Map<String, dynamic>) {
      for (final k in keys) {
        final v = nested[k];
        if (v is String && v.isNotEmpty) return v;
      }
    }
    return null;
  }

  Future<void> _showSuccessDialog(BuildContext context, String? txId) {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) {
        return AlertDialog(
          title: const Text("Transfer Submitted"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("Your transaction has been submitted successfully."),
              const SizedBox(height: 8),
              if (txId != null) ...[
                const Text("Transaction ID:"),
                const SizedBox(height: 4),
                SelectableText(
                  txId,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text("Done"),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    const bg = Color(0xFF0C0D17);
    const textPrimary = Colors.white;
    const textSecondary = Color(0xFF9DA3AE);
    const divider = Color(0x22FFFFFF);
    const accentNote = Color(0xFFF1DF5A);

    final fromAccountLabel = '${widget.flowData.assetSymbol} - Main Account';
    final toAddress = widget.flowData.toAddress ?? '';

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
                      _willReceive.toStringAsFixed(5),
                      style: const TextStyle(
                        color: textPrimary,
                        fontSize: 30,
                        fontWeight: FontWeight.w700,
                        height: 1.1,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _assetSymbol,
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

                    _kvRow('From', fromAccountLabel),
                    _kvRow('To', toAddress),
                    _kvRow('Time', _timeText),
                    _kvRow('Amount',
                        '${_amountCrypto.toStringAsFixed(5)} $_assetSymbol'),
                    _kvRow(
                      'Activation Fee',
                      '(-) ${_activationFee.toStringAsFixed(_activationFee >= 1 ? 1 : 6)} $_assetSymbol',
                    ),
                    _kvRow('Will Receive',
                        '${_willReceive.toStringAsFixed(5)} $_assetSymbol',
                        strong: true),

                    const SizedBox(height: 10),
                    if (_error != null)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.red.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(8),
                          border:
                              Border.all(color: Colors.red.withOpacity(0.25)),
                        ),
                        child: Text(
                          _error!,
                          style: const TextStyle(color: Colors.red),
                        ),
                      ),

                    const SizedBox(height: 10),

                    // Yellow note
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 2.0),
                      child: Text(
                        'The available total will be sent subtracting the fee',
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

                    // Priority chips
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Wrap(
                        spacing: 8,
                        children: [
                          ChoiceChip(
                            label: const Text('Regular'),
                            selected: _priority == "no",
                            onSelected: (_) {
                              setState(() {
                                _priority = "no";
                                _recalcFees();
                              });
                            },
                            selectedColor: Colors.white,
                            labelStyle: TextStyle(
                              color: _priority == "no"
                                  ? Colors.black
                                  : textSecondary,
                              fontWeight: FontWeight.w600,
                            ),
                            backgroundColor: const Color(0xFF121526),
                          ),
                          ChoiceChip(
                            label: const Text('High'),
                            selected: _priority == "yes",
                            onSelected: (_) {
                              setState(() {
                                _priority = "yes";
                                _recalcFees();
                              });
                            },
                            selectedColor: Colors.white,
                            labelStyle: TextStyle(
                              color: _priority == "yes"
                                  ? Colors.black
                                  : textSecondary,
                              fontWeight: FontWeight.w600,
                            ),
                            backgroundColor: const Color(0xFF121526),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),

                    _kvRow(
                        'Fee Option', _priority == "yes" ? 'High' : 'Regular'),
                    _kvRow(
                      'Estimated Network Fee',
                      '${_networkFee.toStringAsFixed(_networkFee >= 1 ? 1 : 6)} $_assetSymbol',
                    ),

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
                  onPressed: _submitting ? null : _confirmAndSend,
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
                  child: _submitting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : const Text('Confirm'),
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
      child: SizedBox(
        height: 36,
        width: 36,
        child: Icon(icon, size: 18, color: Colors.white),
      ),
    );
  }
}
