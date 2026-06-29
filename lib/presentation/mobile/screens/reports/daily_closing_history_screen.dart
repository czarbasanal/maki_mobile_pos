import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:maki_mobile_pos/config/router/router.dart';
import 'package:maki_mobile_pos/core/constants/app_constants.dart';
import 'package:maki_mobile_pos/core/extensions/navigation_extensions.dart';
import 'package:maki_mobile_pos/core/extensions/num_extensions.dart';
import 'package:maki_mobile_pos/core/theme/theme.dart';
import 'package:maki_mobile_pos/domain/entities/daily_closing_entity.dart';
import 'package:maki_mobile_pos/presentation/providers/providers.dart';
import 'package:maki_mobile_pos/presentation/mobile/widgets/reports/reports_widgets.dart';
import 'package:maki_mobile_pos/presentation/shared/widgets/common/common_widgets.dart';

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
          icon: const Icon(LucideIcons.chevronLeft),
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
          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 20),
            itemCount: closings.length,
            itemBuilder: (context, i) => _ClosingTile(closing: closings[i]),
          );
        },
      ),
    );
  }
}

class _ClosingTile extends StatefulWidget {
  final DailyClosingEntity closing;

  const _ClosingTile({required this.closing});

  @override
  State<_ClosingTile> createState() => _ClosingTileState();
}

class _ClosingTileState extends State<_ClosingTile> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    final c = widget.closing;
    final dateLabel = DateFormat('EEE, MMM d, y').format(c.businessDate);
    final closedAtLabel = DateFormat('MMM d, h:mm a').format(c.closedAt);

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: AppCard(
        radius: AppRadius.field,
        clipBehavior: Clip.antiAlias,
        padding: EdgeInsets.zero,
        child: Column(
          children: [
            InkWell(
              onTap: () => setState(() => _expanded = !_expanded),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            dateLabel,
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text.rich(
                            TextSpan(
                              style: TextStyle(
                                  fontSize: 12, color: muted, height: 1.5),
                              children: [
                                const TextSpan(text: 'Cash on hand '),
                                TextSpan(
                                  text:
                                      '${AppConstants.currencySymbol}${c.countedCash.toCurrencyWithoutSymbol()}',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    color: theme.colorScheme.onSurface,
                                  ),
                                ),
                                TextSpan(text: '\nClosed $closedAtLabel'),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    VariancePill(variance: c.variance),
                    const SizedBox(width: 8),
                    Icon(
                      _expanded
                          ? LucideIcons.chevronUp
                          : LucideIcons.chevronDown,
                      size: 18,
                      color: muted,
                    ),
                  ],
                ),
              ),
            ),
            if (_expanded) _buildDetail(context, c),
          ],
        ),
      ),
    );
  }

  Widget _buildDetail(BuildContext context, DailyClosingEntity c) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    final isDark = theme.brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: AppColors.hairline(isDark))),
      ),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClosingKvRow(
              label: 'Gross sales', value: _peso(c.grossSales), dense: true),
          ClosingKvRow(
              label: 'Cash sales', value: _peso(c.cashSales), dense: true),
          ClosingKvRow(
              label: 'Non-cash sales',
              value: _peso(c.nonCashSales),
              dense: true),
          if (c.gcashSales > 0)
            ClosingKvRow(
                label: 'GCash',
                value: _peso(c.gcashSales),
                dense: true,
                indented: true),
          if (c.mayaSales > 0)
            ClosingKvRow(
                label: 'Maya',
                value: _peso(c.mayaSales),
                dense: true,
                indented: true),
          if (c.salmonReceivable > 0)
            ClosingKvRow(
                label: 'Salmon receivable',
                value: _peso(c.salmonReceivable),
                dense: true),
          ClosingKvRow(
              label: 'Total expenses',
              value: _peso(c.totalExpenses),
              dense: true),
          ClosingKvRow(
              label: 'Cash expenses',
              value: _peso(c.cashExpenses),
              dense: true),
          ClosingKvRow(
              label: 'Opening float',
              value: _peso(c.openingFloat),
              dense: true),
          ClosingKvRow(
              label: 'Expected cash',
              value: _peso(c.expectedCash),
              dense: true),
          ClosingKvRow(
              label: 'Counted cash',
              value: _peso(c.countedCash),
              dense: true),
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Row(
              children: [
                Icon(LucideIcons.user, size: 13, color: muted),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    'Closed by ${c.closedByName} · '
                    '${DateFormat('MMM d, y · h:mm a').format(c.closedAt)}',
                    style: TextStyle(fontSize: 11.5, color: muted),
                  ),
                ),
              ],
            ),
          ),
          if (c.notes != null && c.notes!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                'Notes: ${c.notes}',
                style: TextStyle(fontSize: 11.5, color: muted),
              ),
            ),
        ],
      ),
    );
  }

  String _peso(double v) =>
      '${AppConstants.currencySymbol}${v.toCurrencyWithoutSymbol()}';
}
