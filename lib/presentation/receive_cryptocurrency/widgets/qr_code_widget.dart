import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:sizer/sizer.dart';

import '../../../core/app_export.dart';
import '../../../theme/app_theme.dart';

class QRCodeWidget extends StatelessWidget {
  final String address;
  final String amount;
  final String symbol;
  final bool isHighContrast;

  const QRCodeWidget({
    super.key,
    required this.address,
    required this.amount,
    required this.symbol,
    required this.isHighContrast,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(4.w),
      decoration: BoxDecoration(
        color: AppTheme.darkTheme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Text(
            'QR Code',
            style: AppTheme.darkTheme.textTheme.titleMedium,
          ),
          SizedBox(height: 2.h),

          // QR Code Container
          GestureDetector(
            onLongPress: _showSaveOptions,
            child: Container(
              width: 60.w,
              height: 60.w,
              padding: EdgeInsets.all(4.w),
              decoration: BoxDecoration(
                color: isHighContrast ? Colors.black : Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.darkTheme.colorScheme.shadow,
                    blurRadius: 8,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              child: Center(
                child: _buildQRCodePlaceholder(),
              ),
            ),
          ),

          SizedBox(height: 2.h),

          // QR Code Info
          if (amount.isNotEmpty)
            Container(
              padding: EdgeInsets.symmetric(horizontal: 3.w, vertical: 1.h),
              decoration: BoxDecoration(
                color: AppTheme.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'Amount: \$amount \$symbol',
                style: AppTheme.darkTheme.textTheme.bodySmall?.copyWith(
                  color: AppTheme.primary,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildQRCodePlaceholder() {
    // Simulated QR code pattern
    return SizedBox(
      width: double.infinity,
      height: double.infinity,
      child: CustomPaint(
        painter: QRCodePainter(
          isHighContrast: isHighContrast,
          data: _getQRData(),
        ),
      ),
    );
  }

  String _getQRData() {
    if (amount.isNotEmpty) {
      return '\$address?amount=\$amount';
    }
    return address;
  }

  void _showSaveOptions() {
    HapticFeedback.mediumImpact();
    Fluttertoast.showToast(
      msg: "Long press detected - Save to photos option",
      toastLength: Toast.LENGTH_SHORT,
      gravity: ToastGravity.BOTTOM,
      backgroundColor: AppTheme.darkTheme.colorScheme.surface,
      textColor: AppTheme.darkTheme.colorScheme.onSurface,
    );
  }
}

class QRCodePainter extends CustomPainter {
  final bool isHighContrast;
  final String data;

  QRCodePainter({
    required this.isHighContrast,
    required this.data,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = isHighContrast ? Colors.white : Colors.black
      ..style = PaintingStyle.fill;

    final cellSize = size.width / 25; // 25x25 grid for simplicity

    // Draw a simplified QR code pattern
    for (int i = 0; i < 25; i++) {
      for (int j = 0; j < 25; j++) {
        // Create a pseudo-random pattern based on position and data
        final shouldFill = _shouldFillCell(i, j, data);

        if (shouldFill) {
          final rect = Rect.fromLTWH(
            i * cellSize,
            j * cellSize,
            cellSize,
            cellSize,
          );
          canvas.drawRect(rect, paint);
        }
      }
    }

    // Draw corner squares (finder patterns)
    _drawFinderPattern(canvas, paint, 0, 0, cellSize);
    _drawFinderPattern(canvas, paint, 18 * cellSize, 0, cellSize);
    _drawFinderPattern(canvas, paint, 0, 18 * cellSize, cellSize);
  }

  bool _shouldFillCell(int x, int y, String data) {
    // Simple pseudo-random pattern based on coordinates and data hash
    final hash = data.hashCode;
    final combined = (x * 31 + y * 17 + hash) % 100;
    return combined > 45; // Roughly 55% fill rate
  }

  void _drawFinderPattern(
      Canvas canvas, Paint paint, double x, double y, double cellSize) {
    // Outer square (7x7)
    canvas.drawRect(
      Rect.fromLTWH(x, y, cellSize * 7, cellSize * 7),
      paint,
    );

    // Inner white square (5x5)
    final whitePaint = Paint()
      ..color = isHighContrast ? Colors.black : Colors.white
      ..style = PaintingStyle.fill;

    canvas.drawRect(
      Rect.fromLTWH(x + cellSize, y + cellSize, cellSize * 5, cellSize * 5),
      whitePaint,
    );

    // Center black square (3x3)
    canvas.drawRect(
      Rect.fromLTWH(
          x + cellSize * 2, y + cellSize * 2, cellSize * 3, cellSize * 3),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
