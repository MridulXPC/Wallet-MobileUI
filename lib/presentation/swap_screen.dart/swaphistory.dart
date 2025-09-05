// lib/screens/swap_history_screen.dart
import 'dart:math' as math;
import 'package:cryptowallet/stores/coin_store.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class SwapHistoryScreen extends StatefulWidget {
  const SwapHistoryScreen({super.key});
  @override
  State<SwapHistoryScreen> createState() => _SwapHistoryScreenState();
}

class _SwapHistoryScreenState extends State<SwapHistoryScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tab;
  final TextEditingController _search = TextEditingController();
  String _q = '';

  // TODO: replace with API data
  final List<SwapRecord> _records = const [
    // existing…
    SwapRecord(
      addressShort: 'bc1q07...eyla0f',
      fromCoinId: 'BTC',
      toCoinId: 'USDT',
      fromAmount: 0.008111,
      toAmount: 931.20,
    ),
    SwapRecord(
      addressShort: 'bc1q07...eyla0f',
      fromCoinId: 'BTC',
      toCoinId: 'USDT',
      fromAmount: 0.004256,
      toAmount: 476.40,
    ),
    SwapRecord(
      addressShort: 'bc1q07...eyla0f',
      fromCoinId: 'BTC',
      toCoinId: 'USDT',
      fromAmount: 0.003807,
      toAmount: 426.40,
    ),
    SwapRecord(
      addressShort: 'TAJ6r4...t372GF',
      fromCoinId: 'TRX',
      toCoinId: 'USDT-TRX',
      fromAmount: 7.00,
      toAmount: 2.335116,
    ),
    // extra dummies 👇
    SwapRecord(
      addressShort: 'bc1z9k...m4u8v9',
      fromCoinId: 'ETH',
      toCoinId: 'USDT-ETH',
      fromAmount: 0.215000, // shows as 0.215
      toAmount: 728.55, // shows as 728.55
    ),
    SwapRecord(
      addressShort: '3FZbgi...8m4Gy',
      fromCoinId: 'BTC',
      toCoinId: 'USDT',
      fromAmount: 1.000000, // shows as 1.00
      toAmount: 115, // shows as 115432.20
    ),
  ];

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tab.dispose();
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<CoinStore>();

    final filtered = _records.where((r) {
      if (_q.isEmpty) return true;
      final f = store.getById(r.fromCoinId);
      final t = store.getById(r.toCoinId);
      final pair = '${f?.symbol ?? r.fromCoinId}/${t?.symbol ?? r.toCoinId}';
      return pair.toLowerCase().contains(_q) ||
          r.addressShort.toLowerCase().contains(_q) ||
          (f?.symbol.toLowerCase().contains(_q) ?? false) ||
          (t?.symbol.toLowerCase().contains(_q) ?? false);
    }).toList();

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: const Color(0xFF0F1220),
        body: SafeArea(
          top: true,
          bottom: false,
          child: NestedScrollView(
            headerSliverBuilder: (_, __) => [
              SliverAppBar(
                backgroundColor: const Color(0xFF0F1220),
                pinned: true,
                centerTitle: false,
                titleSpacing: 12,
                leadingWidth: 92,
                leading: TextButton.icon(
                  onPressed: () => Navigator.pop(context),
                  style: TextButton.styleFrom(foregroundColor: Colors.white),
                  icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
                  label: const Text('Back'),
                ),
                title: const Text(
                  'My Swaps',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700, // a touch bolder like SS
                    fontSize: 20, // slightly larger title
                  ),
                ),
                bottom: TabBar(
                  controller: _tab,
                  isScrollable: true,
                  labelPadding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 0),
                  labelColor: Colors.white,
                  unselectedLabelColor: Colors.white54,
                  labelStyle: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w600),
                  unselectedLabelStyle: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w500),
                  indicator: const UnderlineTabIndicator(
                    borderSide: BorderSide(color: Colors.white, width: 2),
                    insets: EdgeInsets.symmetric(horizontal: 24),
                  ),
                  tabs: const [Tab(text: 'Swap'), Tab(text: 'Limit')],
                ),
              ),
            ],
            body: Column(
              children: [
                // search (rounded like screenshot)
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  child: _SearchField(
                    controller: _search,
                    onChanged: (v) => setState(() => _q = v.toLowerCase()),
                  ),
                ),
                // list
                Expanded(
                  child: TabBarView(
                    controller: _tab,
                    children: [
                      ListView.separated(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        itemCount: filtered.length,
                        separatorBuilder: (_, __) =>
                            const Divider(height: 32, color: Colors.white10),
                        itemBuilder: (context, i) {
                          final r = filtered[i];
                          final from = store.getById(r.fromCoinId);
                          final to = store.getById(r.toCoinId);
                          return _SwapRow(
                            from: from,
                            to: to,
                            addressShort: r.addressShort,
                            fromAmount: r.fromAmount,
                            toAmount: r.toAmount,
                          );
                        },
                      ),
                      const _LimitEmptyState(),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class SwapRecord {
  final String addressShort;
  final String fromCoinId;
  final String toCoinId;
  final double fromAmount;
  final double toAmount;
  const SwapRecord({
    required this.addressShort,
    required this.fromCoinId,
    required this.toCoinId,
    required this.fromAmount,
    required this.toAmount,
  });
}

/// rounded search box + right icon, matches screenshot proportions
class _SearchField extends StatelessWidget {
  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  const _SearchField({required this.controller, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final h = math.max(48.0, MediaQuery.of(context).size.height * 0.06);
    return ConstrainedBox(
      constraints: BoxConstraints(minHeight: h, maxHeight: h),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF17192A),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: Colors.white24, width: 1.2),
        ),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: controller,
                onChanged: onChanged,
                style: const TextStyle(color: Colors.white),
                textInputAction: TextInputAction.search,
                decoration: const InputDecoration(
                  hintText: 'Search by token name',
                  hintStyle: TextStyle(color: Colors.white60),
                  border: InputBorder.none,
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                ),
              ),
            ),
            const SizedBox(
              width: 40,
              child: Icon(Icons.search, color: Colors.white70),
            ),
          ],
        ),
      ),
    );
  }
}

/// row tuned for screenshot spacing & typography
class _SwapRow extends StatelessWidget {
  final Coin? from;
  final Coin? to;
  final String addressShort;
  final double fromAmount;
  final double toAmount;

  const _SwapRow({
    required this.from,
    required this.to,
    required this.addressShort,
    required this.fromAmount,
    required this.toAmount,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, c) {
      final w = c.maxWidth;
      final small = w < 360;
      final icon = small ? 26.0 : 30.0;
      final tick = small ? 20.0 : 22.0;
      final gap = small ? 10.0 : 12.0;
      final rightMax = math.min(190.0, w * 0.42);

      final pair = '${from?.symbol ?? ''}/${to?.symbol ?? ''}';

      return Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          _StatusTick(size: tick),
          SizedBox(width: gap),
          _PairIcons(
              leftAsset: from?.assetPath,
              rightAsset: to?.assetPath,
              size: icon),
          SizedBox(width: gap),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // address
                Text(
                  addressShort,
                  style: TextStyle(
                    color: Colors.white60,
                    fontSize: small ? 11.5 : 12,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                // pair
                Text(
                  pair,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: small ? 15 : 16,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.2,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(width: gap),
          // Pay/Get
          ConstrainedBox(
            constraints: BoxConstraints(maxWidth: rightMax, minWidth: 110),
            child: Align(
              alignment: Alignment.centerRight,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  _kv('Pay', _fmtAmount(fromAmount), from?.symbol ?? ''),
                  const SizedBox(height: 6),
                  _kv('Get', _fmtAmount(toAmount), to?.symbol ?? ''),
                ],
              ),
            ),
          ),
        ],
      );
    });
  }

// replace inside _SwapRow
  static Widget _kv(String k, String v, String symbol) {
    return RichText(
      text: TextSpan(
        children: [
          TextSpan(
            text: '$k: ',
            style: const TextStyle(
                color: Colors.white70, fontSize: 13, height: 1.25),
          ),
          TextSpan(
            text: v,
            style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w700,
                height: 1.25),
          ),
          TextSpan(
            text: ' $symbol',
            style: const TextStyle(
                color: Colors.white70, fontSize: 13, height: 1.25),
          ),
        ],
      ),
    );
  }
}

// keep exactly like screenshot: >=1 -> 2dp (incl trailing 0), <1 -> up to 6dp trimmed
String _fmtAmount(double n) {
  if (n.abs() >= 1) {
    return n.toStringAsFixed(2); // 931.20, 7.00, 476.40
  } else {
    var s = n.toStringAsFixed(6);
    s = s.replaceFirst(RegExp(r'0+$'), '');
    if (s.endsWith('.')) s = s.substring(0, s.length - 1);
    return s; // e.g., 0.008111
  }
}

class _StatusTick extends StatelessWidget {
  final double size;
  const _StatusTick({this.size = 22});
  @override
  Widget build(BuildContext context) {
    final inner = size - 8;
    return Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(
        color: Color(0xFF151827), // darker outer like SS
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Container(
          width: inner,
          height: inner,
          decoration: const BoxDecoration(
            color: Color(0xFF20C997), // teal check
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.check, color: Colors.white, size: 12),
        ),
      ),
    );
  }
}

class _PairIcons extends StatelessWidget {
  final String? leftAsset;
  final String? rightAsset;
  final double size;
  const _PairIcons({this.leftAsset, this.rightAsset, this.size = 30});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size + size * 0.85,
      height: size,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
              left: 0,
              top: 0,
              child: _CoinCircle(assetPath: leftAsset, size: size)),
          Positioned(
              left: size * 0.85,
              top: 0,
              child: _CoinCircle(assetPath: rightAsset, size: size)),
        ],
      ),
    );
  }
}

class _CoinCircle extends StatelessWidget {
  final String? assetPath;
  final double size;
  const _CoinCircle({this.assetPath, this.size = 30});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: const Color(0xFF17192A),
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white12, width: 1.4), // crisper ring
        boxShadow: const [
          BoxShadow(color: Colors.black26, blurRadius: 2, offset: Offset(0, 1)),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: (assetPath == null)
          ? const SizedBox()
          : Image.asset(
              assetPath!,
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) => const Icon(
                  Icons.image_not_supported,
                  color: Colors.white38,
                  size: 14),
            ),
    );
  }
}

class _LimitEmptyState extends StatelessWidget {
  const _LimitEmptyState();
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text('No limit orders yet',
          style: TextStyle(color: Colors.white.withOpacity(0.7))),
    );
  }
}
