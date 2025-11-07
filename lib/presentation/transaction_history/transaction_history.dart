// lib/presentation/transaction_history/transaction_history.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sizer/sizer.dart';

import '../../core/app_export.dart';
import '../../services/api_service.dart';
import '../../stores/wallet_store.dart';
import './widgets/transaction_card_widget.dart';
import './widgets/transaction_detail_modal_widget.dart';

// 👇 add thisa
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
      _fetchTransactions(); // no walletId required
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

  // ---------------- data fetch ----------------

  Future<void> _fetchTransactions({String? walletId}) async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      // ✅ JWT-based transaction history (not walletId)
      final records = await AuthService.fetchAllTransactionHistory(limit: 200);

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

  Map<String, dynamic> _mapTxRecordToUi(TxRecord r) {
    // normalize the backend type
    final rawType = (r.type ?? '').toString().toLowerCase();
    String type;
    if (rawType == 'receive' || rawType == 'received') {
      type = 'receive';
    } else if (rawType == 'send' || rawType == 'sent') {
      type = 'send';
    } else if (rawType == 'swap' || rawType == 'exchange') {
      type = 'swap';
    } else if (rawType == 'buy' || rawType == 'purchase') {
      type = 'buy';
    } else if (rawType == 'sell') {
      type = 'sell';
    } else {
      type = rawType.isNotEmpty ? rawType : 'transfer';
    }

    // createdAt in your payload; try to parse safely if your model stores String
    DateTime ts;
    final created = r.createdAt; // DateTime? (recommended)
    if (created is DateTime) {
      ts = created;
    } else {
      // if your model stores createdAt as String, parse it:
      ts = DateTime.now(); // Default to current time if parsing fails
    }

    // optional: numeric USD amount if your model has it; otherwise null
    final double? amtUsd =
        (r.amountUsd is num) ? (r.amountUsd as num).toDouble() : null;

    return {
      "id": r.id ?? r.txHash ?? UniqueKey().toString(),
      "type": type,
      "asset": (r.token?.isNotEmpty == true) ? r.token : (r.chain ?? ''),
      "amount": r.amount ?? '0',
      "amountUsd": amtUsd, // numeric, for later FX formatting
      "fiatAmount": "", // fill at render time
      "timestamp": ts, // DateTime
      "status": (r.status ?? '').toString().toLowerCase(),
      "hash": r.txHash ?? 'pending',
      "fromAddress": r.fromAddress ?? '',
      "toAddress": r.toAddress ?? '',
      "fee": r.fee?.toString() ?? '',
      "confirmations": null,
      "note": "",
    };
  }

  // ---------------- internal (UI helpers) ----------------

  void _applyInitialTypeFilter(List<String> allowedTypes) {
    setState(() {
      _activeFilters =
          allowedTypes.map((t) => t[0].toUpperCase() + t.substring(1)).toList();

      _filteredTransactions = _allTransactions
          .where((t) => allowedTypes.contains(
                (t['type'] ?? '').toString().toLowerCase(),
              ))
          .toList();
    });
  }

  void _onScroll() {
    if (_scrollController.position.pixels ==
        _scrollController.position.maxScrollExtent) {
      _loadMoreTransactions();
    }
  }

  void _loadMoreTransactions() {
    if (_isLoading) return;
    // paging hook
  }

  void _filterTransactions(String query) {
    final q = query.toLowerCase();
    setState(() {
      final base = _applyActiveFilters(_allTransactions);
      if (q.isEmpty) {
        _filteredTransactions = base;
      } else {
        _filteredTransactions = base.where((t) {
          final hash = (t['hash'] ?? '').toString().toLowerCase();
          final amount = (t['amount'] ?? '').toString().toLowerCase();
          final address = (t['toAddress'] ?? '').toString().toLowerCase();
          final asset = (t['asset'] ?? '').toString().toLowerCase();
          return hash.contains(q) ||
              amount.contains(q) ||
              address.contains(q) ||
              asset.contains(q);
        }).toList();
      }
    });
  }

  void _applyFilters() {
    setState(() {
      _filteredTransactions = _applyActiveFilters(_allTransactions);
    });
  }

  List<Map<String, dynamic>> _applyActiveFilters(
      List<Map<String, dynamic>> source) {
    if (_activeFilters.isEmpty) return List.from(source);
    final want = _activeFilters.map((f) => f.toLowerCase()).toSet();
    return source
        .where((t) => want.contains((t['type'] ?? '').toString().toLowerCase()))
        .toList();
  }

  void _removeFilter(String filter) {
    setState(() => _activeFilters.remove(filter));
    _applyFilters();
  }

  void _showTransactionDetail(Map<String, dynamic> transaction) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => TransactionDetailModalWidget(
        transaction: transaction,
      ),
    );
  }

  Future<void> _refreshTransactions() async {
    await _fetchTransactions(walletId: _lastWalletId);
    setState(() {
      _filteredTransactions = _applyActiveFilters(_allTransactions);
    });
  }

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

  // ---- currency helpers
  String _formatFiat(BuildContext context, double? usd) {
    final fx = context.read<CurrencyNotifier>();
    if (usd == null) return fx.formatFromUsd(0);
    return fx.formatFromUsd(usd);
  }

  @override
  Widget build(BuildContext context) {
    // 👇 listen for currency changes to re-render amounts
    context.watch<CurrencyNotifier>();

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
        actions: [],
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
                        suffixIcon: _searchController.text.isNotEmpty
                            ? IconButton(
                                onPressed: () {
                                  _searchController.clear();
                                  _filterTransactions('');
                                },
                                icon: CustomIconWidget(
                                  iconName: 'clear',
                                  color: AppTheme
                                      .darkTheme.colorScheme.onSurface
                                      .withValues(alpha: 0.6),
                                  size: 20,
                                ),
                              )
                            : null,
                      ),
                    ),
                  )
                : const SizedBox.shrink(),
          ),

          // Active Filters (chips)
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
                      label: Text(
                        filter,
                        style: TextStyle(
                            color: AppTheme.onPrimary, fontSize: 12.sp),
                      ),
                      backgroundColor: AppTheme.info,
                      deleteIcon: CustomIconWidget(
                        iconName: 'close',
                        color: AppTheme.onPrimary,
                        size: 16,
                      ),
                      onDeleted: () => _removeFilter(filter),
                    ),
                  );
                },
              ),
            ),

          // Error banner
          if (_error != null)
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 1.h),
              child: Row(
                children: [
                  const Icon(Icons.error_outline, color: Colors.redAccent),
                  SizedBox(width: 2.w),
                  Expanded(
                    child: Text(
                      _error!,
                      style: AppTheme.darkTheme.textTheme.bodySmall?.copyWith(
                        color: Colors.redAccent,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () =>
                        _fetchTransactions(walletId: _lastWalletId),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            ),

          // Transaction List
          Expanded(
            child: _isLoading
                ? Center(
                    child: CircularProgressIndicator(
                      color: AppTheme.info,
                      strokeWidth: 2,
                    ),
                  )
                : _filteredTransactions.isEmpty
                    ? _buildEmptyState()
                    : RefreshIndicator(
                        onRefresh: _refreshTransactions,
                        color: AppTheme.info,
                        backgroundColor: AppTheme.darkTheme.colorScheme.surface,
                        child: ListView.builder(
                          controller: _scrollController,
                          padding: EdgeInsets.symmetric(horizontal: 4.w),
                          itemCount: grouped.length,
                          itemBuilder: (context, index) {
                            final item = grouped[index];

                            if (item['type'] == 'header') {
                              return _buildDateHeader(item['title'] as String);
                            }

                            // 👇 Clone and inject currency-formatted fiat for the current selection
                            final cloned = Map<String, dynamic>.from(item);
                            final double? usd = cloned['amountUsd'] as double?;
                            cloned['fiatAmount'] = _formatFiat(context, usd);

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
          CustomIconWidget(
            iconName: 'receipt_long',
            color:
                AppTheme.darkTheme.colorScheme.onSurface.withValues(alpha: 0.3),
            size: 80,
          ),
          SizedBox(height: 3.h),
          Text(
            'No transactions yet',
            style: AppTheme.darkTheme.textTheme.headlineSmall?.copyWith(
              color: AppTheme.darkTheme.colorScheme.onSurface
                  .withValues(alpha: 0.6),
            ),
          ),
          SizedBox(height: 2.h),
          Text(
            'Your transaction history will appear here\nonce you start trading',
            style: AppTheme.darkTheme.textTheme.bodyMedium?.copyWith(
              color: AppTheme.darkTheme.colorScheme.onSurface
                  .withValues(alpha: 0.4),
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 4.h),
        ],
      ),
    );
  }

  Widget _buildDateHeader(String title) {
    return Container(
      padding: EdgeInsets.symmetric(vertical: 2.h),
      child: Text(
        title,
        style: AppTheme.darkTheme.textTheme.titleMedium?.copyWith(
          color:
              AppTheme.darkTheme.colorScheme.onSurface.withValues(alpha: 0.7),
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  void _handleSwipeAction(String action, Map<String, dynamic> transaction) {
    switch (action) {
      case 'details':
        _showTransactionDetail(transaction);
        break;
      case 'share':
        // Implement share functionality
        break;
      case 'note':
        // Implement add note functionality
        break;
    }
  }
}
