import 'package:flutter/material.dart';
import 'package:sizer/sizer.dart';

import '../../../core/app_export.dart';

class TransactionCardWidget extends StatelessWidget {
  final Map<String, dynamic> transaction;
  final VoidCallback onTap;
  final Function(String) onSwipeAction;

  const TransactionCardWidget({
    super.key,
    required this.transaction,
    required this.onTap,
    required this.onSwipeAction,
  });

  @override
  Widget build(BuildContext context) {
    final String type = transaction['type'] as String;
    final String status = transaction['status'] as String;
    final DateTime timestamp = transaction['timestamp'] as DateTime;

    return Container(
      margin: EdgeInsets.only(bottom: 2.h),
      child: Dismissible(
        key: Key(transaction['id'] as String),
        direction: DismissDirection.startToEnd,
        background: _buildSwipeBackground(),
        confirmDismiss: (direction) async {
          _showSwipeActions(context);
          return false;
        },
        child: Card(
          color: AppTheme.darkTheme.colorScheme.surface,
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: EdgeInsets.all(4.w),
              child: Row(
                children: [
                  // Asset Icon with Transaction Type Indicator
                  Stack(
                    children: [
                      Container(
                        width: 12.w,
                        height: 12.w,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppTheme.darkTheme.colorScheme.surface,
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(6.w),
                          child: CustomImageWidget(
                            imageUrl: transaction['assetIcon'] as String,
                            width: 12.w,
                            height: 12.w,
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: Container(
                          width: 5.w,
                          height: 5.w,
                          decoration: BoxDecoration(
                            color: _getTypeColor(type),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: AppTheme.darkTheme.colorScheme.surface,
                              width: 1,
                            ),
                          ),
                          child: CustomIconWidget(
                            iconName: _getTypeIcon(type),
                            color: Colors.white,
                            size: 12,
                          ),
                        ),
                      ),
                    ],
                  ),

                  SizedBox(width: 4.w),

                  // Transaction Details
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              _getTransactionTitle(type),
                              style: AppTheme.darkTheme.textTheme.titleMedium
                                  ?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Text(
                              '${_getAmountPrefix(type)}${transaction['amount']} ${transaction['asset']}',
                              style: AppTheme.darkTheme.textTheme.titleMedium
                                  ?.copyWith(
                                color: _getAmountColor(type),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),

                        SizedBox(height: 1.h),

                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              _formatTimestamp(timestamp),
                              style: AppTheme.darkTheme.textTheme.bodySmall
                                  ?.copyWith(
                                color: AppTheme.darkTheme.colorScheme.onSurface
                                    .withValues(alpha: 0.6),
                              ),
                            ),
                            Text(
                              transaction['fiatAmount'] as String,
                              style: AppTheme.darkTheme.textTheme.bodySmall
                                  ?.copyWith(
                                color: AppTheme.darkTheme.colorScheme.onSurface
                                    .withValues(alpha: 0.6),
                              ),
                            ),
                          ],
                        ),

                        SizedBox(height: 1.h),

                        // Status Indicator
                        Row(
                          children: [
                            _buildStatusIndicator(status),
                            SizedBox(width: 2.w),
                            Text(
                              _getStatusText(status),
                              style: AppTheme.darkTheme.textTheme.bodySmall
                                  ?.copyWith(
                                color: _getStatusColor(status),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            Spacer(),
                            if (status == 'confirmed')
                              Text(
                                '${transaction['confirmations']} confirmations',
                                style: AppTheme.darkTheme.textTheme.bodySmall
                                    ?.copyWith(
                                  color: AppTheme
                                      .darkTheme.colorScheme.onSurface
                                      .withValues(alpha: 0.5),
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSwipeBackground() {
    return Container(
      margin: EdgeInsets.only(bottom: 2.h),
      decoration: BoxDecoration(
        color: AppTheme.primary.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Padding(
          padding: EdgeInsets.only(left: 6.w),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              CustomIconWidget(
                iconName: 'more_horiz',
                color: AppTheme.primary,
                size: 24,
              ),
              SizedBox(width: 2.w),
              Text(
                'Actions',
                style: TextStyle(
                  color: AppTheme.primary,
                  fontWeight: FontWeight.w600,
                  fontSize: 14.sp,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showSwipeActions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: AppTheme.darkTheme.colorScheme.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
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
            ListTile(
              leading: CustomIconWidget(
                iconName: 'visibility',
                color: AppTheme.primary,
                size: 24,
              ),
              title: Text(
                'View Details',
                style: AppTheme.darkTheme.textTheme.bodyLarge,
              ),
              onTap: () {
                Navigator.pop(context);
                onSwipeAction('details');
              },
            ),
            ListTile(
              leading: CustomIconWidget(
                iconName: 'share',
                color: AppTheme.primary,
                size: 24,
              ),
              title: Text(
                'Share',
                style: AppTheme.darkTheme.textTheme.bodyLarge,
              ),
              onTap: () {
                Navigator.pop(context);
                onSwipeAction('share');
              },
            ),
            ListTile(
              leading: CustomIconWidget(
                iconName: 'note_add',
                color: AppTheme.primary,
                size: 24,
              ),
              title: Text(
                'Add Note',
                style: AppTheme.darkTheme.textTheme.bodyLarge,
              ),
              onTap: () {
                Navigator.pop(context);
                onSwipeAction('note');
              },
            ),
            SizedBox(height: 2.h),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusIndicator(String status) {
    if (status == 'pending') {
      return SizedBox(
        width: 4.w,
        height: 4.w,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          color: AppTheme.warning,
        ),
      );
    } else {
      return CustomIconWidget(
        iconName: 'check_circle',
        color: AppTheme.success,
        size: 16,
      );
    }
  }

  String _getTransactionTitle(String type) {
    switch (type) {
      case 'send':
        return 'Sent';
      case 'receive':
        return 'Received';
      case 'buy':
        return 'Bought';
      case 'sell':
        return 'Sold';
      default:
        return 'Transaction';
    }
  }

  String _getTypeIcon(String type) {
    switch (type) {
      case 'send':
        return 'arrow_upward';
      case 'receive':
        return 'arrow_downward';
      case 'buy':
        return 'add';
      case 'sell':
        return 'remove';
      default:
        return 'swap_horiz';
    }
  }

  Color _getTypeColor(String type) {
    switch (type) {
      case 'send':
        return AppTheme.error;
      case 'receive':
        return AppTheme.success;
      case 'buy':
        return AppTheme.primary;
      case 'sell':
        return AppTheme.warning;
      default:
        return AppTheme.darkTheme.colorScheme.onSurface;
    }
  }

  String _getAmountPrefix(String type) {
    switch (type) {
      case 'send':
      case 'sell':
        return '-';
      case 'receive':
      case 'buy':
        return '+';
      default:
        return '';
    }
  }

  Color _getAmountColor(String type) {
    switch (type) {
      case 'send':
      case 'sell':
        return AppTheme.error;
      case 'receive':
      case 'buy':
        return AppTheme.success;
      default:
        return AppTheme.darkTheme.colorScheme.onSurface;
    }
  }

  String _getStatusText(String status) {
    switch (status) {
      case 'pending':
        return 'Pending';
      case 'confirmed':
        return 'Confirmed';
      case 'failed':
        return 'Failed';
      default:
        return 'Unknown';
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'pending':
        return AppTheme.warning;
      case 'confirmed':
        return AppTheme.success;
      case 'failed':
        return AppTheme.error;
      default:
        return AppTheme.darkTheme.colorScheme.onSurface;
    }
  }

  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else {
      return '${timestamp.day}/${timestamp.month}/${timestamp.year}';
    }
  }
}
