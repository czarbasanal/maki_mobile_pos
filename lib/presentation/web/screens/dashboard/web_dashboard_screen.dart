import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:maki_mobile_pos/core/theme/theme.dart';
import 'package:maki_mobile_pos/presentation/providers/sale_provider.dart';
import 'package:maki_mobile_pos/presentation/shared/widgets/dashboard/inventory_status_widget.dart';
import 'package:maki_mobile_pos/presentation/shared/widgets/dashboard/recent_sale_widget.dart';
import 'package:maki_mobile_pos/presentation/shared/widgets/dashboard/summary_card.dart';
import 'package:maki_mobile_pos/presentation/web/widgets/web_page.dart';

class WebDashboardScreen extends ConsumerWidget {
  const WebDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summaryAsync = ref.watch(todaysSalesSummaryProvider);
    final money = NumberFormat.currency(symbol: '₱', decimalDigits: 2);

    return WebPage(
      title: 'Dashboard',
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            summaryAsync.when(
              loading: () => const SizedBox(
                height: 120,
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (e, _) => _ErrorTile(message: 'Could not load sales: $e'),
              data: (summary) => Row(
                children: [
                  Expanded(
                    child: SummaryCard(
                      title: 'Sales today',
                      value: '${summary.totalSalesCount}',
                      icon: Icons.receipt_long,
                      iconColor: AppColors.info,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: SummaryCard(
                      title: 'Revenue',
                      value: money.format(summary.netAmount),
                      icon: Icons.payments,
                      iconColor: AppColors.success,
                      highlighted: true,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: SummaryCard(
                      title: 'Gross profit',
                      value: money.format(summary.totalProfit),
                      icon: Icons.trending_up,
                      iconColor: AppColors.primaryAccent,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: SummaryCard(
                      title: 'Avg order',
                      value: money.format(summary.averageSaleAmount),
                      icon: Icons.show_chart,
                      iconColor: AppColors.warning,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 2,
                  child: _PanelCard(
                    title: 'Recent sales',
                    child: const RecentSalesWidget(limit: 8),
                  ),
                ),
                const SizedBox(width: AppSpacing.lg),
                Expanded(
                  flex: 1,
                  child: _PanelCard(
                    title: 'Inventory status',
                    child: const InventoryStatusWidget(),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _PanelCard extends StatelessWidget {
  final String title;
  final Widget child;
  const _PanelCard({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: AppColors.lightDivider),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              title,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
            const SizedBox(height: AppSpacing.md),
            child,
          ],
        ),
      ),
    );
  }
}

class _ErrorTile extends StatelessWidget {
  final String message;
  const _ErrorTile({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.error.withOpacity(0.08),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: AppColors.error),
          const SizedBox(width: AppSpacing.sm),
          Expanded(child: Text(message)),
        ],
      ),
    );
  }
}
