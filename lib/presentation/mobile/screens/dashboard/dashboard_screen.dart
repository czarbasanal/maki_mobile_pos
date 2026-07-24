import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
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

  bool get _canCloseDay =>
      RolePermissions.hasPermission(_role, Permission.closeDay);

  // ==================== ACTIONS ====================

  Future<void> _handleSignOut() async {
    final shouldSignOut = await context.showConfirmDialog(
      title: 'Sign Out',
      message: 'Are you sure you want to sign out?',
      confirmText: 'Sign Out',
      icon: LucideIcons.logOut,
    );

    if (!shouldSignOut || !mounted) return;

    try {
      await context.runWithWaiting(
        () => ref.read(authActionsProvider).signOut(),
        message: 'Signing out…',
      );
      if (mounted) {
        context.go(RoutePaths.login);
      }
    } catch (e) {
      if (mounted) {
        context.showErrorSnackBar('Failed to sign out: $e');
      }
    }
  }

  Future<void> _handleRefresh() async {
    ref.invalidate(todaysSalesSummaryProvider);
    ref.invalidate(todaysSalesProvider);
    ref.invalidate(inventorySummaryProvider);
    // Feeds the Avg Daily Sales card — without this, its month-to-date query
    // never re-runs on pull-to-refresh (only on app restart).
    ref.invalidate(monthToDateSummaryProvider);
  }

  // ==================== BUILD ====================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).brightness == Brightness.dark
            ? AppColors.darkBackground
            : AppColors.lightBackground,
        elevation: 0,
        scrolledUnderElevation: 0,
        leadingWidth: 16 + 42 + 12,
        leading: Padding(
          padding: const EdgeInsets.only(left: 16),
          child: Center(child: _buildAvatarTile()),
        ),
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
          if (widget.user.hasPermission(Permission.voidSale))
            VoidRequestsBell(
              onPressed: () => context.push(RoutePaths.voidRequests),
            ),
          IconButton(
            icon: const Icon(LucideIcons.settings),
            onPressed: () => context.go(RoutePaths.settings),
            tooltip: 'Settings',
          ),
          IconButton(
            icon: const Icon(LucideIcons.logOut),
            onPressed: _handleSignOut,
            tooltip: 'Sign Out',
          ),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _handleRefresh,
          child: _buildScrollableSections(),
        ),
      ),
    );
  }

  /// Avatar tile in the app bar — the user's initials on a brand-slate (gold
  /// in dark) rounded tile with a soft brand glow.
  Widget _buildAvatarTile() {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: 42,
      height: 42,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: scheme.primary,
        borderRadius: BorderRadius.circular(AppRadius.md),
        boxShadow: AppShadows.newSalePill(dark: isDark),
      ),
      child: Text(
        _initials,
        style: TextStyle(
          color: scheme.onPrimary,
          fontWeight: FontWeight.w600,
          fontSize: 15,
        ),
      ),
    );
  }

  String get _initials {
    final name = widget.user.displayName.trim();
    if (name.isEmpty) return '?';
    final parts = name.split(RegExp(r'\s+'));
    final first = parts.first.substring(0, 1);
    final last = parts.length > 1 ? parts.last.substring(0, 1) : '';
    return (first + last).toUpperCase();
  }

  Widget _buildScrollableSections() {
    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          sliver: SliverList(
            delegate: SliverChildListDelegate([
              // Date strip + role-based QuickActions — scroll with the page
              // (unpinned; only the AppBar stays fixed).
              _buildDateHeader(),
              const SizedBox(height: 16),
              QuickActions(
                onNewSale: () => context.go(RoutePaths.pos),
                onReceiving: _canAccessReceiving
                    ? () => context.go(RoutePaths.receiving)
                    : null,
                onInventory: _canViewInventory
                    ? () => context.go(RoutePaths.inventory)
                    : null,
                onReorder: _canAccessReceiving
                    ? () => context.go(RoutePaths.purchaseOrders)
                    : null,
                onExpenses: _canViewExpenses
                    ? () => context.go(RoutePaths.expenses)
                    : null,
                onReports: _canViewReports
                    ? () => context.go(RoutePaths.reports)
                    : null,
                onCloseDay: _canCloseDay
                    ? () => context.push(RoutePaths.endOfDay)
                    : null,
              ),
              const SizedBox(height: 24),

              // Sales summary section - all roles can see today's sales
              _buildSectionHeader('Today\'s Sales'),
              const SizedBox(height: 12),
              SalesSummarySection(isAdmin: _isAdmin),

              const SizedBox(height: 24),

              // Top Selling Items Today — replaced Inventory Status per
              // the May 2026 roadmap. Visible to all roles.
              _buildSectionHeader(
                'Top Selling Items Today',
                trailing: _canViewReports
                    ? TextButton(
                        onPressed: () => context.push(RoutePaths.topSelling),
                        style: TextButton.styleFrom(
                          textStyle: const TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        child: const Text('View All'),
                      )
                    : null,
              ),
              const SizedBox(height: 12),
              const TopSellingTodayWidget(),
              const SizedBox(height: 24),

              // Recent sales header
              _buildSectionHeader(
                'Recent Transactions',
                trailing: _canViewReports
                    ? TextButton(
                        // push (not go): salesHistory nests under /reports,
                        // and go rebuilds the stack so back would walk the
                        // reports hierarchy instead of returning here.
                        onPressed: () => context.push(RoutePaths.salesHistory),
                        style: TextButton.styleFrom(
                          textStyle: const TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
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
        Icon(LucideIcons.calendar, color: muted, size: 18),
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
