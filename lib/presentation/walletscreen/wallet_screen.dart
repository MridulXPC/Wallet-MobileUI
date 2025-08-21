import 'package:cryptowallet/presentation/bottomnavbar.dart';
import 'package:cryptowallet/routes/app_routes.dart';
import 'package:flutter/material.dart';

class WalletInfoScreen extends StatefulWidget {
  const WalletInfoScreen({Key? key}) : super(key: key);

  @override
  State<WalletInfoScreen> createState() => _WalletInfoScreenState();
}

class _WalletInfoScreenState extends State<WalletInfoScreen> {
  String selectedCoin = 'BTC';
  String selectedCoinName = 'Bitcoin';
  String selectedCoinPrice = '43,825.67';
  String selectedCoinBalance = '0.00';
  String selectedCoinUsdBalance = '0.00';
  String selectedCoinAddress = 'bc1qxy2kgdygjrsqtzq2n0yrf2493p83kkfjhx0wlh';

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
  };

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
                        Text(
                          '= ${coinData[selectedCoin]!['price']!} USD',
                          style: const TextStyle(
                            color: Color(0xFF6B7280),
                            fontSize: 11,
                          ),
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

  Widget _buildBalanceCard() {
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
          // Header with coin name and copy button
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

          Text(
            '= ${coinData[selectedCoin]!['usdBalance']!} USD',
            style: const TextStyle(
              color: Color(0xFF6B7280),
              fontSize: 13,
            ),
          ),
        ],
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

  Widget _buildTransactionsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section header
        const Text(
          'Transactions',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),

        const SizedBox(height: 20),

        // Error state
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(40),
          child: Column(
            children: [
              const Text(
                'Oops, something went wrong',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w500,
                ),
              ),

              const SizedBox(height: 8),

              const Text(
                'Error when trying to load the Transaction list',
                style: TextStyle(
                  color: Color(0xFF6B7280),
                  fontSize: 14,
                ),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 24),

              // Retry button
              GestureDetector(
                onTap: () {
                  // Handle retry
                },
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.refresh,
                      color: Color(0xFF6B7280),
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'Retry',
                      style: TextStyle(
                        color: Color(0xFF6B7280),
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 100), // Extra space for scrolling
      ],
    );
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
                            Text(
                              '\$${coin['price']!}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
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
                          });
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
