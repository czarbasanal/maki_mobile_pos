import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:maki_mobile_pos/core/constants/app_constants.dart';
import 'package:maki_mobile_pos/core/theme/theme.dart';
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
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  CupertinoIcons.star,
                  color: theme.colorScheme.primary,
                  size: 22,
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    'Top Selling Products',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Text(
                  'Top $limit',
                  style: theme.textTheme.labelSmall?.copyWith(color: muted),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            topProductsAsync.when(
              data: (products) => _buildProductsList(context, products),
              loading: () => const Center(
                child: Padding(
                  padding: EdgeInsets.all(AppSpacing.xl),
                  child: CircularProgressIndicator(),
                ),
              ),
              error: (error, _) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.md),
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
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;

    if (products.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            children: [
              Icon(CupertinoIcons.cube_box, size: 40, color: muted),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'No sales data available',
                style: theme.textTheme.bodyMedium?.copyWith(color: muted),
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
    final muted = theme.colorScheme.onSurfaceVariant;
    final isDark = theme.brightness == Brightness.dark;
    final hairline =
        isDark ? AppColors.darkHairline : AppColors.lightHairline;
    final progress =
        maxQuantity > 0 ? product.quantitySold / maxQuantity : 0.0;

    final medalColor = _medalColor(index);

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm + 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Rank — medal-coloured outlined circle for top 3, neutral
              // outlined for the rest
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: medalColor ?? hairline,
                    width: medalColor != null ? 1.5 : 1,
                  ),
                ),
                child: Center(
                  child: Text(
                    '${index + 1}',
                    style: theme.textTheme.labelSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: medalColor ?? muted,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm + 4),
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
                      style: theme.textTheme.bodySmall?.copyWith(color: muted),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${product.quantitySold} sold',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  Text(
                    '${AppConstants.currencySymbol}${product.totalRevenue.toStringAsFixed(2)}',
                    style: theme.textTheme.bodySmall?.copyWith(color: muted),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              const SizedBox(width: 40),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                  child: LinearProgressIndicator(
                    value: progress,
                    backgroundColor: hairline,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      medalColor ?? theme.colorScheme.primary,
                    ),
                    minHeight: 6,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm + 4),
              // Profit — outlined success badge
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 6,
                  vertical: 2,
                ),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                  border: Border.all(color: AppColors.success),
                ),
                child: Text(
                  '+${AppConstants.currencySymbol}${product.totalProfit.toStringAsFixed(0)}',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppColors.successDark,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Top-3 medal colour. The amber/silver/bronze idiom is widely
  /// understood and worth keeping despite the broader color discipline.
  Color? _medalColor(int index) {
    switch (index) {
      case 0:
        return Colors.amber;
      case 1:
        return Colors.blueGrey;
      case 2:
        return Colors.brown;
      default:
        return null;
    }
  }
}
