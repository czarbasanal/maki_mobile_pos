import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:maki_mobile_pos/config/router/router.dart';
import 'package:maki_mobile_pos/core/constants/app_constants.dart';
import 'package:maki_mobile_pos/core/extensions/navigation_extensions.dart';
import 'package:maki_mobile_pos/core/extensions/num_extensions.dart';
import 'package:maki_mobile_pos/core/theme/theme.dart';
import 'package:maki_mobile_pos/domain/entities/daily_closing_entity.dart';
import 'package:maki_mobile_pos/presentation/providers/providers.dart';

/// List of past end-of-day closings, newest first. Tap a row to expand its
/// reconciliation detail.
class DailyClosingHistoryScreen extends ConsumerWidget {
  const DailyClosingHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final historyAsync = ref.watch(dailyClosingHistoryProvider);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(CupertinoIcons.back),
          onPressed: () => context.goBackOr(RoutePaths.endOfDay),
        ),
        title: const Text('Closing History'),
      ),
      body: historyAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (closings) {
          if (closings.isEmpty) {
            return const Center(child: Text('No closings yet.'));
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: closings.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, i) => _ClosingTile(closing: closings[i]),
          );
        },
      ),
    );
  }
}

class _ClosingTile extends StatelessWidget {
  final DailyClosingEntity closing;

  const _ClosingTile({required this.closing});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final variance = closing.variance;
    final color = variance == 0
        ? AppColors.successDark
        : (variance < 0 ? AppColors.error : AppColors.warningDark);
    final dateLabel = DateFormat('EEE, MMM d, y').format(closing.businessDate);
    final closedAtLabel = DateFormat('MMM d, h:mm a').format(closing.closedAt);
    final cashOnHand = closing.countedCash;

    return Card(
      margin: EdgeInsets.zero,
      child: ExpansionTile(
        shape: const Border(),
        title: Text(dateLabel,
            style: theme.textTheme.titleSmall
                ?.copyWith(fontWeight: FontWeight.w600)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Cash on hand: ${AppConstants.currencySymbol}${cashOnHand.toCurrencyWithoutSymbol()}',
              style: theme.textTheme.bodySmall,
            ),
            Text(
              'Closed $closedAtLabel',
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
          ],
        ),
        trailing: Text(
          '${variance >= 0 ? '+' : ''}${AppConstants.currencySymbol}${variance.toCurrencyWithoutSymbol()}',
          style: theme.textTheme.bodyMedium
              ?.copyWith(color: color, fontWeight: FontWeight.bold),
        ),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        children: [
          _kv(context, 'Gross sales', closing.grossSales),
          _kv(context, 'Cash sales', closing.cashSales),
          _kv(context, 'Non-cash sales', closing.nonCashSales),
          if (closing.salmonReceivable > 0)
            _kv(context, 'Salmon receivable', closing.salmonReceivable),
          _kv(context, 'Total expenses', closing.totalExpenses),
          _kv(context, 'Cash expenses', closing.cashExpenses),
          _kv(context, 'Opening float', closing.openingFloat),
          _kv(context, 'Expected cash', closing.expectedCash),
          _kv(context, 'Counted cash', closing.countedCash),
          const SizedBox(height: 4),
          Text(
            'Closed by ${closing.closedByName} · '
            '${DateFormat('MMM d, y · h:mm a').format(closing.closedAt)}',
            style: theme.textTheme.bodySmall,
          ),
          if (closing.notes != null)
            Text('Notes: ${closing.notes}', style: theme.textTheme.bodySmall),
        ],
      ),
    );
  }

  Widget _kv(BuildContext context, String label, double value) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: theme.textTheme.bodySmall),
          Text(
            '${AppConstants.currencySymbol}${value.toCurrencyWithoutSymbol()}',
            style: theme.textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}
