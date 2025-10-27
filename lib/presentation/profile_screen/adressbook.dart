// lib/screens/address_book_screen.dart
import 'package:cryptowallet/stores/coin_store.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class AddressBookScreen extends StatefulWidget {
  const AddressBookScreen({super.key});

  @override
  State<AddressBookScreen> createState() => _AddressBookScreenState();
}

class _AddressBookScreenState extends State<AddressBookScreen> {
  String searchQuery = '';

  @override
  Widget build(BuildContext context) {
    final coinStore = context.watch<CoinStore>();
    coinStore.coins.values.toList();

    // choose 5 coins for the top row (you can reorder this list)
    final topRowIds = <String>["BTC", "BTC-LN", "ETH", "TRX", "BNB"];
    final topCoins =
        topRowIds.map((id) => coinStore.getById(id)).whereType<Coin>().toList();

    return Scaffold(
      backgroundColor: const Color(0xFF0B0D1A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0B0D1A),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          children: const [
            Text(
              'Wallet Settings',
              style: TextStyle(
                color: Colors.grey,
                fontSize: 16,
                fontWeight: FontWeight.w400,
              ),
            ),
            SizedBox(width: 12),
            Text(
              'Address Book',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          // Top coin icons row
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _GridIcon(onTap: () => _showCoinSelectionBottomSheet(context)),
                for (final c in topCoins) _TopCoinIcon(coin: c),
              ],
            ),
          ),
          SizedBox(height: 10),
          // Tabs
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Column(
                  children: [
                    const Text(
                      'My Accounts',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      height: 2,
                      width: 100,
                      color: Colors.purple,
                    ),
                  ],
                ),
                const SizedBox(width: 40),
                const Text(
                  'Contacts',
                  style: TextStyle(
                    color: Colors.grey,
                    fontSize: 16,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // Example account item (static placeholder)
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 5),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: Colors.purple, width: 1),
            ),
            child: const Row(
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'LN - Main Account',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      '039049...b272b9',
                      style: TextStyle(
                        color: Colors.grey,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
                Spacer(),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '0.00',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      '≈ 0.00 USD',
                      style: TextStyle(
                        color: Colors.grey,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const Spacer(),

          // Bottom sheet handle (also opens on tap)
          GestureDetector(
            onTap: () => _showCoinSelectionBottomSheet(context),
            child: Container(
              height: 6,
              width: 80,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showCoinSelectionBottomSheet(BuildContext context) {
    final store = context.read<CoinStore>();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => CoinSelectionBottomSheet(store: store),
    );
  }
}

/// Top grid trigger
class _GridIcon extends StatelessWidget {
  final VoidCallback onTap;
  const _GridIcon({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 50,
        height: 50,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: Colors.grey.withOpacity(0.3)),
        ),
        child: const Icon(Icons.grid_view, color: Colors.white, size: 20),
      ),
    );
  }
}

/// Top row coin item using CoinStore icon ONLY
class _TopCoinIcon extends StatelessWidget {
  final Coin coin;
  const _TopCoinIcon({required this.coin});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 60,
      height: 60,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _CoinAvatar(assetPath: coin.assetPath, size: 32, radius: 16),
          const SizedBox(height: 4),
          Text(
            coin.symbol,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 10,
              fontWeight: FontWeight.w400,
            ),
          ),
        ],
      ),
    );
  }
}

/// Bottom sheet with real icons from CoinStore
class CoinSelectionBottomSheet extends StatefulWidget {
  final CoinStore store;
  const CoinSelectionBottomSheet({super.key, required this.store});

  @override
  State<CoinSelectionBottomSheet> createState() =>
      _CoinSelectionBottomSheetState();
}

class _CoinSelectionBottomSheetState extends State<CoinSelectionBottomSheet> {
  String searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  List<Coin> get filteredCoins {
    final coins = widget.store.coins.values.toList();
    if (searchQuery.isEmpty) return coins;
    return coins
        .where((c) =>
            c.symbol.toLowerCase().contains(searchQuery.toLowerCase()) ||
            c.name.toLowerCase().contains(searchQuery.toLowerCase()) ||
            c.id.toLowerCase().contains(searchQuery.toLowerCase()))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.8,
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
      child: Column(
        children: [
          // Handle bar
          Container(
            margin: const EdgeInsets.only(top: 12),
            height: 4,
            width: 40,
            decoration: BoxDecoration(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 20),

          // Search bar
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 10),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(
                      hintText: 'Search tokens',
                      hintStyle: TextStyle(color: Colors.grey),
                      border: InputBorder.none,
                      isDense: true,
                    ),
                    onChanged: (v) => setState(() => searchQuery = v),
                  ),
                ),
                const Icon(Icons.search, color: Colors.grey, size: 20),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Coins grid (icons from CoinStore only)
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: GridView.builder(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 5,
                  crossAxisSpacing: 15,
                  mainAxisSpacing: 20,
                  childAspectRatio: 0.8,
                ),
                itemCount: filteredCoins.length,
                itemBuilder: (context, i) {
                  final coin = filteredCoins[i];
                  return _BottomSheetCoinItem(
                    coin: coin,
                    onTap: () {
                      Navigator.pop(context);
                      // TODO: handle coin selection for address book
                      // e.g., setState in parent / callback
                    },
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BottomSheetCoinItem extends StatelessWidget {
  final Coin coin;
  final VoidCallback onTap;
  const _BottomSheetCoinItem({required this.coin, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _CoinAvatar(assetPath: coin.assetPath, size: 50, radius: 25),
          const SizedBox(height: 8),
          Text(
            coin.symbol, // or coin.id if you prefer “BTC-LN”
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

/// Shared avatar that loads ONLY from CoinStore.assetPath
class _CoinAvatar extends StatelessWidget {
  final String assetPath;
  final double size;
  final double radius;
  const _CoinAvatar({
    required this.assetPath,
    required this.size,
    required this.radius,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: Container(
        width: size,
        height: size,
        color: const Color(0xFF2A2B35),
        child: Image.asset(
          assetPath,
          fit: BoxFit.contain,
          errorBuilder: (context, _, __) => const Icon(
            Icons.image_not_supported,
            size: 18,
          ),
        ),
      ),
    );
  }
}
