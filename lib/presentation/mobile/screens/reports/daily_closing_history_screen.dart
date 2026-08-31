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
import 'package:maki_mobile_pos/core/utils/report_date_range.dart';
import 'package:maki_mobile_pos/presentation/providers/shop_time_provider.dart';
import 'package:maki_mobile_pos/core/utils/shop_time.dart';

/// List of past end-of-day closings, newest first. Tap a row to expand its
/// reconciliation detail.
///
/// Opens on the last [kClosingHistoryDefaultDays] days and fetches further
/// back only when a range is chosen — a closing is written once a day and
/// never edited, so streaming the whole collection read everything to show a
/// handful of rows.
class DailyClosingHistoryScreen extends ConsumerStatefulWidget {
  const DailyClosingHistoryScreen({super.key});

  @override
  ConsumerState<DailyClosingHistoryScreen> createState() =>
      _DailyClosingHistoryScreenState();
}

class _DailyClosingHistoryScreenState
    extends ConsumerState<DailyClosingHistoryScreen> {
  ClosingHistoryRange? _range;
  bool _isCustom = false;

  @override
  Widget build(BuildContext context) {
    final offset = ref.watch(shopOffsetProvider);
    final shopToday = ref.watch(businessDayProvider);
    final range = _range ?? defaultClosingHistoryRange(shopToday);
    final historyAsync = ref.watch(closingHistoryInRangeProvider(range));

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(LucideIcons.chevronLeft),
          onPressed: () => context.goBackOr(RoutePaths.endOfDay),
        ),
        title: const Text('Closing History'),
      ),
      body: Column(
        children: [
          _RangeBar(
            range: range,
            isCustom: _isCustom,
            offset: offset,
            onPickRange: () => _pickRange(context, range, offset),
            onReset: _isCustom
                ? () => setState(() {
                      _range = null;
                      _isCustom = false;
                    })
                : null,
          ),
          Expanded(child: _buildBody(historyAsync)),
        ],
      ),
    );
  }

  Future<void> _pickRange(
      BuildContext context, ClosingHistoryRange current, int offset) async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2024),
      lastDate: shopTimeOf(DateTime.now(), offset),
      initialDateRange:
          DateTimeRange(start: current.from, end: current.to),
    );
    if (picked == null) return;
    setState(() {
      _isCustom = true;
      // Shop WALL dates: the picker hands back the calendar days the operator
      // meant, and businessDate is stored as exactly those.
      _range = ClosingHistoryRange(
        from: shopWall(picked.start.year, picked.start.month, picked.start.day),
        to: shopWall(picked.end.year, picked.end.month, picked.end.day),
      );
    });
  }

  Widget _buildBody(AsyncValue<List<DailyClosingEntity>> historyAsync) {
    return historyAsync.when(
        loading: () => const ListSkeleton(),
        error: (e, _) => ErrorStateView(
          message: 'Error: $e',
          onRetry: () => ref.invalidate(closingHistoryInRangeProvider),
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
      );
  }
}

/// Says which days are on screen, and offers a wider span.
///
/// The default is deliberately short, so the bar has to state it — otherwise
/// an operator looking for last month's close would read an empty list as
/// "there is nothing there" rather than "you are looking at this week".
class _RangeBar extends StatelessWidget {
  const _RangeBar({
    required this.range,
    required this.isCustom,
    required this.offset,
    required this.onPickRange,
    this.onReset,
  });

  final ClosingHistoryRange range;
  final bool isCustom;
  final int offset;
  final VoidCallback onPickRange;
  final VoidCallback? onReset;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final muted = theme.colorScheme.onSurfaceVariant;
    final fmt = DateFormat('MMM d');

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.hairline(isDark))),
      ),
      child: Row(
        children: [
          Icon(LucideIcons.calendarDays, size: 15, color: muted),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              isCustom
                  ? '${fmt.format(range.from)} – ${fmt.format(range.to)}'
                  : 'Last $kClosingHistoryDefaultDays days',
              style: TextStyle(fontSize: 13, color: muted),
            ),
          ),
          if (onReset != null)
            TextButton(
              onPressed: onReset,
              child: const Text('Reset'),
            ),
          TextButton.icon(
            onPressed: onPickRange,
            icon: const Icon(LucideIcons.search, size: 15),
            label: const Text('Other dates'),
          ),
        ],
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
    // businessDate is already a shop WALL value, so it formats as-is.
    // closedAt is a real instant — formatting it directly would render the
    // handset's clock, which is right only on a phone sitting in the shop's
    // timezone. That is exactly the assumption the shop-time layer removes.
    final dateLabel = DateFormat('EEE, MMM d, y').format(c.businessDate);
    final closedAtLabel = DateFormat('MMM d, h:mm a')
        .format(shopTimeOf(c.closedAt, ref.read(shopOffsetProvider)));

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
    final offset = ref.watch(shopOffsetProvider);
    final shares = ref
        .watch(mechanicPerformanceReportProvider(DateRangeParams(
          startDate: shopDayStartInstant(c.businessDate, offset),
          endDate: shopDayEndInstant(c.businessDate, offset),
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
          // Four recessed zones, each ending with the single line it
          // resolves to. Scanning vertically gives cash sales, shop fees, cash
          // expenses and counted cash before any detail is read — thirteen
          // flat rows gave no such affordance.
          //
          // Signs mark cash-on-hand terms only. Gross is PARTS money; labor
          // and fees are separate tracks that were never inside it, and labor
          // sits directly under gross because the hand-over below subtracts it.
          ClosingZone(
            icon: LucideIcons.arrowDownLeft,
            heading: 'SALES',
            rows: [
              ZoneRow(label: 'Gross sales (parts)', value: c.grossSales),
              ZoneRow(label: 'Labor (service)', value: c.laborRevenue),
              ZoneRow(label: 'Non-cash sales', value: c.nonCashSales),
              if (c.gcashSales > 0)
                ZoneRow(label: 'GCash', value: c.gcashSales, indented: true),
              if (c.mayaSales > 0)
                ZoneRow(label: 'Maya', value: c.mayaSales, indented: true),
              if (c.salmonReceivable > 0)
                ZoneRow(
                    label: 'Salmon receivable',
                    value: c.salmonReceivable,
                    indented: true),
            ],
            result: ZoneRow(
                label: 'Cash sales',
                value: c.cashSales,
                sign: ZoneSign.plus),
          ),
          const SizedBox(height: 8),
          // Fee cash stays in the drawer and reaches management with the rest,
          // so there is no hand-over line for it. The per-type rows exist only
          // on closings sealed after the breakdown shipped; the document is
          // immutable, so older days show the total alone — permanently.
          ClosingZone(
            icon: LucideIcons.receipt,
            heading: 'SHOP FEES',
            rows: [
              for (final entry in c.feesByType.entries)
                ZoneRow(label: entry.key, value: entry.value),
            ],
            result: ZoneRow(label: 'Shop fees', value: c.feesRevenue),
          ),
          const SizedBox(height: 8),
          ClosingZone(
            icon: LucideIcons.arrowUpRight,
            heading: 'EXPENSES',
            rows: [ZoneRow(label: 'Total expenses', value: c.totalExpenses)],
            result: ZoneRow(
                label: 'Cash expenses',
                value: c.cashExpenses,
                sign: ZoneSign.minus),
          ),
          const SizedBox(height: 8),
          // Expected cash stays reconcilable on screen:
          // float + cash sales − cash expenses + DP − delivery. Every term has
          // a row, and the plate rows render at zero — hiding an empty row was
          // read as "this summary does not show DP".
          ClosingZone(
            icon: LucideIcons.scale,
            heading: 'CASH RECONCILIATION',
            rows: [
              ZoneRow(
                  label: 'Opening float',
                  value: c.openingFloat,
                  sign: ZoneSign.plus),
              ZoneRow(
                  label: 'Plate No DP',
                  value: c.plateNoDp,
                  sign: ZoneSign.plus),
              ZoneRow(
                  label: 'Plate No Delivery',
                  value: c.plateNoDelivery,
                  sign: ZoneSign.minus),
              ZoneRow(label: 'Expected cash', value: c.expectedCash),
            ],
            result: ZoneRow(label: 'Counted cash', value: c.countedCash),
            resultLeading: VarianceChip(variance: c.variance),
          ),
          const SizedBox(height: 8),
          // What changed comes first: the hand-over below states figures the
          // reader would otherwise see move with no explanation yet given.
          if (activity != null && activity.hasChanged)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: AfterCloseCard(activity: activity),
            ),
          ClosingHandoverPanel(
            countedCash: c.countedCash,
            laborFees: c.forMechanics,
            forManagement: c.forManagement,
            shares: shares,
            activity: activity,
            dense: true,
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
                    '${DateFormat('MMM d, y · h:mm a').format(shopTimeOf(c.closedAt, offset))}',
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

}
