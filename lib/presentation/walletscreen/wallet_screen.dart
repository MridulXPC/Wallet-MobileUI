import 'package:cryptowallet/presentation/bottomnavbar.dart';
import 'package:cryptowallet/routes/app_routes.dart';
import 'package:flutter/material.dart';
import 'dart:async';
import 'package:provider/provider.dart';

// ✅ Pull coin metadata (name, symbol, icon) from Provider
import 'package:cryptowallet/coin_store.dart';

class WalletInfoScreen extends StatefulWidget {
  const WalletInfoScreen({Key? key}) : super(key: key);

  @override
  State<WalletInfoScreen> createState() => _WalletInfoScreenState();
}

class _WalletInfoScreenState extends State<WalletInfoScreen>
    with TickerProviderStateMixin {
  /// Selected coin by **coinId** (must match CoinStore ids, e.g. BTC, BTC-LN, USDT-ETH, USDT-TRX, BNB-BNB, etc.)
  String selectedCoinId = 'BTC';

  // Animation controllers
  late AnimationController _flipController;
  late Animation<double> _flipAnimation;

  // State variables
  bool _isCardFlipped = false;
  String _lightningState = 'sync'; // sync, syncing, synced
  Timer? _lightningTimer;
  bool _isLightningComplete = false;

  // --------- Dummy wallet details (price/balance/address) per coinId ----------
  // Feel free to swap with real values from your APIs later.
  Map<String, Map<String, String>> get _dummyDetails => {
        // BTC family
        'BTC': {
          'price': '43,825.67',
          'balance': '0.00',
          'usdBalance': '0.00',
          'address': 'bc1qxy2kgdygjrsqtzq2n0yrf2493p83kkfjhx0wlh',
        },
        'BTC-LN': {
          'price': '43,825.67',
          'balance': '0.00',
          'usdBalance': '0.00',
          'address': 'lnbc1...xyz',
        },

        // BNB family
        'BNB': {
          'price': '575.42',
          'balance': '0.00',
          'usdBalance': '0.00',
          'address': 'bnb1qxy2kgdygjrsqtzq2n0yrf2493p83kksm3kz3a',
        },
        'BNB-BNB': {
          'price': '575.42',
          'balance': '0.00',
          'usdBalance': '0.00',
          'address': 'bnb1abc9d8f7k6m5n4p3q2r1s0t9u8v7w6x5y4z3',
        },

        // ETH family
        'ETH': {
          'price': '2,641.25',
          'balance': '0.00',
          'usdBalance': '0.00',
          'address': '0x742d35Cc6Dd7D8b4B8B4f42C8B4B2f4D8E8F8G8H',
        },
        'ETH-ETH': {
          'price': '2,641.25',
          'balance': '0.00',
          'usdBalance': '0.00',
          'address': '0x1234567890abcdef1234567890abcdef12345678',
        },

        // SOL family
        'SOL': {
          'price': '148.12',
          'balance': '0.00',
          'usdBalance': '0.00',
          'address': '4Nd1mW2...SolanaAddress...',
        },
        'SOL-SOL': {
          'price': '148.12',
          'balance': '0.00',
          'usdBalance': '0.00',
          'address': '7Gh3pQk...AnotherSolAddr...',
        },

        // TRX family
        'TRX': {
          'price': '0.13',
          'balance': '0.00',
          'usdBalance': '0.00',
          'address': 'TAJ6r4...t372GF',
        },
        'TRX-TRX': {
          'price': '0.13',
          'balance': '0.00',
          'usdBalance': '0.00',
          'address': 'TBmLQS...LFGABn',
        },

        // USDT family
        'USDT': {
          'price': '1.00',
          'balance': '0.00',
          'usdBalance': '0.00',
          'address': 'TetherGeneric...',
        },
        'USDT-ETH': {
          'price': '1.00',
          'balance': '0.00',
          'usdBalance': '0.00',
          'address': '0xUSDTOnETH...',
        },
        'USDT-TRX': {
          'price': '1.00',
          'balance': '0.00',
          'usdBalance': '0.00',
          'address': 'TUSDTOnTRX...',
        },

        // XMR family
        'XMR': {
          'price': '165.50',
          'balance': '0.00',
          'usdBalance': '0.00',
          'address': '44AFFq5kSiGBoZ...MoneroAddr...',
        },
        'XMR-XMR': {
          'price': '165.50',
          'balance': '0.00',
          'usdBalance': '0.00',
          'address': '488fyrk...AnotherXMR...',
        },
      };

  // --------- Dummy transactions (keys must match selectedCoinId) -------------
  Map<String, List<Map<String, dynamic>>> get dummyTransactions => {
        'BTC': [
          {
            'id': 'btc_send_1',
            'type': 'send',
            'status': 'Confirmed',
            'amount': '0.004256',
            'coin': 'BTC',
            'dateTime': '20 Aug 2025 10:38:50',
            'from': 'bc1q07...eyla0f',
            'to': 'bc1qkv...sft0rz',
            'hash':
                'e275b987f6c5b8e715e01461d8fae15dc4f5ae9e9ec178a65bc2173cabfded5b',
            'block': 910917,
            'feeDetails': {'Total Fee': '0.00000378 BTC'},
          },
          {
            'id': 'btc_receive_1',
            'type': 'receive',
            'status': 'Confirmed',
            'amount': '0.0046011',
            'coin': 'BTC',
            'dateTime': '18 Aug 2025 14:22:15',
            'from': 'bc1q89...xyz123',
            'to': 'bc1q07...eyla0f',
            'hash':
                'a1b2c3d4e5f6789012345678901234567890abcdef1234567890abcdef123456',
            'block': 910815,
            'feeDetails': {'Total Fee': '0.00000245 BTC'},
          },
          {
            'id': 'btc_swap_1',
            'type': 'swap',
            'status': 'Confirmed',
            'amount': '0.002',
            'coin': 'BTC',
            'dateTime': '17 Aug 2025 09:15:30',
            'hash':
                'swap123456789abcdef123456789abcdef123456789abcdef123456789abcdef',
            'swapDetails': {
              'fromCoin': 'ETH',
              'fromAmount': '1.25',
              'toCoin': 'BTC',
              'toAmount': '0.002',
              'rate': '0.0016',
              'swapId': 'SWAP_BTC_001'
            },
            'feeDetails': {'Swap Fee': '0.5%', 'Network Fee': '0.00001 BTC'},
          },
        ],
        'ETH': [
          {
            'id': 'eth_send_1',
            'type': 'send',
            'status': 'Confirmed',
            'amount': '2.5',
            'coin': 'ETH',
            'dateTime': '21 Aug 2025 16:45:12',
            'from': '0x742d35Cc6Dd7D8b4B8B4f42C8B4B2f4D8E8F8G8H',
            'to': '0x1234567890abcdef1234567890abcdef12345678',
            'hash':
                '0xeth123456789abcdef123456789abcdef123456789abcdef123456789abcdef',
            'block': 18245673,
            'feeDetails': {
              'Gas Used': '21,000',
              'Gas Price': '25 Gwei',
              'Total Fee': '0.000525 ETH',
            },
          },
          {
            'id': 'eth_receive_1',
            'type': 'receive',
            'status': 'Confirmed',
            'amount': '1.8',
            'coin': 'ETH',
            'dateTime': '19 Aug 2025 11:30:45',
            'from': '0x9876543210fedcba9876543210fedcba98765432',
            'to': '0x742d35Cc6Dd7D8b4B8B4f42C8B4B2f4D8E8F8G8H',
            'hash':
                '0xeth987654321fedcba987654321fedcba987654321fedcba987654321fedcba',
            'block': 18244890,
            'feeDetails': {'Total Fee': '0.00031 ETH'},
          },
          {
            'id': 'eth_swap_1',
            'type': 'swap',
            'status': 'Confirmed',
            'amount': '3.2',
            'coin': 'ETH',
            'dateTime': '16 Aug 2025 08:22:18',
            'hash':
                '0xswapeth123456789abcdef123456789abcdef123456789abcdef123456789ab',
            'swapDetails': {
              'fromCoin': 'USDT',
              'fromAmount': '8500',
              'toCoin': 'ETH',
              'toAmount': '3.2',
              'rate': '2656.25',
              'swapId': 'SWAP_ETH_001'
            },
            'feeDetails': {'Swap Fee': '0.3%', 'Network Fee': '0.0015 ETH'},
          },
        ],
        'USDT': [
          {
            'id': 'usdt_send_1',
            'type': 'send',
            'status': 'Confirmed',
            'amount': '50.332725',
            'coin': 'USDT',
            'dateTime': '09 Aug 2025 06:01:48',
            'from': 'TAJ6r4...t372GF',
            'to': 'TBmLQS...LFGABn',
            'hash':
                '72c2e0618ba1c320f6da0e8dfaba7dc6e7f54a531609889e01af6edb800d55429',
            'block': 74680192,
            'feeDetails': {'Bandwidth Fee': '0.0', 'Total Fee': '13.84485 TRX'},
          },
          {
            'id': 'usdt_send_2',
            'type': 'send',
            'status': 'Confirmed',
            'amount': '52.842548',
            'coin': 'USDT',
            'dateTime': '09 Aug 2025 05:40:06',
            'from': 'TH2B65...TbTDJv',
            'to': 'TLntW9...828ird',
            'hash':
                'd414a6af812068499d3348d9c8cd2d54064d25538b14735c0b787443727a0ff8',
            'block': 74679758,
            'feeDetails': {'Bandwidth Fee': '699.0', 'Total Fee': '0.00 TRX'},
          },
          {
            'id': 'usdt_swap_1',
            'type': 'swap',
            'status': 'Confirmed',
            'amount': '1000',
            'coin': 'USDT',
            'dateTime': '15 Aug 2025 09:25:33',
            'hash':
                'SWAPUSDT123456789ABCDEF123456789ABCDEF123456789ABCDEF123456789A',
            'swapDetails': {
              'fromCoin': 'BTC',
              'fromAmount': '0.0228',
              'toCoin': 'USDT',
              'toAmount': '1000',
              'rate': '43859.65',
              'swapId': 'SWAP_USDT_001'
            },
            'feeDetails': {'Swap Fee': '0.1%', 'Network Fee': '15 TRX'},
          },
        ],
        'BTC-LN': [
          {
            'id': 'ln_send_1',
            'type': 'send',
            'status': 'Confirmed',
            'amount': '0.00116463',
            'coin': 'BTC-LN',
            'dateTime': '09 Aug 2025 05:25:10',
            'from': '033834...485b7d',
            'to': 'lnbc1164...p8wjgwt',
            'hash':
                'ea3cd3027c1445ebc88e30f2da55d1fafc4706f08feb97864c6a25a5680b0098',
            'lightningDetails': {
              'Swap ID': 'TCkQ1ZmWzeqy',
              'Description': '-',
              'Destination public key': '032842...2571de',
              'Payment hash':
                  '0c0d12b226cd40dadf1262fdfe11e940a7074fdac6250697eca7e5442b2f1dca',
              'Refund amount': '0',
            },
          },
          {
            'id': 'ln_send_2',
            'type': 'send',
            'status': 'Confirmed',
            'amount': '0.0005',
            'coin': 'BTC-LN',
            'dateTime': '12 Aug 2025 14:18:25',
            'from': '033834...485b7d',
            'to': 'lnbc500...xyz789',
            'hash':
                'ln987654321abcdef987654321abcdef987654321abcdef987654321abcdef12',
            'lightningDetails': {
              'Swap ID': 'LN_SWAP_002',
              'Description': 'Coffee payment',
              'Destination public key': '035512...8841ac',
              'Payment hash':
                  '1a2b3c4d5e6f789012345678901234567890abcdef1234567890abcdef123456',
              'Refund amount': '0',
            },
          },
          {
            'id': 'ln_receive_1',
            'type': 'receive',
            'status': 'Confirmed',
            'amount': '0.00046011',
            'coin': 'BTC-LN',
            'dateTime': '11 Aug 2025 18:33:42',
            'from': 'lnbc4601...def456',
            'to': '033834...485b7d',
            'hash':
                'lnreceive123456789abcdef123456789abcdef123456789abcdef123456789ab',
            'lightningDetails': {
              'Swap ID': 'LN_RCV_001',
              'Description': 'Payment received',
              'Source public key': '028847...9923fe',
              'Payment hash':
                  '9f8e7d6c5b4a392817263544536271890abcdef1234567890abcdef123456789',
              'Refund amount': '0',
            },
          },
        ],

        // Minimal examples for remaining families
        'TRX': [
          {
            'id': 'trx_receive_1',
            'type': 'receive',
            'status': 'Confirmed',
            'amount': '120',
            'coin': 'TRX',
            'dateTime': '18 Aug 2025 10:12:00',
            'from': 'TDv...abc',
            'to': 'TAJ6...xyz',
            'hash': 'trxHash1',
            'block': 74670001,
            'feeDetails': {'Total Fee': '0 TRX'},
          },
        ],
        'SOL': [
          {
            'id': 'sol_send_1',
            'type': 'send',
            'status': 'Confirmed',
            'amount': '1.25',
            'coin': 'SOL',
            'dateTime': '19 Aug 2025 09:01:00',
            'from': '4Nd1mW2...',
            'to': '7Gh3pQk...',
            'hash': 'solHash1',
            'feeDetails': {'Total Fee': '0.000005 SOL'},
          },
        ],
        'BNB': [
          {
            'id': 'bnb_send_1',
            'type': 'send',
            'status': 'Confirmed',
            'amount': '0.5',
            'coin': 'BNB',
            'dateTime': '20 Aug 2025 12:20:00',
            'from': 'bnb1qxy2...',
            'to': 'bnb1abc9...',
            'hash': 'bnbHash1',
            'feeDetails': {'Total Fee': '0.000375 BNB'},
          },
        ],
        'XMR': [
          {
            'id': 'xmr_send_1',
            'type': 'send',
            'status': 'Confirmed',
            'amount': '0.75',
            'coin': 'XMR',
            'dateTime': '21 Aug 2025 15:45:00',
            'from': '44AFFq...',
            'to': '488fyrk...',
            'hash': 'xmrHash1',
            'feeDetails': {'Total Fee': '0.0002 XMR'},
          },
        ],
      };

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
  }

  @override
  void dispose() {
    _flipController.dispose();
    _lightningTimer?.cancel();
    super.dispose();
  }

  // Convenience getters from Provider
  bool get isLightningSelected => selectedCoinId == 'BTC-LN';
  Coin? get _selectedCoin => context.read<CoinStore>().getById(selectedCoinId);

  Map<String, String> _currentDetails() {
    return _dummyDetails[selectedCoinId] ??
        {
          'price': '0.00',
          'balance': '0.00',
          'usdBalance': '0.00',
          'address': '—',
        };
  }

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

  void _toggleCardFlip() {
    if (_isCardFlipped) {
      _flipController.reverse();
    } else {
      _flipController.forward();
    }
    setState(() => _isCardFlipped = !_isCardFlipped);
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
    // Listen so UI updates when coin store changes (e.g., icons)
    final store = context.watch<CoinStore>();
    final coin = store.getById(selectedCoinId);
    final details = _currentDetails();

    return Scaffold(
      backgroundColor: const Color(0xFF0B0D1A),
      bottomNavigationBar: BottomNavBar(
        selectedIndex: 1, // Balance tab selected
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
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Column(
                  children: [
                    const SizedBox(height: 16),
                    _buildBalanceCard(coin, details),
                    const SizedBox(height: 16),
                    _buildAvailableReservedRow(details),
                    const SizedBox(height: 24),
                    _buildActionButtons(),
                    const SizedBox(height: 24),
                    _buildTransactionsSection(),
                  ],
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
    final name = coin?.name ?? selectedCoinId;

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
                      color: const Color(0xFF2A2D3A),
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
                            color: Color(0xFF6B7280),
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
                color: const Color(0xFF2A2D3A),
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
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF2A2D3A),
            Color.fromARGB(255, 0, 0, 0),
            Color.fromARGB(255, 0, 12, 56),
          ],
          stops: [0.0, 0.5, 1.0],
        ),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: const Color(0xFF3A3D4A), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
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
              color: Color(0xFF6B7280),
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
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF2D5A2D),
              Color.fromARGB(255, 0, 20, 0),
              Color.fromARGB(255, 0, 56, 12),
            ],
            stops: [0.0, 0.5, 1.0],
          ),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: const Color(0xFF4A6A4A), width: 1),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
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
          _miniIconBox(
              Icons.copy, const Color(0xFF3A3D4A), const Color(0xFF6B7280)),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: _toggleCardFlip,
            child:
                _miniIconBox(Icons.eco, const Color(0xFF3A3D4A), Colors.green),
          ),
        ],
      );
    } else if (isLightningSelected) {
      return _getLightningStateWidget();
    } else {
      return _miniIconBox(
          Icons.copy, const Color(0xFF3A3D4A), const Color(0xFF6B7280));
    }
  }

  Widget _miniIconBox(IconData icon, Color bg, Color fg) {
    return Container(
      padding: const EdgeInsets.all(6),
      decoration:
          BoxDecoration(color: bg, borderRadius: BorderRadius.circular(6)),
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

  Widget _buildAvailableReservedRow(Map<String, String> details) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(
        children: [
          Expanded(
            child: _kv('Available', details['balance'] ?? '0'),
          ),
          Container(width: 1, height: 36, color: const Color(0xFF3A3D4A)),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(left: 16),
              child: _kv('Reserved', '0'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _kv(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(color: Color(0xFF6B7280), fontSize: 13)),
        const SizedBox(height: 4),
        Row(
          children: [
            Text(value,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w500)),
            const SizedBox(width: 8),
            const Icon(Icons.info_outline, color: Color(0xFF6B7280), size: 16),
          ],
        ),
      ],
    );
  }

  Widget _buildActionButtons() {
    if (isLightningSelected) {
      // Only Send, Receive, Scan for Lightning
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildActionButton('Send', Icons.send, () {}),
            _buildActionButton('Receive', Icons.arrow_downward, () {}),
            _buildActionButton('Scan', Icons.qr_code_scanner, () {}),
          ],
        ),
      );
    } else {
      // Full set
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _buildActionButton('Send', Icons.send, () {}),
            _buildActionButton('Swap', Icons.swap_horiz, () {}),
            _buildActionButton('Receive', Icons.arrow_downward, () {}),
            _buildActionButton('Charge', Icons.credit_card, () {}),
            _buildActionButton('Scan', Icons.qr_code_scanner, () {}),
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
                color: const Color(0xFF2A2D3A),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: const Color(0xFF3A3D4A)),
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

  Widget _buildTransactionsSection() {
    final transactions = dummyTransactions[selectedCoinId] ?? [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section header with tabs
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
                    fontWeight: FontWeight.w500),
              ),
            ),
            const SizedBox(width: 24),
            Container(
              padding: const EdgeInsets.only(bottom: 8),
              child: const Text(
                'Refundables',
                style: TextStyle(
                    color: Color(0xFF6B7280),
                    fontSize: 16,
                    fontWeight: FontWeight.w500),
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
            child: const Column(
              children: [
                Text(
                  'No transactions yet',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w500),
                ),
                SizedBox(height: 8),
                Text(
                  'Your transactions will appear here',
                  style: TextStyle(color: Color(0xFF6B7280), fontSize: 14),
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
    return InkWell(
      onTap: () => _navigateToTransactionDetails(transaction),
      splashColor: const Color(0xFF2A2D3A).withOpacity(0.3),
      highlightColor: const Color(0xFF2A2D3A).withOpacity(0.1),
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
                color: const Color(0xFF2A2D3A),
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
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            _getTimeAgo(transaction['dateTime']),
                            style: const TextStyle(
                              color: Color(0xFF6B7280),
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${transaction['amount']} ${_getCoinSymbol(transaction['coin'])}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
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
        Text(label,
            style: const TextStyle(color: Color(0xFF6B7280), fontSize: 12)),
        Text(value,
            style: const TextStyle(color: Color(0xFF6B7280), fontSize: 12)),
      ],
    );
  }

  // ------------------- Helpers -------------------

  String _getTimeAgo(String dateTime) {
    try {
      final parts = dateTime.split(' ');
      if (parts.length >= 3) {
        final day = int.parse(parts[0]);
        final month = parts[1];
        final year = int.parse(parts[2]);

        final months = {
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
    // coinKey could be 'BTC', 'BTC-LN', 'USDT-ETH', etc.
    // Prefer mapping by id => symbol from provider where possible:
    final store = context.read<CoinStore>();
    final coin = store.getById(coinKey);
    if (coin != null) return coin.symbol;

    // Fallback from known families:
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

  void _showCoinSelector() {
    final store = context.read<CoinStore>();
    final coins = store.coins.values.toList(); // all 15

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (context, scrollController) => Container(
          decoration: const BoxDecoration(
            color: Color(0xFF1A1D29),
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              // Handle bar
              Container(
                margin: const EdgeInsets.only(top: 10, bottom: 20),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFF3A3D4A),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),

              // Header
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    Text(
                      'Select Cryptocurrency',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // Coin list (from provider)
              Expanded(
                child: ListView.builder(
                  controller: scrollController,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  itemCount: coins.length,
                  itemBuilder: (context, index) {
                    final c = coins[index];
                    final details = _dummyDetails[c.id] ??
                        {
                          'price': '0.00',
                          'balance': '0.00',
                          'usdBalance': '0.00'
                        };

                    final isSelected = selectedCoinId == c.id;

                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: ListTile(
                        contentPadding: const EdgeInsets.all(16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        tileColor: isSelected
                            ? const Color(0xFF2A2D3A)
                            : const Color(0xFF1F2329),
                        leading: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: const Color(0xFF3A3D4A),
                            borderRadius: BorderRadius.circular(6),
                          ),
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
                              color: Colors.white, fontWeight: FontWeight.w500),
                        ),
                        subtitle: Text(
                          c.name,
                          style: const TextStyle(
                              color: Color(0xFF6B7280), fontSize: 12),
                        ),
                        trailing: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              '${details['balance']} ${c.symbol}',
                              style: const TextStyle(
                                  color: Color(0xFF6B7280), fontSize: 12),
                            ),
                          ],
                        ),
                        onTap: () {
                          setState(() {
                            selectedCoinId = c.id;
                            _isCardFlipped = false;
                            _flipController.reset();

                            // Reset Lightning state appropriately
                            _lightningState = 'sync';
                            _isLightningComplete = false;
                          });
                          _startLightningTimer();
                          Navigator.pop(context);
                        },
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------- Transaction Details Screen (unchanged UI; coin icon color tuned) ------------
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

  Widget _buildSwapDetails(BuildContext context) {
    final swapDetails = transaction['swapDetails'] as Map<String, dynamic>;
    return Column(
      children: [
        _buildTransactionDetailItem(context, 'From',
            '${swapDetails['fromAmount']} ${swapDetails['fromCoin']}'),
        _buildTransactionDetailItem(context, 'To',
            '${swapDetails['toAmount']} ${swapDetails['toCoin']}'),
        _buildTransactionDetailItem(context, 'Exchange Rate',
            '1 ${swapDetails['fromCoin']} = ${swapDetails['rate']} ${swapDetails['toCoin']}'),
        _buildTransactionDetailItem(context, 'Swap ID', swapDetails['swapId']),
      ],
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
            // Title
            Text(
              _getTransactionTitle(),
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 32,
                  fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),

            // Date
            Text(
              transaction['dateTime'] ?? '',
              style: const TextStyle(color: Color(0xFF6B7280), fontSize: 14),
            ),
            const SizedBox(height: 16),

            // Status
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

            // Amount + Coin badge
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
                if ((transaction['coin'] ?? '')
                    .toString()
                    .startsWith('BTC-LN')) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                        color: Colors.purple,
                        borderRadius: BorderRadius.circular(10)),
                    child: const Text('Lightning',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold)),
                  ),
                ],
              ],
            ),

            const SizedBox(height: 32),

            const Text('Transaction details',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w500)),
            const SizedBox(height: 16),

            if ((transaction['type'] ?? '') == 'swap') ...[
              _buildSwapDetails(context),
            ] else ...[
              if (transaction['block'] != null)
                _buildTransactionDetailItem(
                    context, 'Block', transaction['block']?.toString() ?? '-'),
              _buildTransactionDetailItem(
                  context, 'To', transaction['to'] ?? '-'),
              _buildTransactionDetailItem(
                  context, 'From', transaction['from'] ?? '-'),
              _buildTransactionDetailItem(
                  context, 'Hash', transaction['hash'] ?? '-'),
            ],

            if (transaction['coin'].toString().startsWith('BTC-LN') &&
                transaction['lightningDetails'] != null) ...[
              const SizedBox(height: 32),
              Row(
                children: const [
                  Icon(Icons.flash_on, color: Colors.purple, size: 16),
                  SizedBox(width: 8),
                  Text('Lightning details',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w500)),
                ],
              ),
              const SizedBox(height: 16),
              ...((transaction['lightningDetails'] as Map).entries)
                  .map<Widget>((entry) {
                return _buildTransactionDetailItem(
                    context, entry.key, entry.value?.toString() ?? '-');
              }).toList(),
            ],

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
