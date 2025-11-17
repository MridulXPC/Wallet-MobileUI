// lib/presentation/transaction_history/transaction_history.dart
import 'package:cryptowallet/stores/portfolio_store.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sizer/sizer.dart';

import '../../core/app_export.dart';
import '../../services/api_service.dart';
import '../../stores/wallet_store.dart';
import '../../stores/coin_store.dart';
import './widgets/transaction_card_widget.dart';
import './widgets/transaction_detail_modal_widget.dart';

// 👇 currency
import 'package:cryptowallet/core/currency_notifier.dart';

class TransactionHistory extends StatefulWidget {
  final List<String>? onlyTypes;

  const TransactionHistory({super.key, this.onlyTypes});

  static Route<void> routeForActivity() => MaterialPageRoute(
        builder: (_) => const TransactionHistory(
          onlyTypes: ['buy', 'sell', 'swap'],
        ),
      );

  @override
  State<TransactionHistory> createState() => _TransactionHistoryState();
}

class _TransactionHistoryState extends State<TransactionHistory>
    with TickerProviderStateMixin {
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  bool _isSearchExpanded = false;
  bool _isLoading = false;
  String? _error;

  List<String> _activeFilters = [];
  List<Map<String, dynamic>> _filteredTransactions = [];
  List<Map<String, dynamic>> _allTransactions = [];
  List<String>? _onlyTypesFromArgs;

  String? _lastWalletId;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fetchTransactions();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    final currentId = context.watch<WalletStore>().activeWalletId;
    if (currentId != _lastWalletId) {
      _lastWalletId = currentId;
      _fetchTransactions(walletId: currentId);
    }

    final args =
        ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    _onlyTypesFromArgs = args?['onlyTypes'] != null
        ? List<String>.from(args!['onlyTypes'] as List)
        : null;

    final initial = widget.onlyTypes ?? _onlyTypesFromArgs;
    if (initial != null && initial.isNotEmpty) {
      _applyInitialTypeFilter(initial.map((e) => e.toLowerCase()).toList());
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  // ---------------- Fetch using correct API ----------------

  Future<void> _fetchTransactions({String? walletId}) async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      walletId ??= await AuthService.getStoredWalletId();
      if (walletId == null || walletId.isEmpty) {
        throw "No wallet selected.";
      }

      final records = await AuthService.fetchTransactionHistoryByWallet(
        walletId: walletId,
        limit: 200,
      );

      final mapped = records.map(_mapTxRecordToUi).toList();

      mapped.sort((a, b) {
        final ta = a['timestamp'] as DateTime?;
        final tb = b['timestamp'] as DateTime?;
        if (ta == null && tb == null) return 0;
        if (ta == null) return 1;
        if (tb == null) return -1;
        return tb.compareTo(ta);
      });

      setState(() {
        _allTransactions = mapped;
        _filteredTransactions = _applyActiveFilters(mapped);
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _allTransactions = const [];
        _filteredTransactions = const [];
      });
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ---------------- Convert API model → UI map ----------------

  Map<String, dynamic> _mapTxRecordToUi(TxRecord r) {
    final coinStore = context.read<CoinStore>();

    final typeRaw = (r.type ?? "").toLowerCase();
    String type;

    double? amtUsd =
        (r.amountUsd is num) ? (r.amountUsd as num).toDouble() : null;

    if (typeRaw.contains("receive"))
      type = "receive";
    else if (typeRaw.contains("send"))
      type = "send";
    else if (typeRaw.contains("swap"))
      type = "swap";
    else if (typeRaw.contains("buy"))
      type = "buy";
    else if (typeRaw.contains("sell"))
      type = "sell";
    else
      type = typeRaw.isEmpty ? "transfer" : typeRaw;

    final created = r.createdAt;
    final ts = created is DateTime ? created : DateTime.now();

    final usd = (r.amountUsd is num) ? (r.amountUsd as num).toDouble() : null;

    final sym = (r.token?.isNotEmpty == true) ? r.token! : (r.chain ?? "");

    final coin = coinStore.getById(sym) ?? coinStore.getById(r.chain ?? "");

    return {
      "id": r.id ?? r.txHash ?? UniqueKey().toString(),
      "type": type,
      "asset": sym,
      "assetIcon": coin?.assetPath ?? "assets/images/no-image.jpg",
      "amount": r.amount ?? "0",
      "amountUsd": usd,
      "timestamp": ts,
      "status": (r.status ?? "").toLowerCase(),
      "hash": r.txHash ?? "pending",
      "fromAddress": r.fromAddress ?? "",
      "toAddress": r.toAddress ?? "",
      "fee": r.fee?.toString() ?? "",
    };
  }

  // ---------------- Filtering & Searching ----------------

  void _applyInitialTypeFilter(List<String> allowed) {
    setState(() {
      _activeFilters =
          allowed.map((t) => t[0].toUpperCase() + t.substring(1)).toList();

      _filteredTransactions = _allTransactions
          .where((t) =>
              allowed.contains((t['type'] ?? '').toString().toLowerCase()))
          .toList();
    });
  }

  List<Map<String, dynamic>> _applyActiveFilters(
      List<Map<String, dynamic>> source) {
    if (_activeFilters.isEmpty) {
      return List<Map<String, dynamic>>.from(source);
    }

    final want = _activeFilters.map((e) => e.toLowerCase()).toSet();

    return source
        .where((t) => want.contains((t['type'] ?? '').toString().toLowerCase()))
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }

  void _onScroll() {
    if (_scrollController.position.pixels ==
        _scrollController.position.maxScrollExtent) {
      _loadMoreTransactions();
    }
  }

  void _loadMoreTransactions() {
    // pagination future
  }

  void _filterTransactions(String q) {
    q = q.toLowerCase();
    setState(() {
      final base = _applyActiveFilters(_allTransactions);
      if (q.isEmpty) {
        _filteredTransactions = base;
      } else {
        _filteredTransactions = base.where((t) {
          return (t['hash'] ?? '').toString().toLowerCase().contains(q) ||
              (t['asset'] ?? '').toString().toLowerCase().contains(q) ||
              (t['amount'] ?? '').toString().toLowerCase().contains(q) ||
              (t['toAddress'] ?? '').toString().toLowerCase().contains(q);
        }).toList();
      }
    });
  }

  Future<void> _refreshTransactions() async {
    await _fetchTransactions(walletId: _lastWalletId);
    setState(() {
      _filteredTransactions = _applyActiveFilters(_allTransactions);
    });
  }

  // ---------------- Group by Date ----------------

  List<Map<String, dynamic>> _groupTransactionsByDate() {
    final grouped = <String, List<Map<String, dynamic>>>{};

    for (var t in _filteredTransactions) {
      final date = (t['timestamp'] ?? DateTime.now()) as DateTime;
      final key = _dateKey(date);
      grouped.putIfAbsent(key, () => []).add(t);
    }

    final result = <Map<String, dynamic>>[];
    grouped.forEach((k, txs) {
      result.add({'type': 'header', 'title': k});
      result.addAll(txs.map((t) => {...t, 'type': 'transaction'}));
    });

    return result;
  }

  String _dateKey(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final d = DateTime(date.year, date.month, date.day);

    if (d == today) return 'Today';
    if (d == yesterday) return 'Yesterday';
    if (now.difference(date).inDays <= 7) return 'This Week';
    return '${date.day}/${date.month}/${date.year}';
  }

  // ---------------- Currency formatting ----------------

  String _formatFiat(BuildContext context, double? usd) {
    final fx = context.read<CurrencyNotifier>();
    return fx.formatFromUsd(usd ?? 0.0);
  }

  // ---------------- UI ----------------

  @override
  Widget build(BuildContext context) {
    context.watch<CurrencyNotifier>(); // watches currency changes

    final grouped = _groupTransactionsByDate();

    return Scaffold(
      backgroundColor: const Color(0xFF0B0D1A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0B0D1A),
        elevation: 0,
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: CustomIconWidget(
            iconName: 'arrow_back',
            color: AppTheme.darkTheme.colorScheme.onSurface,
            size: 24,
          ),
        ),
        title: Text('Transaction History',
            style: AppTheme.darkTheme.textTheme.titleLarge),
      ),
      body: Column(
        children: [
          // Search Bar
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            height: _isSearchExpanded ? 12.h : 0,
            child: _isSearchExpanded
                ? Container(
                    padding:
                        EdgeInsets.symmetric(horizontal: 4.w, vertical: 2.h),
                    child: TextField(
                      controller: _searchController,
                      onChanged: _filterTransactions,
                      style: AppTheme.darkTheme.textTheme.bodyMedium,
                      decoration: InputDecoration(
                        hintText:
                            'Search by hash, amount, address, or asset...',
                        prefixIcon: CustomIconWidget(
                          iconName: 'search',
                          color: AppTheme.darkTheme.colorScheme.onSurface
                              .withValues(alpha: 0.6),
                          size: 20,
                        ),
                      ),
                    ),
                  )
                : const SizedBox.shrink(),
          ),

          if (_activeFilters.isNotEmpty)
            Container(
              height: 8.h,
              padding: EdgeInsets.symmetric(horizontal: 4.w),
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: _activeFilters.length,
                itemBuilder: (context, index) {
                  final filter = _activeFilters[index];
                  return Container(
                    margin: EdgeInsets.only(right: 2.w, top: 1.h, bottom: 1.h),
                    child: Chip(
                      label: Text(filter,
                          style: TextStyle(
                              color: AppTheme.onPrimary, fontSize: 12.sp)),
                      backgroundColor: AppTheme.info,
                      deleteIcon: CustomIconWidget(
                        iconName: 'close',
                        color: AppTheme.onPrimary,
                        size: 16,
                      ),
                      onDeleted: () => setState(() {
                        _activeFilters.remove(filter);
                        _applyActiveFilters(_allTransactions);
                      }),
                    ),
                  );
                },
              ),
            ),

          if (_error != null)
            Padding(
              padding: EdgeInsets.all(4.w),
              child: Text(_error!,
                  style: const TextStyle(color: Colors.redAccent)),
            ),

          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : _filteredTransactions.isEmpty
                    ? _buildEmptyState()
                    : RefreshIndicator(
                        onRefresh: _refreshTransactions,
                        child: ListView.builder(
                          controller: _scrollController,
                          padding: EdgeInsets.symmetric(horizontal: 4.w),
                          itemCount: grouped.length,
                          itemBuilder: (context, index) {
                            final item = grouped[index];
                            if (item['type'] == 'header') {
                              return _buildDateHeader(item['title']);
                            }

                            final portfolio = context.read<PortfolioStore>();
                            final coinStore = context.read<CoinStore>();

                            final cloned = Map<String, dynamic>.from(item);

                            double? usd = cloned['amountUsd'] as double?;

// If USD not sent by backend → calculate manually
                            if (usd == null) {
                              final String asset =
                                  (cloned['asset'] ?? '').toString();
                              final token = portfolio.getBySymbol(asset);

                              if (token != null) {
                                final double amount =
                                    double.tryParse(cloned['amount'] ?? "0") ??
                                        0;
                                usd = token.value == 0
                                    ? 0
                                    : amount *
                                        (token.value /
                                            token.balance); // USD per token
                              }
                            }

                            // cloned['fiatAmount'] =
                            //     _formatFiat(context, usd ?? 0);

                            return TransactionCardWidget(
                              transaction: cloned,
                              onTap: () => _showTransactionDetail(cloned),
                              onSwipeAction: (action) =>
                                  _handleSwipeAction(action, cloned),
                            );
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.receipt_long,
              color: Colors.white.withOpacity(0.3), size: 80),
          SizedBox(height: 2.h),
          Text('No transactions yet',
              style: TextStyle(color: Colors.white70, fontSize: 14.sp)),
        ],
      ),
    );
  }

  Widget _buildDateHeader(String title) {
    return Padding(
      padding: EdgeInsets.only(top: 2.h, bottom: 1.h),
      child: Text(
        title,
        style: TextStyle(
          color: Colors.white70,
          fontWeight: FontWeight.w600,
          fontSize: 13.sp,
        ),
      ),
    );
  }

  void _showTransactionDetail(Map<String, dynamic> tx) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent, // important
      builder: (_) {
        return Container(
          decoration: const BoxDecoration(
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color.fromARGB(255, 6, 11, 33), // top
                Color.fromARGB(255, 0, 0, 0), // middle
                Color.fromARGB(255, 0, 12, 56), // bottom
              ],
            ),
          ),
          child: TransactionDetailModalWidget(transaction: tx),
        );
      },
    );
  }

  void _handleSwipeAction(String action, Map<String, dynamic> tx) {}
}
