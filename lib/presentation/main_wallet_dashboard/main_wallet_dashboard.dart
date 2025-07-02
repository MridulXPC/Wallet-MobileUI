import 'package:flutter/material.dart';
import 'package:sizer/sizer.dart';

import '../../core/app_export.dart';
import './widgets/action_buttons_grid_widget.dart';
import './widgets/balance_card_widget.dart';
import './widgets/crypto_portfolio_widget.dart';
import './widgets/promotional_banner_widget.dart';

class MainWalletDashboard extends StatefulWidget {
  const MainWalletDashboard({super.key});

  @override
  State<MainWalletDashboard> createState() => _MainWalletDashboardState();
}

class _MainWalletDashboardState extends State<MainWalletDashboard>
    with TickerProviderStateMixin {
  late TabController _tabController;
  int _selectedBottomNavIndex = 0;
  bool _showPromoBanner = true;

  // Mock cryptocurrency portfolio data
  final List<Map<String, dynamic>> cryptoPortfolio = [
    {
      "id": 1,
      "symbol": "BTC",
      "name": "Bitcoin",
      "balance": "0.00234567",
      "usdValue": "\$1,234.56",
      "change24h": "+5.67%",
      "isPositive": true,
      "icon": "https://cryptologos.cc/logos/bitcoin-btc-logo.png",
    },
    {
      "id": 2,
      "symbol": "ETH",
      "name": "Ethereum",
      "balance": "1.23456789",
      "usdValue": "\$2,345.67",
      "change24h": "-2.34%",
      "isPositive": false,
      "icon": "https://cryptologos.cc/logos/ethereum-eth-logo.png",
    },
    {
      "id": 3,
      "symbol": "ADA",
      "name": "Cardano",
      "balance": "1,234.56",
      "usdValue": "\$567.89",
      "change24h": "+12.45%",
      "isPositive": true,
      "icon": "https://cryptologos.cc/logos/cardano-ada-logo.png",
    },
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 1, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _dismissPromoBanner() {
    setState(() {
      _showPromoBanner = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.darkTheme.scaffoldBackgroundColor,
      appBar: _buildAppBar(),
      body: RefreshIndicator(
        onRefresh: _refreshData,
        color: AppTheme.primary,
        backgroundColor: AppTheme.darkTheme.colorScheme.surface,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            children: [
              SizedBox(height: 2.h),
              BalanceCardWidget(),
              if (_showPromoBanner) ...[
                SizedBox(height: 2.h),
                PromotionalBannerWidget(
                  onDismiss: _dismissPromoBanner,
                ),
              ],
              SizedBox(height: 3.h),
              ActionButtonsGridWidget(),
              SizedBox(height: 3.h),
              _buildTabSection(),
              SizedBox(height: 2.h),
              _buildTabContent(),
              SizedBox(height: 10.h),
            ],
          ),
        ),
      ),
      bottomNavigationBar: _buildBottomNavigationBar(),
      floatingActionButton: _buildFloatingActionButton(),
    );
  }

PreferredSizeWidget _buildAppBar() {
  return AppBar(
    backgroundColor: AppTheme.darkTheme.scaffoldBackgroundColor,
    elevation: 0,
    automaticallyImplyLeading: false,
    title: Text(
      'Main Wallet',
      style: AppTheme.darkTheme.textTheme.titleLarge?.copyWith(
        color: AppTheme.darkTheme.colorScheme.onSurface,
        fontWeight: FontWeight.w600,
      ),
    ),
    actions: [
      // Transaction Icon Button
      IconButton(
        onPressed: () {
          // Navigate to transaction history
        },
        icon: CustomIconWidget(
          iconName: 'receipt_long', // Use a relevant transaction icon name
          color: AppTheme.darkTheme.colorScheme.onSurface,
          size: 24,
        ),
        tooltip: 'Transactions',
      ),

      // Notification Icon Button with Badge
      Stack(
        children: [
          IconButton(
            onPressed: () {
              // Navigate to notifications
            },
            icon: CustomIconWidget(
              iconName: 'notifications_outlined',
              color: AppTheme.darkTheme.colorScheme.onSurface,
              size: 24,
            ),
            tooltip: 'Notifications',
          ),
          Positioned(
            right: 8,
            top: 8,
            child: Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: AppTheme.error,
                shape: BoxShape.circle,
              ),
            ),
          ),
        ],
      ),

      SizedBox(width: 2.w),
    ],
  );
}


  Widget _buildTabSection() {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 4.w),
      child: TabBar(
        controller: _tabController,
        labelColor: AppTheme.primary,
        unselectedLabelColor: AppTheme.darkTheme.colorScheme.onSurfaceVariant,
        indicatorColor: AppTheme.primary,
        indicatorWeight: 2,
        indicatorSize: TabBarIndicatorSize.label,
        labelStyle: AppTheme.darkTheme.textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.w600,
        ),
        unselectedLabelStyle:
            AppTheme.darkTheme.textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.w400,
        ),
        tabs: const [
          Tab(text: 'Holdings'),
        ],
      ),
    );
  }

  Widget _buildTabContent() {
    return SizedBox(
      height: 50.h,
      child: TabBarView(
        controller: _tabController,
        children: [
          CryptoPortfolioWidget(portfolio: cryptoPortfolio),
        ],
      ),
    );
  }

  Widget _buildEmptyState({
    required String title,
    required String subtitle,
    required String actionText,
  }) {
    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 8.w),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CustomIconWidget(
              iconName: 'account_balance_wallet_outlined',
              color: AppTheme.darkTheme.colorScheme.onSurfaceVariant,
              size: 64,
            ),
            SizedBox(height: 3.h),
            Text(
              title,
              style: AppTheme.darkTheme.textTheme.headlineSmall?.copyWith(
                color: AppTheme.darkTheme.colorScheme.onSurface,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 1.h),
            Text(
              subtitle,
              style: AppTheme.darkTheme.textTheme.bodyLarge?.copyWith(
                color: AppTheme.darkTheme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 4.h),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      // Navigate to buy crypto
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primary,
                      foregroundColor: AppTheme.onPrimary,
                      padding: EdgeInsets.symmetric(vertical: 2.h),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      'Buy Crypto',
                      style: AppTheme.darkTheme.textTheme.titleMedium?.copyWith(
                        color: AppTheme.onPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                SizedBox(width: 4.w),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      // Navigate to deposit crypto
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.primary,
                      side: BorderSide(color: AppTheme.primary, width: 1.5),
                      padding: EdgeInsets.symmetric(vertical: 2.h),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      'Deposit Crypto',
                      style: AppTheme.darkTheme.textTheme.titleMedium?.copyWith(
                        color: AppTheme.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomNavigationBar() {
    return BottomNavigationBar(
      currentIndex: _selectedBottomNavIndex,
      onTap: (index) {
        setState(() {
          _selectedBottomNavIndex = index;
        });
      },
      type: BottomNavigationBarType.fixed,
      backgroundColor: AppTheme.darkTheme.colorScheme.surface,
      selectedItemColor: AppTheme.primary,
      unselectedItemColor: AppTheme.darkTheme.colorScheme.onSurfaceVariant,
      selectedLabelStyle: AppTheme.darkTheme.textTheme.labelMedium?.copyWith(
        fontWeight: FontWeight.w500,
      ),
      unselectedLabelStyle: AppTheme.darkTheme.textTheme.labelMedium?.copyWith(
        fontWeight: FontWeight.w400,
      ),
      items: [
        BottomNavigationBarItem(
          icon: CustomIconWidget(
            iconName: 'home_outlined',
            color: _selectedBottomNavIndex == 0
                ? AppTheme.primary
                : AppTheme.darkTheme.colorScheme.onSurfaceVariant,
            size: 24,
          ),
          activeIcon: CustomIconWidget(
            iconName: 'home',
            color: AppTheme.primary,
            size: 24,
          ),
          label: 'Home',
        ),
        BottomNavigationBarItem(
          icon: CustomIconWidget(
            iconName: 'add_circle_outline',
            color: _selectedBottomNavIndex == 1
                ? AppTheme.primary
                : AppTheme.darkTheme.colorScheme.onSurfaceVariant,
            size: 24,
          ),
          label: 'Create',
        ),
        BottomNavigationBarItem(
          icon: CustomIconWidget(
            iconName: 'card_giftcard',
            color: _selectedBottomNavIndex == 2
                ? AppTheme.primary
                : AppTheme.darkTheme.colorScheme.onSurfaceVariant,
            size: 24,
          ),
          label: 'Rewards',
        ),
        BottomNavigationBarItem(
          icon: CustomIconWidget(
            iconName: 'account_balance_wallet_outlined',
            color: _selectedBottomNavIndex == 3
                ? AppTheme.primary
                : AppTheme.darkTheme.colorScheme.onSurfaceVariant,
            size: 24,
          ),
          activeIcon: CustomIconWidget(
            iconName: 'account_balance_wallet',
            color: AppTheme.primary,
            size: 24,
          ),
          label: 'Holdings',
        ),
      ],
    );
  }

  Widget _buildFloatingActionButton() {
    return FloatingActionButton.extended(
      onPressed: () {
        // Navigate to manage crypto
      },
      backgroundColor: AppTheme.primary,
      foregroundColor: AppTheme.onPrimary,
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      label: Text(
        'Manage Crypto',
        style: AppTheme.darkTheme.textTheme.labelLarge?.copyWith(
          color: AppTheme.onPrimary,
          fontWeight: FontWeight.w600,
        ),
      ),
      icon: CustomIconWidget(
        iconName: 'settings',
        color: AppTheme.onPrimary,
        size: 20,
      ),
    );
  }

  Future<void> _refreshData() async {
    // Simulate network call
    await Future.delayed(const Duration(seconds: 1));
    // Refresh portfolio data here
  }
}