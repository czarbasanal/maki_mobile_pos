import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:maki_mobile_pos/core/constants/app_constants.dart';
import 'package:maki_mobile_pos/core/extensions/num_extensions.dart';
import 'package:maki_mobile_pos/presentation/shared/widgets/common/common_widgets.dart';
import 'package:maki_mobile_pos/core/enums/enums.dart';
import 'package:maki_mobile_pos/core/theme/theme.dart';
import 'package:maki_mobile_pos/domain/entities/entities.dart';
import 'package:maki_mobile_pos/presentation/mobile/widgets/inventory/cost_code_pill.dart';

/// Displays a single item in the cart with quantity controls and discount.
class CartItemTile extends StatelessWidget {
  final SaleItemEntity item;
  final DiscountType discountType;
  final ValueChanged<int> onQuantityChanged;
  final VoidCallback onDiscountTap;
  final VoidCallback onRemove;

  const CartItemTile({
    super.key,
    required this.item,
    required this.discountType,
    required this.onQuantityChanged,
    required this.onDiscountTap,
    required this.onRemove,
  });

  bool get isPercentageDiscount => discountType == DiscountType.percentage;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final muted = theme.colorScheme.onSurfaceVariant;
    final netAmount = item.calculateNetAmount(
      isPercentage: isPercentageDiscount,
    );

    return Dismissible(
      key: Key(item.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: AppSpacing.lg - 4),
        color: AppColors.error,
        child: const Icon(LucideIcons.trash2, color: Colors.white),
      ),
      onDismissed: (_) => onRemove(),
      child: AppCard(
        margin: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: 5,
        ),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.sm + 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Product name and remove button
              Row(
                children: [
                  Expanded(
                    child: Text(
                      item.name,
                      style: AppTextStyles.productName.copyWith(fontSize: 14),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(LucideIcons.x, size: 20),
                    onPressed: onRemove,
                    visualDensity: VisualDensity.compact,
                    tooltip: 'Remove item',
                  ),
                ],
              ),
              // SKU + unit price (muted) + encoded cost-code pill so the
              // cashier can sanity-check the line's cost at a glance
              // without exposing the raw number.
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '${item.sku} • ${item.unitPrice.toCurrency()} / ${item.unit}',
                      style:
                          theme.textTheme.bodySmall?.copyWith(color: muted),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  CostCodePill(cost: item.unitCost, compact: true),
                ],
              ),
              const SizedBox(height: AppSpacing.sm + 4),
              // Quantity controls + discount button + line total
              Row(
                children: [
                  _QuantityControls(
                    quantity: item.quantity,
                    onChanged: onQuantityChanged,
                  ),
                  const SizedBox(width: AppSpacing.md),
                  _DiscountButton(
                    hasDiscount: item.hasDiscount,
                    label: isPercentageDiscount
                        ? '${item.discountValue.toStringAsFixed(0)}%'
                        : '${AppConstants.currencySymbol}${item.discountValue.toStringAsFixed(0)}',
                    onTap: onDiscountTap,
                  ),
                  const Spacer(),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      // Discounted: small strikethrough gross over the green
                      // net — the net is the hero (17/700), matching handoff.
                      if (item.hasDiscount)
                        Text(
                          item.grossAmount.toCurrency(),
                          style: TextStyle(
                            fontSize: 11,
                            decoration: TextDecoration.lineThrough,
                            color: muted,
                          ),
                        ),
                      Text(
                        netAmount.toCurrency(),
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          color: item.hasDiscount
                              ? AppColors.successText(isDark)
                              : theme.colorScheme.onSurface,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _QuantityControls extends StatelessWidget {
  const _QuantityControls({
    required this.quantity,
    required this.onChanged,
  });

  final int quantity;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final hairline =
        isDark ? AppColors.darkHairline : AppColors.lightHairline;
    return Container(
      height: _kPillHeight,
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCanvas : AppColors.lightSurfaceMuted,
        border: Border.all(color: hairline),
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(LucideIcons.minus),
            onPressed: quantity > 1 ? () => onChanged(quantity - 1) : null,
            iconSize: 18,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints.tightFor(
              width: _kPillHeight,
              height: _kPillHeight,
            ),
          ),
          Container(
            constraints: const BoxConstraints(minWidth: 36),
            alignment: Alignment.center,
            child: Text(
              '$quantity',
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 16,
              ),
            ),
          ),
          IconButton(
            icon: const Icon(LucideIcons.plus),
            onPressed: () => onChanged(quantity + 1),
            iconSize: 18,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints.tightFor(
              width: _kPillHeight,
              height: _kPillHeight,
            ),
          ),
        ],
      ),
    );
  }
}

/// Shared height for the cart row's outlined controls so the quantity
/// stepper and discount button line up at the same touch-target size.
const double _kPillHeight = 40;

class _DiscountButton extends StatelessWidget {
  const _DiscountButton({
    required this.hasDiscount,
    required this.label,
    required this.onTap,
  });

  final bool hasDiscount;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    final isDark = theme.brightness == Brightness.dark;
    final hairline =
        isDark ? AppColors.darkHairline : AppColors.lightHairline;

    // Applied = filled success-tint chip (no border); unapplied = quiet
    // hairline-outlined chip. Matches the handoff.
    final fgColor = hasDiscount ? AppColors.successText(isDark) : muted;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: Container(
        height: _kPillHeight,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm + 4),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: hasDiscount ? AppColors.successFill(isDark) : null,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: hasDiscount ? null : Border.all(color: hairline),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(LucideIcons.tag, size: 16, color: fgColor),
            const SizedBox(width: 4),
            Text(
              hasDiscount ? label : 'Discount',
              style: TextStyle(
                fontSize: 12,
                fontWeight: hasDiscount ? FontWeight.w600 : FontWeight.normal,
                color: fgColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
