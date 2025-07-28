import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sizer/sizer.dart';

import '../../core/app_export.dart';
import './widgets/about_section_widget.dart';
import './widgets/balance_section_widget.dart';
import './widgets/price_chart_widget.dart';
import './widgets/time_period_selector_widget.dart';
import './widgets/token_price_display_widget.dart';
import '../main_wallet_dashboard/widgets/action_buttons_grid_widget.dart';

class TokenDetailScreen extends StatefulWidget {
  const TokenDetailScreen({super.key});

  @override
  State<TokenDetailScreen> createState() => _TokenDetailScreenState();
}

class _TokenDetailScreenState extends State<TokenDetailScreen> {
  Map<String, dynamic>? tokenData;
  String selectedPeriod = 'LIVE';
  bool isBookmarked = false;
  List<FlSpot> chartData = [];

  final List<String> timePeriods = ['LIVE', '4H', '1D', '1W', '1M', 'MAX'];

  @override
  void initState() {
    super.initState();
    _generateMockChartData();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    if (args != null) {
      setState(() {
        tokenData = args;
      });
    }
  }

  void _generateMockChartData() {
    chartData = List.generate(20, (index) {
      return FlSpot(index.toDouble(), 0.8 + (index * 0.02) + (index % 3 * 0.05));
    });
  }

  void _onPeriodSelected(String period) {
    setState(() {
      selectedPeriod = period;
      _generateMockChartData();
    });
  }

  void _shareToken() {
    if (tokenData != null) {
      HapticFeedback.lightImpact();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Sharing ${tokenData!['name']}...'),
          backgroundColor: AppTheme.darkTheme.colorScheme.surface,
        ),
      );
    }
  }

  void _toggleBookmark() {
    setState(() {
      isBookmarked = !isBookmarked;
    });
    HapticFeedback.lightImpact();
  }

  @override
  Widget build(BuildContext context) {
    if (tokenData == null) {
      return Scaffold(
        backgroundColor: AppTheme.darkTheme.scaffoldBackgroundColor,
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: AppTheme.darkTheme.scaffoldBackgroundColor,
      appBar: _buildAppBar(),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(height: 2.h),
            _buildTokenHeader(),
            SizedBox(height: 3.h),
            TokenPriceDisplayWidget(
              currentPrice: '\$1.08',
              priceChange: '\$0.0414',
              percentageChange: '3.69%',
              isPositive: true,
              period: 'Past day',
            ),
            SizedBox(height: 3.h),
            TimePeriodSelectorWidget(
              periods: timePeriods,
              selectedPeriod: selectedPeriod,
              onPeriodSelected: _onPeriodSelected,
            ),
            SizedBox(height: 2.h),
            PriceChartWidget(
              chartData: chartData,
              selectedPeriod: selectedPeriod,
            ),
            SizedBox(height: 3.h),
            BalanceSectionWidget(tokenData: tokenData!),
            SizedBox(height: 3.h),
            AboutSectionWidget(tokenData: tokenData!),
            SizedBox(height: 3.h),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 4.w),
              child: ActionButtonsGridWidget(),
            ),
            SizedBox(height: 4.h),
          ],
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
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
        tokenData?['name'] ?? 'Token Details',
        style: AppTheme.darkTheme.textTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.w600,
        ),
      ),
      centerTitle: true,
      actions: [
        IconButton(
          onPressed: _toggleBookmark,
          icon: CustomIconWidget(
            iconName: isBookmarked ? 'star' : 'star_border',
            color: isBookmarked ? Colors.yellow : AppTheme.darkTheme.colorScheme.onSurface,
            size: 24,
          ),
        ),
        IconButton(
          onPressed: _shareToken,
          icon: CustomIconWidget(
            iconName: 'share',
            color: AppTheme.darkTheme.colorScheme.onSurface,
            size: 24,
          ),
        ),
        SizedBox(width: 2.w),
      ],
    );
  }

  Widget _buildTokenHeader() {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 4.w),
      child: Row(
        children: [
          Container(
            width: 16.w,
            height: 16.w,
            decoration: BoxDecoration(
              color: AppTheme.primary.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: CustomImageWidget(
                imageUrl: tokenData!["icon"] as String,
                width: 16.w,
                height: 16.w,
                fit: BoxFit.cover,
              ),
            ),
          ),
          SizedBox(width: 4.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tokenData!["name"] as String,
                  style: AppTheme.darkTheme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                SizedBox(height: 0.5.h),
                Text(
                  tokenData!["symbol"] as String,
                  style: AppTheme.darkTheme.textTheme.bodyLarge?.copyWith(
                    color: AppTheme.darkTheme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}