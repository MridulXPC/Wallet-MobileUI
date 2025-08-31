// lib/screens/explore_screen.dart
import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'package:cryptowallet/coin_store.dart'; // <-- uses your CoinStore for icons

class ExploreScreen extends StatefulWidget {
  const ExploreScreen({super.key});
  @override
  State<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends State<ExploreScreen>
    with SingleTickerProviderStateMixin {
  final _searchCtl = TextEditingController();
  late final _ExploreVM _vm;
  late final TabController _tab;

  @override
  void initState() {
    super.initState();
    _vm = _ExploreVM()..addListener(_onVm);
    _tab = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _vm.removeListener(_onVm);
    _vm.dispose();
    _searchCtl.dispose();
    _tab.dispose();
    super.dispose();
  }

  void _onVm() => setState(() {});

  void _triggerSearch() {
    final q = _searchCtl.text.trim();
    if (q.isEmpty) return;
    _vm.search(q);
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<CoinStore>();

    return Scaffold(
      backgroundColor: const Color(0xFF0F1220),
      body: SafeArea(
        child: Column(
          children: [
            // App bar
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 6, 12, 2),
              child: Row(
                children: [
                  TextButton.icon(
                    onPressed: () => Navigator.pop(context),
                    style: TextButton.styleFrom(foregroundColor: Colors.white),
                    icon:
                        const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
                    label: const Text('Back'),
                  ),
                  const Spacer(),
                  const Text(
                    'Explore',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 20,
                    ),
                  ),
                  const Spacer(flex: 2),
                ],
              ),
            ),

            // Search bar
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
              child: _SearchField(
                controller: _searchCtl,
                hint: 'Search by wallet address',
                onSubmitted: (_) => _triggerSearch(),
                onSearchTap: _triggerSearch,
                onPasteTap: () async {
                  final data = await Clipboard.getData('text/plain');
                  if (data?.text?.isNotEmpty ?? false) {
                    _searchCtl.text = data!.text!;
                    _triggerSearch();
                  }
                },
                onClearTap: () {
                  _searchCtl.clear();
                  _vm.reset();
                },
              ),
            ),

            // Body
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: switch (_vm.state) {
                  _ExploreState.idle => _IdleHint(key: const ValueKey('idle')),
                  _ExploreState.loading =>
                    _LoadingSkeleton(key: const ValueKey('loading')),
                  _ExploreState.error => _ErrorBox(
                      key: const ValueKey('err'),
                      message: _vm.error ?? 'Something went wrong',
                      onRetry: _triggerSearch,
                    ),
                  _ExploreState.loaded => _LoadedView(
                      key: const ValueKey('loaded'),
                      result: _vm.result!,
                      store: store,
                      tab: _tab,
                    ),
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/* ----------------------------- UI Components ----------------------------- */

class _SearchField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final ValueChanged<String>? onSubmitted;
  final VoidCallback onSearchTap;
  final VoidCallback onPasteTap;
  final VoidCallback onClearTap;

  const _SearchField({
    required this.controller,
    required this.hint,
    required this.onSubmitted,
    required this.onSearchTap,
    required this.onPasteTap,
    required this.onClearTap,
  });

  @override
  Widget build(BuildContext context) {
    final h = math.max(48.0, MediaQuery.of(context).size.height * 0.06);
    return ConstrainedBox(
      constraints: BoxConstraints(minHeight: h, maxHeight: h),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF17192A),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white24, width: 1.1),
        ),
        child: Row(
          children: [
            const SizedBox(width: 8),
            IconButton(
              tooltip: 'Paste',
              onPressed: onPasteTap,
              icon: const Icon(Icons.content_paste, color: Colors.white60),
            ),
            Expanded(
              child: TextField(
                controller: controller,
                style: const TextStyle(color: Colors.white),
                textInputAction: TextInputAction.search,
                onSubmitted: onSubmitted,
                decoration: InputDecoration(
                  hintText: hint,
                  hintStyle: const TextStyle(color: Colors.white60),
                  border: InputBorder.none,
                  isDense: true,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 4, vertical: 12),
                ),
              ),
            ),
            if (controller.text.isNotEmpty)
              IconButton(
                tooltip: 'Clear',
                onPressed: onClearTap,
                icon: const Icon(Icons.close, color: Colors.white54),
              ),
            IconButton(
              tooltip: 'Search',
              onPressed: onSearchTap,
              icon: const Icon(Icons.search, color: Colors.white70),
            ),
          ],
        ),
      ),
    );
  }
}

class _IdleHint extends StatelessWidget {
  const _IdleHint({super.key});
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        'Enter a wallet address to explore\nportfolio, assets, and transactions.',
        textAlign: TextAlign.center,
        style: TextStyle(color: Colors.white.withOpacity(0.7)),
      ),
    );
  }
}

class _LoadingSkeleton extends StatelessWidget {
  const _LoadingSkeleton({super.key});
  @override
  Widget build(BuildContext context) {
    Widget bar([double h = 16, double w = 140]) => Container(
          height: h,
          width: w,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.08),
            borderRadius: BorderRadius.circular(8),
          ),
        );

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
      children: [
        // header card skeleton
        Container(
          padding: const EdgeInsets.all(16),
          decoration: _cardDeco(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              bar(14, 220),
              const SizedBox(height: 10),
              bar(26, 160),
              const SizedBox(height: 12),
              Row(
                children: [bar(18, 90), const SizedBox(width: 10), bar(18, 90)],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        // tabs skeleton
        Row(
          children: [
            bar(18, 60),
            const SizedBox(width: 20),
            bar(18, 60),
          ],
        ),
        const SizedBox(height: 16),
        // list skeleton
        for (int i = 0; i < 5; i++) ...[
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: const BoxDecoration(
                    color: Color(0xFF17192A), shape: BoxShape.circle),
              ),
              const SizedBox(width: 12),
              Expanded(child: bar(16, 120)),
              const SizedBox(width: 12),
              bar(14, 80),
            ],
          ),
          const Divider(height: 24, color: Colors.white10),
        ],
      ],
    );
  }
}

class _ErrorBox extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorBox({super.key, required this.message, required this.onRetry});
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Text(message, style: const TextStyle(color: Colors.white70)),
        const SizedBox(height: 12),
        OutlinedButton(
          onPressed: onRetry,
          style: OutlinedButton.styleFrom(
            foregroundColor: Colors.white,
            side: const BorderSide(color: Colors.white24),
          ),
          child: const Text('Try again'),
        ),
      ]),
    );
  }
}

class _LoadedView extends StatelessWidget {
  final _ExploreResult result;
  final CoinStore store;
  final TabController tab;

  const _LoadedView({
    super.key,
    required this.result,
    required this.store,
    required this.tab,
  });

  @override
  Widget build(BuildContext context) {
    final addressShort = _shorten(result.address);
    return Column(
      children: [
        // Header card
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
          child: Container(
            decoration: _cardDeco(),
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // left: address + portfolio
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // address
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Flexible(
                            child: Text(
                              addressShort,
                              style: const TextStyle(
                                  color: Colors.white70, fontSize: 12),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          InkWell(
                            onTap: () {
                              Clipboard.setData(
                                  ClipboardData(text: result.address));
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Address copied'),
                                  behavior: SnackBarBehavior.floating,
                                  duration: Duration(milliseconds: 900),
                                ),
                              );
                            },
                            child: const Icon(Icons.copy,
                                size: 14, color: Colors.white54),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      // value
                      Text(
                        _usd(result.portfolioUsd),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 26,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        children: [
                          _chip('${result.holdings.length} assets'),
                          _chip('${result.transactions.length} transactions'),
                        ],
                      ),
                    ],
                  ),
                ),
                // right: tiny identicon placeholder
                Container(
                  width: 48,
                  height: 48,
                  decoration: const BoxDecoration(
                    color: Color(0xFF17192A),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.account_balance_wallet,
                      color: Colors.white54, size: 22),
                ),
              ],
            ),
          ),
        ),

        // Tabs
        Align(
          alignment: Alignment.centerLeft,
          child: TabBar(
            controller: tab,
            isScrollable: true,
            labelPadding:
                const EdgeInsets.symmetric(horizontal: 20, vertical: 0),
            indicatorPadding: const EdgeInsets.symmetric(horizontal: 20),
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white54,
            labelStyle:
                const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            unselectedLabelStyle:
                const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
            indicatorColor: Colors.white,
            tabs: const [Tab(text: 'Overview'), Tab(text: 'Transactions')],
          ),
        ),

        const SizedBox(height: 6),

        // Tab content
        Expanded(
          child: TabBarView(
            controller: tab,
            children: [
              // Overview: holdings
              ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 6, 16, 16),
                itemCount: result.holdings.length,
                separatorBuilder: (_, __) =>
                    const Divider(height: 20, color: Colors.white10),
                itemBuilder: (context, i) {
                  final h = result.holdings[i];
                  final coin = store.getById(h.coinId);
                  return Row(
                    children: [
                      _CoinCircle(assetPath: coin?.assetPath, size: 30),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              coin?.name ?? h.coinId,
                              style: const TextStyle(
                                  color: Colors.white, fontSize: 15),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${_fmtAmount(h.balance)} ${coin?.symbol ?? ''}',
                              style: const TextStyle(
                                  color: Colors.white60, fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            _usd(h.usdValue),
                            style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${(h.usdValue / result.portfolioUsd * 100).toStringAsFixed(1)}%',
                            style: const TextStyle(
                                color: Colors.white60, fontSize: 12),
                          ),
                        ],
                      ),
                    ],
                  );
                },
              ),

              // Transactions
              ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 6, 16, 24),
                itemCount: result.transactions.length,
                separatorBuilder: (_, __) =>
                    const Divider(height: 22, color: Colors.white10),
                itemBuilder: (context, i) {
                  final tx = result.transactions[i];
                  final coin = store.getById(tx.coinId);
                  final isOut = tx.direction == TxDirection.outgoing;

                  return Row(
                    children: [
                      _TxStatusBullet(status: tx.status),
                      const SizedBox(width: 12),
                      _CoinCircle(assetPath: coin?.assetPath, size: 30),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              isOut ? 'Sent' : 'Received',
                              style: const TextStyle(
                                  color: Colors.white, fontSize: 15),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${_shorten(tx.txid)} • ${_fmtDate(tx.timestamp)}',
                              style: const TextStyle(
                                  color: Colors.white60, fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            '${isOut ? '-' : '+'}${_fmtAmount(tx.amount)} ${coin?.symbol ?? ''}',
                            style: TextStyle(
                              color: isOut
                                  ? const Color(0xFFE86D6D)
                                  : const Color(0xFF20C997),
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _usd(tx.usdValue),
                            style: const TextStyle(
                                color: Colors.white60, fontSize: 12),
                          ),
                        ],
                      ),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/* --------------------------------- Helpers -------------------------------- */

BoxDecoration _cardDeco() => BoxDecoration(
      color: const Color(0xFF17192A),
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: Colors.white10, width: 1),
      boxShadow: const [
        BoxShadow(color: Colors.black26, blurRadius: 20, offset: Offset(0, 8)),
      ],
    );

class _CoinCircle extends StatelessWidget {
  final String? assetPath;
  final double size;
  const _CoinCircle({this.assetPath, this.size = 28});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: const Color(0xFF17192A),
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white12, width: 1.2),
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

// Small pill chip used in the header ("X assets", "Y transactions")
Widget _chip(String label, {IconData? icon}) {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    decoration: BoxDecoration(
      color: const Color(0xFF1B1E2C),
      borderRadius: BorderRadius.circular(999),
      border: Border.all(color: Colors.white12, width: 1),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (icon != null) ...[
          Icon(icon, size: 14, color: Colors.white70),
          const SizedBox(width: 6),
        ],
        Text(
          label,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    ),
  );
}

class _TxStatusBullet extends StatelessWidget {
  final TxStatus status;
  const _TxStatusBullet({required this.status});

  @override
  Widget build(BuildContext context) {
    final innerColor = switch (status) {
      TxStatus.confirmed => const Color(0xFF20C997),
      TxStatus.pending => const Color(0xFFFFCC00),
      TxStatus.failed => const Color(0xFFE86D6D),
    };
    return Container(
      width: 22,
      height: 22,
      decoration:
          const BoxDecoration(color: Color(0xFF151827), shape: BoxShape.circle),
      child: Center(
        child: Container(
          width: 14,
          height: 14,
          decoration: BoxDecoration(color: innerColor, shape: BoxShape.circle),
        ),
      ),
    );
  }
}

String _shorten(String s, {int head = 6, int tail = 6}) {
  if (s.length <= head + tail) return s;
  return '${s.substring(0, head)}...${s.substring(s.length - tail)}';
}

String _usd(double n) {
  final abs = n.abs();
  final withSep = _thousands(n.toStringAsFixed(abs >= 1 ? 2 : 2));
  return '\$ $withSep';
}

String _thousands(String s) {
  final re = RegExp(r'(\d+)(\d{3})');
  var parts = s.split('.');
  var x = parts[0];
  var y = parts.length > 1 ? '.${parts[1]}' : '';
  while (re.hasMatch(x)) {
    x = x.replaceAllMapped(re, (m) => '${m[1]},${m[2]}');
  }
  return '$x$y';
}

String _fmtAmount(double n) {
  if (n.abs() >= 1) return n.toStringAsFixed(2);
  var s = n.toStringAsFixed(6);
  s = s.replaceFirst(RegExp(r'0+$'), '');
  if (s.endsWith('.')) s = s.substring(0, s.length - 1);
  return s;
}

String _fmtDate(DateTime dt) {
  final now = DateTime.now();
  final diff = now.difference(dt);
  if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
  if (diff.inHours < 24) return '${diff.inHours}h ago';
  if (diff.inDays < 7) return '${diff.inDays}d ago';
  return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
}

/* --------------------------------- ViewModel -------------------------------- */

enum _ExploreState { idle, loading, loaded, error }

class _ExploreVM extends ChangeNotifier {
  _ExploreState state = _ExploreState.idle;
  _ExploreResult? result;
  String? error;

  Future<void> search(String address) async {
    state = _ExploreState.loading;
    error = null;
    result = null;
    notifyListeners();

    try {
      // TODO: replace with your real API
      result = await _FakeExplorerApi.fetch(address);
      state = _ExploreState.loaded;
    } catch (e) {
      error = e.toString();
      state = _ExploreState.error;
    }
    notifyListeners();
  }

  void reset() {
    state = _ExploreState.idle;
    result = null;
    error = null;
    notifyListeners();
  }
}

/* ---------------------------------- Models ---------------------------------- */

class _ExploreResult {
  final String address;
  final double portfolioUsd;
  final List<_Holding> holdings;
  final List<_Tx> transactions;

  _ExploreResult({
    required this.address,
    required this.portfolioUsd,
    required this.holdings,
    required this.transactions,
  });
}

class _Holding {
  final String coinId; // must be a key from CoinStore (e.g., 'BTC', 'USDT-TRX')
  final double balance;
  final double usdValue;
  _Holding(
      {required this.coinId, required this.balance, required this.usdValue});
}

enum TxDirection { incoming, outgoing }

enum TxStatus { pending, confirmed, failed }

class _Tx {
  final String txid;
  final String coinId; // key from CoinStore
  final TxDirection direction;
  final TxStatus status;
  final double amount;
  final double usdValue;
  final DateTime timestamp;

  _Tx({
    required this.txid,
    required this.coinId,
    required this.direction,
    required this.status,
    required this.amount,
    required this.usdValue,
    required this.timestamp,
  });
}

/* ----------------------------- Fake API (demo) ----------------------------- */

class _FakeExplorerApi {
  static Future<_ExploreResult> fetch(String address) async {
    // simulate latency
    await Future.delayed(const Duration(milliseconds: 800));

    // pretend validation
    if (address.length < 8) {
      throw Exception('Invalid address');
    }

    // Build some deterministic-ish demo data from the address
    final seed = address.codeUnits.fold<int>(0, (a, b) => a + b);
    final r = math.Random(seed);

    final holdings = <_Holding>[
      _Holding(coinId: 'BTC', balance: 0.052734, usdValue: 0.052734 * 62000),
      _Holding(coinId: 'USDT-TRX', balance: 1250.00, usdValue: 1250.00),
      _Holding(coinId: 'ETH', balance: 0.500000, usdValue: 0.5 * 3400),
      _Holding(coinId: 'TRX', balance: 3250.00, usdValue: 3250 * 0.12),
    ];

    // compute portfolio
    final portfolio = holdings.fold<double>(0, (s, h) => s + h.usdValue);

    final now = DateTime.now();
    final txs = <_Tx>[
      _Tx(
        txid: '0x${_hex(r, 64)}',
        coinId: 'BTC',
        direction: TxDirection.outgoing,
        status: TxStatus.confirmed,
        amount: 0.003807,
        usdValue: 0.003807 * 62000,
        timestamp: now.subtract(const Duration(hours: 6)),
      ),
      _Tx(
        txid: '0x${_hex(r, 64)}',
        coinId: 'USDT-TRX',
        direction: TxDirection.incoming,
        status: TxStatus.confirmed,
        amount: 426.40,
        usdValue: 426.40,
        timestamp: now.subtract(const Duration(days: 1, hours: 3)),
      ),
      _Tx(
        txid: '0x${_hex(r, 64)}',
        coinId: 'ETH',
        direction: TxDirection.outgoing,
        status: TxStatus.pending,
        amount: 0.215000,
        usdValue: 0.215000 * 3400,
        timestamp: now.subtract(const Duration(days: 2, hours: 5)),
      ),
      _Tx(
        txid: '0x${_hex(r, 64)}',
        coinId: 'TRX',
        direction: TxDirection.incoming,
        status: TxStatus.confirmed,
        amount: 700.00,
        usdValue: 700 * 0.12,
        timestamp: now.subtract(const Duration(days: 4, hours: 8)),
      ),
    ];

    return _ExploreResult(
      address: address,
      portfolioUsd: portfolio,
      holdings: holdings,
      transactions: txs,
    );
  }

  static String _hex(math.Random r, int len) {
    const chars = '0123456789abcdef';
    return List.generate(len, (_) => chars[r.nextInt(chars.length)]).join();
  }
}
