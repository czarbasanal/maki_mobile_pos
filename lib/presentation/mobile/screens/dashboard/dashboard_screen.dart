import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:maki_mobile_pos/config/router/router.dart';
import 'package:maki_mobile_pos/core/constants/app_constants.dart';
import 'package:maki_mobile_pos/core/constants/constants.dart';
import 'package:maki_mobile_pos/core/enums/enums.dart';
import 'package:maki_mobile_pos/core/theme/theme.dart';
import 'package:maki_mobile_pos/domain/entities/entities.dart';
import 'package:maki_mobile_pos/presentation/providers/providers.dart';
import 'package:maki_mobile_pos/presentation/shared/widgets/dashboard/dashboard_widgets.dart';
import 'package:maki_mobile_pos/presentation/shared/widgets/common/common_widgets.dart';

/// Dashboard screen showing role-based menu items and summary.
///
/// Features:
/// - Displays logged-in user info
/// - Shows today's sales summary
/// - Quick action buttons (role-based)
/// - Recent transactions
/// - Role-based menu items
/// - Sign out functionality
///
/// Updated role access:
/// - All roles see: Inventory, Reports (daily), Expenses quick actions
/// - Staff/Admin see: Receiving quick action
/// - Admin only sees: Profit summary cards
class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(currentUserProvider);

    return userAsync.when(
      loading: () => const Scaffold(body: LoadingView()),
      error: (error, stack) => Scaffold(
        body: ErrorStateView(
          message: 'Error: $error',
          action: ElevatedButton(
            onPressed: () => context.go(RoutePaths.login),
            child: const Text('Go to Login'),
          ),
        ),
      ),
      data: (user) {
        if (user == null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            context.go(RoutePaths.login);
          });
          return const Scaffold(body: LoadingView());
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

  // ==================== PERMISSION HELPERS ====================

  UserRole get _role => widget.user.role;

  bool get _isAdmin => _role == UserRole.admin;

  bool get _canViewInventory =>
      RolePermissions.hasPermission(_role, Permission.viewInventory);

  bool get _canAccessReceiving =>
      RolePermissions.hasPermission(_role, Permission.accessReceiving);

  bool get _canViewReports =>
      RolePermissions.hasPermission(_role, Permission.viewSalesReports);

  bool get _canViewExpenses =>
      RolePermissions.hasPermission(_role, Permission.viewExpenses);

  // ==================== ACTIONS ====================

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
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
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

  // ==================== BUILD ====================

  @override
  Widget build(BuildContext context) {
    final menuItems = RouteGuards.getMenuItems(widget.user.role);

    return LoadingOverlay(
      isLoading: _isLoggingOut,
      message: 'Signing out...',
      child: Scaffold(
        appBar: AppBar(
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _greeting,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
              Text(
                widget.user.displayName,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
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
                _showDetailedView ? CupertinoIcons.square_grid_2x2 : CupertinoIcons.square_stack,
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
              icon: const Icon(CupertinoIcons.square_arrow_right),
              onPressed: _handleSignOut,
              tooltip: 'Sign Out',
            ),
          ],
        ),
        body: SafeArea(
          child: RefreshIndicator(
            onRefresh: _handleRefresh,
            child: _showDetailedView
                ? _buildDetailedView()
                : _buildGridView(menuItems),
          ),
        ),
      ),
    );
  }

  Widget _buildDetailedView() {
    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
          sliver: SliverList(
            delegate: SliverChildListDelegate([
              // Date display
              _buildDateHeader(),

              const SizedBox(height: 16),

              // Quick actions - role-based
              QuickActions(
                onNewSale: () => context.go(RoutePaths.pos),
                onReceiving: _canAccessReceiving
                    ? () => context.go(RoutePaths.receiving)
                    : null,
                onInventory: _canViewInventory
                    ? () => context.go(RoutePaths.inventory)
                    : null,
                onExpenses: _canViewExpenses
                    ? () => context.go(RoutePaths.expenses)
                    : null,
                onReports: _canViewReports
                    ? () => context.go(RoutePaths.reports)
                    : null,
              ),

              const SizedBox(height: 24),

              // Sales summary section - all roles can see today's sales
              _buildSectionHeader('Today\'s Sales'),
              const SizedBox(height: 12),
              _buildSalesSummary(_isAdmin),

              const SizedBox(height: 24),

              // Inventory summary - all roles can view inventory now
              if (_canViewInventory) ...[
                _buildSectionHeader('Inventory Status'),
                const SizedBox(height: 12),
                const InventoryStatusWidget(),
                const SizedBox(height: 24),
              ],

              // Recent sales header
              _buildSectionHeader(
                'Recent Transactions',
                trailing: _canViewReports
                    ? TextButton(
                        onPressed: () => context.go(RoutePaths.reports),
                        child: const Text('View All'),
                      )
                    : null,
              ),
            ]),
          ),
        ),
        // Recent Transactions fills the rest of the viewport when the page
        // is shorter than the screen, and grows naturally when it isn't.
        SliverFillRemaining(
          hasScrollBody: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: const RecentSalesWidget(limit: 5),
          ),
        ),
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
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;

    return Row(
      children: [
        Icon(CupertinoIcons.calendar, color: muted, size: 18),
        const SizedBox(width: AppSpacing.sm),
        Text(
          dateFormat.format(now),
          style: theme.textTheme.bodyMedium?.copyWith(
            color: muted,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
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
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: SummaryCard(
                      title: 'Total Sales',
                      value: '${summary.totalSalesCount}',
                      icon: CupertinoIcons.doc_text,
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
                      icon: CupertinoIcons.money_dollar_circle,
                      subtitle: summary.totalDiscounts > 0
                          ? '${AppConstants.currencySymbol}${_formatNumber(summary.totalDiscounts)} discount'
                          : null,
                    ),
                  ),
                ],
              ),
            ),
            // Profit cards - admin only
            if (showProfit) ...[
              const SizedBox(height: 12),
              IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      child: SummaryCard(
                        title: 'Gross Profit',
                        value:
                            '${AppConstants.currencySymbol}${_formatNumber(summary.totalProfit)}',
                        icon: CupertinoIcons.arrow_up_right,
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
                        icon: CupertinoIcons.cart,
                      ),
                    ),
                  ],
                ),
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
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          children: [
            Icon(CupertinoIcons.cart, size: 40, color: muted),
            const SizedBox(height: AppSpacing.sm + 4),
            Text(
              'No sales today yet',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Start a new sale to see summary',
              style: theme.textTheme.bodySmall?.copyWith(color: muted),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMenuTile(MenuItem item) {
    final theme = Theme.of(context);
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.go(item.path),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                item.icon,
                size: 32,
                color: theme.colorScheme.onSurface,
              ),
              const SizedBox(height: AppSpacing.sm + 4),
              Text(
                item.title,
                style: theme.textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
              ),
              if (item.badge != null) ...[
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.error,
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                  ),
                  child: Text(
                    item.badge!,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
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
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Text(
        '${AppConstants.appName} v${AppConstants.appVersion}',
        style: theme.textTheme.labelSmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
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
