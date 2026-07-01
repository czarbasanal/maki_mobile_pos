import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
    final reportAsync = ref.watch(priceChangeReportProvider(_params));
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
            ref.invalidate(priceChangeReportProvider(_params)),
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
                      ref.invalidate(priceChangeReportProvider(_params)),
                ),
              ),
              data: (rows) => _buildList(theme, rows, labels),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildList(
      ThemeData theme, List<PriceChangeRow> rows, Map<String, String> labels) {
    if (rows.isEmpty) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 24, 16, 0),
        child: EmptyStateView(
          icon: LucideIcons.tag,
          title: 'No price changes',
          subtitle: 'Price/cost changes in this range will appear here.',
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          for (final row in rows)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: _PriceChangeRowCard(
                row: row,
                label: labels[row.entry.productId] ?? row.entry.productId,
                theme: theme,
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

class _PriceChangeRowCard extends StatelessWidget {
  const _PriceChangeRowCard(
      {required this.row, required this.label, required this.theme});
  final PriceChangeRow row;
  final String label;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    final muted = theme.colorScheme.onSurfaceVariant;
    final e = row.entry;
    final when = DateFormat('MMM d, y • h:mm a').format(e.changedAt);
    return AppCard(
      radius: 12,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodyMedium
                  ?.copyWith(fontWeight: FontWeight.w600, fontSize: 13.5)),
          const SizedBox(height: 4),
          Row(
            children: [
              _MoneyDelta(
                  label: 'Price',
                  value: e.price,
                  delta: row.priceDelta,
                  hasPrior: row.hasPrior,
                  theme: theme),
              const SizedBox(width: 16),
              _MoneyDelta(
                  label: 'Cost',
                  value: e.cost,
                  delta: row.costDelta,
                  hasPrior: row.hasPrior,
                  theme: theme),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '${e.reason ?? 'change'} · $when',
            style: theme.textTheme.bodySmall
                ?.copyWith(color: muted, fontSize: 11.5),
          ),
        ],
      ),
    );
  }
}

class _MoneyDelta extends StatelessWidget {
  const _MoneyDelta(
      {required this.label,
      required this.value,
      required this.delta,
      required this.hasPrior,
      required this.theme});
  final String label;
  final double value;
  final double delta;
  final bool hasPrior;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    final isDark = theme.brightness == Brightness.dark;
    final muted = theme.colorScheme.onSurfaceVariant;
    final up = delta > 0;
    final deltaColor =
        up ? AppColors.costUp(isDark) : AppColors.costDown(isDark);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('$label ',
            style: theme.textTheme.bodySmall
                ?.copyWith(color: muted, fontSize: 11.5)),
        Text(value.toCurrency(),
            style: theme.textTheme.bodyMedium
                ?.copyWith(fontWeight: FontWeight.w600, fontSize: 12.5)),
        if (hasPrior && delta != 0) ...[
          const SizedBox(width: 4),
          Icon(up ? LucideIcons.arrowUpRight : LucideIcons.arrowDownRight,
              size: 12, color: deltaColor),
          Text(delta.abs().toCurrency(),
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: deltaColor, fontSize: 11)),
        ],
      ],
    );
  }
}
