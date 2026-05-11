import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:maki_mobile_pos/core/constants/app_constants.dart';
import 'package:maki_mobile_pos/core/theme/theme.dart';
import 'package:maki_mobile_pos/domain/entities/entities.dart';
import 'package:maki_mobile_pos/presentation/mobile/widgets/inventory/cost_code_pill.dart';

/// List tile for displaying a product in the inventory.
///
/// Stock state is the only colour-bearing element on the tile —
/// success / warning / error tokens via [AppColors] communicate
/// in / low / out of stock. Everything else (category, price, cost,
/// margin, cost code) sits in muted neutrals so the row scans by
/// structure first and color second. Stock adjustment lives on the
/// product detail screen — tap the tile to reach it.
class ProductListTile extends StatelessWidget {
  final ProductEntity product;
  final bool showCost;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  const ProductListTile({
    super.key,
    required this.product,
    required this.showCost,
    required this.onTap,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;

    return Card(
      margin: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.xs,
      ),
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.sm + 4),
          child: Row(
            children: [
              _LeadingVisual(product: product),
              const SizedBox(width: AppSpacing.sm + 4),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      product.name,
                      style: AppTextStyles.productName,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Text(
                          product.sku,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: muted,
                            fontFamily: 'monospace',
                          ),
                        ),
                        if (product.category != null) ...[
                          Text(' • ', style: TextStyle(color: muted)),
                          _CategoryChip(label: product.category!),
                        ],
                      ],
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Row(
                      children: [
                        _PricePill(
                          value:
                              '${AppConstants.currencySymbol}${product.price.toStringAsFixed(2)}',
                          color: theme.colorScheme.primary,
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        if (showCost) ...[
                          _CostPill(
                            value:
                                '${AppConstants.currencySymbol}${product.cost.toStringAsFixed(2)}',
                          ),
                          const SizedBox(width: 4),
                          _MarginBadge(
                            margin: product.profitMargin,
                          ),
                        ] else
                          CostCodePill(cost: product.cost, compact: true),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              _StockBadge(product: product),
            ],
          ),
        ),
      ),
    );
  }
}

/// Tile leading visual: a 40x40 thumbnail when [ProductEntity.imageUrl] is
/// set, otherwise the stock-status icon. Stock count + color are already
/// communicated by the trailing [_StockBadge], so the leading slot is free
/// to surface imagery when available.
class _LeadingVisual extends StatelessWidget {
  const _LeadingVisual({required this.product});
  final ProductEntity product;

  static const double _size = 40;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final url = product.imageUrl;
    if (url != null && url.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(AppRadius.sm),
        child: Image.network(
          url,
          width: _size,
          height: _size,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _stockFallback(theme),
        ),
      );
    }
    return _stockFallback(theme);
  }

  Widget _stockFallback(ThemeData theme) {
    final (color, icon) = _stockStyle(product);
    return SizedBox(
      width: _size,
      height: _size,
      child: Icon(icon, color: color, size: 24),
    );
  }
}

class _CategoryChip extends StatelessWidget {
  const _CategoryChip({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    final isDark = theme.brightness == Brightness.dark;
    final hairline =
        isDark ? AppColors.darkHairline : AppColors.lightHairline;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
        border: Border.all(color: hairline),
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Text(
        label,
        style: theme.textTheme.labelSmall?.copyWith(
          fontSize: 10,
          color: muted,
        ),
      ),
    );
  }
}

class _PricePill extends StatelessWidget {
  const _PricePill({required this.value, required this.color});
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        border: Border.all(color: color, width: 1.2),
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Text(
        value,
        style: TextStyle(
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}

class _CostPill extends StatelessWidget {
  const _CostPill({required this.value});
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    final isDark = theme.brightness == Brightness.dark;
    final hairline =
        isDark ? AppColors.darkHairline : AppColors.lightHairline;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        border: Border.all(color: hairline),
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Cost: ',
            style: TextStyle(fontSize: 12, color: muted),
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _MarginBadge extends StatelessWidget {
  const _MarginBadge({required this.margin});
  final double margin;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.success),
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Text(
        '${margin.toStringAsFixed(0)}%',
        style: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: AppColors.successDark,
        ),
      ),
    );
  }
}

class _StockBadge extends StatelessWidget {
  const _StockBadge({required this.product});
  final ProductEntity product;

  @override
  Widget build(BuildContext context) {
    final (color, _) = _stockStyle(product);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        border: Border.all(color: color, width: 1.2),
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Column(
        children: [
          Text(
            '${product.quantity}',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
          Text(
            product.unit,
            style: TextStyle(fontSize: 10, color: color),
          ),
        ],
      ),
    );
  }
}

/// Status -> (color, icon) for in / low / out of stock.
(Color, IconData) _stockStyle(ProductEntity product) {
  if (product.isOutOfStock) {
    return (AppColors.error, CupertinoIcons.exclamationmark_circle);
  }
  if (product.isLowStock) {
    return (AppColors.warning, CupertinoIcons.exclamationmark_triangle);
  }
  return (AppColors.success, CupertinoIcons.checkmark_circle);
}
