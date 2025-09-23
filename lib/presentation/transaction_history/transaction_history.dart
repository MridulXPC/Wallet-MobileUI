// lib/presentation/transaction_history/transaction_history.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sizer/sizer.dart';

import '../../core/app_export.dart';
import '../../services/api_service.dart';
import '../../stores/wallet_store.dart';
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
  String? _error;

  List<String> _activeFilters = [];
  List<Map<String, dynamic>> _filteredTransactions = [];
  List<Map<String, dynamic>> _allTransactions = [];
  List<String>? _onlyTypesFromArgs;

  String? _lastWalletId; // refetch when active wallet changes

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);

    // Initial fetch after first frame so context is ready
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final id = context.read<WalletStore>().activeWalletId;
      _lastWalletId = id;
      _fetchTransactions(walletId: id);
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    // Watch for wallet id changes; refetch if changed
    final currentId = context.watch<WalletStore>().activeWalletId;
    if (currentId != _lastWalletId) {
      _lastWalletId = currentId;
      _fetchTransactions(walletId: currentId);
    }

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

  // ---------------- data fetch ----------------

  Future<void> _fetchTransactions({required String? walletId}) async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      // If walletId is null/empty, try to pick first from backend
      String? useId = walletId;
      if (useId == null || useId.isEmpty) {
        final wallets = await AuthService.fetchWallets();
        if (wallets.isNotEmpty) {
          useId = wallets.first['_id']?.toString();
        }
      }

      if (useId == null || useId.isEmpty) {
        setState(() {
          _allTransactions = const [];
          _filteredTransactions = const [];
          _isLoading = false;
          _error = 'No wallet available.';
        });
        return;
      }

      // Fetch from backend
      final records = await AuthService.fetchTransactionHistoryByWallet(
        walletId: useId,
        limit: 200, // adjust as desired
      );

      // Map TxRecord -> Map<String,dynamic> used by UI widgets
      final mapped = records.map(_mapTxRecordToUi).toList();

      // Sort newest first (in case backend doesn’t)
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
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Map<String, dynamic> _mapTxRecordToUi(TxRecord r) {
    // Derive a UI "type" that your chips & cards expect.
    // We prefer explicit direction/type if provided; otherwise infer.
    final raw = (r.direction ?? '').toLowerCase();
    String type;
    if (raw == 'in' || raw == 'receive' || raw == 'received') {
      type = 'receive';
    } else if (raw == 'out' || raw == 'send' || raw == 'sent') {
      type = 'send';
    } else if (raw == 'swap' || raw == 'exchange') {
      type = 'swap';
    } else if (raw == 'buy' || raw == 'purchase') {
      type = 'buy';
    } else if (raw == 'sell') {
      type = 'sell';
    } else {
      // fallback based on presence of from/to
      type = 'transfer';
    }

    // Map fields your UI uses
    return {
      "id": r.id ?? r.txHash ?? UniqueKey().toString(),
      "type": type,
      "asset": r.token ?? r.chain ?? '',
      "amount": r.amount ?? '0',
      "fiatAmount":
          r.amountUsd != null ? '\$${r.amountUsd!.toStringAsFixed(2)}' : '',
      "timestamp": r.timestamp ?? DateTime.now(),
      "status": (r.status ?? '').toLowerCase(),
      "hash": r.txHash ?? 'pending',
      "fromAddress": r.from ?? '',
      "toAddress": r.to ?? '',
      "fee": r.fee ?? '',
      // Optional/extras your UI tolerates:
      "confirmations": null,
      "note": "",
    };
  }

  // ---------------- internal (UI helpers) ----------------

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
    // If your API supports paging, call fetch with page/limit here.
    if (_isLoading) return;
    // No-op for now (list already fetched with a sensible limit).
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
      _filteredTransactions =
          _applyActiveFilters(_allTransactions); // base on all
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
      _filteredTransactions =
          _applyActiveFilters(_allTransactions); // respect active filters
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

  @override
  Widget build(BuildContext context) {
    _groupTransactionsByDate();

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
                          itemCount: _groupTransactionsByDate().length,
                          itemBuilder: (context, index) {
                            final grouped = _groupTransactionsByDate();
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
