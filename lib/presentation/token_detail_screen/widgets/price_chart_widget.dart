import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:sizer/sizer.dart';

import '../../../core/app_export.dart';
import '../../../theme/app_theme.dart';

class PriceChartWidget extends StatelessWidget {
  final List<FlSpot> chartData;
  final String selectedPeriod;

  const PriceChartWidget({
    super.key,
    required this.chartData,
    required this.selectedPeriod,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
        height: 40.h,
        margin: EdgeInsets.symmetric(horizontal: 4.w),
        padding: EdgeInsets.all(4.w),
        decoration: BoxDecoration(
            color: AppTheme.darkTheme.colorScheme.surface,
            borderRadius: BorderRadius.circular(16)),
        child: LineChart(LineChartData(
            gridData: FlGridData(
                show: true,
                drawVerticalLine: false,
                horizontalInterval: 0.1,
                getDrawingHorizontalLine: (value) {
                  return FlLine(
                      color: AppTheme.darkTheme.colorScheme.outline
                          .withValues(alpha: 0.2),
                      strokeWidth: 0.5);
                }),
            titlesData: FlTitlesData(show: false),
            borderData: FlBorderData(show: false),
            minX: 0,
            maxX: chartData.length.toDouble() - 1,
            minY: chartData
                    .map((spot) => spot.y)
                    .reduce((a, b) => a < b ? a : b) *
                0.95,
            maxY: chartData
                    .map((spot) => spot.y)
                    .reduce((a, b) => a > b ? a : b) *
                1.05,
            lineBarsData: [
              LineChartBarData(
                  spots: chartData,
                  isCurved: true,
                  gradient: LinearGradient(colors: [
                    Colors.pink.shade400,
                    Colors.purple.shade400,
                  ], begin: Alignment.centerLeft, end: Alignment.centerRight),
                  barWidth: 3,
                  isStrokeCapRound: true,
                  dotData: FlDotData(show: false),
                  belowBarData: BarAreaData(
                      show: true,
                      gradient: LinearGradient(
                          colors: [
                            Colors.pink.shade400.withValues(alpha: 0.3),
                            Colors.purple.shade400.withValues(alpha: 0.1),
                          ],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter))),
            ],
            lineTouchData: LineTouchData(
                enabled: true,
                touchTooltipData: LineTouchTooltipData(
                    getTooltipItems: (List<LineBarSpot> touchedBarSpots) {
                  return touchedBarSpots.map((barSpot) {
                    return LineTooltipItem(
                        '\$${barSpot.y.toStringAsFixed(2)}',
                        AppTheme.darkTheme.textTheme.bodyMedium!.copyWith(
                            color: Colors.pink.shade400,
                            fontWeight: FontWeight.w600));
                  }).toList();
                }),
                touchCallback:
                    (FlTouchEvent event, LineTouchResponse? touchResponse) {
                  // Handle touch events for haptic feedback
                },
                handleBuiltInTouches: true))));
  }
}
