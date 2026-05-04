import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:maki_mobile_pos/config/router/router.dart';
import 'package:maki_mobile_pos/core/constants/constants.dart';
import 'package:maki_mobile_pos/core/enums/enums.dart';
import 'package:maki_mobile_pos/core/extensions/navigation_extensions.dart';
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
        context.showErrorSnackBar('Failed to sign out: $e');
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
            child: _buildDetailedView(),
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
              SalesSummarySection(showProfit: _isAdmin),

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

}
