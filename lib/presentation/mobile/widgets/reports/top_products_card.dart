import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:maki_mobile_pos/core/constants/app_constants.dart';
import 'package:maki_mobile_pos/core/extensions/num_extensions.dart';
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
            child: _RankRow(
              index: i,
              product: products[i],
              maxQuantity: maxQuantity,
              canViewProfit: canViewProfit,
            ),
          ),
      ],
    );
  }
}

/// One ranked product line: medal + name/SKU + qty/revenue, then a share bar
/// and (admin-only) profit badge.
class _RankRow extends StatelessWidget {
  const _RankRow({
    required this.index,
    required this.product,
    required this.maxQuantity,
    required this.canViewProfit,
  });

  final int index;
  final ProductSalesData product;
  final int maxQuantity;
  final bool canViewProfit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    final isDark = theme.brightness == Brightness.dark;
    final hairline = AppColors.hairline(isDark);
    final progress =
        maxQuantity > 0 ? product.quantitySold / maxQuantity : 0.0;
    final medal = _rankColors(index, isDark);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            // Rank medal.
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: medal.ring,
                  width: index < 3 ? 1.5 : 1,
                ),
              ),
              child: Center(
                child: Text(
                  '${index + 1}',
                  style: theme.textTheme.labelSmall?.copyWith(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: medal.number,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.name,
                    style: AppTextStyles.productName.copyWith(fontSize: 13.5),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    product.sku,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: muted,
                      fontSize: 11.5,
                      fontFamily: 'RobotoMono',
                    ),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${product.quantitySold} sold',
                  style: const TextStyle(
                      fontWeight: FontWeight.w700, fontSize: 13.5),
                ),
                Text(
                  product.totalRevenue.toCurrency(),
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: muted, fontSize: 11.5),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 9),
        Row(
          children: [
            const SizedBox(width: 28),
            const SizedBox(width: 11),
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(AppRadius.pill),
                child: LinearProgressIndicator(
                  value: progress,
                  backgroundColor: hairline,
                  valueColor: AlwaysStoppedAnimation<Color>(medal.bar),
                  minHeight: 6,
                ),
              ),
            ),
            // Profit badge (admin-only; cost/profit data is gated).
            if (canViewProfit) ...[
              const SizedBox(width: 10),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(7),
                  color: AppColors.successFill(isDark),
                ),
                child: Text(
                  '+${AppConstants.currencySymbol}${product.totalProfit.toStringAsFixed(0)}',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppColors.successText(isDark),
                  ),
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }

  /// Medal palette per 0-based rank — amber / silver / bronze for the top three,
  /// neutral after. Rank-1 leads gold in dark to match the primary flip.
  _RankColors _rankColors(int index, bool dark) {
    switch (index) {
      case 0:
        return _RankColors(
          ring: const Color(0xFFE8B84C),
          number: dark ? const Color(0xFFE8B84C) : const Color(0xFFB07A12),
          bar: const Color(0xFFE8B84C),
        );
      case 1:
        return _RankColors(
          ring: const Color(0xFF90A4AE),
          number: dark ? const Color(0xFFAEC0C6) : const Color(0xFF5E7079),
          bar: const Color(0xFF90A4AE),
        );
      case 2:
        return _RankColors(
          ring: const Color(0xFFB08D6F),
          number: dark ? const Color(0xFFCBA890) : const Color(0xFF8A6244),
          bar: const Color(0xFFB08D6F),
        );
      default:
        return _RankColors(
          ring: dark ? AppColors.darkInputBorder : AppColors.lightHairline,
          number:
              dark ? AppColors.darkTextSecondary : AppColors.lightTextMuted,
          bar: dark ? const Color(0xFF5E7A84) : const Color(0xFF283E46),
        );
    }
  }
}

class _RankColors {
  const _RankColors({
    required this.ring,
    required this.number,
    required this.bar,
  });
  final Color ring;
  final Color number;
  final Color bar;
}
