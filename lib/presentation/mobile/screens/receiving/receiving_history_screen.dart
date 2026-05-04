import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:maki_mobile_pos/config/router/router.dart';
import 'package:maki_mobile_pos/core/constants/app_constants.dart';
import 'package:maki_mobile_pos/core/enums/enums.dart';
import 'package:maki_mobile_pos/core/extensions/navigation_extensions.dart';
import 'package:maki_mobile_pos/core/utils/receiving_filters.dart';
import 'package:maki_mobile_pos/domain/entities/receiving_entity.dart';
import 'package:maki_mobile_pos/presentation/providers/providers.dart';
import 'package:maki_mobile_pos/presentation/providers/receiving_provider.dart';
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
          icon: const Icon(CupertinoIcons.back),
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
              icon: CupertinoIcons.cube_box,
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
                  itemBuilder: (context, i) => _ReceivingHistoryItem(
                    receiving: group.items[i],
                    dateFormat: dateFormat,
                    isAdmin: isAdmin,
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
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Text(
            '$count',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
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
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.green[50],
            borderRadius: BorderRadius.circular(8),
          ),
          child:
              Icon(CupertinoIcons.checkmark_circle, color: Colors.green[700]),
        ),
        title: Text(
          receiving.referenceNumber,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              dateFormat.format(receiving.completedAt ?? receiving.createdAt),
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
            if (receiving.supplierName != null)
              Text(
                receiving.supplierName!,
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
          ],
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              '${receiving.totalQuantity} items',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            if (isAdmin)
              Text(
                '${AppConstants.currencySymbol}${receiving.totalCost.toStringAsFixed(2)}',
                style: TextStyle(
                  fontSize: 12,
                  color: theme.colorScheme.primary,
                ),
              ),
          ],
        ),
        onTap: () =>
            context.push('${RoutePaths.bulkReceiving}/${receiving.id}'),
      ),
    );
  }
}
