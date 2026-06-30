import 'package:fl_chart/fl_chart.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:maki_mobile_pos/core/extensions/num_extensions.dart';
import 'package:maki_mobile_pos/core/theme/theme.dart';
import 'package:maki_mobile_pos/presentation/shared/widgets/common/app_card.dart';
import 'package:maki_mobile_pos/presentation/shared/widgets/common/app_skeleton.dart';
import 'package:maki_mobile_pos/presentation/shared/widgets/common/state_views.dart';
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
          icon: const Icon(LucideIcons.chevronLeft),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: const Text('Price History'),
      ),
      body: historyAsync.when(
        data: (entries) => _buildBody(context, entries),
        loading: () => const ListSkeleton(),
        error: (_, __) => ErrorStateView(
          message: 'Could not load price history',
          onRetry: () =>
              ref.invalidate(priceHistoryProvider(widget.productId)),
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context, List<PriceHistoryEntry> entries) {
    if (entries.isEmpty) {
      return const EmptyStateView(
        icon: LucideIcons.trendingUp,
        title: 'No price changes yet',
        subtitle: 'Cost and price updates will show up here.',
      );
    }
    final rows = buildPriceHistoryRows(entries, _metric);
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        _MetricFilter(
          selected: _metric,
          onChanged: (m) => setState(() => _metric = m),
        ),
        const SizedBox(height: 14),
        _SparklineSection(entries: entries, metric: _metric),
        Padding(
          padding: const EdgeInsets.only(left: 2, top: 18, bottom: 8),
          child: Text(
            'CHANGES',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.8,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        AppCard(
          radius: AppRadius.lg,
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          child: Column(
            children: [
              for (var i = 0; i < rows.length; i++)
                _HistoryRow(row: rows[i], metric: _metric, isFirst: i == 0),
            ],
          ),
        ),
      ],
    );
  }
}

/// Segmented All / Price / Cost filter — a pill on an [AppCard]; selected
/// segment is a slate(light)/gold(dark) fill, per the handoff.
class _MetricFilter extends StatelessWidget {
  const _MetricFilter({required this.selected, required this.onChanged});
  final PriceMetric selected;
  final ValueChanged<PriceMetric> onChanged;

  static const _labels = {
    PriceMetric.all: 'All',
    PriceMetric.price: 'Price',
    PriceMetric.cost: 'Cost',
  };

  @override
  Widget build(BuildContext context) {
    return AppCard(
      key: const Key('metric-filter'),
      radius: AppRadius.pill,
      padding: const EdgeInsets.all(4),
      child: Row(
        children: [
          for (final m in PriceMetric.values)
            Expanded(child: _segment(context, m)),
        ],
      ),
    );
  }

  Widget _segment(BuildContext context, PriceMetric m) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final isSel = m == selected;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => onChanged(m),
      child: Container(
        key: Key('metric-seg-${m.name}'),
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: isSel
              ? (isDark ? AppColors.primaryAccent : AppColors.brandSlate)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(AppRadius.pill),
        ),
        child: Text(
          _labels[m]!,
          style: TextStyle(
            fontSize: 13,
            fontWeight: isSel ? FontWeight.w600 : FontWeight.w500,
            color: isSel
                ? (isDark ? AppColors.primaryDark : Colors.white)
                : theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ),
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
    final isDark = theme.brightness == Brightness.dark;
    final priceColor = theme.colorScheme.primary;
    final costColor =
        isDark ? const Color(0xFF6C797C) : const Color(0xFF9AA0A3);
    final priceSeries = sparklineSeries(entries, forCost: false);
    final costSeries = sparklineSeries(entries, forCost: true);
    return AppCard(
      radius: AppRadius.lg,
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (showPrice) ...[
            _TrendHeader(
              label: 'Price trend',
              from: priceSeries.first,
              to: priceSeries.last,
            ),
            const SizedBox(height: 6),
            _Sparkline(values: priceSeries, color: priceColor),
            if (showCost) const SizedBox(height: AppSpacing.md),
          ],
          if (showCost) ...[
            _TrendHeader(
              label: 'Cost trend',
              from: costSeries.first,
              to: costSeries.last,
            ),
            const SizedBox(height: 6),
            _Sparkline(values: costSeries, color: costColor),
          ],
        ],
      ),
    );
  }
}

/// Sparkline header: a muted "Price/Cost trend" label on the left, the
/// from→to range (compact) on the right.
class _TrendHeader extends StatelessWidget {
  const _TrendHeader(
      {required this.label, required this.from, required this.to});
  final String label;
  final double from;
  final double to;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Text(
          label,
          style: theme.textTheme.labelSmall
              ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
        ),
        Text(
          '${from.toCurrencyCompact()} → ${to.toCurrencyCompact()}',
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
        ),
      ],
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
      height: 40,
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
              barWidth: 2.5,
              isStrokeCapRound: true,
              isStrokeJoinRound: true,
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
        Text(value.toCurrencyCompact(),
            style: theme.textTheme.bodyMedium
                ?.copyWith(fontWeight: FontWeight.w600)),
        if (changed) ...[
          const SizedBox(width: 4),
          Icon(up ? LucideIcons.arrowUp : LucideIcons.arrowDown,
              size: 12, color: arrowColor),
          Text(delta.abs().toCurrencyCompact(),
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: arrowColor, fontWeight: FontWeight.w500)),
        ],
      ],
    );
  }
}
