import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:maki_mobile_pos/config/router/router.dart';
import 'package:maki_mobile_pos/core/extensions/num_extensions.dart';
import 'package:maki_mobile_pos/core/enums/enums.dart';
import 'package:maki_mobile_pos/core/extensions/navigation_extensions.dart';
import 'package:maki_mobile_pos/core/theme/theme.dart';
import 'package:maki_mobile_pos/core/utils/receiving_filters.dart';
import 'package:maki_mobile_pos/domain/entities/receiving_entity.dart';
import 'package:maki_mobile_pos/presentation/providers/providers.dart';
import 'package:maki_mobile_pos/presentation/shared/widgets/common/common_widgets.dart';

/// Full list of completed receivings, grouped by month and year.
class ReceivingHistoryScreen extends ConsumerWidget {
  const ReceivingHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final receivingsAsync = ref.watch(recentReceivingsProvider);
    final dateFormat = DateFormat('MMM d, y • h:mm a');
    final monthHeaderFormat = DateFormat('MMMM y');
    final isAdmin =
        ref.watch(currentUserProvider).valueOrNull?.role == UserRole.admin;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(LucideIcons.chevronLeft),
          onPressed: () => context.goBackOr(RoutePaths.receiving),
        ),
        title: const Text('Receiving History'),
      ),
      body: receivingsAsync.when(
        data: (receivings) {
          final completed = receivings
              .where((r) => r.status == ReceivingStatus.completed)
              .toList();

          if (completed.isEmpty) {
            return const EmptyStateView(
              icon: LucideIcons.package,
              title: 'No Receiving History',
              subtitle: 'Completed receivings will appear here',
            );
          }

          final groups = groupByMonthYear(completed);

          // Build a flat slivers stream so the month-header sticks
          // visually with its items: one SliverPadding(SliverToBoxAdapter)
          // per header, followed by a SliverList per group's items.
          return CustomScrollView(
            slivers: [
              const SliverPadding(padding: EdgeInsets.only(top: 8)),
              for (final group in groups) ...[
                SliverToBoxAdapter(
                  child: _MonthHeader(
                    label: monthHeaderFormat.format(group.monthStart),
                    count: group.items.length,
                  ),
                ),
                SliverList.builder(
                  itemCount: group.items.length,
                  itemBuilder: (context, i) => Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                    child: _ReceivingHistoryItem(
                      receiving: group.items[i],
                      dateFormat: dateFormat,
                      isAdmin: isAdmin,
                    ),
                  ),
                ),
              ],
              const SliverPadding(padding: EdgeInsets.only(bottom: 16)),
            ],
          );
        },
        loading: () => const LoadingView(),
        error: (error, _) => ErrorStateView(
          message: 'Error: $error',
          onRetry: () => ref.invalidate(recentReceivingsProvider),
        ),
      ),
    );
  }
}

class _MonthHeader extends StatelessWidget {
  final String label;
  final int count;

  const _MonthHeader({required this.label, required this.count});

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.6,
                color: muted,
              ),
            ),
          ),
          Text(
            '$count',
            style: TextStyle(fontSize: 12, color: muted),
          ),
        ],
      ),
    );
  }
}

class _ReceivingHistoryItem extends StatelessWidget {
  final ReceivingEntity receiving;
  final DateFormat dateFormat;

  const _ReceivingHistoryItem({
    required this.receiving,
    required this.dateFormat,
    required this.isAdmin,
  });

  final bool isAdmin;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final muted = theme.colorScheme.onSurfaceVariant;

    final subtitle = receiving.supplierName != null
        ? '${dateFormat.format(receiving.completedAt ?? receiving.createdAt)} · ${receiving.supplierName}'
        : dateFormat.format(receiving.completedAt ?? receiving.createdAt);

    return AppCard(
      radius: AppRadius.field,
      padding: const EdgeInsets.all(12),
      onTap: () => context.push('${RoutePaths.bulkReceiving}/${receiving.id}'),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.success.withValues(alpha: isDark ? 0.16 : 0.10),
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(
              LucideIcons.checkCircle,
              color: AppColors.successIcon(isDark),
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  receiving.referenceNumber,
                  style: TextStyle(
                    fontFamily: 'RobotoMono',
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.onSurface,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(fontSize: 12, color: muted),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${receiving.totalQuantity} items',
                style: TextStyle(fontSize: 12, color: muted),
              ),
              if (isAdmin)
                Text(
                  receiving.totalCost.toCurrency(),
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
