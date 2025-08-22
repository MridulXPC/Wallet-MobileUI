import 'package:cryptowallet/core/app_export.dart';
import 'package:cryptowallet/presentation/bottomnavbar.dart';
import 'package:cryptowallet/routes/app_routes.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'package:cryptowallet/coin_store.dart';

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

  static const Color _pageBg = Color(0xFF0B0D1A);

  Coin? _coinById(BuildContext ctx, String id) =>
      ctx.read<CoinStore>().getById(id);

  String _baseSymbol(String coinId) {
    // Examples: USDT-ETH -> USDT, BTC-LN -> BTC, SOL -> SOL
    final dash = coinId.indexOf('-');
    return dash == -1 ? coinId : coinId.substring(0, dash);
  }

  void _swapCoins() {
    setState(() {
      final tmp = fromCoinId;
      fromCoinId = toCoinId;
      toCoinId = tmp;
      _fromController.clear();
      fromAmount = 0.0;
    });
  }

  // ---------- Coin Picker ----------
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

          // Build unique chip list: ALL + base symbols present
          final baseSet = <String>{};
          for (final c in coins) baseSet.add(_baseSymbol(c.id));
          final chips = ['ALL', ...baseSet.toList()..sort()];

          // Filter by chip + search (symbol or name match)
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
                            hintStyle: const TextStyle(color: Colors.white54),
                            prefixIcon:
                                const Icon(Icons.search, color: Colors.white54),
                            filled: true,
                            fillColor: const Color(0xFF2A2D3A),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: BorderSide.none,
                            ),
                          ),
                          onChanged: (v) => setModalState(() => _search = v),
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
                          padding: const EdgeInsets.symmetric(horizontal: 6),
                          child: ChoiceChip(
                            label: Text(filter),
                            selected: isSelected,
                            onSelected: (_) =>
                                setModalState(() => _chipFilter = filter),
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
                              style: const TextStyle(color: Colors.white70)),
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
                            });
                          },
                        );
                      },
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

  String _networkHint(String id) {
    // surface the chain part if present
    final dash = id.indexOf('-');
    if (dash == -1) return '';
    return id.substring(dash + 1); // e.g. ETH, TRX, BNB, LN, etc.
  }

  Widget _coinAvatar(String assetPath, String symbol) {
    return Container(
      width: 40,
      height: 40,
      decoration:
          const BoxDecoration(shape: BoxShape.circle, color: Color(0xFF2A2D3A)),
      child: ClipOval(
        child: Image.asset(
          assetPath,
          width: 40,
          height: 40,
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
                onTap: () => _selectCoin(isFrom: isFrom),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF3A3D4A),
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
                    color: const Color(0xFF3A3D4A),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text('MAX',
                      style: TextStyle(color: Colors.white70, fontSize: 12)),
                ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: isFrom ? _fromController : null,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
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
                  onChanged: (val) =>
                      setState(() => fromAmount = double.tryParse(val) ?? 0.0),
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
    // listen so icons/names react to provider updates
    final store = context.watch<CoinStore>();
    // if ids no longer exist (e.g., removed coin), fallback to first available
    if (store.getById(fromCoinId) == null && store.coins.isNotEmpty) {
      fromCoinId = store.coins.values.first.id;
    }
    if (store.getById(toCoinId) == null && store.coins.length > 1) {
      toCoinId = store.coins.values.skip(1).first.id;
    }

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
                Text('Auto',
                    style: TextStyle(color: Colors.white70, fontSize: 12)),
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
                coinId: fromCoinId,
                isFrom: true,
                value: fromAmount,
              ),
              _buildSwapCard(
                label: 'To',
                coinId: toCoinId,
                isFrom: false,
                value: fromAmount * 0.95, // demo conversion
              ),
              const Spacer(),
              Container(
                margin: const EdgeInsets.all(16),
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: () {
                    // TODO: implement swap action with your backend/DEX router
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
