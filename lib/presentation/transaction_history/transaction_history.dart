import 'package:flutter/material.dart';
import 'package:sizer/sizer.dart';

import '../../core/app_export.dart';
import './widgets/filter_bottom_sheet_widget.dart';
import './widgets/transaction_card_widget.dart';
import './widgets/transaction_detail_modal_widget.dart';

class TransactionHistory extends StatefulWidget {
  const TransactionHistory({super.key});

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

  // Mock transaction data
  final List<Map<String, dynamic>> _mockTransactions = [
    {
      "id": "tx_001",
      "type": "receive",
      "asset": "BTC",
      "assetIcon": "https://cryptologos.cc/logos/bitcoin-btc-logo.png",
      "amount": "0.00234567",
      "fiatAmount": "\$156.78",
      "timestamp": DateTime.now().subtract(Duration(minutes: 30)),
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
      "assetIcon": "https://cryptologos.cc/logos/ethereum-eth-logo.png",
      "amount": "0.5",
      "fiatAmount": "\$1,234.50",
      "timestamp": DateTime.now().subtract(Duration(hours: 2)),
      "status": "confirmed",
      "hash": "0x742d35cc6e4c4e0c4e4e4e4e4e4e4e4e4e4e4e4e",
      "fromAddress": "0x742d35cc6e4c4e0c4e4e4e4e4e4e4e4e4e4e4e4e",
      "toAddress": "0x8ba1f109551bD432803012645Hac136c22C501e5",
      "fee": "0.002",
      "confirmations": 12,
      "note": "Payment for services"
    },
    {
      "id": "tx_003",
      "type": "buy",
      "asset": "BTC",
      "assetIcon": "https://cryptologos.cc/logos/bitcoin-btc-logo.png",
      "amount": "0.01",
      "fiatAmount": "\$670.00",
      "timestamp": DateTime.now().subtract(Duration(hours: 5)),
      "status": "pending",
      "hash": "pending",
      "fromAddress": "Coinbase Exchange",
      "toAddress": "bc1qw508d6qejxtdg4y5r3zarvary0c5xw7kv8f3t4",
      "fee": "0.00",
      "confirmations": 0,
      "note": ""
    },
    {
      "id": "tx_004",
      "type": "sell",
      "asset": "ETH",
      "assetIcon": "https://cryptologos.cc/logos/ethereum-eth-logo.png",
      "amount": "1.0",
      "fiatAmount": "\$2,469.00",
      "timestamp": DateTime.now().subtract(Duration(days: 1)),
      "status": "confirmed",
      "hash": "0x8ba1f109551bD432803012645Hac136c22C501e5",
      "fromAddress": "0x742d35cc6e4c4e0c4e4e4e4e4e4e4e4e4e4e4e4e",
      "toAddress": "Binance Exchange",
      "fee": "0.003",
      "confirmations": 25,
      "note": "Profit taking"
    },
    {
      "id": "tx_005",
      "type": "receive",
      "asset": "USDT",
      "assetIcon": "https://cryptologos.cc/logos/tether-usdt-logo.png",
      "amount": "500.00",
      "fiatAmount": "\$500.00",
      "timestamp": DateTime.now().subtract(Duration(days: 2)),
      "status": "confirmed",
      "hash": "0x9cb2f109551bD432803012645Hac136c22C501e6",
      "fromAddress": "0x8ba1f109551bD432803012645Hac136c22C501e5",
      "toAddress": "0x742d35cc6e4c4e0c4e4e4e4e4e4e4e4e4e4e4e4e",
      "fee": "0.00",
      "confirmations": 50,
      "note": "Freelance payment"
    },
    {
      "id": "tx_006",
      "type": "send",
      "asset": "BTC",
      "assetIcon": "https://cryptologos.cc/logos/bitcoin-btc-logo.png",
      "amount": "0.005",
      "fiatAmount": "\$335.00",
      "timestamp": DateTime.now().subtract(Duration(days: 3)),
      "status": "confirmed",
      "hash": "1B2zP1eP5QGefi2DMPTfTL5SLmv7DivfNb",
      "fromAddress": "bc1qw508d6qejxtdg4y5r3zarvary0c5xw7kv8f3t4",
      "toAddress": "bc1qxy2kgdygjrsqtzq2n0yrf2493p83kkfjhx0wlh",
      "fee": "0.00000567",
      "confirmations": 100,
      "note": "Gift to friend"
    }
  ];

  @override
  void initState() {
    super.initState();
    _allTransactions = List.from(_mockTransactions);
    _filteredTransactions = List.from(_mockTransactions);
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels ==
        _scrollController.position.maxScrollExtent) {
      _loadMoreTransactions();
    }
  }

  void _loadMoreTransactions() {
    if (!_isLoading) {
      setState(() {
        _isLoading = true;
      });

      // Simulate loading more data
      Future.delayed(Duration(seconds: 2), () {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      });
    }
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
    setState(() {
      if (query.isEmpty) {
        _filteredTransactions = List.from(_allTransactions);
      } else {
        _filteredTransactions = _allTransactions.where((transaction) {
          final hash = (transaction['hash'] as String).toLowerCase();
          final amount = (transaction['amount'] as String).toLowerCase();
          final address = (transaction['toAddress'] as String).toLowerCase();
          final searchQuery = query.toLowerCase();

          return hash.contains(searchQuery) ||
              amount.contains(searchQuery) ||
              address.contains(searchQuery);
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
          setState(() {
            _activeFilters = filters;
          });
          _applyFilters();
        },
        activeFilters: _activeFilters,
      ),
    );
  }

  void _applyFilters() {
    setState(() {
      _filteredTransactions = _allTransactions.where((transaction) {
        if (_activeFilters.isEmpty) return true;

        bool matchesFilter = true;

        for (String filter in _activeFilters) {
          if (filter == 'Send' && transaction['type'] != 'send') {
            matchesFilter = false;
            break;
          }
          if (filter == 'Receive' && transaction['type'] != 'receive') {
            matchesFilter = false;
            break;
          }
          if (filter == 'Buy' && transaction['type'] != 'buy') {
            matchesFilter = false;
            break;
          }
          if (filter == 'Sell' && transaction['type'] != 'sell') {
            matchesFilter = false;
            break;
          }
        }

        return matchesFilter;
      }).toList();
    });
  }

  void _removeFilter(String filter) {
    setState(() {
      _activeFilters.remove(filter);
    });
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
    // Simulate refresh
    await Future.delayed(Duration(seconds: 1));
    setState(() {
      _filteredTransactions = List.from(_allTransactions);
    });
  }

  List<Map<String, dynamic>> _groupTransactionsByDate() {
    Map<String, List<Map<String, dynamic>>> grouped = {};

    for (var transaction in _filteredTransactions) {
      DateTime date = transaction['timestamp'] as DateTime;
      String dateKey = _getDateKey(date);

      if (!grouped.containsKey(dateKey)) {
        grouped[dateKey] = [];
      }
      grouped[dateKey]!.add(transaction);
    }

    List<Map<String, dynamic>> result = [];
    grouped.forEach((dateKey, transactions) {
      result.add({
        'type': 'header',
        'title': dateKey,
      });
      result.addAll(transactions.map((t) => {...t, 'type': 'transaction'}));
    });

    return result;
  }

  String _getDateKey(DateTime date) {
    DateTime now = DateTime.now();
    DateTime today = DateTime(now.year, now.month, now.day);
    DateTime yesterday = today.subtract(Duration(days: 1));
    DateTime transactionDate = DateTime(date.year, date.month, date.day);

    if (transactionDate == today) {
      return 'Today';
    } else if (transactionDate == yesterday) {
      return 'Yesterday';
    } else if (now.difference(date).inDays <= 7) {
      return 'This Week';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }

  @override
  Widget build(BuildContext context) {
    final groupedTransactions = _groupTransactionsByDate();

    return Scaffold(
      backgroundColor: AppTheme.darkTheme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: AppTheme.darkTheme.scaffoldBackgroundColor,
        elevation: 0,
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: CustomIconWidget(
            iconName: 'arrow_back',
            color: AppTheme.darkTheme.colorScheme.onSurface,
            size: 24,
          ),
        ),
        title: Text(
          'Transaction History',
          style: AppTheme.darkTheme.textTheme.titleLarge,
        ),
        actions: [
          IconButton(
            onPressed: _toggleSearch,
            icon: CustomIconWidget(
              iconName: _isSearchExpanded ? 'close' : 'search',
              color: AppTheme.darkTheme.colorScheme.onSurface,
              size: 24,
            ),
          ),
          IconButton(
            onPressed: _showFilterBottomSheet,
            icon: Stack(
              children: [
                CustomIconWidget(
                  iconName: 'filter_list',
                  color: AppTheme.darkTheme.colorScheme.onSurface,
                  size: 24,
                ),
                if (_activeFilters.isNotEmpty)
                  Positioned(
                    right: 0,
                    top: 0,
                    child: Container(
                      padding: EdgeInsets.all(1.w),
                      decoration: BoxDecoration(
                        color: AppTheme.info,
                        shape: BoxShape.circle,
                      ),
                      constraints: BoxConstraints(
                        minWidth: 4.w,
                        minHeight: 4.w,
                      ),
                      child: Text(
                        '${_activeFilters.length}',
                        style: TextStyle(
                          color: AppTheme.onPrimary,
                          fontSize: 8.sp,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          SizedBox(width: 2.w),
        ],
      ),
      body: Column(
        children: [
          // Search Bar
          AnimatedContainer(
            duration: Duration(milliseconds: 300),
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
                : SizedBox.shrink(),
          ),

          // Active Filters
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
                          color: AppTheme.onPrimary,
                          fontSize: 12.sp,
                        ),
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
                      itemCount:
                          groupedTransactions.length + (_isLoading ? 1 : 0),
                      itemBuilder: (context, index) {
                        if (index == groupedTransactions.length) {
                          return _buildLoadingIndicator();
                        }

                        final item = groupedTransactions[index];

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
