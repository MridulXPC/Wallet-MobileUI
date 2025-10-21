// lib/presentation/send_cryptocurrency/SendCryptocurrency.dart
import 'dart:async';
import 'package:cryptowallet/core/currency_adapter.dart';
import 'package:cryptowallet/presentation/receive_cryptocurrency/receive_btclightning.dart';
import 'package:cryptowallet/presentation/send_cryptocurrency/SendConfirmationScreen.dart';
import 'package:cryptowallet/presentation/send_cryptocurrency/SendConfirmationView.dart';
import 'package:cryptowallet/stores/portfolio_store.dart';
import 'package:cryptowallet/widgets/tx_failure_card.dart';
import 'package:flutter/material.dart';
import 'package:sizer/sizer.dart';
import 'package:provider/provider.dart';

import 'package:cryptowallet/stores/coin_store.dart';
import 'package:cryptowallet/stores/balance_store.dart';
import 'package:cryptowallet/services/api_service.dart';
import 'package:flutter/foundation.dart' show debugPrint;

// currency notifier (wrapped by FxAdapter)
import 'package:cryptowallet/core/currency_notifier.dart';

/// ----------------------------------------------
/// Flow model passed across the 3-screen send flow
/// ----------------------------------------------
class SendFlowData {
  final String? userId;
  final String? walletId;

  /// API fields
  final String chain; // e.g. "BTC", "ETH"
  final String amount; // crypto amount as string
  final String priority; // "Standard" | "Fast"
  final String? toAddress;

  /// UI helpers (stored in USD — render converts to selected currency)
  final double usdValue;
  final String assetName;
  final String assetSymbol;
  final String assetIconPath;

  const SendFlowData({
    required this.userId,
    required this.walletId,
    required this.chain,
    required this.amount,
    required this.priority,
    required this.usdValue,
    required this.assetName,
    required this.assetSymbol,
    required this.assetIconPath,
    this.toAddress,
  });

  SendFlowData copyWith({
    String? userId,
    String? walletId,
    String? chain,
    String? amount,
    String? priority,
    double? usdValue,
    String? assetName,
    String? assetSymbol,
    String? assetIconPath,
    String? toAddress,
  }) {
    return SendFlowData(
      userId: userId ?? this.userId,
      walletId: walletId ?? this.walletId,
      chain: chain ?? this.chain,
      amount: amount ?? this.amount,
      priority: priority ?? this.priority,
      usdValue: usdValue ?? this.usdValue,
      assetName: assetName ?? this.assetName,
      assetSymbol: assetSymbol ?? this.assetSymbol,
      assetIconPath: assetIconPath ?? this.assetIconPath,
      toAddress: toAddress ?? this.toAddress,
    );
  }
}

// 1) IMAGE CACHE
class ImageCacheManager {
  static final Map<String, ImageProvider> _cachedImages = {};

  static ImageProvider getCachedImage(String assetPath) {
    _cachedImages.putIfAbsent(assetPath, () => AssetImage(assetPath));
    return _cachedImages[assetPath]!;
  }

  static void preloadImages(List<String> assetPaths, BuildContext context) {
    for (final path in assetPaths) {
      precacheImage(AssetImage(path), context).catchError((_) {
        debugPrint('Failed to preload image: $path');
      });
    }
  }

  static void clearCache() => _cachedImages.clear();
}

// 2) ICON
class OptimizedCoinIcon extends StatelessWidget {
  final String assetPath;
  final double size;

  const OptimizedCoinIcon({
    Key? key,
    required this.assetPath,
    this.size = 40,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        color: Color(0xFF1F2431),
      ),
      clipBehavior: Clip.antiAlias,
      child: Image(
        image: ImageCacheManager.getCachedImage(assetPath),
        fit: BoxFit.cover,
        width: size,
        height: size,
        frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
          if (wasSynchronouslyLoaded) return child;
          return AnimatedOpacity(
            opacity: frame == null ? 0 : 1,
            duration: const Duration(milliseconds: 150),
            curve: Curves.easeOut,
            child: child,
          );
        },
        errorBuilder: (_, __, ___) =>
            Icon(Icons.currency_bitcoin, color: Colors.white, size: size * 0.6),
        gaplessPlayback: true,
      ),
    );
  }
}

// 3) ASSET TILE
class OptimizedAssetListTile extends StatelessWidget {
  final Coin coin;

  /// price in USD
  final double price;
  final double balance;
  final VoidCallback onTap;

  const OptimizedAssetListTile({
    Key? key,
    required this.coin,
    required this.price,
    required this.balance,
    required this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // listen to currency selection for live reformatting
    final fx = FxAdapter(context.watch<CurrencyNotifier>());

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        splashColor: Colors.white.withOpacity(0.1),
        highlightColor: Colors.white.withOpacity(0.05),
        child: Container(
          height: 72,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              OptimizedCoinIcon(assetPath: coin.assetPath, size: 40),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      '${coin.symbol} - ${coin.name}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Balance: ${balance.toStringAsFixed(6)}',
                      style: const TextStyle(
                        color: Color(0xFF9CA3AF),
                        fontSize: 14,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              // price displayed in selected currency
              Text(
                fx.formatFromUsd(price),
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w500,
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Local model for selector
class _AssetRow {
  final String id; // e.g. "USDT-ETH" or "ETH"
  final String symbol; // e.g. "USDT" or "ETH"
  final String name; // "Tether", "Ethereum"
  final double price; // USD (spot or derived)
  final double balance; // crypto units
  final String assetPath;

  _AssetRow({
    required this.id,
    required this.symbol,
    required this.name,
    required this.price,
    required this.balance,
    required this.assetPath,
  });
}

// SHEET SCAFFOLD
class _AssetSheetScaffold extends StatelessWidget {
  final String title;
  final Widget child;
  final Widget? header;
  final Widget? chips;

  const _AssetSheetScaffold({
    Key? key,
    required this.title,
    required this.child,
    this.header,
    this.chips,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      child: Container(
        height: MediaQuery.of(context).size.height * 0.85,
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
        child: SafeArea(
          top: false,
          child: Column(
            children: [
              Container(
                margin: const EdgeInsets.symmetric(vertical: 10),
                height: 4,
                width: 40,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.25),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const Padding(
                padding: EdgeInsets.all(16.0),
                child: Text(
                  'Select Asset',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (header != null) ...[
                header!,
                const SizedBox(height: 10),
              ],
              if (chips != null) ...[
                chips!,
                const SizedBox(height: 8),
              ],
              Expanded(child: child),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}

class SendCryptocurrency extends StatefulWidget {
  final String title;
  final String? initialAddress;
  final String? initialCoinId; // e.g. "BTC-LN" or "ETH"
  final String? buttonLabel;
  final bool isChargeMode;
  final double? initialUsd;
  final bool startInUsd;
  final String? userId;
  final String? walletId;

  const SendCryptocurrency({
    super.key,
    this.title = 'Insert Amount',
    this.initialCoinId,
    this.buttonLabel,
    this.isChargeMode = false,
    this.initialUsd,
    this.startInUsd = false,
    this.userId,
    this.walletId,
    this.initialAddress,
  });

  @override
  State<SendCryptocurrency> createState() => _SendCryptocurrencyState();
}

class _SendCryptocurrencyState extends State<SendCryptocurrency> {
  String _currentAmount = '0';
  bool _isCryptoSelected = true;

  /// Always store USD value here; render converts to selected currency.
  double _usdValue = 0.00;
  bool _isImagesPreloaded = false;

  // selected
  String _selectedAsset = 'Bitcoin';
  String _selectedAssetSymbol = 'BTC';
  double _selectedAssetBalance = 0.00;
  String _selectedAssetIconPath = 'assets/currencyicons/bitcoin.png';

  /// Asset spot price in USD
  double _selectedAssetPrice = 0.00;

  // cached spot prices for user-held symbols (USD)
  Map<String, double> _priceBySymbol = const {};
  bool _loadingPrices = false;

  @override
  void dispose() {
    ImageCacheManager.clearCache();
    super.dispose();
  }

  // ---------- amount helpers ----------
  void _onNumberPressed(String number) {
    setState(() {
      if (_currentAmount == '0') {
        _currentAmount = number;
      } else {
        _currentAmount += number;
      }
      _recomputeUsdFromInput();
    });
  }

  void _onDecimalPressed() {
    setState(() {
      if (!_currentAmount.contains('.')) {
        _currentAmount += '.';
      }
    });
  }

  void _onBackspacePressed() {
    setState(() {
      if (_currentAmount.length > 1) {
        _currentAmount = _currentAmount.substring(0, _currentAmount.length - 1);
      } else {
        _currentAmount = '0';
      }
      _recomputeUsdFromInput();
    });
  }

  void _onPercentagePressed(double percentage) {
    final fx = FxAdapter(context.read<CurrencyNotifier>());
    setState(() {
      if (_isCryptoSelected) {
        final amt = _selectedAssetBalance * percentage; // crypto amount
        _currentAmount = _trimCrypto(amt);
      } else {
        // percentage of fiat balance (convert USD balance to selected currency for the keypad)
        final usdBal = _selectedAssetBalance * _selectedAssetPrice; // USD
        final selectedFiatBal = fx.fromUsd(usdBal);
        final usd = fx.toUsd(selectedFiatBal * percentage); // back to USD
        _currentAmount = fx
            .fromUsd(usd)
            .toStringAsFixed(2); // keypad shows selected currency
      }
      if (_currentAmount.isEmpty) _currentAmount = '0';
      _recomputeUsdFromInput();
    });
  }

  /// Recompute the internal USD value from the current text field and toggle.
  void _recomputeUsdFromInput() {
    final fx = FxAdapter(context.read<CurrencyNotifier>());
    final val = double.tryParse(_currentAmount) ?? 0.0;

    if (_isCryptoSelected) {
      _usdValue = val * _selectedAssetPrice; // crypto → USD
    } else {
      // keyed-in value is in selected fiat; convert to USD
      _usdValue = fx.toUsd(val);
    }
  }

  String _trimCrypto(double v) {
    return v
        .toStringAsFixed(8)
        .replaceAll(RegExp(r'0*$'), '')
        .replaceAll(RegExp(r'\.$'), '');
  }

  // ---------- NEXT (Review) ----------
  void _onNextPressed() {
    final fx = FxAdapter(context.read<CurrencyNotifier>());

    final entered = double.tryParse(_currentAmount) ?? 0.0;

    // Resolve crypto amount no matter what mode the user is typing in.
    final amountCrypto = _isCryptoSelected
        ? entered
        : (fx.toUsd(entered) /
            (_selectedAssetPrice == 0 ? 1 : _selectedAssetPrice));

    if (amountCrypto <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter an amount greater than 0'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (amountCrypto > _selectedAssetBalance) {
      TxFailureCard.show(
        context,
        title: 'Transaction failed',
        message: 'Insufficient balance',
        barrier: true,
      );
      return;
    }

    final amountCryptoStr = _trimCrypto(amountCrypto);

    // Charge flow
    if (widget.isChargeMode) {
      final isLn = (widget.initialCoinId ?? _selectedAssetSymbol)
          .toUpperCase()
          .contains('BTC-LN');

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ReceiveQRbtclightning(
            title: 'Charge',
            accountLabel: isLn ? 'LN - Main Account' : 'Main Account',
            coinName: _selectedAsset,
            iconAsset: _selectedAssetIconPath,
            isLightning: isLn,
            amount: amountCryptoStr,
            symbol: _selectedAssetSymbol,
            // Keep USD; any screen rendering should convert with CurrencyNotifier
            fiatValue: amountCrypto * _selectedAssetPrice,
            qrData: amountCryptoStr,
          ),
        ),
      );
      return;
    }

    // Default SEND → review
    final data = SendFlowData(
      userId: widget.userId,
      walletId: widget.walletId,
      chain: _selectedAssetSymbol,
      amount: amountCryptoStr,
      priority: "Standard",
      usdValue: amountCrypto * _selectedAssetPrice, // USD
      assetName: _selectedAsset,
      assetSymbol: _selectedAssetSymbol,
      assetIconPath: _selectedAssetIconPath,
      toAddress: null,
    );

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SendConfirmationScreen(flowData: data),
      ),
    );
  }

  // ---------- Resolve Coin from CoinStore ----------
  Coin? _resolveCoinFromStore({
    required CoinStore store,
    required String id,
    required String symbol,
  }) {
    Coin? coin = store.getById(id);
    if (coin != null) return coin;

    for (final c in store.coins.values) {
      if (c.symbol.toUpperCase() == symbol.toUpperCase()) return c;
    }

    final base = id.contains('-') ? id.split('-').first : id;
    coin = store.getById(base);
    return coin;
  }

  // ---------- Build rows from BalanceStore (+ prices) ----------
  Future<List<_AssetRow>> _loadAssetsFromStore() async {
    final ps = context.read<PortfolioStore>();
    final store = context.read<CoinStore>();

    if (ps.tokens.isEmpty && !ps.loading) {
      await ps.fetchCurrentWalletPortfolio();
    }

    final rows = <_AssetRow>[];

    for (final t in ps.tokens) {
      final coin = store.getById(t.symbol) ?? store.getById(t.chain);
      final assetPath = coin?.assetPath ?? 'assets/currencyicons/bitcoin.png';
      final name = coin?.name ?? t.name;
      final id = coin?.id ?? t.symbol;

      rows.add(_AssetRow(
        id: id,
        symbol: t.symbol,
        name: name,
        price: t.value /
            (t.balance == 0 ? 1 : t.balance), // derive USD price if needed
        balance: t.balance,
        assetPath: assetPath,
      ));
    }

    rows.sort((a, b) => (b.price * b.balance).compareTo(a.price * a.balance));
    return rows;
  }

  void _showAssetSelector() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      enableDrag: true,
      builder: (context) {
        return FutureBuilder<List<_AssetRow>>(
          future: _loadAssetsFromStore(),
          builder: (context, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return const _AssetSheetScaffold(
                title: 'Select Asset',
                child: Center(
                  child: SizedBox(
                    height: 28,
                    width: 28,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              );
            }

            if (snap.hasError) {
              return _AssetSheetScaffold(
                title: 'Select Asset',
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Text(
                      'Failed to load assets.\n${snap.error}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.white70),
                    ),
                  ),
                ),
              );
            }

            final rows = snap.data ?? const <_AssetRow>[];

            final baseSet = <String>{for (final r in rows) _baseSymbol(r.id)};
            final chips = ['ALL', ...baseSet.toList()..sort()];

            String search = '';
            String chip = 'ALL';

            return StatefulBuilder(
              builder: (context, setModalState) {
                final filtered = rows.where((r) {
                  final q = search.trim().toLowerCase();
                  final matchesSearch = q.isEmpty ||
                      r.symbol.toLowerCase().contains(q) ||
                      r.name.toLowerCase().contains(q) ||
                      r.id.toLowerCase().contains(q);
                  final matchesChip =
                      chip == 'ALL' || _baseSymbol(r.id) == chip;
                  return matchesSearch && matchesChip;
                }).toList();

                return _AssetSheetScaffold(
                  title: 'Select Asset',
                  header: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: TextField(
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        hintText: 'Search symbol, name, or network',
                        hintStyle: const TextStyle(color: Colors.white54),
                        prefixIcon:
                            const Icon(Icons.search, color: Colors.white54),
                        filled: true,
                        fillColor: const Color(0xFF1F2431),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      onChanged: (v) => setModalState(() => search = v),
                    ),
                  ),
                  chips: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Row(
                      children: chips.map((f) {
                        final selected = chip == f;
                        return Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 6),
                          child: ChoiceChip(
                            label: Text(f),
                            selected: selected,
                            onSelected: (_) => setModalState(() => chip = f),
                            selectedColor: Colors.blue,
                            labelStyle: TextStyle(
                              color: selected ? Colors.white : Colors.white70,
                            ),
                            backgroundColor: const Color(0xFF1F2431),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  child: ListView.builder(
                    physics: const ClampingScrollPhysics(),
                    cacheExtent: 500,
                    itemExtent: 72,
                    itemCount: filtered.length,
                    itemBuilder: (context, i) {
                      final r = filtered[i];
                      final coin = Coin(
                        id: r.id,
                        symbol: r.symbol,
                        name: r.name,
                        assetPath: r.assetPath,
                      );
                      return OptimizedAssetListTile(
                        coin: coin,
                        price: r
                            .price, // USD, rendered by tile in selected currency
                        balance: r.balance,
                        onTap: () {
                          _applySelectedRow(r);
                          Navigator.pop(context);
                        },
                      );
                    },
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  void _applySelectedRow(_AssetRow r) {
    setState(() {
      _selectedAsset = r.name;
      _selectedAssetSymbol = r.symbol;
      _selectedAssetBalance = r.balance;
      _selectedAssetIconPath = r.assetPath;
      _selectedAssetPrice = r.price; // USD
    });
    _recomputeUsdFromInput();
  }

  String _baseSymbol(String coinId) {
    final dash = coinId.indexOf('-');
    return dash == -1 ? coinId : coinId.substring(0, dash);
  }

  Widget _iconCircle(String assetPath, double size) {
    return OptimizedCoinIcon(assetPath: assetPath, size: size);
  }

  void _toggleCurrency() {
    setState(() {
      _isCryptoSelected = !_isCryptoSelected;
      _recomputeUsdFromInput();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    if (!_isImagesPreloaded) {
      final coins = context.read<CoinStore>().coins.values.toList();
      final paths = coins.map((c) => c.assetPath).toList();
      ImageCacheManager.preloadImages(paths, context);
      _isImagesPreloaded = true;
    }

    _initSelectionIfNeeded();
  }

  Future<void> _initSelectionIfNeeded() async {
    if (!mounted) return;

    final ps = context.read<PortfolioStore>();
    final store = context.read<CoinStore>();

    if (ps.tokens.isEmpty && !ps.loading) {
      await ps.fetchCurrentWalletPortfolio();
    }

    if (!mounted) return;

    final wantedId = widget.initialCoinId ?? _selectedAssetSymbol;
    final wantedSymbol =
        wantedId.contains('-') ? wantedId.split('-').first : wantedId;

    final t = ps.getBySymbol(wantedSymbol) ??
        (ps.tokens.isNotEmpty ? ps.tokens.first : null);
    if (t == null) return;

    final coin = store.getById(t.symbol) ?? store.getById(t.chain);
    final assetPath = coin?.assetPath ?? 'assets/currencyicons/bitcoin.png';

    setState(() {
      _selectedAsset = t.name;
      _selectedAssetSymbol = t.symbol;
      _selectedAssetBalance = t.balance;
      _selectedAssetIconPath = assetPath;
      _selectedAssetPrice =
          t.value / (t.balance == 0 ? 1 : t.balance); // derive USD price
    });

    if (!mounted) return;
    _recomputeUsdFromInput();
  }

  Future<void> _ensurePricesLoaded() async {
    if (_priceBySymbol.isNotEmpty) return;
    if (!mounted) return;
    final syms = context.read<BalanceStore>().symbols;
    if (syms.isEmpty) return;

    final prices = await AuthService.fetchSpotPrices(symbols: syms);
    if (!mounted) return;

    setState(() {
      _priceBySymbol = prices; // USD
    });
  }

  @override
  Widget build(BuildContext context) {
    // rebuild on currency change
    final fx = FxAdapter(context.watch<CurrencyNotifier>());

    final ps = context.watch<PortfolioStore>();
    final token = ps.getBySymbol(_selectedAssetSymbol);
    if (token != null && token.balance != _selectedAssetBalance) {
      _selectedAssetBalance = token.balance;
      _selectedAssetPrice =
          token.value / (token.balance == 0 ? 1 : token.balance);
    }

    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenHeight < 0.6 * screenWidth;
    final isTablet = screenWidth > 600;

    final double primaryVal = double.tryParse(_currentAmount) ?? 0.0;

    // When fiat-tab is active, the primaryVal is in selected currency:
    // Convert to USD, then to crypto.
    final double cryptoAmt = _isCryptoSelected
        ? primaryVal
        : (fx.toUsd(primaryVal) /
            (_selectedAssetPrice == 0 ? 1 : _selectedAssetPrice));

    final String balanceApproxFiat =
        fx.formatFromUsd(_selectedAssetBalance * _selectedAssetPrice);

    return Scaffold(
      backgroundColor: const Color(0xFF0B0D1A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0B0D1A),
        elevation: 0,
        leading: IconButton(
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white, size: 16),
        ),
        title: Text(
          widget.title,
          style: TextStyle(
            color: Colors.white,
            fontSize: isTablet ? 20 : 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: IntrinsicHeight(
                  child: Column(
                    children: [
                      SizedBox(height: 1.h),

                      // Account Card (tap to select asset)
                      GestureDetector(
                        onTap: _showAssetSelector,
                        child: Container(
                          margin: EdgeInsets.symmetric(horizontal: 4.w),
                          padding: EdgeInsets.all(isSmallScreen ? 3.w : 2.w),
                          decoration: BoxDecoration(
                            color: Colors.transparent,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: const Color.fromARGB(255, 170, 171, 177),
                              width: 1.2,
                            ),
                          ),
                          child: Row(
                            children: [
                              _iconCircle(_selectedAssetIconPath, 40),
                              SizedBox(width: 3.w),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '$_selectedAssetSymbol - Main Account',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: isSmallScreen ? 14 : 14,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    Text(
                                      _selectedAsset,
                                      style: TextStyle(
                                        color: const Color(0xFF9CA3AF),
                                        fontSize: isSmallScreen ? 12 : 14,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    _selectedAssetBalance.toStringAsFixed(6),
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: isSmallScreen ? 14 : 14,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  Text(
                                    '≈ $balanceApproxFiat',
                                    style: TextStyle(
                                      color: const Color(0xFF9CA3AF),
                                      fontSize: isSmallScreen ? 10 : 12,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),

                      SizedBox(height: isSmallScreen ? 2.h : 2.h),

                      // Currency Toggle (crypto vs selected fiat)
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          GestureDetector(
                            onTap: () {
                              if (!_isCryptoSelected) _toggleCurrency();
                            },
                            child: Container(
                              padding: EdgeInsets.symmetric(
                                  horizontal: 4.w, vertical: 0.3.h),
                              decoration: BoxDecoration(
                                color: _isCryptoSelected
                                    ? const Color(0xFF4C5563)
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: const Color(0xFF4C5563),
                                  width: 1,
                                ),
                              ),
                              child: Text(
                                _selectedAssetSymbol,
                                style: TextStyle(
                                  color: _isCryptoSelected
                                      ? Colors.white
                                      : const Color(0xFF9CA3AF),
                                  fontSize: isSmallScreen ? 14 : 16,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ),
                          SizedBox(width: 4.w),
                          GestureDetector(
                            onTap: () {
                              if (_isCryptoSelected) _toggleCurrency();
                            },
                            child: Container(
                              padding: EdgeInsets.symmetric(
                                  horizontal: 4.w, vertical: 0.3.h),
                              decoration: BoxDecoration(
                                color: !_isCryptoSelected
                                    ? const Color(0xFF4C5563)
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: const Color(0xFF4C5563),
                                  width: 1,
                                ),
                              ),
                              child: Text(
                                fx.code, // show selected currency code
                                style: TextStyle(
                                  color: !_isCryptoSelected
                                      ? Colors.white
                                      : const Color(0xFF9CA3AF),
                                  fontSize: isSmallScreen ? 14 : 16,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),

                      SizedBox(height: isSmallScreen ? 2.h : 1.h),

                      // Amount Display
                      Column(
                        children: [
                          const Text(
                            'Amount',
                            style: TextStyle(
                              color: Color(0xFF9CA3AF),
                              fontSize: 14,
                            ),
                          ),
                          SizedBox(height: 0.5.h),
                          Text(
                            _isCryptoSelected
                                ? _currentAmount
                                : fx.symbol +
                                    (double.tryParse(_currentAmount) ?? 0.0)
                                        .toStringAsFixed(2),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 28,
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          SizedBox(height: 0.5.h),
                          Text(
                            _isCryptoSelected
                                ? '≈ ${fx.formatFromUsd(_usdValue)}'
                                : '≈ ${cryptoAmt.toStringAsFixed(8)} $_selectedAssetSymbol',
                            style: TextStyle(
                              color: const Color(0xFF9CA3AF),
                              fontSize: isSmallScreen ? 14 : 16,
                            ),
                          ),
                        ],
                      ),

                      SizedBox(height: 2.w),

                      // Percentage Buttons
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 4.w),
                        child: Row(
                          children: [
                            _buildPercentageButton('25%', 0.25, isSmallScreen),
                            SizedBox(width: 2.w),
                            _buildPercentageButton('50%', 0.50, isSmallScreen),
                            SizedBox(width: 2.w),
                            _buildPercentageButton('75%', 0.75, isSmallScreen),
                            SizedBox(width: 2.w),
                            _buildPercentageButton('100%', 1.00, isSmallScreen),
                          ],
                        ),
                      ),

                      // Number Pad
                      Padding(
                        padding: EdgeInsets.symmetric(
                            horizontal: 4.w, vertical: 2.h),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            _buildNumberRow(['1', '2', '3'], isSmallScreen),
                            SizedBox(height: 1.h),
                            _buildNumberRow(['4', '5', '6'], isSmallScreen),
                            SizedBox(height: 1.h),
                            _buildNumberRow(['7', '8', '9'], isSmallScreen),
                            SizedBox(height: 1.h),
                            _buildNumberRow(
                                ['.', '0', 'backspace'], isSmallScreen),
                          ],
                        ),
                      ),

                      const Spacer(),

                      // Next Button
                      Container(
                        margin: EdgeInsets.all(4.w),
                        width: double.infinity,
                        height: isSmallScreen ? 5.h : 6.h,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: ElevatedButton(
                          onPressed: _onNextPressed,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            shadowColor: Colors.transparent,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          child: Text(
                            widget.buttonLabel ?? 'Next',
                            style: TextStyle(
                              color: Colors.black,
                              fontSize: isSmallScreen ? 16 : 18,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildPercentageButton(
      String text, double percentage, bool isSmallScreen) {
    return Expanded(
      child: GestureDetector(
        onTap: () => _onPercentagePressed(percentage),
        child: Container(
          padding: EdgeInsets.symmetric(vertical: 0.5.h),
          decoration: BoxDecoration(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: const Color(0xFF3A3D4A), width: 1),
          ),
          child: Center(
            child: Text(
              text,
              style: TextStyle(
                color: Colors.white,
                fontSize: isSmallScreen ? 14 : 16,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNumberRow(List<String> numbers, bool isSmallScreen) {
    return Row(
      children:
          numbers.map((n) => _buildNumberButton(n, isSmallScreen)).toList(),
    );
  }

  Widget _buildNumberButton(String number, bool isSmallScreen) {
    return Expanded(
      child: GestureDetector(
        onTap: () {
          if (number == 'backspace') {
            _onBackspacePressed();
          } else if (number == '.') {
            _onDecimalPressed();
          } else {
            _onNumberPressed(number);
          }
        },
        child: Container(
          margin: EdgeInsets.symmetric(horizontal: 1.w),
          height: isSmallScreen ? 2.h : 5.h,
          decoration: BoxDecoration(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(35),
            border: Border.all(color: const Color(0xFF3A3D4A), width: 1),
          ),
          child: Center(
            child: number == 'backspace'
                ? Icon(Icons.backspace_outlined,
                    color: Colors.white, size: isSmallScreen ? 20 : 24)
                : Text(
                    number,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: isSmallScreen ? 20 : 24,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}
