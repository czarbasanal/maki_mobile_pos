import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:maki_mobile_pos/core/extensions/num_extensions.dart';
import 'package:maki_mobile_pos/core/theme/theme.dart';
import 'package:maki_mobile_pos/core/utils/price_history_view.dart';
import 'package:maki_mobile_pos/domain/repositories/product_repository.dart'
    show PriceHistoryEntry;
import 'package:maki_mobile_pos/presentation/providers/providers.dart';

/// Shared row-date formatter — built once and reused across rows rather than
/// reconstructed per row per build.
final DateFormat _kHistoryDateFormat = DateFormat('MMM d, y • h:mm a');

/// Full-screen, admin-only price-history view for a single product. Combined
/// cost + selling-price, with an All / Price / Cost filter, a sparkline trend,
/// and a detailed table. Reuses [priceHistoryProvider] (newest-first, limit 50).
class PriceHistoryScreen extends ConsumerStatefulWidget {
  const PriceHistoryScreen({super.key, required this.productId});
  final String productId;

  @override
  ConsumerState<PriceHistoryScreen> createState() =>
      _PriceHistoryScreenState();
}

class _PriceHistoryScreenState extends ConsumerState<PriceHistoryScreen> {
  PriceMetric _metric = PriceMetric.all;

  @override
  Widget build(BuildContext context) {
    final historyAsync = ref.watch(priceHistoryProvider(widget.productId));
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(CupertinoIcons.back),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: const Text('Price History'),
      ),
      body: historyAsync.when(
        data: (entries) => _buildBody(context, entries),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => const Center(
          child: Padding(
            padding: EdgeInsets.all(AppSpacing.lg),
            child: Text('Could not load price history'),
          ),
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context, List<PriceHistoryEntry> entries) {
    if (entries.isEmpty) {
      return const Center(child: Text('No price changes yet.'));
    }
    final rows = buildPriceHistoryRows(entries, _metric);
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        _MetricFilter(
          selected: _metric,
          onChanged: (m) => setState(() => _metric = m),
        ),
        const SizedBox(height: AppSpacing.lg),
        _SparklineSection(entries: entries, metric: _metric),
        const SizedBox(height: AppSpacing.lg),
        for (var i = 0; i < rows.length; i++)
          _HistoryRow(row: rows[i], metric: _metric, isFirst: i == 0),
      ],
    );
  }
}

/// Segmented All / Price / Cost filter.
class _MetricFilter extends StatelessWidget {
  const _MetricFilter({required this.selected, required this.onChanged});
  final PriceMetric selected;
  final ValueChanged<PriceMetric> onChanged;

  @override
  Widget build(BuildContext context) {
    return SegmentedButton<PriceMetric>(
      showSelectedIcon: false,
      segments: const [
        ButtonSegment(value: PriceMetric.all, label: Text('All')),
        ButtonSegment(value: PriceMetric.price, label: Text('Price')),
        ButtonSegment(value: PriceMetric.cost, label: Text('Cost')),
      ],
      selected: {selected},
      onSelectionChanged: (s) => onChanged(s.first),
    );
  }
}

/// Stacked, separately-scaled sparklines for the active metric(s). Hidden with
/// a caption when there are fewer than two data points.
class _SparklineSection extends StatelessWidget {
  const _SparklineSection({required this.entries, required this.metric});
  final List<PriceHistoryEntry> entries;
  final PriceMetric metric;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (entries.length < 2) {
      return Text(
        'Not enough changes to chart',
        style: theme.textTheme.bodySmall
            ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
      );
    }
    final showPrice = metric != PriceMetric.cost;
    final showCost = metric != PriceMetric.price;
    final lineColor = theme.colorScheme.primary;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (showPrice) ...[
          const _SparklineLabel('Price'),
          _Sparkline(
            values: sparklineSeries(entries, forCost: false),
            color: lineColor,
          ),
          if (showCost) const SizedBox(height: AppSpacing.md),
        ],
        if (showCost) ...[
          const _SparklineLabel('Cost'),
          _Sparkline(
            values: sparklineSeries(entries, forCost: true),
            color: lineColor,
          ),
        ],
      ],
    );
  }
}

class _SparklineLabel extends StatelessWidget {
  const _SparklineLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Text(
        text,
        style: theme.textTheme.labelSmall
            ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
      ),
    );
  }
}

/// Minimal axis-less, touch-less fl_chart line — a sparkline. [values] are
/// chronological and length >= 2.
class _Sparkline extends StatelessWidget {
  const _Sparkline({required this.values, required this.color});
  final List<double> values;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final spots = <FlSpot>[
      for (var i = 0; i < values.length; i++) FlSpot(i.toDouble(), values[i]),
    ];
    return SizedBox(
      height: 44,
      child: LineChart(
        LineChartData(
          lineTouchData: const LineTouchData(enabled: false),
          gridData: const FlGridData(show: false),
          titlesData: const FlTitlesData(show: false),
          borderData: FlBorderData(show: false),
          minX: 0,
          maxX: (values.length - 1).toDouble(),
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              isCurved: false,
              color: color,
              barWidth: 2,
              dotData: const FlDotData(show: false),
            ),
          ],
        ),
      ),
    );
  }
}

/// One table row: metric value(s) with old->new arrows, then date / actor /
/// source. Mirrors the layout previously used by the inline card.
class _HistoryRow extends ConsumerWidget {
  const _HistoryRow({
    required this.row,
    required this.metric,
    required this.isFirst,
  });
  final PriceHistoryRow row;
  final PriceMetric metric;
  final bool isFirst;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    final isDark = theme.brightness == Brightness.dark;
    final hairline =
        isDark ? AppColors.darkHairline : AppColors.lightHairline;

    final entry = row.entry;
    final showPrice = metric != PriceMetric.cost;
    final showCost = metric != PriceMetric.price;
    final source = derivePriceHistorySource(entry.reason, entry.note);

    final userAsync = ref.watch(userByIdProvider(entry.changedBy));
    final who = userAsync.whenOrNull(data: (u) => u?.displayName) ?? '—';

    return Container(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm + 2),
      decoration: isFirst
          ? null
          : BoxDecoration(border: Border(top: BorderSide(color: hairline))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (showPrice)
                Expanded(
                  child: _MetricLine(
                    label: 'Price',
                    value: entry.price,
                    delta: row.hasPrior ? row.priceDelta : 0,
                  ),
                ),
              if (showPrice && showCost) const SizedBox(width: AppSpacing.md),
              if (showCost)
                Expanded(
                  child: _MetricLine(
                    label: 'Cost',
                    value: entry.cost,
                    delta: row.hasPrior ? row.costDelta : 0,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(_kHistoryDateFormat.format(entry.changedAt),
                  style: theme.textTheme.bodySmall?.copyWith(color: muted)),
              Text('•',
                  style: theme.textTheme.bodySmall?.copyWith(color: muted)),
              Text(who,
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: muted, fontWeight: FontWeight.w500)),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm, vertical: 2),
                decoration: BoxDecoration(
                  border: Border.all(color: hairline),
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                child: Text(source,
                    style: theme.textTheme.labelSmall?.copyWith(color: muted)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// One labelled value with an up/down arrow + delta when it changed.
class _MetricLine extends StatelessWidget {
  const _MetricLine({
    required this.label,
    required this.value,
    required this.delta,
  });
  final String label;
  final double value;
  final double delta;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    final changed = delta.abs() > 0.01;
    final up = delta > 0;
    final arrowColor =
        !changed ? muted : (up ? AppColors.successDark : AppColors.errorDark);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('$label ',
            style: theme.textTheme.bodySmall?.copyWith(color: muted)),
        Text(value.toCurrency(),
            style: theme.textTheme.bodyMedium
                ?.copyWith(fontWeight: FontWeight.w600)),
        if (changed) ...[
          const SizedBox(width: 4),
          Icon(up ? CupertinoIcons.arrow_up : CupertinoIcons.arrow_down,
              size: 12, color: arrowColor),
          Text(delta.abs().toCurrency(),
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: arrowColor, fontWeight: FontWeight.w500)),
        ],
      ],
    );
  }
}
