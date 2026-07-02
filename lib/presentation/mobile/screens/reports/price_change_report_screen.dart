import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:maki_mobile_pos/config/router/router.dart';
import 'package:maki_mobile_pos/core/extensions/navigation_extensions.dart';
import 'package:maki_mobile_pos/core/extensions/num_extensions.dart';
import 'package:maki_mobile_pos/core/theme/theme.dart';
import 'package:maki_mobile_pos/core/utils/price_change_report.dart';
import 'package:maki_mobile_pos/core/utils/report_csv.dart';
import 'package:maki_mobile_pos/core/utils/report_date_range.dart';
import 'package:maki_mobile_pos/core/utils/report_export.dart';
import 'package:maki_mobile_pos/domain/entities/entities.dart';
import 'package:maki_mobile_pos/presentation/providers/providers.dart';
import 'package:maki_mobile_pos/presentation/mobile/widgets/reports/reports_widgets.dart';
import 'package:maki_mobile_pos/presentation/shared/widgets/common/common_widgets.dart';
import 'package:intl/intl.dart';

/// Admin-only report: price/cost changes across all products in a date range.
class PriceChangeReportScreen extends ConsumerStatefulWidget {
  const PriceChangeReportScreen({super.key});
  @override
  ConsumerState<PriceChangeReportScreen> createState() =>
      _PriceChangeReportScreenState();
}

class _PriceChangeReportScreenState
    extends ConsumerState<PriceChangeReportScreen> {
  late DateTime _startDate;
  late DateTime _endDate;
  DateRangePreset _selectedPreset = DateRangePreset.thisMonth;
  PriceChangeSort _sort = PriceChangeSort.latest;

  @override
  void initState() {
    super.initState();
    final r = dateRangeForPreset(DateRangePreset.thisMonth, DateTime.now());
    _startDate = r.start;
    _endDate = r.end;
  }

  DateRangeParams get _params =>
      DateRangeParams(startDate: _startDate, endDate: _endDate);

  Map<String, String> _labels(List<ProductEntity> products) => {
        for (final p in products) p.id: '${p.name} (${p.sku})',
      };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final reportAsync = ref.watch(priceChangeSummariesProvider(_params));
    final products = ref.watch(productsProvider).valueOrNull ?? const [];
    final labels = _labels(products);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Price Changes'),
        leading: IconButton(
          icon: const Icon(LucideIcons.chevronLeft),
          onPressed: () => context.goBackOr(RoutePaths.reports),
        ),
        actions: [
          IconButton(
            icon: const Icon(LucideIcons.download),
            tooltip: 'Export CSV',
            onPressed: () => _exportCsv(labels),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async =>
            ref.invalidate(priceChangeSummariesProvider(_params)),
        child: ListView(
          children: [
            DateRangePicker(
              startDate: _startDate,
              endDate: _endDate,
              selectedPreset: _selectedPreset,
              onPresetChanged: (preset) {
                if (preset == DateRangePreset.custom) return;
                final r = dateRangeForPreset(preset, DateTime.now());
                setState(() {
                  _startDate = r.start;
                  _endDate = r.end;
                  _selectedPreset = preset;
                });
              },
              onCustomRangeSelected: (start, end) {
                setState(() {
                  _startDate = start;
                  _endDate = DateTime(end.year, end.month, end.day, 23, 59, 59);
                  _selectedPreset = DateRangePreset.custom;
                });
              },
            ),
            reportAsync.when(
              loading: () => const Padding(
                padding: EdgeInsets.fromLTRB(16, 16, 16, 0),
                child: SizedBox(height: 300, child: ListSkeleton()),
              ),
              error: (e, _) => Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                child: ErrorStateView(
                  message: 'Failed to load price changes: $e',
                  onRetry: () =>
                      ref.invalidate(priceChangeSummariesProvider(_params)),
                ),
              ),
              data: (result) => _buildList(
                  theme, result.summaries, result.truncated, labels),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildList(ThemeData theme, List<ProductPriceChangeSummary> summaries,
      bool truncated, Map<String, String> labels) {
    if (summaries.isEmpty) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 24, 16, 0),
        child: EmptyStateView(
          icon: LucideIcons.tag,
          title: 'No price changes',
          subtitle: 'Price/cost changes in this range will appear here.',
        ),
      );
    }
    final sorted = sortPriceChangeSummaries(summaries, _sort);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          const SizedBox(height: 12),
          SegmentedPillFilter<PriceChangeSort>(
            key: const Key('price-change-sort'),
            values: PriceChangeSort.values,
            labels: const {
              PriceChangeSort.latest: 'Latest',
              PriceChangeSort.cost: 'Cost',
              PriceChangeSort.price: 'SRP',
              PriceChangeSort.both: 'Both',
            },
            selected: _sort,
            onChanged: (s) => setState(() => _sort = s),
            segmentKeyPrefix: 'sort-seg',
          ),
          if (truncated)
            Padding(
              padding: const EdgeInsets.only(top: 10, left: 2, right: 2),
              child: Text(
                'Showing the most recent 500 changes — narrow the date range '
                'for exact totals.',
                style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant, fontSize: 11.5),
              ),
            ),
          for (final summary in sorted)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: _ProductChangeCard(
                summary: summary,
                label: labels[summary.productId] ?? summary.productId,
                theme: theme,
                onTap: () => context
                    .push('${RoutePaths.inventory}/${summary.productId}'),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _exportCsv(Map<String, String> labels) async {
    final rows = await ref.read(priceChangeReportProvider(_params).future);
    if (!mounted) return;
    if (rows.isEmpty) {
      context.showSnackBar('No price changes to export in this range');
      return;
    }
    final d = DateFormat('yyyy-MM-dd');
    final name =
        'price-changes_${d.format(_startDate)}_to_${d.format(_endDate)}.csv';
    if (!mounted) return;
    await saveReportCsv(context, buildPriceChangeReportCsv(rows, labels), name);
  }
}

class _ProductChangeCard extends StatelessWidget {
  const _ProductChangeCard({
    required this.summary,
    required this.label,
    required this.theme,
    required this.onTap,
  });
  final ProductPriceChangeSummary summary;
  final String label;
  final ThemeData theme;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final muted = theme.colorScheme.onSurfaceVariant;
    final last = DateFormat('MMM d, y').format(summary.lastChangedAt);
    final n = summary.changeCount;
    return AppCard(
      radius: 12,
      onTap: onTap,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600, fontSize: 13.5)),
              ),
              if (summary.isNew) ...[
                const SizedBox(width: 6),
                Text('New',
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: muted, fontSize: 11)),
              ],
              const SizedBox(width: 4),
              Icon(LucideIcons.chevronRight, size: 15, color: muted),
            ],
          ),
          const SizedBox(height: 6),
          _PrevCurrRow(
              label: 'Cost',
              prev: summary.prevCost,
              curr: summary.currCost,
              diff: summary.costDiff,
              hasPrev: summary.hasPrev,
              theme: theme),
          const SizedBox(height: 3),
          _PrevCurrRow(
              label: 'SRP',
              prev: summary.prevPrice,
              curr: summary.currPrice,
              diff: summary.priceDiff,
              hasPrev: summary.hasPrev,
              theme: theme),
          const SizedBox(height: 6),
          Text(
            '$n change${n == 1 ? '' : 's'} · last $last',
            style: theme.textTheme.bodySmall
                ?.copyWith(color: muted, fontSize: 11.5),
          ),
        ],
      ),
    );
  }
}

class _PrevCurrRow extends StatelessWidget {
  const _PrevCurrRow({
    required this.label,
    required this.prev,
    required this.curr,
    required this.diff,
    required this.hasPrev,
    required this.theme,
  });
  final String label;
  final double prev;
  final double curr;
  final double diff;

  /// False when no prior value is known (lone entry, no baseline): the row
  /// shows only the current value — a fake "prev → curr —" would wrongly
  /// assert that nothing changed.
  final bool hasPrev;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    final isDark = theme.brightness == Brightness.dark;
    final muted = theme.colorScheme.onSurfaceVariant;
    final up = diff > 0;
    final deltaColor =
        up ? AppColors.costUp(isDark) : AppColors.costDown(isDark);
    if (!hasPrev) {
      return Row(
        children: [
          SizedBox(
            width: 34,
            child: Text(label,
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: muted, fontSize: 11.5)),
          ),
          Text(curr.toCurrency(),
              style: theme.textTheme.bodyMedium
                  ?.copyWith(fontWeight: FontWeight.w600, fontSize: 12.5)),
        ],
      );
    }
    return Row(
      children: [
        SizedBox(
          width: 34,
          child: Text(label,
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: muted, fontSize: 11.5)),
        ),
        // Long peso values (₱5,781.29 → ₱7,500.00) must shrink, not overflow.
        Expanded(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(prev.toCurrency(),
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: muted, fontSize: 12)),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Icon(LucideIcons.arrowRight, size: 11, color: muted),
                ),
                Text(curr.toCurrency(),
                    style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600, fontSize: 12.5)),
              ],
            ),
          ),
        ),
        const SizedBox(width: 8),
        if (diff == 0)
          Text('—',
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: muted, fontSize: 11.5))
        else ...[
          Icon(up ? LucideIcons.arrowUpRight : LucideIcons.arrowDownRight,
              size: 12, color: deltaColor),
          const SizedBox(width: 2),
          Text(diff.abs().toCurrency(),
              style: theme.textTheme.bodySmall?.copyWith(
                  color: deltaColor,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600)),
        ],
      ],
    );
  }
}
