import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:maki_mobile_pos/config/router/router.dart';
import 'package:maki_mobile_pos/core/constants/app_constants.dart';
import 'package:maki_mobile_pos/core/enums/enums.dart';
import 'package:maki_mobile_pos/core/theme/theme.dart';
import 'package:maki_mobile_pos/domain/entities/entities.dart';
import 'package:maki_mobile_pos/presentation/providers/providers.dart';
import 'package:maki_mobile_pos/presentation/widgets/dashboard/dashboard_widgets.dart';

import '../../widgets/common/common_widgets.dart';

/// Dashboard screen showing role-based menu items and summary.
///
/// Features:
/// - Displays logged-in user info
/// - Shows today's sales summary
/// - Quick action buttons
/// - Recent transactions
/// - Role-based menu items
/// - Sign out functionality
class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(currentUserProvider);

    return userAsync.when(
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (error, stack) => Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              Text('Error: $error'),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => context.go(RoutePaths.login),
                child: const Text('Go to Login'),
              ),
            ],
          ),
        ),
      ),
      data: (user) {
        if (user == null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            context.go(RoutePaths.login);
          });
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        return _DashboardContent(user: user);
      },
    );
  }
}

class _DashboardContent extends ConsumerStatefulWidget {
  final UserEntity user;

  const _DashboardContent({required this.user});

  @override
  ConsumerState<_DashboardContent> createState() => _DashboardContentState();
}

class _DashboardContentState extends ConsumerState<_DashboardContent> {
  bool _isLoggingOut = false;
  bool _showDetailedView = true; // Toggle between detailed and grid view

  String get _greeting {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }

  Future<void> _handleSignOut() async {
    final shouldSignOut = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sign Out'),
        content: const Text('Are you sure you want to sign out?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
            ),
            child: const Text('Sign Out'),
          ),
        ],
      ),
    );

    if (shouldSignOut != true) return;

    setState(() => _isLoggingOut = true);

    try {
      await ref.read(authActionsProvider).signOut();
      if (mounted) {
        context.go(RoutePaths.login);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to sign out: $e'),
            backgroundColor: AppColors.error,
          ),
        );
        setState(() => _isLoggingOut = false);
      }
    }
  }

  Future<void> _handleRefresh() async {
    ref.invalidate(todaysSalesSummaryProvider);
    ref.invalidate(todaysSalesProvider);
    ref.invalidate(inventorySummaryProvider);
  }

  @override
  Widget build(BuildContext context) {
    final menuItems = RouteGuards.getMenuItems(widget.user.role);
    final isAdmin = widget.user.role == UserRole.admin;
    final isStaffOrAdmin = widget.user.role == UserRole.admin ||
        widget.user.role == UserRole.staff;

    return LoadingOverlay(
      isLoading: _isLoggingOut,
      message: 'Signing out...',
      child: Scaffold(
        backgroundColor: AppColors.lightBackground,
        appBar: AppBar(
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _greeting,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.grey[600],
                    ),
              ),
              Text(
                widget.user.displayName,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
            ],
          ),
          centerTitle: false,
          automaticallyImplyLeading: false,
          actions: [
            // Toggle view button
            IconButton(
              icon: Icon(
                _showDetailedView ? Icons.grid_view : Icons.view_agenda,
              ),
              onPressed: () {
                setState(() => _showDetailedView = !_showDetailedView);
              },
              tooltip: _showDetailedView ? 'Show Menu Grid' : 'Show Details',
            ),
            IconButton(
              icon: const Icon(Icons.settings_outlined),
              onPressed: () => context.go(RoutePaths.settings),
              tooltip: 'Settings',
            ),
            IconButton(
              icon: const Icon(Icons.logout),
              onPressed: _handleSignOut,
              tooltip: 'Sign Out',
            ),
          ],
        ),
        body: SafeArea(
          child: RefreshIndicator(
            onRefresh: _handleRefresh,
            child: _showDetailedView
                ? _buildDetailedView(isAdmin, isStaffOrAdmin)
                : _buildGridView(menuItems),
          ),
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => context.go(RoutePaths.pos),
          icon: const Icon(Icons.add),
          label: const Text('New Sale'),
          backgroundColor: AppColors.primaryAccent,
        ),
      ),
    );
  }

  Widget _buildDetailedView(bool isAdmin, bool isStaffOrAdmin) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Date display
        _buildDateHeader(),

        const SizedBox(height: 16),

        // Quick actions
        QuickActions(
          onNewSale: () => context.go(RoutePaths.pos),
          onReceiving:
              isStaffOrAdmin ? () => context.go(RoutePaths.receiving) : null,
          onInventory:
              isStaffOrAdmin ? () => context.go(RoutePaths.inventory) : null,
          onReports:
              isStaffOrAdmin ? () => context.go(RoutePaths.reports) : null,
        ),

        const SizedBox(height: 24),

        // Sales summary section
        _buildSectionHeader('Today\'s Sales'),
        const SizedBox(height: 12),
        _buildSalesSummary(isAdmin),

        const SizedBox(height: 24),

        // Inventory summary (staff and admin only)
        if (isStaffOrAdmin) ...[
          _buildSectionHeader('Inventory Status'),
          const SizedBox(height: 12),
          const InventoryStatusWidget(),
          const SizedBox(height: 24),
        ],

        // Recent sales
        _buildSectionHeader(
          'Recent Transactions',
          trailing: TextButton(
            onPressed: () => context.go(RoutePaths.reports),
            child: const Text('View All'),
          ),
        ),
        const SizedBox(height: 12),
        const RecentSalesWidget(limit: 5),

        const SizedBox(height: 80), // Space for FAB
      ],
    );
  }

  Widget _buildGridView(List<MenuItem> menuItems) {
    final screenWidth = MediaQuery.of(context).size.width;
    final crossAxisCount = screenWidth > 600 ? 3 : 2;

    return Column(
      children: [
        // User Info Section
        Container(
          margin: const EdgeInsets.all(16),
          child: UserInfoCard(user: widget.user),
        ),

        const SizedBox(height: 8),

        // Menu Grid
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: GridView.builder(
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: crossAxisCount,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                childAspectRatio: 1.1,
              ),
              itemCount: menuItems.length,
              itemBuilder: (context, index) {
                return _buildMenuTile(menuItems[index]);
              },
            ),
          ),
        ),

        // Footer
        _buildFooter(),
      ],
    );
  }

  Widget _buildDateHeader() {
    final now = DateTime.now();
    final dateFormat = DateFormat('EEEE, MMMM d, y');

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.primaryAccent.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(
            Icons.calendar_today,
            color: AppColors.primaryDark,
            size: 20,
          ),
          const SizedBox(width: 12),
          Text(
            dateFormat.format(now),
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: AppColors.primaryDark,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, {Widget? trailing}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        if (trailing != null) trailing,
      ],
    );
  }

  Widget _buildSalesSummary(bool showProfit) {
    final summaryAsync = ref.watch(todaysSalesSummaryProvider);

    return summaryAsync.when(
      data: (summary) {
        if (summary == null) {
          return _buildEmptySalesSummary();
        }

        return Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: SummaryCard(
                    title: 'Total Sales',
                    value: '${summary.totalSalesCount}',
                    icon: Icons.receipt_long,
                    iconColor: Colors.blue,
                    subtitle: summary.voidedSalesCount > 0
                        ? '${summary.voidedSalesCount} voided'
                        : null,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: SummaryCard(
                    title: 'Revenue',
                    value:
                        '${AppConstants.currencySymbol}${_formatNumber(summary.netAmount)}',
                    icon: Icons.payments,
                    iconColor: Colors.green,
                    subtitle: summary.totalDiscounts > 0
                        ? '${AppConstants.currencySymbol}${_formatNumber(summary.totalDiscounts)} discount'
                        : null,
                  ),
                ),
              ],
            ),
            if (showProfit) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: SummaryCard(
                      title: 'Gross Profit',
                      value:
                          '${AppConstants.currencySymbol}${_formatNumber(summary.totalProfit)}',
                      icon: Icons.trending_up,
                      iconColor: Colors.orange,
                      subtitle:
                          '${summary.profitMargin.toStringAsFixed(1)}% margin',
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: SummaryCard(
                      title: 'Avg Order',
                      value:
                          '${AppConstants.currencySymbol}${_formatNumber(summary.averageSaleAmount)}',
                      icon: Icons.shopping_cart,
                      iconColor: Colors.purple,
                    ),
                  ),
                ],
              ),
            ],
          ],
        );
      },
      loading: () => const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: CircularProgressIndicator(),
        ),
      ),
      error: (error, _) => Center(
        child: Text('Error loading summary: $error'),
      ),
    );
  }

  Widget _buildEmptySalesSummary() {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Icon(Icons.point_of_sale, size: 48, color: Colors.grey[400]),
          const SizedBox(height: 12),
          Text(
            'No sales today yet',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Start a new sale to see summary',
            style: TextStyle(color: Colors.grey[500]),
          ),
        ],
      ),
    );
  }

  Widget _buildMenuTile(MenuItem item) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => context.go(item.path),
        borderRadius: BorderRadius.circular(16),
        child: Container(
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: AppColors.primaryDark.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  item.icon,
                  size: 32,
                  color: AppColors.primaryDark,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                item.title,
                style: AppTextStyles.labelLarge.copyWith(
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
              ),
              if (item.badge != null) ...[
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.error,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    item.badge!,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFooter() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Text(
        '${AppConstants.appName} v${AppConstants.appVersion}',
        style: TextStyle(
          color: Colors.grey[500],
          fontSize: 12,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }

  String _formatNumber(double value) {
    if (value >= 1000000) {
      return '${(value / 1000000).toStringAsFixed(1)}M';
    }
    if (value >= 1000) {
      return '${(value / 1000).toStringAsFixed(1)}K';
    }
    return value.toStringAsFixed(2);
  }
}
