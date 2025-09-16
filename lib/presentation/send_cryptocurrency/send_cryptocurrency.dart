// lib/presentation/send_cryptocurrency/SendCryptocurrency.dart
import 'package:cryptowallet/presentation/receive_cryptocurrency/receive_btclightning.dart';
import 'package:cryptowallet/presentation/send_cryptocurrency/SendConfirmationScreen.dart';
import 'package:cryptowallet/presentation/send_cryptocurrency/SendConfirmationView.dart'; // ← navigate to review screen next
import 'package:cryptowallet/widgets/tx_failure_card.dart';
import 'package:flutter/material.dart';
import 'package:sizer/sizer.dart';
import 'package:provider/provider.dart';

import 'package:cryptowallet/stores/coin_store.dart'; // ✅ Provider source of truth
import 'package:cryptowallet/services/api_service.dart'; // ✅ AuthService with fetchTokens
import 'package:flutter/foundation.dart' show debugPrint;

/// ----------------------------------------------
/// Flow model passed across the 3-screen send flow
/// ----------------------------------------------
class SendFlowData {
  final String? userId;
  final String? walletId;

  /// API fields
  final String chain; // e.g. "BTC", "ETH" (maps to API "chain")
  final String amount; // crypto amount as string (API expects string)
  final String priority; // "yes" | "no"
  final String? toAddress; // will be filled later

  /// UI helpers
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

// 1. IMAGE CACHE MANAGER
class ImageCacheManager {
  static final Map<String, ImageProvider> _cachedImages = {};

  static ImageProvider getCachedImage(String assetPath) {
    if (!_cachedImages.containsKey(assetPath)) {
      _cachedImages[assetPath] = AssetImage(assetPath);
    }
    return _cachedImages[assetPath]!;
  }

  static void preloadImages(List<String> assetPaths, BuildContext context) {
    for (String path in assetPaths) {
      precacheImage(AssetImage(path), context).catchError((_) {
        debugPrint('Failed to preload image: $path');
      });
    }
  }

  static void clearCache() {
    _cachedImages.clear();
  }
}

// 2. OPTIMIZED COIN ICON WIDGET
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
        errorBuilder: (context, error, stackTrace) => Container(
          color: const Color(0xFF1F2431),
          child: Icon(
            Icons.currency_bitcoin,
            color: Colors.white,
            size: size * 0.6,
          ),
        ),
        gaplessPlayback: true,
      ),
    );
  }
}

// 3. OPTIMIZED LIST TILE WIDGET
class OptimizedAssetListTile extends StatelessWidget {
  final Coin coin;
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
                      'Balance: ${balance.toStringAsFixed(4)}',
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
              Text(
                '\$${price.toStringAsFixed(2)}',
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

// ---------- Local row model for API-loaded assets (but icons from CoinStore) ----------
class _AssetRow {
  final String id; // e.g. "BTC" or "USDT-ETH"
  final String symbol; // e.g. "BTC"
  final String name; // e.g. "Bitcoin"
  final double price; // USD price
  final double balance; // user balance (crypto units)
  final String assetPath; // from CoinStore.assetPath

  _AssetRow({
    required this.id,
    required this.symbol,
    required this.name,
    required this.price,
    required this.balance,
    required this.assetPath,
  });
}

// ---------- Bottom sheet scaffold ----------
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
              // Handle bar
              Container(
                margin: const EdgeInsets.symmetric(vertical: 10),
                height: 4,
                width: 40,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.25),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),

              // Title
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

              // Content
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
  /// Screen title (defaults to "Insert Amount")
  final String title;
  final String? initialAddress;

  /// Preselect a coin/network by its CoinStore id (e.g. "BTC-LN", "BTC", "USDT-TRX")
  final String? initialCoinId;

  /// Optional button label (defaults to "Next")
  final String? buttonLabel;

  /// If true, behaves as a "Charge" screen (we'll hook next step later)
  final bool isChargeMode;

  /// NEW: prefill USD amount (when opening from amount chips)
  final double? initialUsd;

  /// NEW: open with USD tab selected
  final bool startInUsd;

  /// (Optional) Pass from your wallet/dashboard so it flows to API
  final String? userId;
  final String? walletId;

  const SendCryptocurrency({
    super.key,
    this.title = 'Insert Amount',
    this.initialCoinId,
    this.buttonLabel,
    this.isChargeMode = false,
    this.initialUsd, // NEW
    this.startInUsd = false, // NEW
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
  double _usdValue = 0.00;
  bool _isImagesPreloaded = false;

  // Selected asset properties (derived from CoinStore or API)
  String _selectedAsset = 'Bitcoin';
  String _selectedAssetSymbol = 'BTC';
  double _selectedAssetBalance = 0.00;
  String _selectedAssetIconPath = 'assets/currencyicons/bitcoin.png';
  double _selectedAssetPrice = 30000.00;

  // Dummy prices/balances (fallback)
  final Map<String, double> _dummyPrices = const {
    'BTC': 43825.67,
    'BTC-LN': 43825.67,
    'ETH': 2641.25,
    'BNB': 580.00,
    'SOL': 148.12,
    'TRX': 0.13,
    'USDT': 1.00,
    'USDT-ETH': 1.00,
    'USDT-TRX': 1.00,
    'BNB-BNB': 580.00,
    'ETH-ETH': 2641.25,
    'SOL-SOL': 148.12,
    'TRX-TRX': 0.13,
    'XMR': 168.00,
    'XMR-XMR': 168.00,
  };

  final Map<String, double> _dummyBalances = const {
    'BTC': 500.0,
    'BTC-LN': 0.0,
    'ETH': 500.0,
    'BNB': 0.0,
    'SOL': 0.0,
    'TRX': 0.0,
    'USDT': 0.0,
    'USDT-ETH': 0.0,
    'USDT-TRX': 0.0,
    'BNB-BNB': 0.0,
    'ETH-ETH': 0.0,
    'SOL-SOL': 0.0,
    'TRX-TRX': 0.0,
    'XMR': 0.0,
    'XMR-XMR': 0.0,
  };

  @override
  void dispose() {
    ImageCacheManager.clearCache();
    super.dispose();
  }

  // ---------- Amount helpers ----------
  void _onNumberPressed(String number) {
    setState(() {
      if (_currentAmount == '0') {
        _currentAmount = number;
      } else {
        _currentAmount += number;
      }
      _calculateUSDValue();
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
      _calculateUSDValue();
    });
  }

  void _onPercentagePressed(double percentage) {
    setState(() {
      if (_isCryptoSelected) {
        final amt = _selectedAssetBalance * percentage; // crypto amount
        _currentAmount = amt
            .toStringAsFixed(8)
            .replaceAll(RegExp(r'0*$'), '')
            .replaceAll(RegExp(r'\.$'), '');
      } else {
        final usd = _selectedAssetBalance *
            _selectedAssetPrice *
            percentage; // USD amount
        _currentAmount = usd.toStringAsFixed(2);
      }
      if (_currentAmount.isEmpty) _currentAmount = '0';
      _calculateUSDValue();
    });
  }

  void _calculateUSDValue() {
    final val = double.tryParse(_currentAmount) ?? 0.0;
    _usdValue = _isCryptoSelected ? val * _selectedAssetPrice : val;
  }

  // ---------- NEXT (Review) ----------
  void _onNextPressed() {
    final entered = double.tryParse(_currentAmount) ?? 0.0;
    final amountCrypto =
        _isCryptoSelected ? entered : (entered / _selectedAssetPrice);

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
        barrier: true, // nice dim+blur
        // autoHideAfter: const Duration(seconds: 5),
      );

      return;
    }

    final amountCryptoStr = amountCrypto
        .toStringAsFixed(8)
        .replaceAll(RegExp(r'0*$'), '')
        .replaceAll(RegExp(r'\.$'), '');

    // 👉 If this screen is opened as "Charge" (invoice flow)
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
            coinName: _selectedAsset, // e.g. "Bitcoin"
            iconAsset: _selectedAssetIconPath, // coin icon
            isLightning: isLn, // shows purple Lightning pill
            amount: amountCryptoStr, // crypto amount
            symbol: _selectedAssetSymbol, // e.g. "BTC"
            fiatValue: amountCrypto * _selectedAssetPrice,
            qrData: amountCryptoStr, // 🔥 QR encodes crypto amount
          ),
        ),
      );
      return;
    }

    // Default SEND flow → go to review screen with all computed info
    final data = SendFlowData(
      userId: widget.userId,
      walletId: widget.walletId,
      chain: _selectedAssetSymbol, // maps to API "chain"
      amount: amountCryptoStr, // API expects string
      priority: "yes", // default; can be edited next screen
      usdValue: amountCrypto * _selectedAssetPrice,
      assetName: _selectedAsset,
      assetSymbol: _selectedAssetSymbol,
      assetIconPath: _selectedAssetIconPath,
      toAddress: null, // will be filled on next screen
    );

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SendConfirmationScreen(flowData: data),
      ),
    );
  }

  // ---------- Selector & state updates ----------
  void _onAssetSelected(Coin coin) {
    final symbol = coin.symbol;
    final price = _dummyPrices[symbol] ?? _dummyPrices[coin.id] ?? 1.0;
    final balance = _dummyBalances[symbol] ?? _dummyBalances[coin.id] ?? 0.0;

    setState(() {
      _selectedAsset = coin.name;
      _selectedAssetSymbol = symbol;
      _selectedAssetBalance = balance;
      _selectedAssetIconPath = coin.assetPath;
      _selectedAssetPrice = price;
    });
    _calculateUSDValue();
  }

  // ---------- Flexible JSON pickers for VaultToken → UI ----------
  String _pickString(Map<String, dynamic> j, List<String> keys,
      {String def = ''}) {
    for (final k in keys) {
      final v = j[k];
      if (v == null) continue;
      if (v is String && v.trim().isNotEmpty) return v.trim();
      return v.toString();
    }
    return def;
  }

  double _pickNum(Map<String, dynamic> j, List<String> keys,
      {double def = 0.0}) {
    for (final k in keys) {
      final v = j[k];
      if (v == null) continue;
      if (v is num) return v.toDouble();
      if (v is String) {
        final d = double.tryParse(v);
        if (d != null) return d;
      }
    }
    return def;
  }

  // 🔎 Resolve a Coin from CoinStore (id → symbol → base id)
  Coin? _resolveCoinFromStore({
    required CoinStore store,
    required String id,
    required String symbol,
  }) {
    // 1) Try exact id
    Coin? coin = store.getById(id);
    if (coin != null) return coin;

    // 2) Try by exact symbol match among values
    for (final c in store.coins.values) {
      if (c.symbol.toUpperCase() == symbol.toUpperCase()) return c;
    }

    // 3) Try by base id (e.g., "USDT-ETH" -> "USDT")
    final base = id.contains('-') ? id.split('-').first : id;
    coin = store.getById(base);
    if (coin != null) return coin;

    return null;
  }

  // 🔥 Load assets via API (fetchTokens) and map to rows — ICONS ALWAYS FROM CoinStore
  Future<List<_AssetRow>> _loadAssetsFromApi() async {
    try {
      final tokens = await AuthService.fetchTokens();
      final store = context.read<CoinStore>();

      // Map VaultToken → _AssetRow via toJson/keys (field-agnostic)
      final rows = tokens.map((t) {
        Map<String, dynamic> j;
        try {
          j = (t as dynamic).toJson() as Map<String, dynamic>;
        } catch (_) {
          j = <String, dynamic>{};
        }

        final rawId = _pickString(j, ['id', '_id', 'tokenId', 'symbol']);
        final rawSymbol = _pickString(j, ['symbol', 'ticker', 'code'],
            def: rawId.isNotEmpty ? rawId : 'BTC');
        final rawName =
            _pickString(j, ['name', 'tokenName', 'assetName'], def: rawSymbol);

        // Price candidates — adjust if your API uses different keys
        final price = _pickNum(
            j,
            [
              'priceUsd',
              'price',
              'usdPrice',
              'fiatPrice',
              'currentPrice',
              'lastPrice',
              'marketPrice',
            ],
            def: 0.0);

        // Balance candidates
        final balance = _pickNum(
            j,
            [
              'balance',
              'amount',
              'qty',
              'quantity',
              'free',
              'available',
            ],
            def: 0.0);

        // 🔗 Resolve the Coin from CoinStore to get the PNG path
        final coinFromStore = _resolveCoinFromStore(
          store: store,
          id: rawId.isNotEmpty ? rawId : rawSymbol,
          symbol: rawSymbol,
        );

        final displayId =
            coinFromStore?.id ?? (rawId.isNotEmpty ? rawId : rawSymbol);
        final displaySymbol = coinFromStore?.symbol ?? rawSymbol;
        final displayName = coinFromStore?.name ?? rawName;
        final assetPath = coinFromStore?.assetPath ??
            store.cardAssetFor(displayId) // fallback to watermark if exists
            ??
            'assets/currencyicons/bitcoin.png'; // last-resort default

        return _AssetRow(
          id: displayId,
          symbol: displaySymbol,
          name: displayName,
          price: price,
          balance: balance,
          assetPath: assetPath, // ✅ from CoinStore
        );
      }).toList();

      return rows;
    } catch (e) {
      debugPrint('fetchTokens failed, falling back to CoinStore: $e');

      // Fallback to current provider coins so UI still works
      final coins = context.read<CoinStore>().coins.values.toList()
        ..sort((a, b) => a.symbol.compareTo(b.symbol));

      return coins.map((c) {
        final symbol = c.symbol;
        final name = c.name;
        final price = _dummyPrices[symbol] ?? _dummyPrices[c.id] ?? 1.0;
        final balance = _dummyBalances[symbol] ?? _dummyBalances[c.id] ?? 0.0;
        return _AssetRow(
          id: c.id,
          symbol: symbol,
          name: name,
          price: price,
          balance: balance,
          assetPath: c.assetPath, // ✅ store icon
        );
      }).toList();
    }
  }

  void _showAssetSelector() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      enableDrag: true,
      builder: (context) {
        return FutureBuilder<List<_AssetRow>>(
          future: _loadAssetsFromApi(),
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

            // Build chip list from base symbols
            final baseSet = <String>{};
            for (final r in rows) {
              final base = _baseSymbol(r.id);
              baseSet.add(base);
            }
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
                      // Build a Coin purely from store-driven assetPath & identity
                      final coin = Coin(
                        id: r.id,
                        symbol: r.symbol,
                        name: r.name,
                        assetPath: r.assetPath, // ✅ from CoinStore
                      );
                      return OptimizedAssetListTile(
                        coin: coin,
                        price: r.price,
                        balance: r.balance,
                        onTap: () {
                          _onAssetSelected(coin);
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
      _calculateUSDValue();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    if (!_isImagesPreloaded) {
      final coins = context.read<CoinStore>().coins.values.toList();
      final imagePaths = coins.map((coin) => coin.assetPath).toList();
      ImageCacheManager.preloadImages(imagePaths, context);
      _isImagesPreloaded = true;
    }

    // Initialize selection from Provider the first time
    final coins = context.read<CoinStore>().coins.values.toList()
      ..sort((a, b) => a.symbol.compareTo(b.symbol));

    if (coins.isNotEmpty) {
      Coin initial;

      if (widget.initialCoinId != null && widget.initialCoinId!.isNotEmpty) {
        // Try to find by id (e.g. "BTC-LN")
        initial = coins.firstWhere(
          (c) => c.id == widget.initialCoinId,
          orElse: () => coins.first,
        );
      } else {
        // Fallback to your previous default by symbol
        initial = coins.firstWhere(
          (c) => c.symbol == _selectedAssetSymbol,
          orElse: () => coins.first,
        );
      }

      _onAssetSelected(initial);

      // Apply prefill/selection from navigation
      if (widget.startInUsd) {
        _isCryptoSelected = false; // show USD tab
      }
      if (widget.initialUsd != null) {
        if (_isCryptoSelected) {
          // convert USD → crypto text
          final crypto = widget.initialUsd! / _selectedAssetPrice;
          _currentAmount = crypto
              .toStringAsFixed(8)
              .replaceAll(RegExp(r'0*$'), '')
              .replaceAll(RegExp(r'\.$'), '');
        } else {
          _currentAmount = widget.initialUsd!.toStringAsFixed(2);
        }
      }
      _calculateUSDValue();
    }
  }

  @override
  Widget build(BuildContext context) {
    // ensure rebuilds if coins update (icons/names)
    context.watch<CoinStore>();

    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenHeight < 0.6 * screenWidth;
    final isTablet = screenWidth > 600;

    // compute secondary line conversion when needed
    final double primaryVal = double.tryParse(_currentAmount) ?? 0.0;
    final double cryptoAmt =
        _isCryptoSelected ? primaryVal : (primaryVal / _selectedAssetPrice);

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
                              // Asset Icon (optimized)
                              _iconCircle(_selectedAssetIconPath, 40),

                              SizedBox(width: 3.w),

                              // Account Details
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

                              // Balance
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    _selectedAssetBalance.toStringAsFixed(4),
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: isSmallScreen ? 14 : 14,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  Text(
                                    '≈ \$${(_selectedAssetBalance * _selectedAssetPrice).toStringAsFixed(2)}',
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

                      // Currency Toggle Buttons
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
                                'USD',
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
                                : '\$$_currentAmount',
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
                                ? '≈ \$${_usdValue.toStringAsFixed(2)} USD'
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
