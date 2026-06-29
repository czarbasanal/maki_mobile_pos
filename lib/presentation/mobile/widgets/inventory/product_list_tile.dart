import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:maki_mobile_pos/core/extensions/num_extensions.dart';
import 'package:maki_mobile_pos/core/theme/theme.dart';
import 'package:maki_mobile_pos/domain/entities/entities.dart';
import 'package:maki_mobile_pos/presentation/mobile/widgets/inventory/cost_code_pill.dart';
import 'package:maki_mobile_pos/presentation/shared/widgets/common/app_card.dart';

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
    final isDark = theme.brightness == Brightness.dark;
    final muted = theme.colorScheme.onSurfaceVariant;

    final row = Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _LeadingVisual(product: product, isDark: isDark),
        const SizedBox(width: 11),
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
              const SizedBox(height: 3),
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
                    const SizedBox(width: 6),
                    _CategoryChip(label: product.category!),
                  ],
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              Row(
                children: [
                  _PricePill(value: product.price.toCurrency(), isDark: isDark),
                  const SizedBox(width: 6),
                  if (showCost) ...[
                    _CostPill(value: product.cost.toCurrencyCompact()),
                    const SizedBox(width: 6),
                    _MarginBadge(margin: product.profitMargin, isDark: isDark),
                  ] else
                    CostCodePill(cost: product.cost, compact: true),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        _StockBadge(product: product, isDark: isDark),
      ],
    );

    return AppCard(
      margin: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.xs,
      ),
      radius: 16,
      padding: const EdgeInsets.all(12),
      onTap: onTap,
      child: onLongPress != null
          ? GestureDetector(
              behavior: HitTestBehavior.opaque,
              onLongPress: onLongPress,
              child: row,
            )
          : row,
    );
  }
}

/// Tile leading visual: a 40x40 thumbnail when [ProductEntity.imageUrl] is
/// set, otherwise a stock-tinted icon. Stock count + color are already
/// communicated by the trailing [_StockBadge], so the leading slot is free
/// to surface imagery when available.
class _LeadingVisual extends StatelessWidget {
  const _LeadingVisual({required this.product, required this.isDark});
  final ProductEntity product;
  final bool isDark;

  static const double _size = 40;

  @override
  Widget build(BuildContext context) {
    final url = product.imageUrl;
    if (url != null && url.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(11),
        child: Image.network(
          url,
          width: _size,
          height: _size,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _stockFallback(),
        ),
      );
    }
    return _stockFallback();
  }

  Widget _stockFallback() {
    final s = _stockStyle(product, isDark);
    return Container(
      width: _size,
      height: _size,
      decoration: BoxDecoration(
        color: s.tint,
        borderRadius: BorderRadius.circular(11),
      ),
      child: Icon(s.icon, color: s.color, size: 21),
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
        borderRadius: BorderRadius.circular(7),
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

/// Filled primary pill carrying the selling price (slate light / gold dark).
class _PricePill extends StatelessWidget {
  const _PricePill({required this.value, required this.isDark});
  final String value;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(
        color: isDark ? AppColors.primaryAccent : AppColors.brandSlate,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        value,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: isDark ? AppColors.primaryDark : Colors.white,
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
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        border: Border.all(color: hairline),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('Cost ', style: TextStyle(fontSize: 11, color: muted)),
          Text(
            value,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: theme.colorScheme.onSurface,
            ),
          ),
        ],
      ),
    );
  }
}

/// Filled success-tint badge carrying the profit margin %.
class _MarginBadge extends StatelessWidget {
  const _MarginBadge({required this.margin, required this.isDark});
  final double margin;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.successFill(isDark),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        '${margin.toStringAsFixed(0)}%',
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: AppColors.successText(isDark),
        ),
      ),
    );
  }
}

class _StockBadge extends StatelessWidget {
  const _StockBadge({required this.product, required this.isDark});
  final ProductEntity product;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final s = _stockStyle(product, isDark);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
      decoration: BoxDecoration(
        border: Border.all(color: s.border, width: 1.4),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Text(
            '${product.quantity}',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: s.color,
            ),
          ),
          Text(
            product.unit,
            style: TextStyle(fontSize: 10, color: s.color),
          ),
        ],
      ),
    );
  }
}

/// Stock state → theme-aware colors + Lucide icon for in / low / out of stock.
/// `color` paints the icon, count, and badge text; `border` the badge outline;
/// `tint` the leading-visual fallback background.
({Color color, Color border, Color tint, IconData icon}) _stockStyle(
    ProductEntity product, bool isDark) {
  if (product.isOutOfStock) {
    return (
      color: isDark ? const Color(0xFFFF6B5E) : AppColors.error,
      border: AppColors.error,
      tint: AppColors.error.withValues(alpha: isDark ? 0.16 : 0.10),
      icon: LucideIcons.alertCircle,
    );
  }
  if (product.isLowStock) {
    final low = isDark ? const Color(0xFFF5B547) : AppColors.warningDark;
    return (
      color: low,
      border: low,
      tint: (isDark ? const Color(0xFFF5B547) : AppColors.warning)
          .withValues(alpha: isDark ? 0.16 : 0.14),
      icon: LucideIcons.alertTriangle,
    );
  }
  return (
    color: isDark ? const Color(0xFF5FC86A) : AppColors.success,
    border: AppColors.success,
    tint: AppColors.success.withValues(alpha: isDark ? 0.16 : 0.10),
    icon: LucideIcons.checkCircle,
  );
}
