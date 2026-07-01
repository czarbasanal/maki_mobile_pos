import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:maki_mobile_pos/config/router/router.dart';
import 'package:maki_mobile_pos/core/constants/role_permissions.dart';
import 'package:maki_mobile_pos/core/extensions/navigation_extensions.dart';
import 'package:maki_mobile_pos/core/theme/theme.dart';
import 'package:maki_mobile_pos/presentation/providers/providers.dart';
import 'package:maki_mobile_pos/presentation/shared/widgets/common/common_widgets.dart';

/// Reports landing: pick Sales, Profit (admin), or Labor.
class ReportsHubScreen extends ConsumerWidget {
  const ReportsHubScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider).valueOrNull;
    final canProfit = user != null &&
        RolePermissions.hasPermission(user.role, Permission.viewProfitReports);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(LucideIcons.chevronLeft),
          onPressed: () => context.goBackOr(RoutePaths.dashboard),
        ),
        title: const Text('Reports'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
        children: [
          _ReportCard(
            icon: LucideIcons.barChart3,
            title: 'Sales',
            subtitle: 'Summary, top products, payment breakdown',
            onTap: () => context.pushNamed(RouteNames.salesReport),
          ),
          if (canProfit) ...[
            const SizedBox(height: 10),
            _ReportCard(
              icon: LucideIcons.trendingUp,
              title: 'Profit',
              subtitle: 'Cost, gross profit, and margin',
              onTap: () => context.pushNamed(RouteNames.profitReport),
            ),
          ],
          const SizedBox(height: 10),
          _ReportCard(
            icon: LucideIcons.wrench,
            title: 'Labor',
            subtitle: 'Service revenue by mechanic',
            onTap: () => context.pushNamed(RouteNames.laborReport),
          ),
        ],
      ),
    );
  }
}

class _ReportCard extends StatelessWidget {
  const _ReportCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    final dark = theme.brightness == Brightness.dark;
    return AppCard(
      radius: AppRadius.field,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      onTap: onTap,
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: dark ? const Color(0x1FE8B84C) : const Color(0x12283E46),
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(icon, size: 22, color: theme.colorScheme.primary),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w700, fontSize: 15),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: muted, fontSize: 12),
                ),
              ],
            ),
          ),
          Icon(LucideIcons.chevronRight, size: 18, color: muted),
        ],
      ),
    );
  }
}
