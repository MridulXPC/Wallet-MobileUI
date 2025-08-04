import 'package:flutter/material.dart';
import 'package:sizer/sizer.dart';

import '../../../core/app_export.dart';

class FilterBottomSheetWidget extends StatefulWidget {
  final Function(List<String>) onFiltersApplied;
  final List<String> activeFilters;

  const FilterBottomSheetWidget({
    super.key,
    required this.onFiltersApplied,
    required this.activeFilters,
  });

  @override
  State<FilterBottomSheetWidget> createState() =>
      _FilterBottomSheetWidgetState();
}

class _FilterBottomSheetWidgetState extends State<FilterBottomSheetWidget> {
  late List<String> _selectedFilters;
  DateTimeRange? _selectedDateRange;
  RangeValues _amountRange = RangeValues(0, 10000);
  final List<String> _selectedAssets = [];

  final List<String> _transactionTypes = ['Send', 'Receive', 'Buy', 'Sell'];
  final List<Map<String, String>> _availableAssets = [
    {'name': 'Bitcoin', 'symbol': 'BTC'},
    {'name': 'Ethereum', 'symbol': 'ETH'},
    {'name': 'Tether', 'symbol': 'USDT'},
    {'name': 'Binance Coin', 'symbol': 'BNB'},
    {'name': 'Cardano', 'symbol': 'ADA'},
  ];

  @override
  void initState() {
    super.initState();
    _selectedFilters = List.from(widget.activeFilters);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 85.h,
      decoration: BoxDecoration(
        color: AppTheme.darkTheme.colorScheme.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Handle
          Container(
            width: 10.w,
            height: 0.5.h,
            margin: EdgeInsets.symmetric(vertical: 2.h),
            decoration: BoxDecoration(
              color: AppTheme.darkTheme.colorScheme.onSurface
                  .withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Header
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 4.w),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Filter Transactions',
                  style: AppTheme.darkTheme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                TextButton(
                  onPressed: _clearAllFilters,
                  child: Text(
                    'Clear All',
                    style: TextStyle(
                      color: AppTheme.info,
                      fontSize: 14.sp,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),

          Divider(
            color:
                AppTheme.darkTheme.colorScheme.onSurface.withValues(alpha: 0.1),
            height: 1,
          ),

          // Filter Content
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.all(4.w),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Transaction Type Filter
                  _buildSectionTitle('Transaction Type'),
                  SizedBox(height: 2.h),
                  _buildTransactionTypeFilter(),

                  SizedBox(height: 4.h),

                  // Date Range Filter
                  _buildSectionTitle('Date Range'),
                  SizedBox(height: 2.h),
                  _buildDateRangeFilter(),

                  SizedBox(height: 4.h),

                  // Asset Filter
                  _buildSectionTitle('Assets'),
                  SizedBox(height: 2.h),
                  _buildAssetFilter(),

                  SizedBox(height: 4.h),

                  // Amount Range Filter
                  _buildSectionTitle('Amount Range (\$)'),
                  SizedBox(height: 2.h),
                  _buildAmountRangeFilter(),

                  SizedBox(height: 6.h),
                ],
              ),
            ),
          ),

          // Apply Button
          Container(
            padding: EdgeInsets.all(4.w),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      padding: EdgeInsets.symmetric(vertical: 2.h),
                      side: BorderSide(color: AppTheme.info),
                    ),
                    child: Text(
                      'Cancel',
                      style: TextStyle(
                        color: AppTheme.info,
                        fontSize: 16.sp,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                SizedBox(width: 4.w),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _applyFilters,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.info,
                      padding: EdgeInsets.symmetric(vertical: 2.h),
                    ),
                    child: Text(
                      'Apply Filters',
                      style: TextStyle(
                        color: AppTheme.onPrimary,
                        fontSize: 16.sp,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: AppTheme.darkTheme.textTheme.titleMedium?.copyWith(
        fontWeight: FontWeight.w600,
      ),
    );
  }

  Widget _buildTransactionTypeFilter() {
    return Wrap(
      spacing: 2.w,
      runSpacing: 1.h,
      children: _transactionTypes.map((type) {
        final isSelected = _selectedFilters.contains(type);
        return FilterChip(
          label: Text(
            type,
            style: TextStyle(
              color: isSelected
                  ? AppTheme.onPrimary
                  : AppTheme.darkTheme.colorScheme.onSurface,
              fontSize: 14.sp,
            ),
          ),
          selected: isSelected,
          onSelected: (selected) {
            setState(() {
              if (selected) {
                _selectedFilters.add(type);
              } else {
                _selectedFilters.remove(type);
              }
            });
          },
          backgroundColor: AppTheme.darkTheme.colorScheme.surface,
          selectedColor: AppTheme.info,
          checkmarkColor: AppTheme.onPrimary,
          side: BorderSide(
            color: isSelected
                ? AppTheme.info
                : AppTheme.darkTheme.colorScheme.onSurface
                    .withValues(alpha: 0.3),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildDateRangeFilter() {
    return InkWell(
      onTap: _selectDateRange,
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.all(4.w),
        decoration: BoxDecoration(
          border: Border.all(
            color:
                AppTheme.darkTheme.colorScheme.onSurface.withValues(alpha: 0.3),
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              _selectedDateRange != null
                  ? '${_formatDate(_selectedDateRange!.start)} - ${_formatDate(_selectedDateRange!.end)}'
                  : 'Select date range',
              style: AppTheme.darkTheme.textTheme.bodyMedium?.copyWith(
                color: _selectedDateRange != null
                    ? AppTheme.darkTheme.colorScheme.onSurface
                    : AppTheme.darkTheme.colorScheme.onSurface
                        .withValues(alpha: 0.6),
              ),
            ),
            CustomIconWidget(
              iconName: 'calendar_today',
              color: AppTheme.info,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAssetFilter() {
    return Wrap(
      spacing: 2.w,
      runSpacing: 1.h,
      children: _availableAssets.map((asset) {
        final symbol = asset['symbol']!;
        final isSelected = _selectedAssets.contains(symbol);
        return FilterChip(
          label: Text(
            symbol,
            style: TextStyle(
              color: isSelected
                  ? AppTheme.onPrimary
                  : AppTheme.darkTheme.colorScheme.onSurface,
              fontSize: 14.sp,
            ),
          ),
          selected: isSelected,
          onSelected: (selected) {
            setState(() {
              if (selected) {
                _selectedAssets.add(symbol);
              } else {
                _selectedAssets.remove(symbol);
              }
            });
          },
          backgroundColor: AppTheme.darkTheme.colorScheme.surface,
          selectedColor: AppTheme.info,
          checkmarkColor: AppTheme.onPrimary,
          side: BorderSide(
            color: isSelected
                ? AppTheme.info
                : AppTheme.darkTheme.colorScheme.onSurface
                    .withValues(alpha: 0.3),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildAmountRangeFilter() {
    return Column(
      children: [
        RangeSlider(
          values: _amountRange,
          min: 0,
          max: 10000,
          divisions: 100,
          activeColor: AppTheme.info,
          inactiveColor: AppTheme.info.withValues(alpha: 0.3),
          onChanged: (values) {
            setState(() {
              _amountRange = values;
            });
          },
        ),
        SizedBox(height: 1.h),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '\$${_amountRange.start.round()}',
              style: AppTheme.darkTheme.textTheme.bodyMedium,
            ),
            Text(
              '\$${_amountRange.end.round()}',
              style: AppTheme.darkTheme.textTheme.bodyMedium,
            ),
          ],
        ),
      ],
    );
  }

  void _selectDateRange() async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime.now().subtract(Duration(days: 365)),
      lastDate: DateTime.now(),
      initialDateRange: _selectedDateRange,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.dark(
              primary: AppTheme.info,
              onPrimary: AppTheme.onPrimary,
              surface: AppTheme.darkTheme.colorScheme.surface,
              onSurface: AppTheme.darkTheme.colorScheme.onSurface,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _selectedDateRange = picked;
      });
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  void _clearAllFilters() {
    setState(() {
      _selectedFilters.clear();
      _selectedDateRange = null;
      _selectedAssets.clear();
      _amountRange = RangeValues(0, 10000);
    });
  }

  void _applyFilters() {
    List<String> allFilters = List.from(_selectedFilters);

    // Add other filter criteria to the list if needed
    if (_selectedDateRange != null) {
      allFilters.add('Date Range');
    }

    if (_selectedAssets.isNotEmpty) {
      allFilters.addAll(_selectedAssets);
    }

    if (_amountRange.start > 0 || _amountRange.end < 10000) {
      allFilters.add('Amount Range');
    }

    widget.onFiltersApplied(allFilters);
    Navigator.pop(context);
  }
}
