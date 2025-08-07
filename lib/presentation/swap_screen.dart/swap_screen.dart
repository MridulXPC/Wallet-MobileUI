import 'package:cryptowallet/core/app_export.dart';
import 'package:cryptowallet/presentation/bottomnavbar.dart';
import 'package:cryptowallet/routes/app_routes.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class SwapScreen extends StatefulWidget {
  const SwapScreen({super.key});

  @override
  State<SwapScreen> createState() => _SwapScreenState();
}

class _SwapScreenState extends State<SwapScreen> {
  String fromCoin = 'BTC';
  String toCoin = 'ETH';

  double fromAmount = 0.0;
  final TextEditingController _fromController = TextEditingController();

  final List<Map<String, String>> allCoins = [
    {
      "symbol": "BTC",
      "name": "Bitcoin",
      "balance": "0",
      "usdValue": "\$0.00",
      "change24h": "-1.25%",
      "icon": "assets/currencyicons/bitcoin.png",
    },
    {
      "symbol": "ETH",
      "name": "Ethereum",
      "balance": "0",
      "usdValue": "\$0.00",
      "change24h": "0.75%",
      "icon": "assets/currencyicons/ethereum.png",
    },
    {
      "symbol": "MATIC",
      "name": "Polygon",
      "balance": "0",
      "usdValue": "\$0.00",
      "change24h": "-0.50%",
      "icon": "assets/currencyicons/matic.png",
    },
    {
      "symbol": "BCH",
      "name": "Bitcoin Cash",
      "balance": "0",
      "usdValue": "\$0.00",
      "change24h": "0.00%",
      "icon": "assets/currencyicons/bitcoin-cash.png",
    },
    {
      "symbol": "TRX",
      "name": "Tron",
      "balance": "0",
      "usdValue": "\$0.00",
      "change24h": "-0.25%",
      "icon": "assets/currencyicons/trx.png",
    },
    {
      "symbol": "USDT",
      "name": "Tether",
      "balance": "0",
      "usdValue": "\$0.00",
      "change24h": "0.00%",
      "icon": "assets/currencyicons/usdt.png",
    },
    {
      "symbol": "KLV",
      "name": "Klever",
      "balance": "0",
      "usdValue": "\$0.00",
      "change24h": "2.15%",
      "icon": "assets/currencyicons/klv.png",
    },
  ];

  String selectedFilter = 'ALL';

  // Helper method to get coin data by symbol
  Map<String, String>? getCoinData(String symbol) {
    try {
      return allCoins.firstWhere((coin) => coin['symbol'] == symbol);
    } catch (e) {
      return null;
    }
  }

  // Helper method to get coin icon path
  String getCoinIcon(String symbol) {
    final coinData = getCoinData(symbol);
    return coinData?['icon'] ?? 'assets/currencyicons/default.png';
  }

  void _swapCoins() {
    setState(() {
      final temp = fromCoin;
      fromCoin = toCoin;
      toCoin = temp;
      _fromController.clear();
      fromAmount = 0.0;
    });
  }

  void _selectCoin(bool isFrom) {
    showModalBottomSheet(
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1A1D29),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      context: context,
      builder: (_) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            List<Map<String, String>> filteredCoins = selectedFilter == 'ALL'
                ? allCoins
                : allCoins.where((c) => c['symbol'] == selectedFilter).toList();
            
            return SafeArea(
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
                              hintText: 'Type to search chain',
                              hintStyle: const TextStyle(color: Colors.white54),
                              prefixIcon: const Icon(Icons.search, color: Colors.white54),
                              filled: true,
                              fillColor: const Color(0xFF2A2D3A),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: BorderSide.none,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: ['ALL', 'BTC', 'ETH', 'MATIC', 'TRX', 'USDT'].map((filter) {
                          final isSelected = selectedFilter == filter;
                          return Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 6),
                            child: ChoiceChip(
                              label: Text(filter),
                              selected: isSelected,
                              onSelected: (_) =>
                                  setModalState(() => selectedFilter = filter),
                              selectedColor: Colors.blue,
                              labelStyle: TextStyle(
                                color: isSelected ? Colors.white : Colors.white70,
                              ),
                              backgroundColor: const Color(0xFF2A2D3A),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      height: 400,
                      child: ListView(
                        children: filteredCoins.map((coin) {
                          return ListTile(
                            leading: Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: const Color(0xFF2A2D3A),
                              ),
                              child: ClipOval(
                                child: Image.asset(
                                  coin['icon'] ?? '',
                                  width: 40,
                                  height: 40,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) {
                                    return CircleAvatar(
                                      backgroundColor: const Color(0xFF2A2D3A),
                                      child: Text(
                                        coin['symbol']?[0] ?? '?',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ),
                            title: Text(coin['symbol'] ?? '',
                                style: const TextStyle(color: Colors.white)),
                            subtitle: Text(coin['name'] ?? '',
                                style: const TextStyle(color: Colors.white70)),
                            trailing: Text(
                              coin['change24h'] ?? '',
                              style: TextStyle(
                                color: coin['change24h']?.startsWith('-') == true 
                                    ? Colors.red 
                                    : Colors.green,
                                fontSize: 12,
                              ),
                            ),
                            onTap: () {
                              Navigator.pop(context);
                              setState(() {
                                if (isFrom) {
                                  fromCoin = coin['symbol']!;
                                } else {
                                  toCoin = coin['symbol']!;
                                }
                              });
                            },
                          );
                        }).toList(),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildSwapCard({
    required String label,
    required String coin,
    required bool isFrom,
    required double value,
  }) {
    final coinData = getCoinData(coin);
    final coinIcon = getCoinIcon(coin);
    
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFF2A2D3A),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 16,
                  color: Colors.white70,
                  fontWeight: FontWeight.w500,
                ),
              ),
              if (isFrom)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF3A3D4A),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'Balance: ${coinData?['balance'] ?? '0.00'}',
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              GestureDetector(
                onTap: () => _selectCoin(isFrom),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF3A3D4A),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 24,
                        height: 24,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: Color(0xFF2A2D3A),
                        ),
                        child: ClipOval(
                          child: Image.asset(
                            coinIcon,
                            width: 24,
                            height: 24,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              return CircleAvatar(
                                radius: 12,
                                backgroundColor: coin == 'USDT' ? Colors.green : Colors.purple,
                                child: Text(
                                  coin[0],
                                  style: const TextStyle(color: Colors.white, fontSize: 12),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        coin,
                        style: const TextStyle(color: Colors.white, fontSize: 16),
                      ),
                      const SizedBox(width: 4),
                      const Icon(
                        Icons.keyboard_arrow_down,
                        color: Colors.white70,
                        size: 20,
                      ),
                    ],
                  ),
                ),
              ),
              const Spacer(),
              if (isFrom)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF3A3D4A),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                    'MAX',
                    style: TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: isFrom ? _fromController : null,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,8}')),
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
                    setState(() {
                      fromAmount = double.tryParse(val) ?? 0.0;
                    });
                  },
                  enabled: isFrom,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: Text(
              '≈ \$${(value * 1).toStringAsFixed(2)}',
              style: const TextStyle(color: Colors.white54, fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1D29),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A1D29),
        elevation: 0,
        leading: const BackButton(color: Colors.white),
        title: const Text(
          'Swap',
          style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w600),
        ),
        centerTitle: false,
        actions: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFF2A2D3A),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.tune, color: Colors.white70, size: 16),
                SizedBox(width: 4),
                Text('Auto', style: TextStyle(color: Colors.white70, fontSize: 12)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          const Icon(Icons.refresh, color: Colors.white70),
          const SizedBox(width: 8),
          const Icon(Icons.history, color: Colors.white70),
          const SizedBox(width: 16),
        ],
      ),
      body: Stack(
        children: [
          Column(
            children: [
              _buildSwapCard(
                label: 'From',
                coin: fromCoin,
                isFrom: true,
                value: fromAmount,
              ),
              _buildSwapCard(
                label: 'To',
                coin: toCoin,
                isFrom: false,
                value: fromAmount * 0.95,
              ),
              const Spacer(),
              Container(
                margin: const EdgeInsets.all(16),
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: () {
                    // Handle swap action
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4A5568),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 0,
                  ),
                  child: const Text(
                    'Swap Now',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
          // Positioned swap button between containers
          Positioned(
            top: 125, // Position between the two containers
            left: 0,
            right: 0,
            child: Center(
              child: GestureDetector(
                onTap: _swapCoins,
                child: Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: const Color(0xFF1A1D29),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: const Color(0xFF2A2D3A),
                      width: 2,
                    ),
                  ),
                  child: const Icon(
                    Icons.swap_vert,
                    color: Colors.white70,
                    size: 24,
                  ),
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