import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:maki_mobile_pos/config/router/router.dart';
import 'package:maki_mobile_pos/core/constants/role_permissions.dart';
import 'package:maki_mobile_pos/core/theme/theme.dart';
import 'package:maki_mobile_pos/domain/repositories/repositories.dart';
import 'package:maki_mobile_pos/presentation/providers/providers.dart';
import 'package:maki_mobile_pos/presentation/shared/widgets/common/common_widgets.dart';

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
    final canViewProfit = ref
            .watch(currentUserProvider)
            .valueOrNull
            ?.hasPermission(Permission.viewProfitReports) ??
        false;
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;

    return AppCard(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(LucideIcons.star, color: theme.colorScheme.primary,
                  size: 19),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  'Top Selling Products',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                ),
              ),
              Text(
                'Top $limit',
                style: theme.textTheme.labelSmall
                    ?.copyWith(color: muted, fontWeight: FontWeight.w600),
              ),
            ],
          ),
          const SizedBox(height: 14),
          topProductsAsync.when(
            data: (products) =>
                _buildProductsList(context, products, canViewProfit),
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
    );
  }

  Widget _buildProductsList(
    BuildContext context,
    List<ProductSalesData> products,
    bool canViewProfit,
  ) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;

    if (products.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            children: [
              Icon(LucideIcons.package, size: 40, color: muted),
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
      children: [
        for (var i = 0; i < products.length; i++)
          Padding(
            padding: EdgeInsets.only(
                bottom: i == products.length - 1 ? 0 : 14),
            child: RankRow(
              index: i,
              name: products[i].name,
              subtitle: products[i].sku,
              quantitySold: products[i].quantitySold,
              revenue: products[i].totalRevenue,
              maxQuantity: maxQuantity,
              onTap: () => context
                  .push('${RoutePaths.inventory}/${products[i].productId}'),
              profit: canViewProfit ? products[i].totalProfit : null,
            ),
          ),
      ],
    );
  }
}
