import 'dart:async';

import 'package:cryptowallet/core/app_export.dart';
import 'package:cryptowallet/presentation/bottomnavbar.dart';
import 'package:cryptowallet/routes/app_routes.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'package:cryptowallet/stores/coin_store.dart';
import 'package:cryptowallet/services/api_service.dart';

class SwapScreen extends StatefulWidget {
  const SwapScreen({super.key});

  @override
  State<SwapScreen> createState() => _SwapScreenState();
}

class _SwapScreenState extends State<SwapScreen> {
  /// We store **coinId** (must match CoinStore ids)
  String fromCoinId = 'BTC';
  String toCoinId = 'ETH';

  double fromAmount = 0.0;
  final TextEditingController _fromController = TextEditingController();

  // Modal filter/search UI state
  String _chipFilter = 'ALL';
  String _search = '';

  // Slippage (as fraction: 0.01 = 1%)
  double? _slippage;

  // Quote state
  double? _quoteToAmount; // amount of "to" token from /swaps/getQuote
  String? _quoteError;
  bool _quoting = false;
  Timer? _debounce;

  // Quote countdown (30s validity)
  Timer? _quoteCountdown;
  int _quoteSecondsLeft = 0;

  // Swap state
  bool _swapping = false;
  String? _swapError;
  String? _swapTxId;

  static const Color _pageBg = Color(0xFF0B0D1A);

  // ---------- Helpers ----------
  Coin? _coinById(BuildContext ctx, String id) =>
      ctx.read<CoinStore>().getById(id);

  String _baseSymbol(String coinId) {
    final dash = coinId.indexOf('-');
    return dash == -1 ? coinId : coinId.substring(0, dash);
  }

  String _networkPart(String coinId) {
    final dash = coinId.indexOf('-');
    return dash == -1 ? coinId : coinId.substring(dash + 1);
  }

  /// Normalize a coinId/network into the backend chain string.
  /// Examples:
  /// - "USDT-TRX" -> "TRON"
  /// - "BTC-LN" -> "BTC"
  /// - "ETH" -> "ETH"
  String _normalizeChain(String coinId) {
    var net = _networkPart(coinId).toUpperCase().trim();
    if (net == 'LN') net = 'BTC';
    if (net == 'TRX') return 'TRON';
    if (net == 'BNB-BNB') return 'BNB';
    if (net == 'SOL-SOL') return 'SOL';
    return net;
  }

  String _symbolFromId(BuildContext ctx, String coinId) {
    final c = _coinById(ctx, coinId);
    return c?.symbol ?? _baseSymbol(coinId).toUpperCase();
  }

  void _swapCoins() {
    setState(() {
      final tmp = fromCoinId;
      fromCoinId = toCoinId;
      toCoinId = tmp;
      _fromController.clear();
      fromAmount = 0.0;
      _quoteToAmount = null;
      _quoteError = null;
    });
    _stopQuoteCountdown();
    _scheduleQuote(); // refresh quote with new direction
  }

  @override
  void initState() {
    super.initState();
    _ensureMe();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _stopQuoteCountdown();
    _fromController.dispose();
    super.dispose();
  }

  Future<void> _ensureMe() async {
    try {
      await AuthService.fetchMe();
    } catch (e) {
      debugPrint('fetchMe failed: $e');
    }
  }

  // ---------------- Slippage Bottom Sheet ----------------
  void _showSlippageSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF131624),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (_) {
        double? local = _slippage;
        return StatefulBuilder(builder: (context, setModal) {
          void select(double v) => setModal(() => local = v);

          Widget pill(String label, double value) {
            final selected = local == value;
            return Expanded(
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(width: 1.0, color: Colors.white30),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(22),
                  ),
                ),
                onPressed: () => select(value),
                child: Text(label,
                    style: const TextStyle(
                        fontWeight: FontWeight.w700, letterSpacing: 0.1)),
              ),
            );
          }

          return SafeArea(
            child: Padding(
              padding: EdgeInsets.only(
                  bottom: MediaQuery.of(context).viewInsets.bottom),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(height: 8),
                  Container(
                    width: 46,
                    height: 5,
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomRight,
                        stops: [0.0, 0.55, 1.0],
                        colors: [
                          Color.fromARGB(255, 6, 11, 33),
                          Color.fromARGB(255, 0, 0, 0),
                          Color.fromARGB(255, 0, 12, 56),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  const Text(
                    'Slippage',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    child: Row(
                      children: [
                        pill('1%', 0.01),
                        const SizedBox(width: 10),
                        pill('2%', 0.02),
                        const SizedBox(width: 10),
                        pill('5%', 0.05),
                        const SizedBox(width: 10),
                        pill('10%', 0.10),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 18),
                    child: Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFF1D2133),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          CircleAvatar(
                            radius: 14,
                            backgroundColor: Color(0xFF2F4BA8),
                            child:
                                Icon(Icons.info, color: Colors.white, size: 18),
                          ),
                          SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Please note that when you adjust the slippage tolerance, '
                              'the amount you receive after the swap can be affected',
                              style: TextStyle(
                                color: Colors.white70,
                                height: 1.35,
                                fontSize: 8,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
                    child: SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        onPressed: () {
                          setState(() => _slippage = local);
                          Navigator.pop(context);
                          _stopQuoteCountdown();
                          _scheduleQuote();
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: const Color(0xFF0B0D1A),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          elevation: 0,
                        ),
                        child: const Text(
                          'Save',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        });
      },
    );
  }

  // ---------------- Coin Picker ----------------
  Future<void> _openCoinPicker({required bool isFrom}) async {
    // ensure auth (as requested, hit /api/auth/me)
    await _ensureMe();
    _selectCoin(isFrom: isFrom);
  }

  void _selectCoin({required bool isFrom}) {
    showModalBottomSheet(
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1A1D29),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      context: context,
      builder: (_) {
        return StatefulBuilder(builder: (context, setModalState) {
          final store = context.read<CoinStore>();
          final coins = store.coins.values.toList()
            ..sort((a, b) => a.symbol.compareTo(b.symbol));

          final baseSet = <String>{};
          for (final c in coins) baseSet.add(_baseSymbol(c.id));
          final chips = ['ALL', ...baseSet.toList()..sort()];

          final filtered = coins.where((c) {
            final matchesChip =
                _chipFilter == 'ALL' || _baseSymbol(c.id) == _chipFilter;
            final q = _search.trim().toLowerCase();
            final matchesSearch = q.isEmpty ||
                c.symbol.toLowerCase().contains(q) ||
                c.name.toLowerCase().contains(q) ||
                c.id.toLowerCase().contains(q);
            return matchesChip && matchesSearch;
          }).toList();

          return SafeArea(
            child: ClipRect(
              child: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomRight,
                    stops: [0.0, 0.55, 1.0],
                    colors: [
                      Color.fromARGB(255, 6, 11, 33),
                      Color.fromARGB(255, 0, 0, 0),
                      Color.fromARGB(255, 0, 12, 56),
                    ],
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SizedBox(height: 6),
                      const Text('Select Crypto',
                          style: TextStyle(color: Colors.white, fontSize: 18)),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              style: const TextStyle(color: Colors.white),
                              decoration: InputDecoration(
                                hintText: 'Search symbol, name, or network',
                                hintStyle:
                                    const TextStyle(color: Colors.white54),
                                prefixIcon: const Icon(Icons.search,
                                    color: Colors.white54),
                                filled: true,
                                fillColor: const Color(0xFF2A2D3A),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: BorderSide.none,
                                ),
                              ),
                              onChanged: (v) =>
                                  setModalState(() => _search = v),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: chips.map((filter) {
                            final isSelected = _chipFilter == filter;
                            return Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 6),
                              child: ChoiceChip(
                                label: Text(filter),
                                selected: isSelected,
                                onSelected: (_) =>
                                    setModalState(() => _chipFilter = filter),
                                selectedColor: Colors.blue,
                                labelStyle: TextStyle(
                                  color: isSelected
                                      ? Colors.white
                                      : Colors.white70,
                                ),
                                backgroundColor: const Color(0xFF2A2D3A),
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                      const SizedBox(height: 10),
                      SizedBox(
                        height: 440,
                        child: ListView.builder(
                          itemCount: filtered.length,
                          itemBuilder: (context, i) {
                            final c = filtered[i];
                            return ListTile(
                              leading: _coinAvatar(c.assetPath, c.symbol),
                              title: Text(c.symbol,
                                  style: const TextStyle(color: Colors.white)),
                              subtitle: Text(c.name,
                                  style:
                                      const TextStyle(color: Colors.white70)),
                              trailing: Text(
                                _networkHint(c.id),
                                style: const TextStyle(
                                    color: Colors.white54, fontSize: 12),
                              ),
                              onTap: () {
                                Navigator.pop(context);
                                setState(() {
                                  if (isFrom) {
                                    fromCoinId = c.id;
                                  } else {
                                    toCoinId = c.id;
                                  }
                                  _quoteToAmount = null;
                                  _quoteError = null;
                                });
                                _stopQuoteCountdown();
                                _scheduleQuote();
                              },
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        });
      },
    );
  }

  String _networkHint(String id) {
    final dash = id.indexOf('-');
    if (dash == -1) return '';
    return id.substring(dash + 1);
  }

  Widget _coinAvatar(String assetPath, String symbol) {
    return Container(
      width: 25,
      height: 25,
      decoration:
          const BoxDecoration(shape: BoxShape.circle, color: Color(0xFF2A2D3A)),
      child: ClipOval(
        child: Image.asset(
          assetPath,
          width: 25,
          height: 25,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => CircleAvatar(
            backgroundColor: const Color(0xFF2A2D3A),
            child: Text(
              symbol.isNotEmpty ? symbol[0] : '?',
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold),
            ),
          ),
        ),
      ),
    );
  }

  // ---------- Swap Card ----------
  Widget _buildSwapCard({
    required String label,
    required String coinId,
    required bool isFrom,
    required double value,
  }) {
    final coin = _coinById(context, coinId);
    final symbol = coin?.symbol ?? coinId;
    final path = coin?.assetPath ?? '';

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
      decoration: BoxDecoration(
        color: const Color(0xFF171B2B),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Label + (optional) balance
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label,
                  style: const TextStyle(
                    fontSize: 14,
                    color: Colors.white70,
                    fontWeight: FontWeight.w500,
                  )),
              if (isFrom)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: const BoxDecoration(color: Colors.transparent),
                  child: const Text(
                    'Balance: 0.00',
                    style: TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 20),

          // Chip + Amount
          Row(
            children: [
              GestureDetector(
                onTap: () => _openCoinPicker(isFrom: isFrom),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _coinAvatar(path, symbol),
                      const SizedBox(width: 8),
                      Text(symbol,
                          style: const TextStyle(
                              color: Colors.white, fontSize: 16)),
                      const SizedBox(width: 4),
                      const Icon(Icons.keyboard_arrow_down,
                          color: Colors.white70, size: 20),
                    ],
                  ),
                ),
              ),
              const Spacer(),

              if (isFrom)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.white24),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text('MAX',
                      style: TextStyle(color: Colors.white70, fontSize: 12)),
                ),
              const SizedBox(width: 12),

              // Amount: editable for "From", read-only (white) for "To"
              Expanded(
                child: isFrom
                    ? TextField(
                        controller: _fromController,
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(
                              RegExp(r'^\d*\.?\d{0,8}')),
                        ],
                        textAlign: TextAlign.end,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                        ),
                        decoration: const InputDecoration(
                          hintText: '0',
                          hintStyle: TextStyle(
                            color: Colors.white30,
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                          ),
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          contentPadding: EdgeInsets.zero,
                        ),
                        onChanged: (val) {
                          setState(
                              () => fromAmount = double.tryParse(val) ?? 0.0);
                          _stopQuoteCountdown();
                          _scheduleQuote();
                        },
                      )
                    : Align(
                        alignment: Alignment.centerRight,
                        child: Text(
                          _quoteToAmount != null
                              ? _quoteToAmount!.toStringAsFixed(8)
                              : '0',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: _quoteToAmount != null
                                ? Colors.white
                                : Colors.white30,
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: Text(
              isFrom
                  ? '≈ \$${(value * 1).toStringAsFixed(2)}'
                  : (_quoteToAmount != null
                      ? 'Quote: ${_quoteToAmount!.toStringAsFixed(8)} $symbol'
                      : (_quoteError != null
                          ? 'Quote: $_quoteError'
                          : 'Quote: —')),
              style: TextStyle(
                color: isFrom
                    ? Colors.white54
                    : (_quoteError != null ? Colors.redAccent : Colors.white54),
                fontSize: 14,
              ),
            ),
          ),

          // Countdown row (only for "To" card when we have a quote)
          if (!isFrom && _quoteToAmount != null && !_quoting)
            Padding(
              padding: const EdgeInsets.only(top: 6, bottom: 10),
              child: Row(
                children: [
                  const Icon(Icons.timer, size: 16, color: Colors.white60),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      _quoteSecondsLeft > 0
                          ? 'This quote is valid for ${_formatCountdown(_quoteSecondsLeft)}'
                          : 'Refreshing quote…',
                      style:
                          const TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                  ),
                  TextButton(
                    onPressed: _fetchQuote,
                    child: const Text(
                      'Refresh now',
                      style: TextStyle(fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),

          if (isFrom && _quoting)
            const Padding(
              padding: EdgeInsets.only(top: 6, bottom: 8),
              child: Align(
                alignment: Alignment.centerRight,
                child: SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ---------- QUOTE ----------
  void _scheduleQuote() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      if (!mounted) return;
      _fetchQuote();
    });
  }

  String _formatCountdown(int secs) {
    final m = (secs ~/ 60).toString().padLeft(2, '0');
    final s = (secs % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  void _startQuoteCountdown([int seconds = 30]) {
    _quoteCountdown?.cancel();
    setState(() {
      _quoteSecondsLeft = seconds;
    });
    _quoteCountdown = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      if (_quoteSecondsLeft <= 1) {
        t.cancel();
        setState(() => _quoteSecondsLeft = 0);
        // Auto-refresh when expired
        _fetchQuote();
      } else {
        setState(() => _quoteSecondsLeft--);
      }
    });
  }

  void _stopQuoteCountdown() {
    _quoteCountdown?.cancel();
    _quoteCountdown = null;
    _quoteSecondsLeft = 0;
  }

  Future<void> _fetchQuote() async {
    final fromSymbol = _symbolFromId(context, fromCoinId);
    final toSymbol = _symbolFromId(context, toCoinId);
    final chain = _normalizeChain(fromCoinId);

    if (fromAmount <= 0) {
      _stopQuoteCountdown();
      setState(() {
        _quoteToAmount = null;
        _quoteError = null;
      });
      return;
    }

    _stopQuoteCountdown();
    setState(() {
      _quoting = true;
      _quoteError = null;
    });

    try {
      final res = await AuthService.getSwapQuote(
        fromToken: fromSymbol,
        toToken: toSymbol,
        amount: fromAmount,
        chain: chain,
      );

      // Some backends respond with: { success: true, data: {...} }
      // others might return the payload at the top-level.
      final raw = res.data ?? const {};
      final Map<String, dynamic> payload = (raw['data'] is Map)
          ? (raw['data'] as Map).cast<String, dynamic>()
          : raw.cast<String, dynamic>();

      // Look for common fields
      dynamic toAmt = payload['toAmount'] ??
          payload['estimatedAmountOut'] ??
          (payload['quote'] is Map ? payload['quote']['toAmount'] : null) ??
          (payload['result'] is Map ? payload['result']['toAmount'] : null);

      double? parsed;
      if (toAmt is num) {
        parsed = toAmt.toDouble();
      } else if (toAmt is String) {
        parsed = double.tryParse(toAmt);
      }

      setState(() {
        _quoteToAmount = parsed;
        _quoteError = parsed == null ? 'No quote' : null;
      });

      if (parsed != null) {
        _startQuoteCountdown(30); // 🔥 start 30s validity countdown
      }
    } catch (e) {
      _stopQuoteCountdown();
      setState(() {
        _quoteToAmount = null;
        _quoteError = '$e';
      });
    } finally {
      if (mounted) setState(() => _quoting = false);
    }
  }

  // ---------- SWAP ----------
  Future<void> _performSwap() async {
    FocusScope.of(context).unfocus();

    final fromSymbol = _symbolFromId(context, fromCoinId);
    final toSymbol = _symbolFromId(context, toCoinId);
    final chainI = _normalizeChain(fromCoinId);
    final amount = fromAmount;
    final slippagePct = ((_slippage ?? 0.01) * 100); // 1% default if null

    if (amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Enter an amount greater than 0'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _swapping = true;
      _swapError = null;
      _swapTxId = null;
    });

    try {
      // Resolve walletId + private_key from wallets as requested
      final creds = await AuthService.getWalletIdAndPrivateKeyForChain(chainI);
      if (creds == null ||
          (creds['walletId'] ?? '').isEmpty ||
          (creds['private_key'] ?? '').isEmpty) {
        throw 'Could not resolve wallet credentials for $chainI';
      }

      // (Optional) refresh quote just before swap
      await _fetchQuote();

      final res = await AuthService.swapTokens(
        walletId: creds['walletId']!,
        fromToken: fromSymbol,
        toToken: toSymbol,
        amount: amount,
        slippage: slippagePct,
        chainI: chainI,
        privateKey: creds['private_key']!, // 👈 from fetchWallets
      );

      final data = res.data ?? const {};
      final txId = data['txId'] ??
          data['hash'] ??
          data['transactionHash'] ??
          data['id'] ??
          data['result']?['txId'];

      setState(() {
        _swapTxId = txId?.toString();
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              'Swap submitted${_swapTxId != null ? " (tx: $_swapTxId)" : ""}'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      setState(() => _swapError = '$e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Swap failed: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _swapping = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<CoinStore>();
    if (store.getById(fromCoinId) == null && store.coins.isNotEmpty) {
      fromCoinId = store.coins.values.first.id;
    }
    if (store.getById(toCoinId) == null && store.coins.length > 1) {
      toCoinId = store.coins.values.skip(1).first.id;
    }

    // ✅ Enable the swap button only when we have a valid quote & amount
    final bool hasQuote = (_quoteToAmount ?? 0) > 0 && !_quoting;
    final bool canSwap = hasQuote && !_swapping && fromAmount > 0;

    final ButtonStyle swapBtnStyle = ButtonStyle(
      backgroundColor: MaterialStateProperty.resolveWith((states) {
        if (states.contains(MaterialState.disabled)) {
          return const Color(0xFF3A3F55); // disabled gray
        }
        return const Color(0xFF6366F1); // active indigo
      }),
      foregroundColor:
          MaterialStateProperty.all<Color>(Colors.white), // text/spinner color
      elevation: MaterialStateProperty.all<double>(0),
      shape: MaterialStateProperty.all<RoundedRectangleBorder>(
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );

    return Scaffold(
      backgroundColor: _pageBg,
      appBar: AppBar(
        backgroundColor: _pageBg,
        elevation: 0,
        leading: const BackButton(color: Colors.white),
        title: const Text(
          'Swap',
          style: TextStyle(
              color: Colors.white, fontSize: 20, fontWeight: FontWeight.w600),
        ),
        centerTitle: false,
        actions: [
          // Tap to open slippage sheet
          InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: _showSlippageSheet,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFF2A2D3A),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.tune, color: Colors.white70, size: 16),
                  const SizedBox(width: 4),
                  Text(
                    _slippage == null
                        ? 'Auto'
                        : '${(_slippage! * 100).toStringAsFixed(0)}%',
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white70),
            onPressed: () {
              _stopQuoteCountdown();
              _fetchQuote();
            },
          ),
          IconButton(
            icon: const Icon(Icons.history, color: Colors.white70),
            onPressed: () {
              Navigator.of(context, rootNavigator: true)
                  .pushNamed(AppRoutes.swaphistory);
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Stack(
        children: [
          Column(
            children: [
              _buildSwapCard(
                label: 'From',
                coinId: fromCoinId,
                isFrom: true,
                value: fromAmount,
              ),
              _buildSwapCard(
                label: 'To',
                coinId: toCoinId,
                isFrom: false,
                value: _quoteToAmount ?? 0.0,
              ),
              if (_swapError != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                  child: Text(
                    _swapError!,
                    style: const TextStyle(color: Colors.redAccent),
                  ),
                ),
              if (_swapTxId != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                  child: Text(
                    'Tx: $_swapTxId',
                    style: const TextStyle(color: Colors.greenAccent),
                  ),
                ),
              const Spacer(),
              Container(
                margin: const EdgeInsets.all(16),
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: canSwap ? _performSwap : null,
                  style: swapBtnStyle,
                  child: _swapping
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text(
                          'Swap Now',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w600),
                        ),
                ),
              ),
            ],
          ),
          // Positioned swap button between containers
          Positioned(
            top: 105,
            left: 0,
            right: 0,
            child: Center(
              child: GestureDetector(
                onTap: _swapCoins,
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: const Color(0xFF1A1D29),
                    shape: BoxShape.circle,
                    border:
                        Border.all(color: const Color(0xFF2A2D3A), width: 2),
                  ),
                  child: const Icon(Icons.swap_vert,
                      color: Colors.white70, size: 24),
                ),
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: BottomNavBar(
        selectedIndex: 2,
        onTap: (index) {
          if (index == 2) return;
          Navigator.pushReplacementNamed(
            context,
            index == 0
                ? AppRoutes.dashboardScreen
                : index == 1
                    ? AppRoutes.dashboardScreen
                    : AppRoutes.profileScreen,
          );
        },
      ),
    );
  }
}
