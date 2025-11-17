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
    final String note = (transaction['note'] ?? '').toString().trim();

    final String assetIcon =
        (transaction['assetIcon'] ?? '').toString().trim().isNotEmpty
            ? transaction['assetIcon']
            : 'assets/currencyicons/default.png';

    return Container(
      height: 90.h,
      decoration: const BoxDecoration(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color.fromARGB(255, 6, 11, 33), // top
            Color.fromARGB(255, 0, 0, 0), // mid
            Color.fromARGB(255, 0, 12, 56), // bottom
          ],
        ),
      ),
      child: Column(
        children: [
          // ================= HANDLE =================
          Container(
            width: 12.w,
            height: 0.7.h,
            margin: EdgeInsets.only(top: 1.5.h, bottom: 1.5.h),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.25),
              borderRadius: BorderRadius.circular(30),
            ),
          ),

          // ================= HEADER =================
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 1.h),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Transaction Details',
                  style: AppTheme.darkTheme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: CustomIconWidget(
                    iconName: 'close',
                    color: Colors.white.withOpacity(0.85),
                    size: 26,
                  ),
                ),
              ],
            ),
          ),

          Divider(
            color: Colors.white.withOpacity(0.08),
            height: 1,
          ),

          // ================= CONTENT =================
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.all(4.w),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSummaryCard(assetIcon),
                  SizedBox(height: 3.h),
                  _buildDetailSection('Transaction Information', [
                    _buildDetailRow('Transaction ID',
                        transaction['id']?.toString() ?? 'N/A',
                        copyable: true),
                    _buildDetailRow(
                        'Hash', transaction['hash']?.toString() ?? 'N/A',
                        copyable: true),
                    _buildDetailRow('Type', _getTransactionTypeText()),
                    _buildDetailRow('Status', _getStatusText()),
                    _buildDetailRow('Timestamp', _formatFullTimestamp()),
                  ]),
                  SizedBox(height: 3.h),
                  _buildDetailSection('Address Information', [
                    _buildDetailRow(
                        'From', transaction['fromAddress']?.toString() ?? 'N/A',
                        copyable: true),
                    _buildDetailRow(
                        'To', transaction['toAddress']?.toString() ?? 'N/A',
                        copyable: true),
                  ]),
                  if (transaction['status'] == 'confirmed') ...[
                    SizedBox(height: 3.h),
                    _buildDetailSection('Confirmation Details', [
                      _buildDetailRow('Confirmations',
                          transaction['confirmations']?.toString() ?? 'N/A'),
                      _buildDetailRow('Block Explorer', 'View on Explorer',
                          isLink: true),
                    ]),
                  ],
                  if (note.isNotEmpty) ...[
                    SizedBox(height: 3.h),
                    _buildDetailSection('Notes', [
                      _buildDetailRow('Note', note),
                    ]),
                  ],
                  SizedBox(height: 4.h),
                ],
              ),
            ),
          ),

          _buildBottomActions(),
        ],
      ),
    );
  }

  // =====================================================
  // SUMMARY CARD
  // =====================================================
  Widget _buildSummaryCard(String assetIcon) {
    final type = transaction['type']?.toString() ?? '';
    final status = transaction['status']?.toString() ?? '';

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: Colors.white.withOpacity(0.05),
        border: Border.all(
          color: Colors.white.withOpacity(0.08),
        ),
      ),
      child: Padding(
        padding: EdgeInsets.all(6.w),
        child: Column(
          children: [
            // Coin Icon
            Container(
              width: 22.w,
              height: 22.w,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.07),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(50),
                child: Image.asset(
                  assetIcon,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => const Icon(
                    Icons.currency_bitcoin,
                    size: 45,
                    color: Colors.white,
                  ),
                ),
              ),
            ),

            SizedBox(height: 2.h),

            // Amount
            Text(
              '${_getAmountPrefix(type)}${transaction['amount'] ?? '0'} ${transaction['asset'] ?? ''}',
              style: AppTheme.darkTheme.textTheme.headlineMedium?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),

            SizedBox(height: 1.h),

            // STATUS PILL
            Container(
              padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 1.2.h),
              decoration: BoxDecoration(
                color: _getStatusColor(status).withOpacity(0.25),
                borderRadius: BorderRadius.circular(40),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildStatusIcon(status),
                  SizedBox(width: 2.w),
                  Text(
                    _getStatusText(),
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 13.sp,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            )
          ],
        ),
      ),
    );
  }

  // =====================================================
  // DETAIL SECTION
  // =====================================================
  Widget _buildDetailSection(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: AppTheme.darkTheme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
        SizedBox(height: 1.5.h),
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            color: Colors.white.withOpacity(0.05),
            border: Border.all(color: Colors.white.withOpacity(0.08)),
          ),
          child: Padding(
            padding: EdgeInsets.all(4.w),
            child: Column(children: children),
          ),
        ),
      ],
    );
  }

  // =====================================================
  // DETAIL ROW
  // =====================================================
  Widget _buildDetailRow(String label, String value,
      {bool copyable = false, bool isLink = false}) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 1.h),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Label
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: TextStyle(
                color: Colors.white.withOpacity(0.55),
                fontSize: 12.sp,
              ),
            ),
          ),

          // Value
          Expanded(
            flex: 3,
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    value,
                    style: TextStyle(
                      color: isLink ? AppTheme.info : Colors.white,
                      fontSize: 12.5.sp,
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
                      color: AppTheme.info,
                      size: 18,
                    ),
                  )
              ],
            ),
          ),
        ],
      ),
    );
  }

  // =====================================================
  // STATUS ICON
  // =====================================================
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
    }
    return Icon(Icons.check_circle, color: AppTheme.success, size: 18);
  }

  // =====================================================
  // HELPERS
  // =====================================================
  String _getTransactionTypeText() {
    final t = transaction['type']?.toString() ?? '';
    switch (t) {
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
    switch (transaction['status']?.toString()) {
      case 'pending':
        return 'Pending';
      case 'confirmed':
        return 'Completed';
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
        return Colors.grey;
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

  String _formatFullTimestamp() {
    final ts = transaction['timestamp'];
    if (ts is! DateTime) return 'N/A';

    final hh = ts.hour.toString().padLeft(2, '0');
    final mm = ts.minute.toString().padLeft(2, '0');

    return '${ts.day}/${ts.month}/${ts.year}  $hh:$mm';
  }

  // =====================================================
  // ACTIONS
  // =====================================================
  void _copyToClipboard(String text) {
    Clipboard.setData(ClipboardData(text: text));
  }

  void _shareTransaction() {}

  void _generateReceipt() {}

  void _openBlockExplorer() {}

  // =====================================================
  // BOTTOM ACTION BUTTONS
  // =====================================================
  Widget _buildBottomActions() {
    return Container(
      padding: EdgeInsets.all(4.w),
      child: Column(
        children: [
          Row(
            children: [
              // Share Button
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _shareTransaction,
                  icon: CustomIconWidget(
                    iconName: 'share',
                    color: AppTheme.info,
                    size: 20,
                  ),
                  label: Text(
                    'Share',
                    style: TextStyle(
                      color: AppTheme.info,
                      fontSize: 14.sp,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: AppTheme.info),
                    padding: EdgeInsets.symmetric(vertical: 2.h),
                  ),
                ),
              ),

              SizedBox(width: 4.w),

              // Receipt Button
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
                    backgroundColor: AppTheme.info,
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
                    color: AppTheme.info,
                    size: 20,
                  ),
                  label: Text(
                    'View on Block Explorer',
                    style: TextStyle(
                      color: AppTheme.info,
                      fontSize: 14.sp,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
