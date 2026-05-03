import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:maki_mobile_pos/core/constants/app_constants.dart';
import 'package:maki_mobile_pos/core/enums/enums.dart';
import 'package:maki_mobile_pos/core/theme/theme.dart';
import 'package:maki_mobile_pos/domain/entities/entities.dart';

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
    final muted = theme.colorScheme.onSurfaceVariant;
    final discountAmount = item.calculateDiscountAmount(
      isPercentage: isPercentageDiscount,
    );
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
        child: const Icon(CupertinoIcons.trash, color: Colors.white),
      ),
      onDismissed: (_) => onRemove(),
      child: Card(
        margin: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.xs,
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
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(CupertinoIcons.xmark, size: 20),
                    onPressed: onRemove,
                    visualDensity: VisualDensity.compact,
                    tooltip: 'Remove item',
                  ),
                ],
              ),
              // SKU and unit price — muted secondary line
              Text(
                '${item.sku} • ${AppConstants.currencySymbol}${item.unitPrice.toStringAsFixed(2)} / ${item.unit}',
                style: theme.textTheme.bodySmall?.copyWith(color: muted),
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
                      if (item.hasDiscount) ...[
                        Text(
                          '${AppConstants.currencySymbol}${item.grossAmount.toStringAsFixed(2)}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            decoration: TextDecoration.lineThrough,
                            color: muted,
                          ),
                        ),
                        Text(
                          '-${AppConstants.currencySymbol}${discountAmount.toStringAsFixed(2)}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: AppColors.successDark,
                          ),
                        ),
                      ],
                      Text(
                        '${AppConstants.currencySymbol}${netAmount.toStringAsFixed(2)}',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          color:
                              item.hasDiscount ? AppColors.successDark : null,
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
      decoration: BoxDecoration(
        border: Border.all(color: hairline),
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(CupertinoIcons.minus),
            onPressed: quantity > 1 ? () => onChanged(quantity - 1) : null,
            visualDensity: VisualDensity.compact,
            iconSize: 20,
          ),
          Container(
            constraints: const BoxConstraints(minWidth: 40),
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
            icon: const Icon(CupertinoIcons.add),
            onPressed: () => onChanged(quantity + 1),
            visualDensity: VisualDensity.compact,
            iconSize: 20,
          ),
        ],
      ),
    );
  }
}

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

    final borderColor = hasDiscount ? AppColors.success : hairline;
    final fgColor = hasDiscount ? AppColors.successDark : muted;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm + 4,
          vertical: AppSpacing.sm,
        ),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(color: borderColor),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(CupertinoIcons.tag, size: 16, color: fgColor),
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
