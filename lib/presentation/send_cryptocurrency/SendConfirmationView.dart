// lib/presentation/send_cryptocurrency/SendConfirmationView.dart
import 'package:cryptowallet/presentation/send_cryptocurrency/TransactionSuccessScreen.dart';
import 'package:cryptowallet/presentation/send_cryptocurrency/send_cryptocurrency.dart';
import 'package:cryptowallet/services/api_service.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

// 👇 currency + provider
import 'package:provider/provider.dart';
import 'package:cryptowallet/core/currency_notifier.dart';
import 'package:cryptowallet/core/currency_adapter.dart';

class SendConfirmationView extends StatefulWidget {
  final SendFlowData flowData; // must include toAddress from Screen 2

  const SendConfirmationView({super.key, required this.flowData});

  @override
  State<SendConfirmationView> createState() => _SendConfirmationViewState();
}

class _SendConfirmationViewState extends State<SendConfirmationView> {
  // UI/flow
  late String _priority; // "Standard" | "Fast"
  bool _submitting = false;
  String? _error;

  // local preview-only fees (computed, in crypto units)
  double _activationFee = 0.0;
  double _networkFee = 0.0;

  // Formatters are a bit heavy—cache one instance
  static final DateFormat _dateFmt = DateFormat('dd MMM yyyy HH:mm:ss');

  // -------- helpers --------
  String get _assetSymbol => widget.flowData.assetSymbol;

  /// Spot price (USD per coin) derived from flow (amount + usdValue)
  double get _assetPriceUsd => widget.flowData.usdValue > 0
      ? (widget.flowData.usdValue /
          (double.tryParse(widget.flowData.amount) ?? 1.0)
              .clamp(0.00000001, double.infinity))
      : 0.0;

  /// Normalize the token symbol we send to API:
  /// - "USDT-ETH" -> "USDT"
  /// - "BTC-LN"   -> "BTC"
  /// - "ETH"      -> "ETH"
  String get _apiToken {
    final s = _assetSymbol.trim().toUpperCase();
    return s.contains('-') ? s.split('-').first : s;
  }

  double get _amountCrypto =>
      double.tryParse(widget.flowData.amount.trim()) ?? 0.0;

  double get _willReceive {
    final v = _amountCrypto - _activationFee;
    return v < 0 ? 0.0 : v; // preview only
  }

  String get _timeText => _dateFmt.format(DateTime.now());

  @override
  void initState() {
    super.initState();
    final p = widget.flowData.priority.trim();
    _priority = (p == 'Fast' || p == 'Standard') ? p : 'Standard';
    _recalcFees(); // initial fee calc (crypto units)
  }

  void _recalcFees() {
    final base = _baseFeeForSymbol(_assetSymbol);
    final computedNetwork = _priority == "Fast" ? base * 1.5 : base;
    final computedActivation = computedNetwork;

    if (computedNetwork != _networkFee ||
        computedActivation != _activationFee) {
      setState(() {
        _networkFee = computedNetwork;
        _activationFee = computedActivation;
      });
    }
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
        return 1.1; // demo for TRX units
      default:
        return 0.0001;
    }
  }

  String get _apiChain {
    final c = widget.flowData.chain.trim().toUpperCase();
    if (c.contains('ERC20') || c.contains('USDT-ETH') || c.contains('ETH')) {
      return 'ETH';
    }
    if (c.contains('TRX') || c.contains('TRC20') || c.contains('USDT-TRX')) {
      return 'TRX';
    }
    if (c.contains('BEP20') || c.contains('BNB')) {
      return 'BNB';
    }
    if (c.contains('SOL')) {
      return 'SOL';
    }
    return c;
  }

  Future<void> _confirmAndSend() async {
    debugPrint('▶️ confirm tapped');
    final toAddr = (widget.flowData.toAddress ?? '').trim();
    final amtStr = widget.flowData.amount.trim();
    debugPrint(
        '📍 inputs -> to:$toAddr, amount:$amtStr, chain:${widget.flowData.chain}, priority:$_priority, token:$_apiToken');

    if (toAddr.isEmpty) {
      setState(() => _error = 'Missing recipient address.');
      return;
    }
    final amt = double.tryParse(amtStr) ?? 0;
    if (amt <= 0) {
      setState(() => _error = 'Amount must be greater than 0.');
      return;
    }

    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      final userId = await AuthService.getOrFetchUserId();
      if (!mounted) return;
      if (userId == null || userId.isEmpty) {
        setState(() => _error = 'Unable to resolve user ID.');
        return;
      }

      final walletAddress = await AuthService.getOrFetchWalletAddress(
          chain: widget.flowData.chain);
      if (!mounted) return;
      if (walletAddress == null || walletAddress.isEmpty) {
        setState(() => _error = 'Unable to resolve wallet address.');
        return;
      }

      final res = await AuthService.sendTransaction(
        walletAddress: walletAddress,
        toAddress: toAddr,
        amount: amtStr,
        chain: _apiChain, // ✅ fixed chain mapping
        token: _apiToken,
        priority: _priority,
      );

      if (!mounted) return;

      if (res.success) {
        final txId = _extractTxId(res.data);
        if (!mounted) return;
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => TransactionSuccessScreen(
              txId: txId,
              assetSymbol: _assetSymbol,
              amount: _amountCrypto,
              fee: _networkFee,
              toAddress: toAddr,
            ),
          ),
        );
      } else {
        setState(() => _error = res.message ?? 'Transaction failed.');
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = 'Transaction error: $e');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  String? _extractTxId(Map<String, dynamic>? data) {
    if (data == null) return null;
    final tx = data['transaction'];
    if (tx is Map<String, dynamic>) {
      final hash = tx['txHash']?.toString();
      if (hash != null && hash.isNotEmpty) return hash;
      final id = tx['id']?.toString();
      if (id != null && id.isNotEmpty) return id;
    }
    const keys = ['txHash', 'txId', 'txid', 'hash', 'transactionHash', 'id'];
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
      final ntx = nested['transaction'];
      if (ntx is Map<String, dynamic>) {
        final hash = ntx['txHash']?.toString();
        if (hash != null && hash.isNotEmpty) return hash;
        final id = ntx['id']?.toString();
        if (id != null && id.isNotEmpty) return id;
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
                const Text("Transaction ID / Hash:"),
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
    // 👇 currency adapter — rebuilds when user changes currency
    final fx = FxAdapter(context.watch<CurrencyNotifier>());

    const bg = Color(0xFF0C0D17);
    const textPrimary = Colors.white;
    const textSecondary = Color(0xFF9DA3AE);
    const divider = Color(0x22FFFFFF);
    const accentNote = Color(0xFFF1DF5A);

    final fromAccountLabel = '${_assetSymbol} - Main Account';
    final toAddress = (widget.flowData.toAddress ?? '').trim();

    // ---- Fiat conversions (USD → selected) ----
    final amountFiat = _amountCrypto * _assetPriceUsd; // USD
    final willReceiveFiat = _willReceive * _assetPriceUsd; // USD
    final networkFeeFiat = _networkFee * _assetPriceUsd; // USD
    final activationFeeFiat = _activationFee * _assetPriceUsd; // USD

    final amountFiatStr = fx.formatFromUsd(amountFiat);
    final willReceiveFiatStr = fx.formatFromUsd(willReceiveFiat);
    final networkFeeFiatStr = fx.formatFromUsd(networkFeeFiat);
    final activationFeeFiatStr = fx.formatFromUsd(activationFeeFiat);

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
                    const SizedBox(height: 6),
                    // ≈ selected-fiat preview of will receive
                    Text(
                      '≈ $willReceiveFiatStr',
                      style: const TextStyle(
                        color: textSecondary,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
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
                    _kvRow(
                      'Amount',
                      '${_amountCrypto.toStringAsFixed(5)} $_assetSymbol  •  ≈ $amountFiatStr',
                    ),
                    _kvRow(
                      'Activation Fee',
                      '(-) ${_activationFee.toStringAsFixed(_activationFee >= 1 ? 1 : 6)} $_assetSymbol  •  ≈ $activationFeeFiatStr',
                    ),
                    _kvRow(
                      'Will Receive',
                      '${_willReceive.toStringAsFixed(5)} $_assetSymbol  •  ≈ $willReceiveFiatStr',
                      strong: true,
                    ),

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
                            label: const Text('Standard'),
                            selected: _priority == "Standard",
                            onSelected: (_) {
                              setState(() {
                                _priority = "Standard";
                                // _recalcFees();
                              });
                            },
                            selectedColor: Colors.white,
                            labelStyle: TextStyle(
                              color: _priority == "Standard"
                                  ? Colors.black
                                  : textSecondary,
                              fontWeight: FontWeight.w600,
                            ),
                            backgroundColor: const Color(0xFF121526),
                          ),
                          ChoiceChip(
                            label: const Text('Fast'),
                            selected: _priority == "Fast",
                            onSelected: (_) {
                              setState(() {
                                _priority = "Fast";
                                // _recalcFees();
                              });
                            },
                            selectedColor: Colors.white,
                            labelStyle: TextStyle(
                              color: _priority == "Fast"
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

                    _kvRow('Fee Option', _priority),
                    _kvRow(
                      'Estimated Network Fee',
                      '${_networkFee.toStringAsFixed(_networkFee >= 1 ? 1 : 6)} $_assetSymbol  •  ≈ $networkFeeFiatStr',
                    ),

                    const SizedBox(height: 120),
                  ],
                ),
              ),
            ),

            // Bottom Confirm button
            Padding(
              padding: const EdgeInsets.only(
                left: 16,
                right: 16,
                bottom: 16,
                top: 0,
              ),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _submitting
                      ? null
                      : () async {
                          FocusScope.of(context).unfocus();
                          await _confirmAndSend();
                        },
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
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
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
          const SizedBox(width: 0),
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
