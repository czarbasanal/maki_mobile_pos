import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:maki_mobile_pos/core/constants/app_constants.dart';
import 'package:maki_mobile_pos/domain/repositories/repositories.dart';
import 'package:maki_mobile_pos/presentation/providers/providers.dart';

/// Card displaying top selling products.
class TopProductsCard extends ConsumerWidget {
  final DateTime startDate;
  final DateTime endDate;
  final int limit;

  const TopProductsCard({
    super.key,
    required this.startDate,
    required this.endDate,
    this.limit = 10,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final params = TopSellingParams(
      startDate: startDate,
      endDate: endDate,
      limit: limit,
    );

    final topProductsAsync = ref.watch(topSellingProductsProvider(params));

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                const Icon(Icons.star, color: Colors.amber),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Top Selling Products',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Text(
                  'Top $limit',
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 12,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            topProductsAsync.when(
              data: (products) => _buildProductsList(context, products),
              loading: () => const Center(
                child: Padding(
                  padding: EdgeInsets.all(32),
                  child: CircularProgressIndicator(),
                ),
              ),
              error: (error, _) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text('Error: $error'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProductsList(
    BuildContext context,
    List<ProductSalesData> products,
  ) {
    if (products.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            children: [
              Icon(Icons.inventory_2_outlined,
                  size: 48, color: Colors.grey[400]),
              const SizedBox(height: 8),
              Text(
                'No sales data available',
                style: TextStyle(color: Colors.grey[600]),
              ),
            ],
          ),
        ),
      );
    }

    final maxQuantity = products.first.quantitySold;

    return Column(
      children: products.asMap().entries.map((entry) {
        final index = entry.key;
        final product = entry.value;
        return _buildProductRow(context, index, product, maxQuantity);
      }).toList(),
    );
  }

  Widget _buildProductRow(
    BuildContext context,
    int index,
    ProductSalesData product,
    int maxQuantity,
  ) {
    final theme = Theme.of(context);
    final progress = maxQuantity > 0 ? product.quantitySold / maxQuantity : 0.0;

    // Medal colors for top 3
    Color? medalColor;
    if (index == 0) medalColor = Colors.amber;
    if (index == 1) medalColor = Colors.grey[400];
    if (index == 2) medalColor = Colors.brown[300];

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Rank
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: medalColor ?? Colors.grey[200],
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    '${index + 1}',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                      color:
                          medalColor != null ? Colors.white : Colors.grey[700],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),

              // Product info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      product.name,
                      style: const TextStyle(fontWeight: FontWeight.w500),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      product.sku,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),

              // Stats
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${product.quantitySold} sold',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    '${AppConstants.currencySymbol}${product.totalRevenue.toStringAsFixed(2)}',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ],
          ),

          const SizedBox(height: 8),

          // Progress bar
          Row(
            children: [
              const SizedBox(width: 40),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: progress,
                    backgroundColor: Colors.grey[200],
                    valueColor: AlwaysStoppedAnimation<Color>(
                      _getProgressColor(index),
                    ),
                    minHeight: 6,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // Profit
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.green[50],
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  '+${AppConstants.currencySymbol}${product.totalProfit.toStringAsFixed(0)}',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Colors.green[700],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Color _getProgressColor(int index) {
    switch (index) {
      case 0:
        return Colors.amber;
      case 1:
        return Colors.blueGrey;
      case 2:
        return Colors.brown;
      default:
        return Colors.blue;
    }
  }
}
