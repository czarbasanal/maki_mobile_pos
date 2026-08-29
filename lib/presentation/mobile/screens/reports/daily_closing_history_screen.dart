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
        loading: () => const ListSkeleton(),
        error: (e, _) => ErrorStateView(
          message: 'Error: $e',
          onRetry: () => ref.invalidate(dailyClosingHistoryProvider),
        ),
        data: (closings) {
          if (closings.isEmpty) {
            return const EmptyStateView(
              icon: LucideIcons.history,
              title: 'No closings yet',
              subtitle: 'Closed days will show up here.',
            );
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

class _ClosingTile extends ConsumerStatefulWidget {
  final DailyClosingEntity closing;

  const _ClosingTile({required this.closing});

  @override
  ConsumerState<_ClosingTile> createState() => _ClosingTileState();
}

class _ClosingTileState extends ConsumerState<_ClosingTile> {
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
    // Live drift check — the same diff the closed EOD view performs. The
    // comparison draft must honor the snapshot's exclusions. Loading and
    // error states simply omit the After-close block.
    final liveData =
        ref.watch(dailyClosingDataProvider(c.businessDate)).valueOrNull;
    final liveDraft = liveData?.draftExcluding(c.excludedExpenseIds.toSet());
    final activity = liveDraft == null
        ? null
        : PostCloseActivity.between(closing: c, current: liveDraft);
    // Who earned the labor, for the hand-over panel. The closing stores only
    // the total, so the names come from the day's sales — which means they can
    // drift from the frozen figure once a sale is voided after close. The
    // panel says so when they disagree; it never silently replaces the total.
    final shares = ref
        .watch(mechanicPerformanceReportProvider(DateRangeParams(
          startDate: c.businessDate,
          endDate: c.businessDate
              .add(const Duration(days: 1))
              .subtract(const Duration(milliseconds: 1)),
        )))
        .valueOrNull
        ?.byMechanic
        .where((m) => m.laborTotal > 0)
        .map((m) => HandoverShare(name: m.mechanicName, amount: m.laborTotal))
        .toList();
    return Container(
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: AppColors.hairline(isDark))),
      ),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Thirteen flat rows gave no clue which figures were parts of which.
          // Three headings for the three tracks, and anything that breaks down
          // the row above it is indented.
          //
          // Gross is PARTS money only — labor and fees are separate tracks that
          // were never in it. Saying so, and showing labor arriving right
          // underneath, is what makes the hand-over below reconcile: without
          // it the labor appears only as a subtraction and reads as a second
          // deduction of something already taken out.
          _SummaryHeading(label: 'SALES', muted: muted),
          ClosingKvRow(
              label: 'Gross sales (parts)',
              value: _peso(c.grossSales),
              dense: true),
          ClosingKvRow(
              label: 'Labor (service)',
              value: _peso(c.laborRevenue),
              dense: true),
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
          // Salmon is a non-cash tender like the two above it, not a total of
          // its own — it was the one breakdown row left sitting flush left.
          if (c.salmonReceivable > 0)
            ClosingKvRow(
                label: 'Salmon receivable',
                value: _peso(c.salmonReceivable),
                dense: true,
                indented: true),
          _SummaryHeading(label: 'EXPENSES', muted: muted),
          ClosingKvRow(
              label: 'Total expenses',
              value: _peso(c.totalExpenses),
              dense: true),
          ClosingKvRow(
              label: 'Cash expenses',
              value: _peso(c.cashExpenses),
              dense: true,
              indented: true),
          _SummaryHeading(label: 'CASH RECONCILIATION', muted: muted),
          // Expected cash is float + cash sales − cash expenses + DP − delivery.
          // Every term has a row here; without them the figure could not be
          // reconciled against what is on screen. Shown even at zero: hiding an
          // empty row makes "no DP was recorded" indistinguishable from "this
          // summary does not show DP", which is exactly how it was read when
          // the rows were missing.
          ClosingKvRow(
              label: 'Opening float',
              value: _peso(c.openingFloat),
              dense: true),
          ClosingKvRow(
              label: 'Plate No DP', value: _peso(c.plateNoDp), dense: true),
          ClosingKvRow(
              label: 'Plate No Delivery',
              value: _peso(c.plateNoDelivery),
              dense: true),
          ClosingKvRow(
              label: 'Expected cash',
              value: _peso(c.expectedCash),
              dense: true),
          ClosingKvRow(
              label: 'Counted cash',
              value: _peso(c.countedCash),
              dense: true),
          ClosingHandoverPanel(
            countedCash: c.countedCash,
            laborFees: c.forMechanics,
            forManagement: c.forManagement,
            shares: shares,
            activity: activity,
            dense: true,
          ),
          if (activity != null && activity.hasChanged)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: AfterCloseCard(activity: activity),
            ),
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

/// Small-caps divider label inside the dense closing detail. A full
/// ClosingSectionCard would be too heavy here — this is an inline block inside
/// an already-bordered tile, so the grouping is carried by type, not by chrome.
class _SummaryHeading extends StatelessWidget {
  const _SummaryHeading({required this.label, required this.muted});

  final String label;
  final Color muted;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 10, bottom: 2),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.7,
          color: muted,
        ),
      ),
    );
  }
}
