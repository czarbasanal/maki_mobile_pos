import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:maki_mobile_pos/config/router/route_guards.dart';
import 'package:maki_mobile_pos/config/router/route_names.dart';
import 'package:maki_mobile_pos/core/theme/theme.dart';
import 'package:maki_mobile_pos/presentation/providers/auth_provider.dart';

class _NavItem {
  final IconData icon;
  final String label;
  final String path;
  const _NavItem(this.icon, this.label, this.path);
}

class _NavSection {
  final String label;
  final List<_NavItem> items;
  const _NavSection(this.label, this.items);
}

const _navSections = <_NavSection>[
  _NavSection('Sell', [
    _NavItem(Icons.point_of_sale, 'POS', RoutePaths.pos),
    _NavItem(Icons.drafts, 'Drafts', RoutePaths.drafts),
  ]),
  _NavSection('Stock', [
    _NavItem(Icons.inventory_2, 'Inventory', RoutePaths.inventory),
    _NavItem(Icons.local_shipping, 'Receiving', RoutePaths.receiving),
    _NavItem(Icons.people, 'Suppliers', RoutePaths.suppliers),
  ]),
  _NavSection('Money', [
    _NavItem(Icons.receipt_long, 'Expenses', RoutePaths.expenses),
    _NavItem(Icons.savings, 'Petty Cash', RoutePaths.pettyCash),
    _NavItem(Icons.bar_chart, 'Reports', RoutePaths.reports),
  ]),
  _NavSection('Admin', [
    _NavItem(Icons.manage_accounts, 'Users', RoutePaths.users),
    _NavItem(Icons.history, 'Activity Logs', RoutePaths.userLogs),
    _NavItem(Icons.settings, 'Settings', RoutePaths.settings),
  ]),
];

/// Web admin sidebar. Persistent, grouped, role-aware.
///
/// [extended] true → 240px with labels; false → 72px icons only. Items the
/// user can't access are filtered out via `RouteGuards.canAccess`; this is
/// defence-in-depth on top of the web router's admin-only redirect.
class WebSidebar extends ConsumerWidget {
  final bool extended;

  const WebSidebar({super.key, this.extended = true});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider).valueOrNull;
    final currentPath = GoRouterState.of(context).uri.path;
    final dashboardActive = currentPath == RoutePaths.dashboard;

    return Container(
      width: extended ? 240 : 72,
      decoration: BoxDecoration(
        color: AppColors.lightSurface,
        border: Border(right: BorderSide(color: AppColors.lightDivider)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: AppSpacing.md),
          _SidebarItem(
            icon: Icons.dashboard,
            label: 'Dashboard',
            path: RoutePaths.dashboard,
            extended: extended,
            active: dashboardActive,
          ),
          const SizedBox(height: AppSpacing.sm),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
              children: [
                for (final section in _navSections)
                  ..._buildSection(section, user, currentPath),
              ],
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildSection(
    _NavSection section,
    user,
    String currentPath,
  ) {
    final allowedItems = section.items
        .where((item) => RouteGuards.canAccess(item.path, user))
        .toList();

    if (allowedItems.isEmpty) return const [];

    return [
      if (extended)
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.md,
            AppSpacing.lg,
            AppSpacing.xs,
          ),
          child: Text(
            section.label.toUpperCase(),
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.2,
              color: AppColors.lightTextSecondary,
            ),
          ),
        )
      else
        const Padding(
          padding: EdgeInsets.symmetric(vertical: AppSpacing.sm),
          child: Divider(height: 1, indent: 16, endIndent: 16),
        ),
      for (final item in allowedItems)
        _SidebarItem(
          icon: item.icon,
          label: item.label,
          path: item.path,
          extended: extended,
          active: _isActive(currentPath, item.path),
        ),
    ];
  }

  bool _isActive(String currentPath, String itemPath) {
    if (itemPath == RoutePaths.dashboard) return currentPath == itemPath;
    return currentPath == itemPath || currentPath.startsWith('$itemPath/');
  }
}

class _SidebarItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String path;
  final bool extended;
  final bool active;

  const _SidebarItem({
    required this.icon,
    required this.label,
    required this.path,
    required this.extended,
    required this.active,
  });

  @override
  Widget build(BuildContext context) {
    final color = active ? AppColors.primaryDark : AppColors.lightTextSecondary;
    final bg = active
        ? AppColors.primaryAccent.withOpacity(0.18)
        : Colors.transparent;

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: 2,
      ),
      child: Material(
        color: bg,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () => context.go(path),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.sm + 2,
            ),
            child: Row(
              children: [
                Icon(icon, size: 20, color: color),
                if (extended) ...[
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Text(
                      label,
                      style: TextStyle(
                        color: color,
                        fontSize: 14,
                        fontWeight: active ? FontWeight.w600 : FontWeight.w500,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
