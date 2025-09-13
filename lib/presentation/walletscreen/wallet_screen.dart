import 'package:cryptowallet/presentation/bottomnavbar.dart';
import 'package:cryptowallet/presentation/send_cryptocurrency/send_cryptocurrency.dart';
import 'package:cryptowallet/routes/app_routes.dart';
import 'package:cryptowallet/services/api_service.dart';
import 'package:cryptowallet/models/token_model.dart';
import 'package:cryptowallet/models/explore_model.dart';
import 'package:cryptowallet/stores/wallet_store.dart';
import 'package:flutter/material.dart';
import 'dart:async';
import 'package:provider/provider.dart';

import 'package:cryptowallet/stores/coin_store.dart';

class WalletInfoScreen extends StatefulWidget {
  const WalletInfoScreen({Key? key}) : super(key: key);

  @override
  State<WalletInfoScreen> createState() => _WalletInfoScreenState();
}

class _WalletInfoScreenState extends State<WalletInfoScreen>
    with TickerProviderStateMixin {
  String selectedCoinId = 'BTC';

  // Animation controllers
  late AnimationController _flipController;
  late Animation<double> _flipAnimation;

  // State variables
  bool _isCardFlipped = false;
  String _lightningState = 'sync';
  Timer? _lightningTimer;
  bool _isLightningComplete = false;

  // API Integration State
  bool _isLoading = true;
  String? _error;
  List<VaultToken> _tokens = [];
  ExploreData? _exploreData;
  Map<String, double> _spotPrices = {};
  String? _currentWalletAddress;

  // Cached data to avoid repeated API calls
  Map<String, ExploreData> _exploreCache = {};
  DateTime? _lastPriceUpdate;

  static const Duration _priceUpdateInterval = Duration(minutes: 5);

  // UI Constants
  static const Color kBg = Color(0xFF0B0D1A);
  static const Color kTile = Color(0xFF2A2D3A);
  static const Color kTileBorder = Color(0xFF3A3D4A);
  static const Color kMuted = Color(0xFF6B7280);
  static const EdgeInsets kHPad8 = EdgeInsets.symmetric(horizontal: 8);

  static const BoxShadow kSoftShadow = BoxShadow(
    color: Colors.black26,
    blurRadius: 8,
    offset: Offset(0, 2),
  );

  static const LinearGradient kCardFrontGrad = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFF2A2D3A),
      Color.fromARGB(255, 0, 0, 0),
      Color.fromARGB(255, 0, 12, 56),
    ],
    stops: [0.0, 0.5, 1.0],
  );

  static const LinearGradient kCardBackGrad = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFF2D5A2D),
      Color.fromARGB(255, 0, 20, 0),
      Color.fromARGB(255, 0, 56, 12),
    ],
    stops: [0.0, 0.5, 1.0],
  );

  static const LinearGradient kSheetGrad = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomRight,
    stops: [0.0, 0.55, 1.0],
    colors: [
      Color.fromARGB(255, 6, 11, 33),
      Color.fromARGB(255, 0, 0, 0),
      Color.fromARGB(255, 0, 12, 56),
    ],
  );

  @override
  void initState() {
    super.initState();
    _flipController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _flipAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _flipController, curve: Curves.easeInOut),
    );

    _startLightningTimer();
    _initializeWallet();
  }

  @override
  void dispose() {
    _flipController.dispose();
    _lightningTimer?.cancel();
    super.dispose();
  }

  // API Integration Methods
  Future<void> _initializeWallet() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      await Future.wait([_loadTokens(), _loadSpotPrices()]);

      // Choose first available wallet token as the selected coin (if not set)
      if (_tokens.isNotEmpty) {
        final firstBase =
            _baseFromToken(_tokens.first.symbol, _tokens.first.chain);
        if (firstBase.isNotEmpty) selectedCoinId = firstBase;
      }

      await _loadWalletAddress();
      if (_currentWalletAddress != null) {
        await _loadTransactionData();
      }
    } catch (e) {
      setState(() {
        _error = 'Failed to load wallet data: ${e.toString()}';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _loadTokens() async {
    try {
      // Try to get wallet ID and load tokens
      final wallets = await AuthService.fetchWallets();
      if (wallets.isNotEmpty) {
        final walletId = wallets.first['_id']?.toString();
        if (walletId != null) {
          final tokens =
              await AuthService.fetchTokensByWallet(walletId: walletId);
          setState(() {
            _tokens = tokens;
          });
        }
      }
    } catch (e) {
      debugPrint('Error loading tokens: $e');
      // Fallback to legacy method
      try {
        final tokens = await AuthService.fetchTokens();
        setState(() {
          _tokens = tokens;
        });
      } catch (e2) {
        debugPrint('Error with fallback token loading: $e2');
      }
    }
  }

  Future<void> _loadSpotPrices() async {
    final now = DateTime.now();
    if (_lastPriceUpdate != null &&
        now.difference(_lastPriceUpdate!) < _priceUpdateInterval) {
      return;
    }

    try {
      final prices = await AuthService.fetchSpotPrices(
        symbols: ['BTC', 'ETH', 'USDT', 'TRX', 'BNB', 'SOL', 'XMR'],
      );
      setState(() {
        _spotPrices = prices; // may be empty if endpoint unavailable
        _lastPriceUpdate = now;
      });
    } catch (e) {
      // With the tolerant fetcher above, this shouldn't throw anymore.
      // Keep a quiet log just in case.
      debugPrint('Spot prices unavailable: $e');
    }
  }

  Future<void> _loadWalletAddress() async {
    try {
      final address = await AuthService.getOrFetchWalletAddress(
        chain: _getChainForCoin(selectedCoinId),
      );
      setState(() {
        _currentWalletAddress = address;
      });
    } catch (e) {
      debugPrint('Error loading wallet address: $e');
    }
  }

  Future<void> _loadTransactionData() async {
    if (_currentWalletAddress == null) return;

    // Check cache first
    if (_exploreCache.containsKey(_currentWalletAddress)) {
      setState(() {
        _exploreData = _exploreCache[_currentWalletAddress];
      });
      return;
    }

    try {
      final exploreData =
          await AuthService.exploreAddress(_currentWalletAddress!);
      setState(() {
        _exploreData = exploreData;
        _exploreCache[_currentWalletAddress!] = exploreData;
      });
    } catch (e) {
      debugPrint('Error loading transaction data: $e');
    }
  }

  String _getChainForCoin(String coinId) {
    // Map your coin IDs to chain names expected by the API
    if (coinId.startsWith('BTC')) return 'BTC';
    if (coinId.startsWith('ETH')) return 'ETH';
    if (coinId.startsWith('USDT-ETH')) return 'ETH';
    if (coinId.startsWith('USDT-TRX')) return 'TRON';
    if (coinId.startsWith('TRX')) return 'TRON';
    if (coinId.startsWith('BNB')) return 'BNB';
    if (coinId.startsWith('SOL')) return 'SOL';
    if (coinId.startsWith('XMR')) return 'XMR';
    return coinId.split('-').first; // fallback
  }

  // Get current coin data from API or fallback to dummy
  Map<String, String> _getCurrentCoinData() {
    final chainKey = _getChainForCoin(selectedCoinId);

    // Try to get from API data first
    VaultToken? token;
    try {
      token = _tokens.firstWhere(
        (t) => t.symbol.toUpperCase() == chainKey.toUpperCase(),
        orElse: () => _tokens.firstWhere(
          (t) => t.name.toUpperCase().contains(chainKey.toUpperCase()),
        ),
      );
    } catch (e) {
      // Token not found, will use fallback
    }

    final price = _spotPrices[chainKey] ?? 0.0;
    final balance = token?.balance?.toString() ?? '0.00';
    final balanceDouble = double.tryParse(balance) ?? 0.0;
    final usdBalance = token != null && price > 0
        ? (balanceDouble * price).toStringAsFixed(2)
        : '0.00';

    return {
      'price': price > 0 ? price.toStringAsFixed(2) : '0.00',
      'balance': balance,
      'usdBalance': usdBalance,
      'address': _currentWalletAddress ?? 'Loading...',
    };
  }

  // Get transactions from API data
  List<Map<String, dynamic>> _getCurrentTransactions() {
    if (_exploreData?.transactions == null) {
      return []; // Return empty list instead of dummy data
    }

    // Convert API transactions to your UI format
    return _exploreData!.transactions!
        .map((tx) => {
              'id': tx.hash ?? 'unknown',
              'type': _determineTransactionType(tx),
              'status': tx.status ?? 'Unknown',
              'amount': tx.value?.toString() ?? '0',
              'coin': selectedCoinId,
              'dateTime': _formatDateTime(tx.timestamp as String?),
              'from': tx.from ?? 'Unknown',
              'to': tx.to ?? 'Unknown',
              'hash': tx.hash ?? '',
              'block': tx.blockNumber,
              'feeDetails': {
                'Total Fee':
                    '${tx.gasUsed ?? 0} ${_getChainForCoin(selectedCoinId)}',
              },
            })
        .toList();
  }

  String _determineTransactionType(ExploreTransaction tx) {
    final currentAddr = _currentWalletAddress?.toLowerCase();
    final fromAddr = tx.from?.toLowerCase();
    final toAddr = tx.to?.toLowerCase();

    if (fromAddr == currentAddr && toAddr != currentAddr) {
      return 'send';
    } else if (toAddr == currentAddr && fromAddr != currentAddr) {
      return 'receive';
    }
    return 'send'; // default
  }

  String _formatDateTime(String? timestamp) {
    if (timestamp == null) return 'Unknown time';
    try {
      final date =
          DateTime.fromMillisecondsSinceEpoch(int.parse(timestamp) * 1000);
      return '${date.day} ${_getMonthName(date.month)} ${date.year} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}:${date.second.toString().padLeft(2, '0')}';
    } catch (e) {
      return 'Unknown time';
    }
  }

  String _getMonthName(int month) {
    const months = [
      '',
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec'
    ];
    return months[month];
  }

  // Update selected coin and reload data
  Future<void> _updateSelectedCoin(String newCoinId) async {
    setState(() {
      selectedCoinId = newCoinId;
      _isCardFlipped = false;
      _flipController.reset();
      _lightningState = 'sync';
      _isLightningComplete = false;
      _currentWalletAddress = null;
      _exploreData = null;
    });

    _startLightningTimer();

    // Reload data for new coin
    await _loadWalletAddress();
    if (_currentWalletAddress != null) {
      await _loadTransactionData();
    }
  }

  // USD toggle state
  bool _showAllInUsd = false;
  final Set<String> _usdPerTx = <String>{};

  double _priceForCoinUsd(String coinKey) {
    final chainKey = _getChainForCoin(coinKey);
    return _spotPrices[chainKey] ?? 0.0;
  }

  String _formatUsd(double usd) => '\$${usd.toStringAsFixed(2)}';

  // Convenience getters
  bool get isLightningSelected => selectedCoinId == 'BTC-LN';

  // Lightning Timer Methods
  void _startLightningTimer() {
    _lightningTimer?.cancel();
    if (isLightningSelected && !_isLightningComplete) {
      _lightningTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (mounted && isLightningSelected && !_isLightningComplete) {
          _cycleLightningStateAuto();
        } else {
          timer.cancel();
        }
      });
    }
  }

  void _cycleLightningStateAuto() {
    setState(() {
      switch (_lightningState) {
        case 'sync':
          _lightningState = 'syncing';
          break;
        case 'syncing':
          _lightningState = 'synced';
          _isLightningComplete = true;
          _lightningTimer?.cancel();
          break;
        case 'synced':
          break;
      }
    });
  }

  void _cycleLightningState() {
    setState(() {
      switch (_lightningState) {
        case 'sync':
          _lightningState = 'syncing';
          _isLightningComplete = false;
          _startLightningTimer();
          break;
        case 'syncing':
          _lightningState = 'synced';
          _isLightningComplete = true;
          _lightningTimer?.cancel();
          break;
        case 'synced':
          _lightningState = 'sync';
          _isLightningComplete = false;
          _lightningTimer?.cancel();
          break;
      }
    });
  }

  void _toggleCardFlip() {
    if (_isCardFlipped) {
      _flipController.reverse();
    } else {
      _flipController.forward();
    }
    setState(() => _isCardFlipped = !_isCardFlipped);
  }

  // Navigate to transaction details
  void _navigateToTransactionDetails(Map<String, dynamic> transaction) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            TransactionDetailsScreen(transaction: transaction),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<CoinStore>();
    final coin = store.getById(selectedCoinId);

    // Show loading or error state
    if (_isLoading) {
      return Scaffold(
        backgroundColor: kBg,
        body: const Center(
          child: CircularProgressIndicator(color: Colors.white),
        ),
      );
    }

    if (_error != null) {
      return Scaffold(
        backgroundColor: kBg,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                'Error loading wallet',
                style: TextStyle(color: Colors.white, fontSize: 18),
              ),
              const SizedBox(height: 8),
              Text(
                _error!,
                style: const TextStyle(color: kMuted, fontSize: 14),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _initializeWallet,
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    final details = _getCurrentCoinData();

    return Scaffold(
      backgroundColor: kBg,
      bottomNavigationBar: BottomNavBar(
        selectedIndex: 1,
        onTap: (index) {
          if (index == 1) return;
          Navigator.pushReplacementNamed(
            context,
            index == 0
                ? AppRoutes.dashboardScreen
                : index == 1
                    ? AppRoutes.swapScreen
                    : index == 2
                        ? AppRoutes.dashboardScreen
                        : AppRoutes.dashboardScreen,
          );
        },
      ),
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(coin, details),
            Expanded(
              child: RefreshIndicator(
                onRefresh: _initializeWallet,
                child: SingleChildScrollView(
                  padding: kHPad8,
                  physics: const AlwaysScrollableScrollPhysics(),
                  child: Column(
                    children: [
                      const SizedBox(height: 16),
                      _buildBalanceCard(coin, details),
                      const SizedBox(height: 16),
                      _buildAvailableRow(details),
                      const SizedBox(height: 24),
                      _buildActionButtons(context),
                      const SizedBox(height: 24),
                      _buildTransactionsSection(),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(Coin? coin, Map<String, String> details) {
    final iconPath = coin?.assetPath;
    final symbol = coin?.symbol ?? selectedCoinId;

    return Container(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
      child: Row(
        children: [
          // Coin info and dropdown
          Expanded(
            child: GestureDetector(
              onTap: _showCoinSelector,
              child: Row(
                children: [
                  // Coin icon
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: kTile,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Center(
                      child: (iconPath != null)
                          ? Image.asset(iconPath, width: 22, height: 22)
                          : const Icon(Icons.currency_bitcoin,
                              color: Colors.white, size: 18),
                    ),
                  ),
                  const SizedBox(width: 12),

                  // Coin details
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Select Crypto',
                          style: TextStyle(
                            color: kMuted,
                            fontSize: 11,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            Text(
                              symbol,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(width: 6),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Dropdown button
          GestureDetector(
            onTap: _showCoinSelector,
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: kTile,
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Icon(
                Icons.keyboard_arrow_down,
                color: Colors.white,
                size: 20,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBalanceCard(Coin? coin, Map<String, String> details) {
    return AnimatedBuilder(
      animation: _flipAnimation,
      builder: (context, child) {
        final isShowingFront = _flipAnimation.value < 0.5;
        return Transform(
          alignment: Alignment.center,
          transform: Matrix4.identity()
            ..setEntry(3, 2, 0.001)
            ..rotateY(_flipAnimation.value * 3.14159),
          child: isShowingFront
              ? _buildFrontCard(coin, details)
              : _buildBackCard(coin, details),
        );
      },
    );
  }

  Widget _buildFrontCard(Coin? coin, Map<String, String> details) {
    final symbol = coin?.symbol ?? selectedCoinId;
    final address = details['address'] ?? '—';
    final balance = details['balance'] ?? '0.00';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: kCardFrontGrad,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: kTileBorder, width: 1),
        boxShadow: const [kSoftShadow],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with coin name and action icons
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '$symbol - Main Account',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                ),
              ),
              _buildActionIcons(),
            ],
          ),

          const SizedBox(height: 6),

          // Address
          Text(
            address,
            style: const TextStyle(
              color: kMuted,
              fontSize: 11,
            ),
          ),

          const SizedBox(height: 16),

          // Balance
          Text(
            balance,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 42,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBackCard(Coin? coin, Map<String, String> details) {
    final symbol = coin?.symbol ?? selectedCoinId;
    final address = details['address'] ?? '—';
    final balance = details['balance'] ?? '0.00';

    return Transform(
      alignment: Alignment.center,
      transform: Matrix4.identity()..rotateY(3.14159),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: kCardBackGrad,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: const Color(0xFF4A6A4A), width: 1),
          boxShadow: const [kSoftShadow],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with gasfree indicator and refresh icon
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.eco, color: Colors.green, size: 16),
                    const SizedBox(width: 8),
                    Text(
                      '$symbol - Gas Free Mode',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                GestureDetector(
                  onTap: _toggleCardFlip,
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: const Color(0xFF4A6A4A),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Icon(Icons.refresh,
                        color: Colors.green, size: 14),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 6),

            // Address
            Text(
              address,
              style: const TextStyle(
                color: Color(0xFF8B9B8B),
                fontSize: 11,
              ),
            ),

            const SizedBox(height: 16),

            // Balance
            Text(
              balance,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 42,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionIcons() {
    if (selectedCoinId.startsWith('USDT')) {
      return Row(
        children: [
          _miniIconBox(Icons.copy, kTileBorder, kMuted),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: _toggleCardFlip,
            child: _miniIconBox(Icons.eco, kTileBorder, Colors.green),
          ),
        ],
      );
    } else if (isLightningSelected) {
      return _getLightningStateWidget();
    } else {
      return _miniIconBox(Icons.copy, kTileBorder, kMuted);
    }
  }

  Widget _miniIconBox(IconData icon, Color border, Color fg) {
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: kTile,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: border),
      ),
      child: Icon(icon, color: fg, size: 14),
    );
  }

  Color _getLightningStateColor() {
    switch (_lightningState) {
      case 'sync':
        return Colors.red;
      case 'syncing':
        return Colors.orange;
      case 'synced':
        return Colors.green;
      default:
        return Colors.red;
    }
  }

  IconData _getLightningStateIcon() {
    switch (_lightningState) {
      case 'sync':
        return Icons.sync_problem;
      case 'syncing':
        return Icons.sync;
      case 'synced':
        return Icons.check_circle;
      default:
        return Icons.sync_problem;
    }
  }

  Widget _getLightningStateWidget() {
    return GestureDetector(
      onTap: _cycleLightningState,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: _getLightningStateColor(),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_lightningState == 'syncing')
              const SizedBox(
                width: 12,
                height: 12,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            else
              Icon(_getLightningStateIcon(), color: Colors.white, size: 12),
            const SizedBox(width: 4),
            Text(
              _lightningState.toUpperCase(),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAvailableRow(Map<String, String> details) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(
        children: [
          Expanded(child: _kv('Available', details['balance'] ?? '0')),
        ],
      ),
    );
  }

  Widget _kv(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: kMuted, fontSize: 13)),
        const SizedBox(height: 4),
        Row(
          children: [
            Text(value,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w500)),
            const SizedBox(width: 8),
            const Icon(Icons.info_outline, color: kMuted, size: 16),
          ],
        ),
      ],
    );
  }

  Widget _buildActionButtons(BuildContext context) {
    if (isLightningSelected) {
      // Lightning: Send, Receive, Scan
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildActionButton('Send', Icons.send, () {
              Navigator.pushNamed(context, AppRoutes.sendCrypto);
            }),
            _buildActionButton('Receive', Icons.arrow_downward, () {
              _showLightningReceiveOptions();
            }),
            _buildActionButton('Scan', Icons.qr_code_scanner, () {
              // Navigator.pushNamed(context, AppRoutes.scanQr);
            }),
          ],
        ),
      );
    } else {
      // Non-Lightning: Send, Swap, Receive
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildActionButton('Send', Icons.send, () {
              Navigator.pushNamed(context, AppRoutes.sendCrypto);
            }),
            _buildActionButton('Swap', Icons.swap_horiz, () {
              Navigator.pushNamed(context, AppRoutes.swapScreen);
            }),
            _buildActionButton('Receive', Icons.arrow_downward, () {
              Navigator.pushNamed(context, AppRoutes.receiveCrypto);
            }),
          ],
        ),
      );
    }
  }

  Widget _buildActionButton(String label, IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: 62,
        child: Column(
          children: [
            Container(
              width: 60,
              height: 48,
              decoration: BoxDecoration(
                color: kTile,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: kTileBorder),
              ),
              child: Icon(icon, color: Colors.white, size: 22),
            ),
            const SizedBox(height: 6),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w400,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  void _showLightningReceiveOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: false,
      builder: (_) {
        return ClipRect(
          child: Container(
            decoration: const BoxDecoration(gradient: kSheetGrad),
            padding: EdgeInsets.only(
              left: 12,
              right: 12,
              top: 8,
              bottom: MediaQuery.of(context).padding.bottom + 12,
            ),
            child: SafeArea(
              top: false,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 36,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 12, top: 6),
                    decoration: BoxDecoration(
                      color: kTile,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  _receiveOptionTile(
                    icon: Icons.receipt_long,
                    iconBg: kTile,
                    title: 'Receive via Invoice',
                    subtitle: 'Create a Lightning invoice to get paid',
                    onTap: () {
                      Navigator.pop(context);
                      _onLightningInvoiceReceive();
                    },
                  ),
                  const SizedBox(height: 8),
                  _receiveOptionTile(
                    icon: Icons.currency_bitcoin,
                    iconBg: kTile,
                    title: 'Receive via BTC mainnet',
                    subtitle: 'Use on-chain address (SegWit / Taproot)',
                    onTap: () {
                      Navigator.pop(context);
                      _onLightningMainnetReceive();
                    },
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _receiveOptionTile({
    required IconData icon,
    required Color iconBg,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: iconBg,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: Colors.white, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w600)),
                    const SizedBox(height: 2),
                    Text(subtitle,
                        style: const TextStyle(color: kMuted, fontSize: 12)),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: Colors.white, size: 20),
            ],
          ),
        ),
      ),
    );
  }

  void _onLightningInvoiceReceive() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const SendCryptocurrency(
          title: 'Charge',
          initialCoinId: 'BTC-LN',
          buttonLabel: 'Next',
          isChargeMode: true,
        ),
      ),
    );
  }

  void _onLightningMainnetReceive() {
    setState(() {
      selectedCoinId = 'BTC';
      _isCardFlipped = false;
      _flipController.reset();
      _lightningState = 'sync';
      _isLightningComplete = false;
    });

    Navigator.pushNamed(
      context,
      AppRoutes.receiveCrypto,
      arguments: {
        'coinId': 'BTC',
        'mode': 'onchain',
      },
    );
  }

  Widget _buildTransactionsSection() {
    final transactions = _getCurrentTransactions();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.only(bottom: 8),
              decoration: const BoxDecoration(
                border:
                    Border(bottom: BorderSide(color: Colors.white, width: 2)),
              ),
              child: const Text(
                'Transactions',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            const SizedBox(width: 24),
            const Spacer(),
            Tooltip(
              message:
                  _showAllInUsd ? 'Show native amounts' : 'Show all in USD',
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () => setState(() => _showAllInUsd = !_showAllInUsd),
                child: Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: kTile,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: _showAllInUsd ? Colors.green : kTileBorder,
                    ),
                  ),
                  child: Center(
                    child: Icon(
                      Icons.currency_exchange,
                      color: _showAllInUsd ? Colors.green : Colors.white,
                      size: 14,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        if (transactions.isNotEmpty) ...[
          ...transactions.map((tx) => _buildTransactionItem(tx)).toList(),
        ] else ...[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(40),
            child: Column(
              children: [
                const Text(
                  'No transactions yet',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 8),
                Text(
                  _currentWalletAddress == null
                      ? 'Loading wallet...'
                      : 'Your transactions will appear here',
                  style: const TextStyle(color: kMuted, fontSize: 14),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 100),
      ],
    );
  }

  Widget _buildTransactionItem(Map<String, dynamic> transaction) {
    final String txId = (transaction['id'] ?? '').toString();
    final String coinKey = (transaction['coin'] ?? '').toString();
    final bool showUsd = _showAllInUsd || _usdPerTx.contains(txId);

    final double amount =
        double.tryParse((transaction['amount'] ?? '0').toString()) ?? 0.0;

    final double priceUsd = _priceForCoinUsd(coinKey);
    final String amountLabel = showUsd
        ? _formatUsd(amount * priceUsd)
        : '${transaction['amount']} ${_getCoinSymbol(coinKey)}';

    return InkWell(
      onTap: () => _navigateToTransactionDetails(transaction),
      splashColor: kTile.withOpacity(0.3),
      highlightColor: kTile.withOpacity(0.1),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 6),
        child: Row(
          children: [
            // Type icon
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: kTile,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Icon(_getTransactionTypeIcon(transaction['type']),
                  color: Colors.white, size: 18),
            ),
            const SizedBox(width: 16),

            // Details
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Status + Type + Amount row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Left: status+type
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            transaction['status'],
                            style: TextStyle(
                              color: _getStatusColor(transaction['status']),
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _getTransactionTypeLabel(transaction['type']),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),

                      // Right: time + amount + per-tx $ button
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            _getTimeAgo(transaction['dateTime']),
                            style: const TextStyle(
                              color: kMuted,
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                amountLabel,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Tooltip(
                                message: _usdPerTx.contains(txId)
                                    ? 'Show native amount'
                                    : 'Show this in USD',
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(10),
                                  onTap: () {
                                    setState(() {
                                      if (_usdPerTx.contains(txId)) {
                                        _usdPerTx.remove(txId);
                                      } else {
                                        _usdPerTx.add(txId);
                                      }
                                    });
                                  },
                                  child: Container(
                                    width: 22,
                                    height: 22,
                                    decoration: BoxDecoration(
                                      color: kTile,
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(
                                        color: _usdPerTx.contains(txId)
                                            ? Colors.green
                                            : kTileBorder,
                                      ),
                                    ),
                                    child: Center(
                                      child: Icon(
                                        Icons.monetization_on_outlined,
                                        color: _usdPerTx.contains(txId)
                                            ? Colors.green
                                            : Colors.white,
                                        size: 14,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // From / To
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: _kvSmall('From:',
                            _shortenAddress(transaction['from'] ?? 'Unknown')),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _kvSmall('To:',
                            _shortenAddress(transaction['to'] ?? 'Unknown'),
                            end: true),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _kvSmall(String label, String value, {bool end = false}) {
    return Column(
      crossAxisAlignment:
          end ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: kMuted, fontSize: 12)),
        Text(value, style: const TextStyle(color: kMuted, fontSize: 12)),
      ],
    );
  }

  // Helper methods
  String _getTimeAgo(String dateTime) {
    try {
      final parts = dateTime.split(' ');
      if (parts.length >= 3) {
        final day = int.parse(parts[0]);
        final month = parts[1];
        final year = int.parse(parts[2]);

        const months = {
          'Jan': 1,
          'Feb': 2,
          'Mar': 3,
          'Apr': 4,
          'May': 5,
          'Jun': 6,
          'Jul': 7,
          'Aug': 8,
          'Sep': 9,
          'Oct': 10,
          'Nov': 11,
          'Dec': 12
        };

        final transactionDate = DateTime(year, months[month] ?? 1, day);
        final now = DateTime.now();
        final difference = now.difference(transactionDate).inDays;

        if (difference == 0) return 'Today';
        if (difference == 1) return 'Yesterday';
        if (difference < 30) return '$difference days ago';
        return '$day $month $year';
      }
    } catch (_) {}
    return '12 days ago';
  }

  String _getCoinSymbol(String coinKey) {
    final store = context.read<CoinStore>();
    final coin = store.getById(coinKey);
    if (coin != null) return coin.symbol;

    if (coinKey.startsWith('USDT')) return 'USDT';
    if (coinKey.startsWith('ETH')) return 'ETH';
    if (coinKey.startsWith('TRX')) return 'TRX';
    if (coinKey.startsWith('SOL')) return 'SOL';
    if (coinKey.startsWith('BNB')) return 'BNB';
    if (coinKey.startsWith('XMR')) return 'XMR';
    if (coinKey.startsWith('BTC')) return 'BTC';
    return coinKey;
  }

  IconData _getTransactionTypeIcon(String type) {
    switch (type) {
      case 'send':
        return Icons.send;
      case 'receive':
        return Icons.arrow_downward;
      case 'swap':
        return Icons.swap_horiz;
      default:
        return Icons.account_balance_wallet;
    }
  }

  String _getTransactionTypeLabel(String type) {
    switch (type) {
      case 'send':
        return 'Send';
      case 'receive':
        return 'Received';
      case 'swap':
        return 'Swap';
      default:
        return 'Transaction';
    }
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'confirmed':
        return Colors.green;
      case 'pending':
        return Colors.orange;
      case 'failed':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  String _shortenAddress(String address) {
    if (address.length <= 12) return address;
    return '${address.substring(0, 6)}...${address.substring(address.length - 6)}';
  }

  // Map a token's symbol/chain to a base coin id (used to resolve CoinStore icon/name)
  String _baseFromToken(String? symbol, String? chain) {
    final s = (symbol ?? '').toUpperCase();
    final c = (chain ?? '').toUpperCase();
    if (s == 'USDTERC20' || (s == 'USDT' && c == 'ETH')) return 'USDT';
    if (s == 'USDTTRC20' || (s == 'USDT' && (c == 'TRX' || c == 'TRON'))) {
      return 'USDT';
    }
    return s.isEmpty ? c : s;
  }

  /// Returns Coin objects (from CoinStore) that correspond to tokens
  /// in the ACTIVE wallet only. Falls back to CoinStore if no tokens found.
  Future<List<Coin>> _coinsForActiveWallet() async {
    final store = context.read<CoinStore>();
    // 1) figure out active wallet id
    String? activeId = context.read<WalletStore>().activeWalletId;
    if (activeId == null || activeId.isEmpty) {
      final wallets = await AuthService.fetchWallets();
      if (wallets.isNotEmpty) {
        activeId = wallets.first['_id']?.toString();
      }
    }

    // 2) get tokens for that wallet
    if (activeId != null && activeId.isNotEmpty) {
      try {
        final tokens =
            await AuthService.fetchTokensByWallet(walletId: activeId);

        // 3) map tokens -> base symbol -> Coin from store
        final bases = <String>{};
        for (final t in tokens) {
          bases.add(_baseFromToken(t.symbol, t.chain));
        }

        final coins = <Coin>[];
        for (final base in bases) {
          final c = store.getById(base);
          if (c != null) coins.add(c);
        }

        // if we found some, return just those
        if (coins.isNotEmpty) {
          coins.sort((a, b) => a.symbol.compareTo(b.symbol));
          return coins;
        }
      } catch (_) {
        // ignore and fall back
      }
    }

    // 4) fallback: whole store (previous behavior)
    final all = store.coins.values.toList()
      ..sort((a, b) => a.symbol.compareTo(b.symbol));
    return all;
  }

  void _showCoinSelector() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (context, scrollController) => FutureBuilder<List<Coin>>(
          future: _coinsForActiveWallet(),
          builder: (context, snap) {
            final coins = snap.data ?? const <Coin>[];

            return ClipRect(
              child: Container(
                decoration: const BoxDecoration(gradient: kSheetGrad),
                child: Column(
                  children: [
                    Container(
                      margin: const EdgeInsets.only(top: 10, bottom: 20),
                      width: 40,
                      height: 4,
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 20),
                      child: Row(
                        children: [
                          Text(
                            'Select Cryptocurrency',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    if (snap.connectionState == ConnectionState.waiting)
                      const Padding(
                        padding: EdgeInsets.all(24),
                        child: CircularProgressIndicator(color: Colors.white),
                      ),
                    if (snap.hasError)
                      Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          'Failed to load wallet coins.\n${snap.error}',
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.white70),
                        ),
                      ),
                    if (snap.connectionState == ConnectionState.done &&
                        coins.isEmpty)
                      const Padding(
                        padding: EdgeInsets.all(24),
                        child: Text(
                          'No coins for this wallet.',
                          style: TextStyle(color: Colors.white70),
                        ),
                      ),
                    if (coins.isNotEmpty)
                      Expanded(
                        child: ListView.builder(
                          controller: scrollController,
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          itemCount: coins.length,
                          itemBuilder: (context, index) {
                            final c = coins[index];
                            final isSelected = selectedCoinId == c.id;
                            final current = _getCurrentCoinData();

                            return Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              child: ListTile(
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                tileColor: isSelected
                                    ? kTile
                                    : const Color(0xFF1F2329),
                                leading: SizedBox(
                                  width: 40,
                                  height: 40,
                                  child: Center(
                                    child: (c.assetPath.isNotEmpty)
                                        ? Image.asset(c.assetPath,
                                            width: 22, height: 22)
                                        : const Icon(Icons.currency_bitcoin,
                                            color: Colors.white, size: 18),
                                  ),
                                ),
                                title: Text(
                                  c.symbol,
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w500),
                                ),
                                subtitle: Text(
                                  c.name,
                                  style: const TextStyle(
                                      color: kMuted, fontSize: 12),
                                ),
                                trailing: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(
                                      '${selectedCoinId == c.id ? current['balance'] : '0.00'} ${c.symbol}',
                                      style: const TextStyle(
                                          color: kMuted, fontSize: 12),
                                    ),
                                  ],
                                ),
                                onTap: () async {
                                  Navigator.pop(context);
                                  await _updateSelectedCoin(c.id);
                                },
                              ),
                            );
                          },
                        ),
                      ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

// Transaction Details Screen
class TransactionDetailsScreen extends StatelessWidget {
  final Map<String, dynamic> transaction;

  const TransactionDetailsScreen({Key? key, required this.transaction})
      : super(key: key);

  Color _getStatusColor() {
    switch (transaction['status'].toLowerCase()) {
      case 'confirmed':
        return Colors.green;
      case 'pending':
        return Colors.orange;
      case 'failed':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  Color _getCoinColor() {
    final coin = (transaction['coin'] ?? '') as String;
    if (coin.startsWith('BTC')) return Colors.orange;
    if (coin.startsWith('ETH')) return Colors.blue;
    if (coin.startsWith('XMR')) return Colors.orangeAccent;
    if (coin.startsWith('USDT')) return Colors.green;
    if (coin.startsWith('TRX')) return Colors.red;
    if (coin.startsWith('SOL')) return Colors.teal;
    if (coin.startsWith('BNB')) return Colors.amber;
    return const Color(0xFF2A2D3A);
  }

  String _getTransactionTitle() {
    switch (transaction['type']) {
      case 'send':
        return 'Send';
      case 'receive':
        return 'Received';
      case 'swap':
        return 'Swap';
      default:
        return 'Transaction';
    }
  }

  Widget _buildTransactionDetailItem(
      BuildContext context, String label, String value) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: const TextStyle(color: Color(0xFF6B7280), fontSize: 14)),
          const SizedBox(width: 16),
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Flexible(
                  child: Text(
                    value,
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                    textAlign: TextAlign.end,
                  ),
                ),
                if (value != '-' && value.length > 20) ...[
                  const SizedBox(width: 8),
                  const Icon(Icons.copy, color: Color(0xFF6B7280), size: 16),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final coinBadgeColor = _getCoinColor();

    return Scaffold(
      backgroundColor: const Color(0xFF0B0D1A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0B0D1A),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Transaction details',
          style: TextStyle(
              color: Colors.white, fontSize: 18, fontWeight: FontWeight.w500),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _getTransactionTitle(),
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 32,
                  fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              transaction['dateTime'] ?? '',
              style: const TextStyle(color: Color(0xFF6B7280), fontSize: 14),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: _getStatusColor(),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                transaction['status'] ?? '',
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                      color: coinBadgeColor,
                      borderRadius: BorderRadius.circular(12)),
                  child: const Icon(Icons.currency_exchange,
                      color: Colors.white, size: 14),
                ),
                const SizedBox(width: 12),
                Text(
                  '${transaction['amount']} ${transaction['coin']}',
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w600),
                ),
              ],
            ),
            const SizedBox(height: 32),
            const Text('Transaction details',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w500)),
            const SizedBox(height: 16),
            if (transaction['block'] != null)
              _buildTransactionDetailItem(
                  context, 'Block', transaction['block']?.toString() ?? '-'),
            _buildTransactionDetailItem(
                context, 'To', transaction['to'] ?? '-'),
            _buildTransactionDetailItem(
                context, 'From', transaction['from'] ?? '-'),
            _buildTransactionDetailItem(
                context, 'Hash', transaction['hash'] ?? '-'),
            if (transaction['feeDetails'] != null) ...[
              const SizedBox(height: 32),
              const Text('Fee Details',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w500)),
              const SizedBox(height: 16),
              ...((transaction['feeDetails'] as Map).entries)
                  .map<Widget>((entry) {
                return _buildTransactionDetailItem(
                    context, entry.key, entry.value?.toString() ?? '-');
              }).toList(),
            ],
            const SizedBox(height: 100),
          ],
        ),
      ),
    );
  }
}
