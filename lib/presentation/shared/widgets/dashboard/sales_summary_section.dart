import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:maki_mobile_pos/core/constants/app_constants.dart';
import 'package:maki_mobile_pos/core/theme/theme.dart';
import 'package:maki_mobile_pos/presentation/providers/sale_provider.dart';
import 'package:maki_mobile_pos/presentation/shared/widgets/dashboard/summary_card.dart';

/// Today's Sales card row for the mobile admin dashboard.
///
/// Layout:
///   Row 1 (all roles): Gross Sales | Avg Daily Sales (this week)
///   Row 2 (admin only): Total COGS | Gross Profit
///
/// Avg Daily Sales is sourced from a separate week-to-date provider, so a
/// dash is shown while it loads even if today's summary is already in.
class SalesSummarySection extends ConsumerWidget {
  /// When true, shows the second row (Total COGS + Gross Profit).
  /// Cost data is admin-only.
  final bool showProfit;

  const SalesSummarySection({super.key, required this.showProfit});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summaryAsync = ref.watch(todaysSalesSummaryProvider);
    final avgDailyAsync = ref.watch(avgDailySalesProvider);

    return summaryAsync.when(
      data: (summary) {
        final avgDaily = avgDailyAsync.valueOrNull;
        return Column(
          children: [
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: SummaryCard(
                      title: 'Gross Sales',
                      value:
                          '${AppConstants.currencySymbol}${_formatNumber(summary.grossAmount)}',
                      icon: AppIcons.peso,
                      subtitle: summary.totalDiscounts > 0
                          ? '${AppConstants.currencySymbol}${_formatNumber(summary.totalDiscounts)} discount'
                          : null,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: SummaryCard(
                      title: 'Avg Daily Sales',
                      value: avgDaily != null
                          ? '${AppConstants.currencySymbol}${_formatNumber(avgDaily)}'
                          : '—',
                      icon: CupertinoIcons.chart_bar,
                      subtitle: 'this week',
                    ),
                  ),
                ],
              ),
            ),
            if (showProfit) ...[
              const SizedBox(height: 12),
              IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      child: SummaryCard(
                        title: 'Total COGS',
                        value:
                            '${AppConstants.currencySymbol}${_formatNumber(summary.totalCost)}',
                        icon: CupertinoIcons.cube_box,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: SummaryCard(
                        title: 'Gross Profit',
                        value:
                            '${AppConstants.currencySymbol}${_formatNumber(summary.totalProfit)}',
                        icon: CupertinoIcons.arrow_up_right,
                        subtitle:
                            '${summary.profitMargin.toStringAsFixed(1)}% margin',
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        );
      },
      loading: () => const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: CircularProgressIndicator(),
        ),
      ),
      error: (error, _) => Center(
        child: Text('Error loading summary: $error'),
      ),
    );
  }

  String _formatNumber(double value) {
    if (value >= 1000000) {
      return '${(value / 1000000).toStringAsFixed(1)}M';
    }
    if (value >= 1000) {
      return '${(value / 1000).toStringAsFixed(1)}K';
    }
    return value.toStringAsFixed(2);
  }
}
