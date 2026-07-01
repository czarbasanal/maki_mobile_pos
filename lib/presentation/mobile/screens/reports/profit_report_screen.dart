import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:maki_mobile_pos/config/router/router.dart';
import 'package:maki_mobile_pos/core/extensions/navigation_extensions.dart';
import 'package:maki_mobile_pos/core/extensions/num_extensions.dart';
import 'package:maki_mobile_pos/core/theme/theme.dart';
import 'package:maki_mobile_pos/core/utils/report_csv.dart';
import 'package:maki_mobile_pos/core/utils/report_date_range.dart';
import 'package:maki_mobile_pos/core/utils/report_export.dart';
import 'package:maki_mobile_pos/domain/repositories/repositories.dart';
import 'package:maki_mobile_pos/presentation/providers/providers.dart';
import 'package:maki_mobile_pos/presentation/mobile/widgets/reports/date_range_picker.dart';
import 'package:maki_mobile_pos/presentation/shared/widgets/common/common_widgets.dart';
import 'package:intl/intl.dart';

/// Screen displaying profit reports (admin-only). Wires the profit summary and
/// a profit-ranked product list off [profitReportProvider] /
/// [topSellingProductsProvider] for the selected range.
class ProfitReportScreen extends ConsumerStatefulWidget {
  const ProfitReportScreen({super.key});

  @override
  ConsumerState<ProfitReportScreen> createState() => _ProfitReportScreenState();
}

class _ProfitReportScreenState extends ConsumerState<ProfitReportScreen> {
  late DateTime _startDate;
  late DateTime _endDate;
  DateRangePreset _selectedPreset = DateRangePreset.today;

  @override
  void initState() {
    super.initState();
    final r = dateRangeForPreset(DateRangePreset.today, DateTime.now());
    _startDate = r.start;
    _endDate = r.end;
  }

  DateRangeParams get _params =>
      DateRangeParams(startDate: _startDate, endDate: _endDate);

  TopSellingParams get _topParams => TopSellingParams(
        startDate: _startDate,
        endDate: _endDate,
        limit: 50,
      );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final profitAsync = ref.watch(profitReportProvider(_params));
    final topAsync = ref.watch(topSellingProductsProvider(_topParams));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profit Report'),
        leading: IconButton(
          icon: const Icon(LucideIcons.chevronLeft),
          onPressed: () => context.goBackOr(RoutePaths.reports),
        ),
        actions: [
          IconButton(
            icon: const Icon(LucideIcons.download),
            tooltip: 'Export CSV',
            onPressed: _exportCsv,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(profitReportProvider(_params));
          ref.invalidate(topSellingProductsProvider(_topParams));
        },
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
            // Summary cards.
            profitAsync.when(
              loading: () => const Padding(
                padding: EdgeInsets.fromLTRB(16, 16, 16, 4),
                child: SizedBox(height: 180, child: ListSkeleton(count: 2)),
              ),
              error: (e, _) => Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                child: ErrorStateView(
                  message: 'Failed to load profit: $e',
                  onRetry: () => ref.invalidate(profitReportProvider(_params)),
                ),
              ),
              data: _buildMetrics,
            ),
            // Profit by product.
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 18, 18, 6),
              child: Text(
                'Profit by Product',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                ),
              ),
            ),
            topAsync.when(
              loading: () => const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: SizedBox(height: 300, child: ListSkeleton()),
              ),
              error: (e, _) => Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: ErrorStateView(
                  message: 'Failed to load products: $e',
                  onRetry: () =>
                      ref.invalidate(topSellingProductsProvider(_topParams)),
                ),
              ),
              data: _buildProductList,
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildMetrics(SalesSummary s) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _ProfitMetricCard(
                  title: 'Total Revenue',
                  value: s.netAmount.toCurrency(),
                  icon: LucideIcons.banknote,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _ProfitMetricCard(
                  title: 'Total Cost',
                  value: s.totalCost.toCurrency(),
                  icon: LucideIcons.wallet,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _ProfitMetricCard(
                  title: 'Gross Profit',
                  value: s.totalProfit.toCurrency(),
                  icon: LucideIcons.trendingUp,
                  accent: AppColors.success,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _ProfitMetricCard(
                  title: 'Profit Margin',
                  value: '${s.profitMargin.toStringAsFixed(1)}%',
                  icon: LucideIcons.percent,
                  accent: AppColors.success,
                ),
              ),
            ],
          ),
          if (s.laborProfit > 0) ...[
            const SizedBox(height: 10),
            _ProfitMetricCard(
              title: 'Service / Labor Profit (tracked separately)',
              value: s.laborProfit.toCurrency(),
              icon: LucideIcons.wrench,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildProductList(List<ProductSalesData> products) {
    final theme = Theme.of(context);
    if (products.isEmpty) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 24, 16, 0),
        child: EmptyStateView(
          icon: LucideIcons.trendingUp,
          title: 'No profit data available',
          subtitle: 'Make some sales in this range to see profit by product.',
        ),
      );
    }
    // Rank by profit — the report's lens (provider ranks by units sold).
    final ranked = [...products]
      ..sort((a, b) => b.totalProfit.compareTo(a.totalProfit));

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          for (final p in ranked)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _ProductProfitRow(product: p, theme: theme),
            ),
        ],
      ),
    );
  }

  Future<void> _exportCsv() async {
    final products =
        await ref.read(topSellingProductsProvider(_topParams).future);
    if (!mounted) return;
    if (products.isEmpty) {
      context.showSnackBar('No profit data to export in this range');
      return;
    }
    final d = DateFormat('yyyy-MM-dd');
    final name = 'profit_${d.format(_startDate)}_to_${d.format(_endDate)}.csv';
    if (!mounted) return;
    await saveReportCsv(context, buildProfitReportCsv(products), name);
  }
}

/// One product row in the profit-by-product list.
class _ProductProfitRow extends StatelessWidget {
  const _ProductProfitRow({required this.product, required this.theme});

  final ProductSalesData product;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    final isDark = theme.brightness == Brightness.dark;
    final muted = theme.colorScheme.onSurfaceVariant;
    return AppCard(
      radius: 12,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  product.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    fontSize: 13.5,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${product.quantitySold} sold · ${product.totalRevenue.toCurrency()} rev · ${product.totalCost.toCurrency()} cost',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: muted,
                    fontSize: 11.5,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Text(
            '+${product.totalProfit.toCurrency()}',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
              fontSize: 14,
              color: AppColors.successText(isDark),
            ),
          ),
        ],
      ),
    );
  }
}

/// Outlined metric card for the Profit Report (matches Sales Summary metrics).
class _ProfitMetricCard extends StatelessWidget {
  const _ProfitMetricCard({
    required this.title,
    required this.value,
    required this.icon,
    this.accent,
  });

  final String title;
  final String value;
  final IconData icon;
  final Color? accent;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    final isDark = theme.brightness == Brightness.dark;
    final hairline = AppColors.hairline(isDark);
    final valueColor =
        accent == AppColors.success ? AppColors.successText(isDark) : null;

    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : AppColors.lightCard,
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: accent ?? hairline),
        boxShadow: isDark
            ? null
            : const [
                BoxShadow(
                  color: Color(0x0A111C1D),
                  blurRadius: 3,
                  offset: Offset(0, 1),
                ),
              ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 15, color: accent ?? muted),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  title,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: accent ?? muted,
                    fontWeight: FontWeight.w500,
                    fontSize: 11,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w700,
              fontSize: 18,
              color: valueColor ?? theme.colorScheme.onSurface,
            ),
          ),
        ],
      ),
    );
  }
}
