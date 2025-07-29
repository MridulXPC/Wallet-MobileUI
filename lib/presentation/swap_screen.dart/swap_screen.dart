import 'package:cryptowallet/presentation/bottomnavbar.dart';
import 'package:cryptowallet/routes/app_routes.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // for FilteringTextInputFormatter
class SwapScreen extends StatefulWidget {
  const SwapScreen({super.key});

  @override
  State<SwapScreen> createState() => _SwapScreenState();
}

class _SwapScreenState extends State<SwapScreen> {
  String fromCoin = 'USDT';
  String toCoin = 'KLV';
  double fromAmount = 0.0;
  final TextEditingController _fromController = TextEditingController();

  final List<Map<String, String>> allCoins = [
    {
      'symbol': 'USDT',
      'name': 'Tether',
      'icon': 'https://cryptologos.cc/logos/tether-usdt-logo.png',
      'chain': 'TRC20',
    },
    {
      'symbol': 'KLV',
      'name': 'Klever',
      'icon': 'https://cryptologos.cc/logos/klever-klv-logo.png',
      'chain': 'KLV',
    },
    {
      'symbol': 'BTC',
      'name': 'Bitcoin',
      'icon': 'https://cryptologos.cc/logos/bitcoin-btc-logo.png',
      'chain': 'BTC',
    },
    {
      'symbol': 'ETH',
      'name': 'Ethereum',
      'icon': 'https://cryptologos.cc/logos/ethereum-eth-logo.png',
      'chain': 'ETH',
    },
    {
      'symbol': 'ADA',
      'name': 'Cardano',
      'icon': 'https://cryptologos.cc/logos/cardano-ada-logo.png',
      'chain': 'ADA',
    },
  ];

  String selectedFilter = 'ALL';

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
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      context: context,
      builder: (_) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            List<Map<String, String>> filteredCoins = selectedFilter == 'ALL'
                ? allCoins
                : allCoins.where((c) => c['chain'] == selectedFilter).toList();
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(height: 6),
                    const Text('Select Crypto',
                        style: TextStyle(color: Colors.black, fontSize: 18)),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            style: const TextStyle(color: Colors.black),
                            decoration: InputDecoration(
                              hintText: 'Type to search chain',
                              hintStyle: const TextStyle(color: Colors.black45),
                              prefixIcon: const Icon(Icons.search, color: Colors.black45),
                              filled: true,
                              fillColor: Colors.grey[100],
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
                        children: ['ALL', 'BTC', 'ETH', 'KLV', 'ADA'].map((filter) {
                          final isSelected = selectedFilter == filter;
                          return Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 6),
                            child: ChoiceChip(
                              label: Text(filter),
                              selected: isSelected,
                              onSelected: (_) =>
                                  setModalState(() => selectedFilter = filter),
                              selectedColor: Colors.black,
                              labelStyle: TextStyle(
                                color: isSelected ? Colors.white : Colors.black,
                              ),
                              backgroundColor: Colors.grey[300],
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
                            leading: CircleAvatar(
                              backgroundImage: NetworkImage(coin['icon'] ?? ''),
                              backgroundColor: Colors.grey[200],
                            ),
                            title: Text(coin['symbol'] ?? '',
                                style: const TextStyle(color: Colors.black)),
                            subtitle: Text(coin['name'] ?? '',
                                style: const TextStyle(color: Colors.black54)),
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
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 6,
            offset: Offset(0, 2),
          )
        ],
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: Colors.black54)),
          const SizedBox(height: 12),
          Row(
            children: [
              GestureDetector(
                onTap: () => _selectCoin(isFrom),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(radius: 8, backgroundColor: Colors.teal),
                      const SizedBox(width: 6),
                      Text(coin, style: const TextStyle(color: Colors.black)),
                      const Icon(Icons.keyboard_arrow_down,
                          color: Colors.black),
                    ],
                  ),
                ),
              ),
              const Spacer(),
              if (isFrom)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text('MAX',
                      style: TextStyle(color: Colors.black)),
                ),
              const SizedBox(width: 8),
              SizedBox(
                width: 100,
         child: TextField(
  controller: isFrom ? _fromController : null,
  keyboardType: const TextInputType.numberWithOptions(decimal: true),
  inputFormatters: [
    FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,8}')),
  ],
  textAlign: TextAlign.end,
  decoration: InputDecoration(
    filled: true,
    fillColor: Colors.transparent,
    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    hintText: '0',
    hintStyle: const TextStyle(color: Colors.black38),
    border: InputBorder.none,
    enabledBorder: InputBorder.none,
    focusedBorder: InputBorder.none,
  ),
  onChanged: (val) {
    setState(() {
      fromAmount = double.tryParse(val) ?? 0.0;
    });
  },
),

              ),
            ],
          ),
          const SizedBox(height: 6),
          Text('≈ \$${(value * 1).toStringAsFixed(2)}',
              style: const TextStyle(color: Colors.black54)),
        ],
      ),
    );
  }

  @override
@override
Widget build(BuildContext context) {
  return Scaffold(
    backgroundColor: Colors.white,
    appBar: AppBar(
      backgroundColor: Colors.white,
      elevation: 0.5,
      leading: const BackButton(color: Colors.black),
      title: const Text('Swap', style: TextStyle(color: Colors.black)),
      centerTitle: false,
      actions: const [
        Icon(Icons.tune, color: Colors.black),
        SizedBox(width: 8),
        Icon(Icons.history, color: Colors.black),
        SizedBox(width: 12),
      ],
    ),
    body: Column(
      children: [
        const SizedBox(height: 12),
        _buildSwapCard(
          label: 'From',
          coin: fromCoin,
          isFrom: true,
          value: fromAmount,
        ),
        GestureDetector(
          onTap: _swapCoins,
          child: const CircleAvatar(
            radius: 18,
            backgroundColor: Colors.black12,
            child: Icon(Icons.swap_vert, color: Colors.black),
          ),
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
          height: 50,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color.fromARGB(255, 100, 162, 228), Color(0xFF1A73E8)],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
            borderRadius: BorderRadius.circular(20),
          ),
          child: const Center(
            child: Text('Next',
                style: TextStyle(color: Colors.white, fontSize: 16)),
          ),
        )
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
