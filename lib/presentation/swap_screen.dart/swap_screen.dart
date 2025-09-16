// lib/presentation/swap_screen.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'package:cryptowallet/core/app_export.dart';
import 'package:cryptowallet/presentation/bottomnavbar.dart';
import 'package:cryptowallet/routes/app_routes.dart';

import 'package:cryptowallet/stores/coin_store.dart';
import 'package:cryptowallet/services/api_service.dart';
import 'package:cryptowallet/stores/wallet_store.dart'; // LocalWallet, WalletStore

class SwapScreen extends StatefulWidget {
  const SwapScreen({super.key});

  @override
  State<SwapScreen> createState() => _SwapScreenState();
}

class _SwapScreenState extends State<SwapScreen> {
  // Initial selection (must match CoinStore ids)
  String fromCoinId = 'BTC';
  String toCoinId = 'ETH';

  double fromAmount = 0.0;
  final TextEditingController _fromController = TextEditingController();

  // Coin picker UI state
  String _chipFilter = 'ALL';
  String _search = '';

  // Slippage (fraction: 0.01 = 1%)
  double? _slippage;

  // Quote state
  double? _quoteToAmount;
  String? _quoteError;
  bool _quoting = false;
  Timer? _debounce;

  // Quote validity (seconds)
  Timer? _quoteCountdown;
  int _quoteSecondsLeft = 0;

  // Swap state
  bool _swapping = false;
  String? _swapError;
  String? _swapTxId;

  static const Color _pageBg = Color(0xFF0B0D1A);

  // ---------- Wallet-derived capability cache ----------
  String? _loadedWalletId;
  Set<String> _supportedChains = {}; // e.g., {'ETH','TRON','BNB','BTC','SOL'}
  Map<String, double> _balances = {}; // coinId -> balance

  // Stable ref to WalletStore to avoid using BuildContext in dispose()
  WalletStore? _walletStore;

  // ---------- Helpers ----------
  Coin? _coinById(BuildContext ctx, String id) =>
      ctx.read<CoinStore>().getById(id);

  LocalWallet? get _activeWallet => _walletStore?.activeWallet;

  String _baseSymbol(String coinId) {
    final dash = coinId.indexOf('-');
    return dash == -1 ? coinId : coinId.substring(0, dash);
  }

  String _networkPart(String coinId) {
    final dash = coinId.indexOf('-');
    return dash == -1 ? coinId : coinId.substring(dash + 1);
  }

  /// Normalize a coinId/network into the backend chain string.
  /// - "USDT-TRX" -> "TRON"
  /// - "BTC-LN" -> "BTC"
  /// - "BNB-BNB" -> "BNB"
  /// - "SOL-SOL" -> "SOL"
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

  /// Whether the *currently active wallet* supports the given coinId (via chain)
  bool _walletSupportsCoin(String coinId) {
    if (_supportedChains.isEmpty) {
      // If unknown (backend didn’t return), don’t block UI: treat as supported.
      return true;
    }
    final chain = _normalizeChain(coinId);
    return _supportedChains.contains(chain);
  }

  /// Balance for a coinId from current wallet (0 if missing)
  double _balanceFor(String coinId) {
    final v = _balances[coinId];
    if (v == null) return 0.0;
    return v.toDouble();
  }

  bool _hasSufficientBalance(String coinId, double amount) {
    const eps = 1e-9; // avoid float edge cases
    return _balanceFor(coinId) + eps >= amount;
  }

  // --- Sizing: keep big inputs readable without breaking layout
  double _amountFontSize(String text) {
    final len = text.replaceAll(RegExp(r'[^0-9]'), '').length; // digits only
    if (len <= 8) return 32;
    if (len <= 12) return 28;
    if (len <= 16) return 24;
    if (len <= 20) return 22;
    return 20;
  }

  // --- Money: avoid scientific notation, keep short & friendly
  String _formatFiat(double v) {
    if (v.isNaN || v.isInfinite) return '—';
    final abs = v.abs();
    String s;
    if (abs < 1000000) {
      s = v.toStringAsFixed(2);
      final parts = s.split('.');
      final whole = parts[0].replaceAllMapped(
        RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
        (m) => '${m[1]},',
      );
      s = '$whole.${parts[1]}';
    } else if (abs < 1e9) {
      s = '${(v / 1e6).toStringAsFixed(2)}M';
    } else if (abs < 1e12) {
      s = '${(v / 1e9).toStringAsFixed(2)}B';
    } else {
      s = '${(v / 1e12).toStringAsFixed(2)}T';
    }
    return s;
  }

  // Nice floating snackbar + subtle haptic
  void _showErrorSnack(String msg) {
    HapticFeedback.mediumImpact();
    final snack = SnackBar(
      content: Row(
        children: [
          const Icon(Icons.error_outline, size: 20, color: Colors.white),
          const SizedBox(width: 10),
          Expanded(
              child: Text(msg,
                  style: const TextStyle(fontWeight: FontWeight.w600))),
        ],
      ),
      backgroundColor: const Color(0xFFE53935).withOpacity(0.95),
      behavior: SnackBarBehavior.floating,
      margin:
          const EdgeInsets.fromLTRB(16, 0, 16, 90), // float above bottom bar
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 6,
      duration: const Duration(milliseconds: 2200),
      // Built-in slide/fade animation is used by SnackBar automatically
    );
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(snack);
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
    _scheduleQuote();
  }

  // ---------- Lifecycle ----------
  @override
  void initState() {
    super.initState();
    _fromController.addListener(() {
      final val = double.tryParse(_fromController.text) ?? 0.0;
      if (val != fromAmount) {
        setState(() => fromAmount = val);
        _stopQuoteCountdown();
        _scheduleQuote();
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final ws = context.read<WalletStore>();
    if (_walletStore != ws) {
      _walletStore?.removeListener(_onWalletChanged);
      _walletStore = ws;
      _walletStore!.addListener(_onWalletChanged);
      _refreshWalletCapabilitiesIfNeeded();
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _stopQuoteCountdown();
    _fromController.dispose();
    _walletStore?.removeListener(_onWalletChanged);
    super.dispose();
  }

  void _onWalletChanged() {
    if (!mounted) return;
    _refreshWalletCapabilitiesIfNeeded();
  }

  Future<void> _refreshWalletCapabilitiesIfNeeded() async {
    final aw = _activeWallet;
    final wid = aw?.id;
    if (wid == null) {
      if (!mounted) return;
      setState(() {
        _loadedWalletId = null;
        _supportedChains = {};
        _balances = {};
      });
      return;
    }
    if (_loadedWalletId == wid) return;

    try {
      final chains = await AuthService.getWalletSupportedChains(wid);
      final bals = await AuthService.getWalletBalances(wid);
      if (!mounted) return;
      setState(() {
        _loadedWalletId = wid;
        _supportedChains = chains ?? {};
        _balances = bals ?? {};
      });
      _fixUnsupportedSelections();
      _stopQuoteCountdown();
      _scheduleQuote();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loadedWalletId = wid;
        _supportedChains = {};
        _balances = {};
      });
      _fixUnsupportedSelections();
      _stopQuoteCountdown();
      _scheduleQuote();
    }
  }

  void _fixUnsupportedSelections() {
    final store = context.read<CoinStore>();
    if (!_walletSupportsCoin(fromCoinId)) {
      final firstSupported = store.coins.values.map((c) => c.id).firstWhere(
            _walletSupportsCoin,
            orElse: () => fromCoinId,
          );
      if (firstSupported != fromCoinId) fromCoinId = firstSupported;
    }
    if (!_walletSupportsCoin(toCoinId)) {
      final secondSupported = store.coins.values.map((c) => c.id).firstWhere(
            _walletSupportsCoin,
            orElse: () => toCoinId,
          );
      if (secondSupported != toCoinId) toCoinId = secondSupported;
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
        double? local = _slippage; // pre-select current choice
        return StatefulBuilder(builder: (context, setModal) {
          void select(double v) => setModal(() => local = v);

          Widget pill(String label, double value) {
            final bool selected = local == value;
            return Expanded(
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(
                  side: BorderSide(
                    width: 1.0,
                    color: selected ? Colors.white : Colors.white30,
                  ),
                  foregroundColor:
                      selected ? const Color(0xFF0B0D1A) : Colors.white,
                  backgroundColor: selected ? Colors.white : Colors.transparent,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(22),
                  ),
                ),
                onPressed: () => select(value),
                child: Text(
                  label,
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.1,
                    color: selected ? const Color(0xFF0B0D1A) : Colors.white,
                  ),
                ),
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

          // All coins sorted by symbol
          final allCoins = store.coins.values.toList()
            ..sort((a, b) => a.symbol.compareTo(b.symbol));

          // Wallet-supported subset (if we know chains; otherwise show all)
          final listForPicker = _supportedChains.isEmpty
              ? allCoins
              : allCoins.where((c) => _walletSupportsCoin(c.id)).toList();

          // Build chip list (base symbols) from *shown* coins
          final baseSet = <String>{};
          for (final c in listForPicker) baseSet.add(_baseSymbol(c.id));
          final chips = ['ALL', ...baseSet.toList()..sort()];

          // Apply chip + search
          final filtered = listForPicker.where((c) {
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

  // ---------- Swap Cards ----------
  Widget _buildSwapCard({
    required String label,
    required String coinId,
    required bool isFrom,
    required double value,
  }) {
    final coin = _coinById(context, coinId);
    final symbol = coin?.symbol ?? coinId;
    final path = coin?.assetPath ?? '';

    final String inputText = _fromController.text;
    final double dynamicFs = isFrom ? _amountFontSize(inputText) : 32;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
      decoration: BoxDecoration(
        color: const Color(0xFF171B2B),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: label + balance + (MAX on FROM)
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      label,
                      style: const TextStyle(
                        fontSize: 14,
                        color: Colors.white70,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    if (isFrom)
                      Text(
                        'Balance: ${_balanceFor(coinId).toStringAsFixed(8)}',
                        style: const TextStyle(
                            color: Colors.white70, fontSize: 12),
                      ),
                  ],
                ),
              ),
              if (isFrom) ...[
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: () {
                    final maxAmt = _balanceFor(coinId);
                    _fromController.text =
                        (maxAmt > 0 ? maxAmt : 0).toStringAsFixed(8);
                  },
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.transparent,
                      border: Border.all(color: Colors.white24),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text('MAX',
                        style: TextStyle(color: Colors.white70, fontSize: 12)),
                  ),
                ),
              ],
            ],
          ),

          const SizedBox(height: 14),

          // Coin + Amount row
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              GestureDetector(
                onTap: () => _openCoinPicker(isFrom: isFrom),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration:
                      BoxDecoration(borderRadius: BorderRadius.circular(20)),
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
              // Amount lane - stable width so layout doesn't jump
              SizedBox(
                width: 210,
                child: isFrom
                    ? TextField(
                        controller: _fromController,
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(
                              RegExp(r'^\d*\.?\d{0,8}')),
                        ],
                        maxLines: 1,
                        textAlign: TextAlign.end,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: dynamicFs,
                          fontWeight: FontWeight.w700,
                          height: 1.1,
                        ),
                        decoration: const InputDecoration(
                          hintText: '0',
                          hintStyle: TextStyle(
                            color: Colors.white30,
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                          ),
                          isCollapsed: true,
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          contentPadding: EdgeInsets.zero,
                          counterText: '',
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
                            height: 1.1,
                          ),
                        ),
                      ),
              ),
            ],
          ),

          const SizedBox(height: 8),

          // Countdown (for TO)
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
                    child: const Text('Refresh now',
                        style: TextStyle(fontSize: 12)),
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

          if (isFrom && value > 0 && !_hasSufficientBalance(coinId, value))
            const Padding(
              padding: EdgeInsets.only(top: 6, bottom: 0),
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
    setState(() => _quoteSecondsLeft = seconds);
    _quoteCountdown = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      if (_quoteSecondsLeft <= 1) {
        t.cancel();
        setState(() => _quoteSecondsLeft = 0);
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

    if (_supportedChains.isNotEmpty &&
        (!_walletSupportsCoin(fromCoinId) || !_walletSupportsCoin(toCoinId))) {
      _stopQuoteCountdown();
      setState(() {
        _quoteToAmount = null;
        _quoteError = 'Selected coins are not supported by this wallet';
      });
      return;
    }

    // Block quote if insufficient balance
    if (!_hasSufficientBalance(fromCoinId, fromAmount)) {
      _stopQuoteCountdown();
      setState(() {
        _quoteToAmount = null;
        _quoteError = 'Insufficient balance';
      });
      _showErrorSnack('Insufficient balance');
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
        slippage: (_slippage ?? 0.01), // raw number (e.g., 0.01)
      );

      final raw = res.data ?? const {};
      final Map<String, dynamic> payload = (raw['data'] is Map)
          ? (raw['data'] as Map).cast<String, dynamic>()
          : raw.cast<String, dynamic>();

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
        _startQuoteCountdown(30);
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

    if (amount <= 0) {
      _showErrorSnack('Enter an amount greater than 0');
      return;
    }

    if (_supportedChains.isNotEmpty &&
        (!_walletSupportsCoin(fromCoinId) || !_walletSupportsCoin(toCoinId))) {
      _showErrorSnack('Selected coins are not supported by this wallet');
      return;
    }

    if (!_hasSufficientBalance(fromCoinId, amount)) {
      _showErrorSnack('Insufficient balance');
      return;
    }

    setState(() {
      _swapping = true;
      _swapError = null;
      _swapTxId = null;
    });

    try {
      // Resolve wallet credentials for chain from backend
      final creds = await AuthService.getWalletIdAndPrivateKeyForChain(chainI);
      if (creds == null ||
          (creds['walletId'] ?? '').isEmpty ||
          (creds['private_key'] ?? '').isEmpty) {
        throw 'Could not resolve wallet credentials for $chainI';
      }

      // Optional: refresh quote just before swap
      await _fetchQuote();

      final slippageValue = (_slippage ?? 0.01); // raw number (e.g., 0.01)
      final res = await AuthService.swapTokens(
        walletId: creds['walletId']!,
        fromToken: fromSymbol,
        toToken: toSymbol,
        amount: amount,
        slippage: slippageValue, // send raw number
        chainI: chainI,
        privateKey: creds['private_key']!,
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
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 90),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          elevation: 6,
          duration: const Duration(milliseconds: 1800),
        ),
      );
    } catch (e) {
      setState(() => _swapError = '$e');
      _showErrorSnack('Swap failed: $e');
    } finally {
      if (mounted) setState(() => _swapping = false);
    }
  }

  // ---------- Build ----------
  @override
  Widget build(BuildContext context) {
    final store = context.watch<CoinStore>(); // watch coins so UI updates

    // If initial ids are absent in store, pick some defaults
    if (store.getById(fromCoinId) == null && store.coins.isNotEmpty) {
      fromCoinId = store.coins.values.first.id;
    }
    if (store.getById(toCoinId) == null && store.coins.length > 1) {
      toCoinId = store.coins.values.skip(1).first.id;
    }

    // Ensure current selection is supported by selected wallet (if we know chains)
    if (_supportedChains.isNotEmpty) {
      _fixUnsupportedSelections();
    }

    // Enable swap when we have a valid quote, amount, and balance
    final bool hasQuote = (_quoteToAmount ?? 0) > 0 && !_quoting;
    final bool hasBalance =
        _hasSufficientBalance(fromCoinId, fromAmount) && fromAmount > 0;
    final bool canSwap = hasQuote && !_swapping && hasBalance;

    final ButtonStyle swapBtnStyle = ButtonStyle(
      backgroundColor: MaterialStateProperty.resolveWith((states) {
        if (states.contains(MaterialState.disabled)) {
          return const Color(0xFF3A3F55);
        }
        return const Color(0xFF6366F1);
      }),
      foregroundColor: MaterialStateProperty.all<Color>(Colors.white),
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
          // Slippage
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
                  value: fromAmount),
              _buildSwapCard(
                  label: 'To',
                  coinId: toCoinId,
                  isFrom: false,
                  value: _quoteToAmount ?? 0.0),
              if (_swapError != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                  child: Text(_swapError!,
                      style: const TextStyle(color: Colors.redAccent)),
                ),
              if (_swapTxId != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                  child: Text('Tx: $_swapTxId',
                      style: const TextStyle(color: Colors.greenAccent)),
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
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : const Text('Swap Now',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w600)),
                ),
              ),
            ],
          ),

          // Swap direction button between the two cards (nudged lower so it won't overlap)
          Positioned(
            top: 100,
            left: 0,
            right: 0,
            child: Center(
              child: GestureDetector(
                onTap: _swapCoins,
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: const Color(0xFF1A1D29),
                    shape: BoxShape.circle,
                    border:
                        Border.all(color: const Color(0xFF2A2D3A), width: 2),
                  ),
                  child: const Icon(Icons.swap_vert,
                      color: Colors.white70, size: 26),
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
