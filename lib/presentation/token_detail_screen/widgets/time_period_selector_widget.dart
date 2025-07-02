import 'package:flutter/material.dart';
import 'package:sizer/sizer.dart';

import '../../../core/app_export.dart';
import '../../../theme/app_theme.dart';

class TimePeriodSelectorWidget extends StatelessWidget {
  final List<String> periods;
  final String selectedPeriod;
  final Function(String) onPeriodSelected;

  const TimePeriodSelectorWidget({
    super.key,
    required this.periods,
    required this.selectedPeriod,
    required this.onPeriodSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 5.h,
      margin: EdgeInsets.symmetric(horizontal: 4.w),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: periods.length,
        separatorBuilder: (context, index) => SizedBox(width: 2.w),
        itemBuilder: (context, index) {
          final period = periods[index];
          final isSelected = period == selectedPeriod;

          return GestureDetector(
            onTap: () => onPeriodSelected(period),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 1.h),
              decoration: BoxDecoration(
                color: isSelected
                    ? Colors.pink.shade400
                    : AppTheme.darkTheme.colorScheme.surface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isSelected
                      ? Colors.pink.shade400
                      : AppTheme.darkTheme.colorScheme.outline
                          .withValues(alpha: 0.3),
                  width: 1,
                ),
              ),
              child: Center(
                child: Text(
                  period,
                  style: AppTheme.darkTheme.textTheme.bodyMedium?.copyWith(
                    color: isSelected
                        ? Colors.white
                        : AppTheme.darkTheme.colorScheme.onSurface,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
