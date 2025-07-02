import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sizer/sizer.dart';

import '../../../core/app_export.dart';

class TransactionDetailModalWidget extends StatelessWidget {
  final Map<String, dynamic> transaction;

  const TransactionDetailModalWidget({
    super.key,
    required this.transaction,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 90.h,
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
                  'Transaction Details',
                  style: AppTheme.darkTheme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: CustomIconWidget(
                    iconName: 'close',
                    color: AppTheme.darkTheme.colorScheme.onSurface,
                    size: 24,
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

          // Content
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.all(4.w),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Transaction Summary Card
                  _buildSummaryCard(),

                  SizedBox(height: 3.h),

                  // Transaction Details
                  _buildDetailSection('Transaction Information', [
                    _buildDetailRow(
                        'Transaction ID', transaction['id'] as String,
                        copyable: true),
                    _buildDetailRow('Hash', transaction['hash'] as String,
                        copyable: true),
                    _buildDetailRow('Type', _getTransactionTypeText()),
                    _buildDetailRow('Status', _getStatusText()),
                    _buildDetailRow('Timestamp', _formatFullTimestamp()),
                  ]),

                  SizedBox(height: 3.h),

                  // Address Information
                  _buildDetailSection('Address Information', [
                    _buildDetailRow(
                        'From', transaction['fromAddress'] as String,
                        copyable: true),
                    _buildDetailRow('To', transaction['toAddress'] as String,
                        copyable: true),
                  ]),

                  SizedBox(height: 3.h),

                  // Amount Information
                  _buildDetailSection('Amount Information', [
                    _buildDetailRow('Amount',
                        '${transaction['amount']} ${transaction['asset']}'),
                    _buildDetailRow(
                        'Fiat Value', transaction['fiatAmount'] as String),
                    _buildDetailRow('Network Fee',
                        '${transaction['fee']} ${transaction['asset']}'),
                  ]),

                  if (transaction['status'] == 'confirmed') ...[
                    SizedBox(height: 3.h),
                    _buildDetailSection('Confirmation Details', [
                      _buildDetailRow(
                          'Confirmations', '${transaction['confirmations']}'),
                      _buildDetailRow('Block Explorer', 'View on Explorer',
                          isLink: true),
                    ]),
                  ],

                  if ((transaction['note'] as String).isNotEmpty) ...[
                    SizedBox(height: 3.h),
                    _buildDetailSection('Notes', [
                      _buildDetailRow('Note', transaction['note'] as String),
                    ]),
                  ],

                  SizedBox(height: 4.h),
                ],
              ),
            ),
          ),

          // Action Buttons
          Container(
            padding: EdgeInsets.all(4.w),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _shareTransaction,
                        icon: CustomIconWidget(
                          iconName: 'share',
                          color: AppTheme.primary,
                          size: 20,
                        ),
                        label: Text(
                          'Share',
                          style: TextStyle(
                            color: AppTheme.primary,
                            fontSize: 14.sp,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          padding: EdgeInsets.symmetric(vertical: 2.h),
                          side: BorderSide(color: AppTheme.primary),
                        ),
                      ),
                    ),
                    SizedBox(width: 4.w),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _generateReceipt,
                        icon: CustomIconWidget(
                          iconName: 'receipt',
                          color: AppTheme.onPrimary,
                          size: 20,
                        ),
                        label: Text(
                          'Receipt',
                          style: TextStyle(
                            color: AppTheme.onPrimary,
                            fontSize: 14.sp,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primary,
                          padding: EdgeInsets.symmetric(vertical: 2.h),
                        ),
                      ),
                    ),
                  ],
                ),
                if (transaction['status'] == 'confirmed')
                  Padding(
                    padding: EdgeInsets.only(top: 2.h),
                    child: SizedBox(
                      width: double.infinity,
                      child: TextButton.icon(
                        onPressed: _openBlockExplorer,
                        icon: CustomIconWidget(
                          iconName: 'open_in_new',
                          color: AppTheme.primary,
                          size: 20,
                        ),
                        label: Text(
                          'View on Block Explorer',
                          style: TextStyle(
                            color: AppTheme.primary,
                            fontSize: 14.sp,
                            fontWeight: FontWeight.w500,
                          ),
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

  Widget _buildSummaryCard() {
    final String type = transaction['type'] as String;
    final String status = transaction['status'] as String;

    return Card(
      color: AppTheme.darkTheme.scaffoldBackgroundColor,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color:
              AppTheme.darkTheme.colorScheme.onSurface.withValues(alpha: 0.1),
        ),
      ),
      child: Padding(
        padding: EdgeInsets.all(6.w),
        child: Column(
          children: [
            // Asset Icon
            Container(
              width: 20.w,
              height: 20.w,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppTheme.darkTheme.colorScheme.surface,
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10.w),
                child: CustomImageWidget(
                  imageUrl: transaction['assetIcon'] as String,
                  width: 20.w,
                  height: 20.w,
                  fit: BoxFit.cover,
                ),
              ),
            ),

            SizedBox(height: 3.h),

            // Amount
            Text(
              '${_getAmountPrefix(type)}${transaction['amount']} ${transaction['asset']}',
              style: AppTheme.darkTheme.textTheme.headlineMedium?.copyWith(
                color: _getAmountColor(type),
                fontWeight: FontWeight.bold,
              ),
            ),

            SizedBox(height: 1.h),

            // Fiat Amount
            Text(
              transaction['fiatAmount'] as String,
              style: AppTheme.darkTheme.textTheme.titleMedium?.copyWith(
                color: AppTheme.darkTheme.colorScheme.onSurface
                    .withValues(alpha: 0.7),
              ),
            ),

            SizedBox(height: 2.h),

            // Status Badge
            Container(
              padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 1.h),
              decoration: BoxDecoration(
                color: _getStatusColor(status).withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildStatusIcon(status),
                  SizedBox(width: 2.w),
                  Text(
                    _getStatusText(),
                    style: TextStyle(
                      color: _getStatusColor(status),
                      fontSize: 14.sp,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailSection(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: AppTheme.darkTheme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        SizedBox(height: 2.h),
        Card(
          color: AppTheme.darkTheme.scaffoldBackgroundColor,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(
              color: AppTheme.darkTheme.colorScheme.onSurface
                  .withValues(alpha: 0.1),
            ),
          ),
          child: Padding(
            padding: EdgeInsets.all(4.w),
            child: Column(
              children: children,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDetailRow(String label, String value,
      {bool copyable = false, bool isLink = false}) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 1.h),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: AppTheme.darkTheme.textTheme.bodyMedium?.copyWith(
                color: AppTheme.darkTheme.colorScheme.onSurface
                    .withValues(alpha: 0.6),
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    value,
                    style: AppTheme.darkTheme.textTheme.bodyMedium?.copyWith(
                      color: isLink
                          ? AppTheme.primary
                          : AppTheme.darkTheme.colorScheme.onSurface,
                      fontWeight: isLink ? FontWeight.w500 : FontWeight.w400,
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 2,
                  ),
                ),
                if (copyable)
                  IconButton(
                    onPressed: () => _copyToClipboard(value),
                    icon: CustomIconWidget(
                      iconName: 'copy',
                      color: AppTheme.primary,
                      size: 16,
                    ),
                    constraints: BoxConstraints(
                      minWidth: 8.w,
                      minHeight: 8.w,
                    ),
                    padding: EdgeInsets.all(1.w),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusIcon(String status) {
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

  String _getTransactionTypeText() {
    final type = transaction['type'] as String;
    switch (type) {
      case 'send':
        return 'Send';
      case 'receive':
        return 'Receive';
      case 'buy':
        return 'Buy';
      case 'sell':
        return 'Sell';
      default:
        return 'Transaction';
    }
  }

  String _getStatusText() {
    final status = transaction['status'] as String;
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

  String _formatFullTimestamp() {
    final timestamp = transaction['timestamp'] as DateTime;
    return '${timestamp.day}/${timestamp.month}/${timestamp.year} at ${timestamp.hour}:${timestamp.minute.toString().padLeft(2, '0')}';
  }

  void _copyToClipboard(String text) {
    Clipboard.setData(ClipboardData(text: text));
    // Show snackbar or toast notification
  }

  void _shareTransaction() {
    // Implement share functionality
    final String shareText = '''
Transaction Details:
Type: ${_getTransactionTypeText()}
Amount: ${transaction['amount']} ${transaction['asset']}
Value: ${transaction['fiatAmount']}
Status: ${_getStatusText()}
Hash: ${transaction['hash']}
''';

    // Use share_plus package or platform-specific sharing
  }

  void _generateReceipt() {
    // Implement receipt generation (PDF)
  }

  void _openBlockExplorer() {
    // Open blockchain explorer in browser
    final hash = transaction['hash'] as String;
    final asset = transaction['asset'] as String;

    // Different explorers for different assets
    String explorerUrl;
    switch (asset) {
      case 'BTC':
        explorerUrl = 'https://blockstream.info/tx/$hash';
        break;
      case 'ETH':
      case 'USDT':
        explorerUrl = 'https://etherscan.io/tx/$hash';
        break;
      default:
        explorerUrl = 'https://blockstream.info/tx/$hash';
    }

    // Use url_launcher package to open URL
  }
}
