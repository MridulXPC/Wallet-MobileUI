// lib/presentation/transaction_history/transaction_history.dart
import 'package:flutter/material.dart';
import 'package:sizer/sizer.dart';

import '../../core/app_export.dart';
import './widgets/filter_bottom_sheet_widget.dart';
import './widgets/transaction_card_widget.dart';
import './widgets/transaction_detail_modal_widget.dart';

class TransactionHistory extends StatefulWidget {
  /// Limit the screen to only these types (e.g. ['buy','sell','swap']).
  /// If null/empty, all types are shown.
  final List<String>? onlyTypes;

  const TransactionHistory({super.key, this.onlyTypes});

  /// Convenience: use this when pushing from the Activity card
  /// to show only Buy/Sell/Swap.
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

  List<String> _activeFilters = [];
  List<Map<String, dynamic>> _filteredTransactions = [];
  List<Map<String, dynamic>> _allTransactions = [];
  List<String>? _onlyTypesFromArgs;

  // Mock transaction data (added a couple of SWAP rows)
  final List<Map<String, dynamic>> _mockTransactions = [
    {
      "id": "tx_001",
      "type": "receive",
      "asset": "BTC",
      "amount": "0.00234567",
      "fiatAmount": "\$156.78",
      "timestamp": DateTime.now().subtract(const Duration(minutes: 30)),
      "status": "confirmed",
      "hash": "1A1zP1eP5QGefi2DMPTfTL5SLmv7DivfNa",
      "fromAddress": "bc1qxy2kgdygjrsqtzq2n0yrf2493p83kkfjhx0wlh",
      "toAddress": "bc1qw508d6qejxtdg4y5r3zarvary0c5xw7kv8f3t4",
      "fee": "0.00001234",
      "confirmations": 6,
      "note": ""
    },
    {
      "id": "tx_002",
      "type": "send",
      "asset": "ETH",
      "amount": "0.5",
      "fiatAmount": "\$1,234.50",
      "timestamp": DateTime.now().subtract(const Duration(hours: 2)),
      "status": "confirmed",
      "hash": "0x742d35cc6e4c4e0c4e4e4e4e4e4e4e4e4e4e4e4e",
      "fromAddress": "0x742d35...",
      "toAddress": "0x8ba1f1095...",
      "fee": "0.002",
      "confirmations": 12,
      "note": "Payment for services"
    },
    {
      "id": "tx_003",
      "type": "buy",
      "asset": "BTC",
      "amount": "0.01",
      "fiatAmount": "\$670.00",
      "timestamp": DateTime.now().subtract(const Duration(hours: 5)),
      "status": "pending",
      "hash": "pending",
      "fromAddress": "Coinbase Exchange",
      "toAddress": "bc1qw508d6qejx...",
      "fee": "0.00",
      "confirmations": 0,
      "note": ""
    },
    {
      "id": "tx_004",
      "type": "sell",
      "asset": "ETH",
      "amount": "1.0",
      "fiatAmount": "\$2,469.00",
      "timestamp": DateTime.now().subtract(const Duration(days: 1)),
      "status": "confirmed",
      "hash": "0x8ba1f109...",
      "fromAddress": "0x742d35...",
      "toAddress": "Binance Exchange",
      "fee": "0.003",
      "confirmations": 25,
      "note": "Profit taking"
    },
    {
      "id": "tx_005",
      "type": "receive",
      "asset": "USDT",
      "amount": "500.00",
      "fiatAmount": "\$500.00",
      "timestamp": DateTime.now().subtract(const Duration(days: 2)),
      "status": "confirmed",
      "hash": "0x9cb2f10...",
      "fromAddress": "0x8ba1f109...",
      "toAddress": "0x742d35...",
      "fee": "0.00",
      "confirmations": 50,
      "note": "Freelance payment"
    },
    {
      "id": "tx_006",
      "type": "send",
      "asset": "BTC",
      "amount": "0.005",
      "fiatAmount": "\$335.00",
      "timestamp": DateTime.now().subtract(const Duration(days: 3)),
      "status": "confirmed",
      "hash": "1B2zP1eP...",
      "fromAddress": "bc1qw508d6qejx...",
      "toAddress": "bc1qxy2kgdygjr...",
      "fee": "0.00000567",
      "confirmations": 100,
      "note": "Gift to friend"
    },
    // NEW: swap examples
    {
      "id": "tx_007",
      "type": "swap",
      "asset": "BTC",
      "amount": "0.002",
      "fiatAmount": "\$134.00",
      "timestamp":
          DateTime.now().subtract(const Duration(hours: 3, minutes: 10)),
      "status": "confirmed",
      "hash": "swap_0x001",
      "fromAddress": "ETH",
      "toAddress": "BTC",
      "fee": "0.000001",
      "confirmations": 22,
      "note": "ETH → BTC"
    },
    {
      "id": "tx_008",
      "type": "swap",
      "asset": "USDT",
      "amount": "250",
      "fiatAmount": "\$250.00",
      "timestamp": DateTime.now().subtract(const Duration(days: 1, hours: 4)),
      "status": "confirmed",
      "hash": "swap_0x002",
      "fromAddress": "BTC",
      "toAddress": "USDT",
      "fee": "15 TRX",
      "confirmations": 18,
      "note": "BTC → USDT"
    },
  ];

  @override
  void initState() {
    super.initState();
    _allTransactions = List.from(_mockTransactions);
    _filteredTransactions = List.from(_mockTransactions);
    _scrollController.addListener(_onScroll);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Allow passing types via Navigator arguments too.
    final args =
        ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    _onlyTypesFromArgs = args?['onlyTypes'] != null
        ? List<String>.from(args!['onlyTypes'] as List)
        : null;

    // If either widget.onlyTypes or args.onlyTypes is set, apply it.
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

  // ---------------- internal ----------------

  void _applyInitialTypeFilter(List<String> allowedTypes) {
    setState(() {
      _activeFilters = allowedTypes
          .map((t) => t[0].toUpperCase() + t.substring(1)) // for chips display
          .toList();

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
    setState(() => _isLoading = true);
    Future.delayed(const Duration(seconds: 2), () {
      if (!mounted) return;
      setState(() => _isLoading = false);
    });
  }

  void _toggleSearch() {
    setState(() {
      _isSearchExpanded = !_isSearchExpanded;
      if (!_isSearchExpanded) {
        _searchController.clear();
        _filterTransactions('');
      }
    });
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
          return hash.contains(q) || amount.contains(q) || address.contains(q);
        }).toList();
      }
    });
  }

  void _showFilterBottomSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => FilterBottomSheetWidget(
        onFiltersApplied: (filters) {
          setState(() => _activeFilters = filters);
          _applyFilters();
        },
        activeFilters: _activeFilters,
      ),
    );
  }

  void _applyFilters() {
    setState(() {
      _filteredTransactions =
          _applyActiveFilters(_allTransactions); // base on all
    });
  }

  List<Map<String, dynamic>> _applyActiveFilters(
      List<Map<String, dynamic>> source) {
    if (_activeFilters.isEmpty) return List.from(source);
    final want = _activeFilters
        .map((f) => f.toLowerCase())
        .toSet(); // e.g. {send, receive, buy, sell, swap}
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
    await Future.delayed(const Duration(seconds: 1));
    setState(() {
      _filteredTransactions =
          _applyActiveFilters(_allTransactions); // respect active filters
    });
  }

  List<Map<String, dynamic>> _groupTransactionsByDate() {
    final grouped = <String, List<Map<String, dynamic>>>{};
    for (var t in _filteredTransactions) {
      final date = t['timestamp'] as DateTime;
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

  @override
  Widget build(BuildContext context) {
    final grouped = _groupTransactionsByDate();

    return Scaffold(
      backgroundColor: Color(0xFF0B0D1A),
      appBar: AppBar(
        backgroundColor: Color(0xFF0B0D1A),
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
        actions: [
          // IconButton(
          //   onPressed: _toggleSearch,
          //   icon: CustomIconWidget(
          //     iconName: _isSearchExpanded ? 'close' : 'search',
          //     color: AppTheme.darkTheme.colorScheme.onSurface,
          //     size: 24,
          //   ),
          // ),
          // IconButton(
          //   onPressed: _showFilterBottomSheet,
          //   icon: Stack(
          //     children: [
          //       CustomIconWidget(
          //         iconName: 'filter_list',
          //         color: AppTheme.darkTheme.colorScheme.onSurface,
          //         size: 24,
          //       ),
          //       if (_activeFilters.isNotEmpty)
          //         Positioned(
          //           right: 0,
          //           top: 0,
          //           child: Container(
          //             padding: EdgeInsets.all(1.w),
          //             decoration: BoxDecoration(
          //               color: AppTheme.info,
          //               shape: BoxShape.circle,
          //             ),
          //             constraints:
          //                 BoxConstraints(minWidth: 4.w, minHeight: 4.w),
          //             child: Text(
          //               '${_activeFilters.length}',
          //               style: TextStyle(
          //                 color: AppTheme.onPrimary,
          //                 fontSize: 8.sp,
          //                 fontWeight: FontWeight.bold,
          //               ),
          //               textAlign: TextAlign.center,
          //             ),
          //           ),
          //         ),
          //     ],
          //   ),
          // ),
          // SizedBox(width: 2.w),
        ],
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
                        hintText: 'Search by hash, amount, or address...',
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

          // Transaction List
          Expanded(
            child: _filteredTransactions.isEmpty
                ? _buildEmptyState()
                : RefreshIndicator(
                    onRefresh: _refreshTransactions,
                    color: AppTheme.info,
                    backgroundColor: AppTheme.darkTheme.colorScheme.surface,
                    child: ListView.builder(
                      controller: _scrollController,
                      padding: EdgeInsets.symmetric(horizontal: 4.w),
                      itemCount: grouped.length + (_isLoading ? 1 : 0),
                      itemBuilder: (context, index) {
                        if (index == grouped.length) {
                          return _buildLoadingIndicator();
                        }

                        final item = grouped[index];
                        if (item['type'] == 'header') {
                          return _buildDateHeader(item['title'] as String);
                        } else {
                          return TransactionCardWidget(
                            transaction: item,
                            onTap: () => _showTransactionDetail(item),
                            onSwipeAction: (action) =>
                                _handleSwipeAction(action, item),
                          );
                        }
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
          ElevatedButton(
            onPressed: () =>
                Navigator.pushNamed(context, '/main-wallet-dashboard'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.info,
              foregroundColor: AppTheme.onPrimary,
              padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 2.h),
            ),
            child: Text(
              'Buy Crypto',
              style: TextStyle(
                fontSize: 14.sp,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
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

  Widget _buildLoadingIndicator() {
    return Container(
      padding: EdgeInsets.all(4.w),
      child: Center(
        child: CircularProgressIndicator(
          color: AppTheme.info,
          strokeWidth: 2,
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
