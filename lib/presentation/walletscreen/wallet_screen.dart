import 'package:cryptowallet/presentation/bottomnavbar.dart';
import 'package:cryptowallet/routes/app_routes.dart';
import 'package:flutter/material.dart';
import 'dart:async';

class WalletInfoScreen extends StatefulWidget {
  const WalletInfoScreen({Key? key}) : super(key: key);

  @override
  State<WalletInfoScreen> createState() => _WalletInfoScreenState();
}

class _WalletInfoScreenState extends State<WalletInfoScreen>
    with TickerProviderStateMixin {
  String selectedCoin = 'BTC';
  String selectedCoinName = 'Bitcoin';
  String selectedCoinPrice = '43,825.67';
  String selectedCoinBalance = '0.00';
  String selectedCoinUsdBalance = '0.00';
  String selectedCoinAddress = 'bc1qxy2kgdygjrsqtzq2n0yrf2493p83kkfjhx0wlh';

  // Animation controllers
  late AnimationController _flipController;
  late Animation<double> _flipAnimation;

  // State variables
  bool _isCardFlipped = false;
  String _lightningState = 'sync'; // sync, syncing, synced
  Timer? _lightningTimer;
  bool _isLightningComplete = false;

  final Map<String, Map<String, String>> coinData = {
    'BTC': {
      'name': 'Bitcoin',
      'price': '43,825.67',
      'balance': '0.00',
      'usdBalance': '0.00',
      'address': 'bc1qxy2kgdygjrsqtzq2n0yrf2493p83kkfjhx0wlh',
      'icon': '₿'
    },
    'XRP': {
      'name': 'XRP',
      'price': '2.93',
      'balance': '0.00',
      'usdBalance': '0.00',
      'address': 'rKXxQ...h21e3VF',
      'icon': 'X'
    },
    'ETH': {
      'name': 'Ethereum',
      'price': '2,641.25',
      'balance': '0.00',
      'usdBalance': '0.00',
      'address': '0x742d35Cc6Dd7D8b4B8B4f42C8B4B2f4D8E8F8G8H',
      'icon': 'Ξ'
    },
    'ADA': {
      'name': 'Cardano',
      'price': '1.05',
      'balance': '0.00',
      'usdBalance': '0.00',
      'address': 'addr1qxy2kgdygjrsqtzq2n0yrf2493p83kkfjhx0wlh',
      'icon': '₳'
    },
    'USDT': {
      'name': 'Tether USD',
      'price': '1.00',
      'balance': '0.00',
      'usdBalance': '0.00',
      'address': '0x742d35Cc6Dd7D8b4B8B4f42C8B4B2f4D8E8F8G8H',
      'icon': '₮'
    },
    'BTC LIGHTNING': {
      'name': 'Bitcoin Lightning',
      'price': '43,825.67',
      'balance': '0.00',
      'usdBalance': '0.00',
      'address': 'lnbc1...xyz',
      'icon': '⚡'
    },
  };

  // Dummy transactions for all coins
  Map<String, List<Map<String, dynamic>>> get dummyTransactions => {
        'BTC': [
          {
            'id': 'btc_send_1',
            'type': 'send',
            'status': 'Confirmed',
            'amount': '0.004256',
            'coin': 'BTC',
            'coinIcon': '₿',
            'dateTime': '20 Aug 2025 10:38:50',
            'from': 'bc1q07...eyla0f',
            'to': 'bc1qkv...sft0rz',
            'hash':
                'e275b987f6c5b8e715e01461d8fae15dc4f5ae9e9ec178a65bc2173cabfded5b',
            'block': 910917,
            'feeDetails': {
              'Total Fee': '0.00000378 BTC',
            },
          },
          {
            'id': 'btc_receive_1',
            'type': 'receive',
            'status': 'Confirmed',
            'amount': '0.0046011',
            'coin': 'BTC',
            'coinIcon': '₿',
            'dateTime': '18 Aug 2025 14:22:15',
            'from': 'bc1q89...xyz123',
            'to': 'bc1q07...eyla0f',
            'hash':
                'a1b2c3d4e5f6789012345678901234567890abcdef1234567890abcdef123456',
            'block': 910815,
            'feeDetails': {
              'Total Fee': '0.00000245 BTC',
            },
          },
          {
            'id': 'btc_swap_1',
            'type': 'swap',
            'status': 'Confirmed',
            'amount': '0.002',
            'coin': 'BTC',
            'coinIcon': '₿',
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
            'feeDetails': {
              'Swap Fee': '0.5%',
              'Network Fee': '0.00001 BTC',
            },
          },
        ],
        'ETH': [
          {
            'id': 'eth_send_1',
            'type': 'send',
            'status': 'Confirmed',
            'amount': '2.5',
            'coin': 'ETH',
            'coinIcon': 'Ξ',
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
            'coinIcon': 'Ξ',
            'dateTime': '19 Aug 2025 11:30:45',
            'from': '0x9876543210fedcba9876543210fedcba98765432',
            'to': '0x742d35Cc6Dd7D8b4B8B4f42C8B4B2f4D8E8F8G8H',
            'hash':
                '0xeth987654321fedcba987654321fedcba987654321fedcba987654321fedcba',
            'block': 18244890,
            'feeDetails': {
              'Total Fee': '0.00031 ETH',
            },
          },
          {
            'id': 'eth_swap_1',
            'type': 'swap',
            'status': 'Confirmed',
            'amount': '3.2',
            'coin': 'ETH',
            'coinIcon': 'Ξ',
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
            'feeDetails': {
              'Swap Fee': '0.3%',
              'Network Fee': '0.0015 ETH',
            },
          },
        ],
        'XRP': [
          {
            'id': 'xrp_send_1',
            'type': 'send',
            'status': 'Confirmed',
            'amount': '1000',
            'coin': 'XRP',
            'coinIcon': 'X',
            'dateTime': '20 Aug 2025 19:12:33',
            'from': 'rKXxQ...h21e3VF',
            'to': 'rNb8pdkgWQ7NREG...3KgKGg6fX2',
            'hash':
                'XRP123456789ABCDEF123456789ABCDEF123456789ABCDEF123456789ABCDEF',
            'feeDetails': {
              'Total Fee': '0.00012 XRP',
            },
          },
          {
            'id': 'xrp_receive_1',
            'type': 'receive',
            'status': 'Confirmed',
            'amount': '750',
            'coin': 'XRP',
            'coinIcon': 'X',
            'dateTime': '18 Aug 2025 13:45:22',
            'from': 'rPT1Sjq2YGrBMTttX4GZHjKu9dyfzbpAYe',
            'to': 'rKXxQ...h21e3VF',
            'hash':
                'XRP987654321FEDCBA987654321FEDCBA987654321FEDCBA987654321FEDCBA',
            'feeDetails': {
              'Total Fee': '0.00012 XRP',
            },
          },
          {
            'id': 'xrp_swap_1',
            'type': 'swap',
            'status': 'Confirmed',
            'amount': '500',
            'coin': 'XRP',
            'coinIcon': 'X',
            'dateTime': '15 Aug 2025 10:18:55',
            'hash':
                'SWAPXRP123456789ABCDEF123456789ABCDEF123456789ABCDEF123456789AB',
            'swapDetails': {
              'fromCoin': 'BTC',
              'fromAmount': '0.03',
              'toCoin': 'XRP',
              'toAmount': '500',
              'rate': '16666.67',
              'swapId': 'SWAP_XRP_001'
            },
            'feeDetails': {
              'Swap Fee': '0.25%',
              'Network Fee': '0.00012 XRP',
            },
          },
        ],
        'ADA': [
          {
            'id': 'ada_send_1',
            'type': 'send',
            'status': 'Confirmed',
            'amount': '2500',
            'coin': 'ADA',
            'coinIcon': '₳',
            'dateTime': '21 Aug 2025 12:35:18',
            'from': 'addr1qxy2kgdygjrsqtzq2n0yrf2493p83kkfjhx0wlh',
            'to': 'addr1q9f8z3v7y2m8k5j3h6g4d1s9a7f4e2w8q5r6t7y8u9i0o2p3l4k5j6',
            'hash':
                'ADA123456789ABCDEF123456789ABCDEF123456789ABCDEF123456789ABCDEF',
            'feeDetails': {
              'Total Fee': '0.17 ADA',
            },
          },
          {
            'id': 'ada_receive_1',
            'type': 'receive',
            'status': 'Confirmed',
            'amount': '1800',
            'coin': 'ADA',
            'coinIcon': '₳',
            'dateTime': '19 Aug 2025 15:22:41',
            'from': 'addr1q8w7e6r5t4y3u2i1o0p9l8k7j6h5g4f3d2s1a9z8x7c6v5b4n3m2',
            'to': 'addr1qxy2kgdygjrsqtzq2n0yrf2493p83kkfjhx0wlh',
            'hash':
                'ADA987654321FEDCBA987654321FEDCBA987654321FEDCBA987654321FEDCBA',
            'feeDetails': {
              'Total Fee': '0.17 ADA',
            },
          },
          {
            'id': 'ada_swap_1',
            'type': 'swap',
            'status': 'Confirmed',
            'amount': '3000',
            'coin': 'ADA',
            'coinIcon': '₳',
            'dateTime': '17 Aug 2025 14:08:27',
            'hash':
                'SWAPADA123456789ABCDEF123456789ABCDEF123456789ABCDEF123456789AB',
            'swapDetails': {
              'fromCoin': 'USDT',
              'fromAmount': '3150',
              'toCoin': 'ADA',
              'toAmount': '3000',
              'rate': '0.95',
              'swapId': 'SWAP_ADA_001'
            },
            'feeDetails': {
              'Swap Fee': '0.3%',
              'Network Fee': '0.17 ADA',
            },
          },
        ],
        'USDT': [
          {
            'id': 'usdt_send_1',
            'type': 'send',
            'status': 'Confirmed',
            'amount': '50.332725',
            'coin': 'USDT',
            'coinIcon': '₮',
            'dateTime': '09 Aug 2025 06:01:48',
            'from': 'TAJ6r4...t372GF',
            'to': 'TBmLQS...LFGABn',
            'hash':
                '72c2e0618ba1c320f6da0e8dfaba7dc6e7f54a531609889e01af6edb800d55429',
            'block': 74680192,
            'feeDetails': {
              'Bandwidth Fee': '0.0',
              'Total Fee': '13.84485 TRX',
            },
          },
          {
            'id': 'usdt_send_2',
            'type': 'send',
            'status': 'Confirmed',
            'amount': '52.842548',
            'coin': 'USDT',
            'coinIcon': '₮',
            'dateTime': '09 Aug 2025 05:40:06',
            'from': 'TH2B65...TbTDJv',
            'to': 'TLntW9...828ird',
            'hash':
                'd414a6af812068499d3348d9c8cd2d54064d25538b14735c0b787443727a0ff8',
            'block': 74679758,
            'feeDetails': {
              'Bandwidth Fee': '699.0',
              'Total Fee': '0.00 TRX',
            },
          },
          {
            'id': 'usdt_swap_1',
            'type': 'swap',
            'status': 'Confirmed',
            'amount': '1000',
            'coin': 'USDT',
            'coinIcon': '₮',
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
            'feeDetails': {
              'Swap Fee': '0.1%',
              'Network Fee': '15 TRX',
            },
          },
        ],
        'BTC LIGHTNING': [
          {
            'id': 'ln_send_1',
            'type': 'send',
            'status': 'Confirmed',
            'amount': '0.00116463',
            'coin': 'BTC LIGHTNING',
            'coinIcon': '⚡',
            'dateTime': '09 Aug 2025 05:25:10',
            'from': '033834...485b7d',
            'to': 'lnbc1164...p8wjgwt',
            'hash':
                'ea3cd3027c1445ebc88e30f2da55d1fafc4706f08feb97864c6a25a5680b0098',
            'lightningDetails': {
              'Swap ID': 'TCkQ1ZmWzeqy',
              'Description': '-',
              'Destination public key': '032842...2571de',
              'BIP35 address': '-',
              'Payment hash':
                  '0c0d12b226cd40dadf1262fdfe11e940a7074fdac6250697eca7e5442b2f1dca',
              'Claim hash': '-',
              'Refund hash': '-',
              'Refund amount': '0',
            },
          },
          {
            'id': 'ln_send_2',
            'type': 'send',
            'status': 'Confirmed',
            'amount': '0.0005',
            'coin': 'BTC LIGHTNING',
            'coinIcon': '⚡',
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
            'coin': 'BTC LIGHTNING',
            'coinIcon': '⚡',
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
      };

  @override
  void initState() {
    super.initState();
    _flipController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _flipAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _flipController,
      curve: Curves.easeInOut,
    ));

    // Start lightning timer if BTC Lightning is selected
    _startLightningTimer();
  }

  @override
  void dispose() {
    _flipController.dispose();
    _lightningTimer?.cancel();
    super.dispose();
  }

  void _startLightningTimer() {
    _lightningTimer?.cancel();
    if (selectedCoin == 'BTC LIGHTNING' && !_isLightningComplete) {
      _lightningTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (selectedCoin == 'BTC LIGHTNING' &&
            mounted &&
            !_isLightningComplete) {
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
          _isLightningComplete = true; // Stop cycling after synced
          _lightningTimer?.cancel();
          break;
        case 'synced':
          // Stay in synced state - no more changes
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
    setState(() {
      _isCardFlipped = !_isCardFlipped;
    });
  }

  void _cycleLightningState() {
    // Manual click allows cycling and restarting the process
    setState(() {
      switch (_lightningState) {
        case 'sync':
          _lightningState = 'syncing';
          _isLightningComplete = false;
          _startLightningTimer(); // Start auto cycling
          break;
        case 'syncing':
          _lightningState = 'synced';
          _isLightningComplete = true;
          _lightningTimer?.cancel();
          break;
        case 'synced':
          // Reset to sync to allow restarting the process
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
    return Scaffold(
      backgroundColor: const Color(0xFF0B0D1A),
      bottomNavigationBar: BottomNavBar(
        selectedIndex: 1, // Balance tab selected
        onTap: (index) {
          if (index == 1) return; // Stay on balance
          Navigator.pushReplacementNamed(
            context,
            index == 0
                ? AppRoutes.dashboardScreen
                : index == 1
                    ? AppRoutes.swapScreen
                    : index == 2
                        ? AppRoutes.dashboardScreen // Portfolio
                        : AppRoutes.dashboardScreen, // Hub
          );
        },
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Header with coin selector
            _buildHeader(),

            // Main scrollable content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Column(
                  children: [
                    const SizedBox(height: 16),

                    // Main balance card
                    _buildBalanceCard(),

                    const SizedBox(height: 16),

                    // Available and Reserved row
                    _buildAvailableReservedRow(),

                    const SizedBox(height: 24),

                    // Action buttons
                    _buildActionButtons(),

                    const SizedBox(height: 24),

                    // Transactions section
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

  Widget _buildHeader() {
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
                      child: Text(
                        coinData[selectedCoin]!['icon']!,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
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
                              selectedCoin,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(width: 6),
                          ],
                        ),
                        // Text(
                        //   '= \${coinData[selectedCoin]!['price']!} USD',
                        //   style: const TextStyle(
                        //     color: Color(0xFF6B7280),
                        //     fontSize: 11,
                        //   ),
                        // ),
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

  Widget _buildBalanceCard() {
    return AnimatedBuilder(
      animation: _flipAnimation,
      builder: (context, child) {
        final isShowingFront = _flipAnimation.value < 0.5;
        return Transform(
          alignment: Alignment.center,
          transform: Matrix4.identity()
            ..setEntry(3, 2, 0.001)
            ..rotateY(_flipAnimation.value * 3.14159),
          child: isShowingFront ? _buildFrontCard() : _buildBackCard(),
        );
      },
    );
  }

  Widget _buildFrontCard() {
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
                '$selectedCoin - Main Account',
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
            coinData[selectedCoin]!['address']!,
            style: const TextStyle(
              color: Color(0xFF6B7280),
              fontSize: 11,
            ),
          ),

          const SizedBox(height: 16),

          // Balance
          Text(
            coinData[selectedCoin]!['balance']!,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 42,
              fontWeight: FontWeight.w600,
            ),
          ),

          const SizedBox(height: 2),

          // Text(
          //   '= \${coinData[selectedCoin]!['usdBalance']!} USD',
          //   style: const TextStyle(
          //     color: Color(0xFF6B7280),
          //     fontSize: 13,
          //   ),
          // ),
        ],
      ),
    );
  }

  Widget _buildBackCard() {
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
                    const Icon(
                      Icons.eco,
                      color: Colors.green,
                      size: 16,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '$selectedCoin - Gas Free Mode',
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
                    child: const Icon(
                      Icons.refresh,
                      color: Colors.green,
                      size: 14,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 6),

            // Address
            Text(
              coinData[selectedCoin]!['address']!,
              style: const TextStyle(
                color: Color(0xFF8B9B8B),
                fontSize: 11,
              ),
            ),

            const SizedBox(height: 16),

            // Balance
            Text(
              coinData[selectedCoin]!['balance']!,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 42,
                fontWeight: FontWeight.w600,
              ),
            ),

            const SizedBox(height: 2),

            // Text(
            //   '= \${coinData[selectedCoin]!['usdBalance']!} USD (Gas Free)',
            //   style: const TextStyle(
            //     color: Color(0xFF8B9B8B),
            //     fontSize: 13,
            //   ),
            // ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionIcons() {
    if (selectedCoin == 'USDT') {
      return Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: const Color(0xFF3A3D4A),
              borderRadius: BorderRadius.circular(6),
            ),
            child: const Icon(
              Icons.copy,
              color: Color(0xFF6B7280),
              size: 14,
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: _toggleCardFlip,
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: const Color(0xFF3A3D4A),
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Icon(
                Icons.eco,
                color: Colors.green,
                size: 14,
              ),
            ),
          ),
        ],
      );
    } else if (selectedCoin == 'BTC LIGHTNING') {
      return _getLightningStateWidget();
    } else {
      return Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: const Color(0xFF3A3D4A),
          borderRadius: BorderRadius.circular(6),
        ),
        child: const Icon(
          Icons.copy,
          color: Color(0xFF6B7280),
          size: 14,
        ),
      );
    }
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
              SizedBox(
                width: 12,
                height: 12,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            else
              Icon(
                _getLightningStateIcon(),
                color: Colors.white,
                size: 12,
              ),
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

  Widget _buildAvailableReservedRow() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Available',
                  style: TextStyle(
                    color: Color(0xFF6B7280),
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text(
                      coinData[selectedCoin]!['balance']!,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Icon(
                      Icons.info_outline,
                      color: Color(0xFF6B7280),
                      size: 16,
                    ),
                  ],
                ),
              ],
            ),
          ),
          Container(
            width: 1,
            height: 36,
            color: const Color(0xFF3A3D4A),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(left: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Reserved',
                    style: TextStyle(
                      color: Color(0xFF6B7280),
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Text(
                        '0',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Icon(
                        Icons.info_outline,
                        color: Color(0xFF6B7280),
                        size: 16,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    if (selectedCoin == 'BTC LIGHTNING') {
      // Only show Send, Receive, and Scan for BTC Lightning
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
      // Show all buttons for other coins
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
              child: Icon(
                icon,
                color: Colors.white,
                size: 22,
              ),
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

  Widget _buildTransactionItem(Map<String, dynamic> transaction) {
    return InkWell(
      onTap: () => _navigateToTransactionDetails(transaction),
      splashColor: const Color(0xFF2A2D3A).withOpacity(0.3),
      highlightColor: const Color(0xFF2A2D3A).withOpacity(0.1),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
        child: Row(
          children: [
            // Transaction type icon
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: const Color(0xFF2A2D3A),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Icon(
                _getTransactionTypeIcon(transaction['type']),
                color: Colors.white,
                size: 18,
              ),
            ),

            const SizedBox(width: 16),

            // Transaction details
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Status badge
                          Text(
                            transaction['status'],
                            style: TextStyle(
                              color: _getStatusColor(transaction['status']),
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 2),
                          // Transaction type
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
                          // Time ago
                          Text(
                            _getTimeAgo(transaction['dateTime']),
                            style: const TextStyle(
                              color: Color(0xFF6B7280),
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(height: 2),
                          // Amount
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
                  // From and To addresses
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'From:',
                              style: TextStyle(
                                color: Color(0xFF6B7280),
                                fontSize: 12,
                              ),
                            ),
                            Text(
                              _shortenAddress(transaction['from'] ?? 'Unknown'),
                              style: const TextStyle(
                                color: Color(0xFF6B7280),
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            const Text(
                              'To:',
                              style: TextStyle(
                                color: Color(0xFF6B7280),
                                fontSize: 12,
                              ),
                            ),
                            Text(
                              _shortenAddress(transaction['to'] ?? 'Unknown'),
                              style: const TextStyle(
                                color: Color(0xFF6B7280),
                                fontSize: 12,
                              ),
                              textAlign: TextAlign.end,
                            ),
                          ],
                        ),
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

  Widget _buildTransactionsSection() {
    final transactions = dummyTransactions[selectedCoin] ?? [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section header with tabs
        Row(
          children: [
            Container(
              padding: const EdgeInsets.only(bottom: 8),
              decoration: const BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color: Colors.white,
                    width: 2,
                  ),
                ),
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
            Container(
              padding: const EdgeInsets.only(bottom: 8),
              child: const Text(
                'Refundables',
                style: TextStyle(
                  color: Color(0xFF6B7280),
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),

        const SizedBox(height: 24),

        // Transaction list
        if (transactions.isNotEmpty) ...[
          ...transactions
              .map((transaction) => _buildTransactionItem(transaction))
              .toList(),
        ] else ...[
          // Empty state
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
                    fontWeight: FontWeight.w500,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  'Your transactions will appear here',
                  style: TextStyle(
                    color: Color(0xFF6B7280),
                    fontSize: 14,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ],

        const SizedBox(height: 100), // Extra space for scrolling
      ],
    );
  }

// Helper function to get time ago format
  String _getTimeAgo(String dateTime) {
    try {
      // Parse the date string (assuming format: "DD MMM YYYY HH:mm:ss")
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

        if (difference == 0) {
          return 'Today';
        } else if (difference == 1) {
          return 'Yesterday';
        } else if (difference < 30) {
          return '$difference days ago';
        } else {
          return '$day $month $year';
        }
      }
    } catch (e) {
      // Fallback
    }
    return '12 days ago';
  }

// Helper function to get coin symbol
  String _getCoinSymbol(String coin) {
    switch (coin) {
      case 'BTC':
      case 'BTC LIGHTNING':
        return 'BTC';
      case 'ETH':
        return 'ETH';
      case 'XRP':
        return 'XRP';
      case 'ADA':
        return 'ADA';
      case 'USDT':
        return 'USDT';
      default:
        return coin;
    }
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
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // Coin list
              Expanded(
                child: ListView.builder(
                  controller: scrollController,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  itemCount: coinData.length,
                  itemBuilder: (context, index) {
                    String coinKey = coinData.keys.elementAt(index);
                    Map<String, String> coin = coinData[coinKey]!;

                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: ListTile(
                        contentPadding: const EdgeInsets.all(16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        tileColor: selectedCoin == coinKey
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
                            child: Text(
                              coin['icon']!,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                        title: Text(
                          coinKey,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        subtitle: Text(
                          coin['name']!,
                          style: const TextStyle(
                            color: Color(0xFF6B7280),
                            fontSize: 12,
                          ),
                        ),
                        trailing: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            // Text(
                            //   '\${coin['price']!}',
                            //   style: const TextStyle(
                            //     color: Colors.white,
                            //     fontWeight: FontWeight.w500,
                            //   ),
                            // ),
                            Text(
                              '${coin['balance']} $coinKey',
                              style: const TextStyle(
                                color: Color(0xFF6B7280),
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                        onTap: () {
                          setState(() {
                            selectedCoin = coinKey;
                            selectedCoinName = coin['name']!;
                            selectedCoinPrice = coin['price']!;
                            selectedCoinBalance = coin['balance']!;
                            selectedCoinUsdBalance = coin['usdBalance']!;
                            selectedCoinAddress = coin['address']!;
                            // Reset card flip state when changing coins
                            _isCardFlipped = false;
                            _flipController.reset();
                            // Reset lightning state and restart timer
                            _lightningState = 'sync';
                            _isLightningComplete = false;
                          });
                          // Start/stop lightning timer based on selection
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

// Import this at the top of your file
class TransactionDetailsScreen extends StatelessWidget {
  final Map<String, dynamic> transaction;

  const TransactionDetailsScreen({Key? key, required this.transaction})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
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
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w500,
          ),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Transaction Type Title
            Text(
              _getTransactionTitle(),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 32,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 8),

            // Date and Time
            Text(
              transaction['dateTime'],
              style: const TextStyle(
                color: Color(0xFF6B7280),
                fontSize: 14,
              ),
            ),

            const SizedBox(height: 16),

            // Status Badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: _getStatusColor(),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                transaction['status'],
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Amount with Icon
            Row(
              children: [
                Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: _getCoinColor(),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: Text(
                      transaction['coinIcon'],
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  '${transaction['amount']} ${transaction['coin']}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (transaction['coin'] == 'BTC LIGHTNING') ...[
                  const SizedBox(width: 8),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.purple,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Text(
                      'Lightning',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ],
            ),

            const SizedBox(height: 32),

            // Transaction Details Section
            const Text(
              'Transaction details',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),

            const SizedBox(height: 16),

            // Transaction Details Items
            if (transaction['type'] == 'swap') ...[
              _buildSwapDetails(),
            ] else ...[
              if (transaction['block'] != null)
                _buildTransactionDetailItem(
                    'Block', transaction['block']?.toString() ?? '-'),
              _buildTransactionDetailItem('To', transaction['to'] ?? '-'),
              _buildTransactionDetailItem('From', transaction['from'] ?? '-'),
              _buildTransactionDetailItem('Hash', transaction['hash'] ?? '-'),
            ],

            // Lightning Details (if applicable)
            if (transaction['coin'] == 'BTC LIGHTNING' &&
                transaction['lightningDetails'] != null) ...[
              const SizedBox(height: 32),
              Row(
                children: [
                  const Icon(Icons.flash_on, color: Colors.purple, size: 16),
                  const SizedBox(width: 8),
                  const Text(
                    'Lightning details',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              ...transaction['lightningDetails'].entries.map<Widget>((entry) {
                return _buildTransactionDetailItem(
                    entry.key, entry.value?.toString() ?? '-');
              }).toList(),
            ],

            // Fee Details
            if (transaction['feeDetails'] != null) ...[
              const SizedBox(height: 32),
              const Text(
                'Fee Details',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 16),
              ...transaction['feeDetails'].entries.map<Widget>((entry) {
                return _buildTransactionDetailItem(
                    entry.key, entry.value?.toString() ?? '-');
              }).toList(),
            ],

            const SizedBox(height: 100),
          ],
        ),
      ),
    );
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
    switch (transaction['coin']) {
      case 'BTC':
      case 'BTC LIGHTNING':
        return Colors.orange;
      case 'ETH':
        return Colors.blue;
      case 'XRP':
        return Colors.blue.shade800;
      case 'ADA':
        return Colors.blue.shade600;
      case 'USDT':
        return Colors.green;
      default:
        return const Color(0xFF2A2D3A);
    }
  }

  Widget _buildSwapDetails() {
    final swapDetails = transaction['swapDetails'] as Map<String, dynamic>;
    return Column(
      children: [
        _buildTransactionDetailItem(
            'From', '${swapDetails['fromAmount']} ${swapDetails['fromCoin']}'),
        _buildTransactionDetailItem(
            'To', '${swapDetails['toAmount']} ${swapDetails['toCoin']}'),
        _buildTransactionDetailItem('Exchange Rate',
            '1 ${swapDetails['fromCoin']} = ${swapDetails['rate']} ${swapDetails['toCoin']}'),
        _buildTransactionDetailItem('Swap ID', swapDetails['swapId']),
        _buildTransactionDetailItem('Hash', transaction['hash'] ?? '-'),
      ],
    );
  }

  Widget _buildTransactionDetailItem(String label, String value) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFF6B7280),
              fontSize: 14,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Flexible(
                  child: Text(
                    value,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                    ),
                    textAlign: TextAlign.end,
                  ),
                ),
                if (value != '-' && value.length > 20) ...[
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () {
                      // Copy to clipboard functionality would go here
                      // You'll need to import 'package:flutter/services.dart'
                      // Clipboard.setData(ClipboardData(text: value));
                    },
                    child: const Icon(
                      Icons.copy,
                      color: Color(0xFF6B7280),
                      size: 16,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
