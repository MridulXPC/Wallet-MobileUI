import 'package:flutter/material.dart';
import 'package:sizer/sizer.dart';
import '../../../core/app_export.dart';

class TransactionCardWidget extends StatelessWidget {
  const TransactionCardWidget({
    super.key,
    required this.transaction,
    required this.onTap,
    required this.onSwipeAction,
  });

  final Map<String, dynamic> transaction;
  final VoidCallback onTap;
  final void Function(String action) onSwipeAction;

  @override
  Widget build(BuildContext context) {
    final type = (transaction['type'] ?? '').toString().toLowerCase();
    final asset = (transaction['asset'] ?? '').toString();
    final amount = (transaction['amount'] ?? '').toString();
    final fiatAmount = (transaction['fiatAmount'] ?? '').toString();
    final ts = transaction['timestamp'] as DateTime?;
    final status = (transaction['status'] ?? '').toString();

    final _TypeVisual visual = _typeVisual(type);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        margin: EdgeInsets.symmetric(vertical: 0.8.h),
        padding: EdgeInsets.symmetric(vertical: 1.6.h, horizontal: 3.w),
        decoration: BoxDecoration(
          color: AppTheme.darkTheme.colorScheme.surface,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.15),
              blurRadius: 6,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          children: [
            // ---- Icon Circle ----
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: visual.bg,
                shape: BoxShape.circle,
              ),
              child: Icon(visual.icon, color: visual.fg, size: 22),
            ),
            SizedBox(width: 3.w),

            // ---- Details ----
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Amount + fiat
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        "$amount $asset",
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        fiatAmount,
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.85),
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 0.6.h),

                  // Type + time + status pill
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _labelFor(type),
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.7),
                          fontSize: 12,
                        ),
                      ),
                      Row(
                        children: [
                          if (ts != null)
                            Text(
                              _timeAgo(ts),
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.6),
                                fontSize: 12,
                              ),
                            ),
                          SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: _statusColor(status).withOpacity(0.2),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              status,
                              style: TextStyle(
                                color: _statusColor(status),
                                fontSize: 10.sp,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Menu
            PopupMenuButton<String>(
              icon: Icon(Icons.more_vert, color: Colors.white.withOpacity(0.7)),
              color: AppTheme.darkTheme.colorScheme.surface,
              onSelected: onSwipeAction,
              itemBuilder: (context) => [
                const PopupMenuItem(value: 'details', child: Text('Details')),
                const PopupMenuItem(value: 'share', child: Text('Share')),
                const PopupMenuItem(value: 'note', child: Text('Add note')),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // -------- Helpers --------
  String _timeAgo(DateTime dateTime) {
    final now = DateTime.now();
    final diff = now.difference(dateTime);
    if (diff.inMinutes < 1) return '${diff.inSeconds}s ago';
    if (diff.inHours < 1) return '${diff.inMinutes}m ago';
    if (diff.inDays < 1) return '${diff.inHours}h ago';
    if (diff.inDays == 1) return 'Yesterday';
    return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
  }

  String _labelFor(String type) {
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

  Color _statusColor(String status) {
    switch (status.toLowerCase()) {
      case 'confirmed':
        return Colors.green;
      case 'pending':
        return Colors.orange;
      case 'failed':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  _TypeVisual _typeVisual(String type) {
    switch (type) {
      case 'send':
        return _TypeVisual(
            Icons.call_made, Colors.red.withOpacity(0.15), Colors.red);
      case 'receive':
        return _TypeVisual(
            Icons.call_received, Colors.green.withOpacity(0.15), Colors.green);
      case 'buy':
        return _TypeVisual(
            Icons.shopping_cart, Colors.blue.withOpacity(0.15), Colors.blue);
      case 'sell':
        return _TypeVisual(
            Icons.sell_outlined, Colors.amber.withOpacity(0.15), Colors.amber);
      default:
        return _TypeVisual(Icons.swap_horiz, Colors.purple.withOpacity(0.15),
            Colors.purpleAccent);
    }
  }
}

class _TypeVisual {
  final IconData icon;
  final Color bg;
  final Color fg;
  const _TypeVisual(this.icon, this.bg, this.fg);
}
