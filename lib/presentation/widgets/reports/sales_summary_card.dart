import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:maki_mobile_pos/core/constants/app_constants.dart';
import 'package:maki_mobile_pos/domain/repositories/repositories.dart';
import 'package:maki_mobile_pos/presentation/providers/providers.dart';

/// Card displaying sales summary metrics.
class SalesSummaryCard extends ConsumerWidget {
  final DateTime startDate;
  final DateTime endDate;

  const SalesSummaryCard({
    super.key,
    required this.startDate,
    required this.endDate,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final params = DateRangeParams(
      startDate: startDate,
      endDate: endDate,
    );

    final summaryAsync = ref.watch(salesSummaryProvider(params));

    return summaryAsync.when(
      data: (summary) => _buildSummaryContent(context, summary),
      loading: () => _buildLoadingState(),
      error: (error, _) => _buildErrorState(error),
    );
  }

  Widget _buildSummaryContent(BuildContext context, SalesSummary summary) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Icon(Icons.analytics, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                const Text(
                  'Sales Summary',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 20),

            // Main metrics row
            Row(
              children: [
                Expanded(
                  child: _buildMetricCard(
                    context,
                    'Total Sales',
                    '${summary.totalSalesCount}',
                    Icons.receipt_long,
                    Colors.blue,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildMetricCard(
                    context,
                    'Voided',
                    '${summary.voidedSalesCount}',
                    Icons.cancel,
                    Colors.red,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // Revenue metrics
            Row(
              children: [
                Expanded(
                  child: _buildMetricCard(
                    context,
                    'Gross Sales',
                    '${AppConstants.currencySymbol}${summary.grossAmount.toStringAsFixed(2)}',
                    Icons.attach_money,
                    Colors.green,
                    subtitle: 'Before discounts',
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildMetricCard(
                    context,
                    'Discounts',
                    '-${AppConstants.currencySymbol}${summary.totalDiscounts.toStringAsFixed(2)}',
                    Icons.local_offer,
                    Colors.orange,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 16),

            // Net sales highlight
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer.withOpacity(0.3),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Net Sales',
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: Colors.grey[700],
                          ),
                        ),
                        Text(
                          '${AppConstants.currencySymbol}${summary.netAmount.toStringAsFixed(2)}',
                          style: theme.textTheme.headlineMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.green,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      'Avg: ${AppConstants.currencySymbol}${summary.averageSaleAmount.toStringAsFixed(2)}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Profit section
            Row(
              children: [
                Expanded(
                  child: _buildMetricCard(
                    context,
                    'Total Cost',
                    '${AppConstants.currencySymbol}${summary.totalCost.toStringAsFixed(2)}',
                    Icons.inventory,
                    Colors.grey,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildMetricCard(
                    context,
                    'Gross Profit',
                    '${AppConstants.currencySymbol}${summary.totalProfit.toStringAsFixed(2)}',
                    Icons.trending_up,
                    Colors.green,
                    subtitle:
                        '${summary.profitMargin.toStringAsFixed(1)}% margin',
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricCard(
    BuildContext context,
    String label,
    String value,
    IconData icon,
    Color color, {
    String? subtitle,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[700],
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          if (subtitle != null)
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 10,
                color: Colors.grey[600],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildLoadingState() {
    return const Card(
      child: Padding(
        padding: EdgeInsets.all(48),
        child: Center(child: CircularProgressIndicator()),
      ),
    );
  }

  Widget _buildErrorState(Object error) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const Icon(Icons.error_outline, color: Colors.red, size: 48),
            const SizedBox(height: 8),
            Text('Failed to load summary: $error'),
          ],
        ),
      ),
    );
  }
}
