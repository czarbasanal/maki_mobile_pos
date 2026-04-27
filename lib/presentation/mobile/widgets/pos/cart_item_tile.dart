import 'package:flutter/material.dart';
import 'package:maki_mobile_pos/core/constants/app_constants.dart';
import 'package:maki_mobile_pos/core/enums/enums.dart';
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
        padding: const EdgeInsets.only(right: 20),
        color: Colors.red,
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      onDismissed: (_) => onRemove(),
      child: Card(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        child: Padding(
          padding: const EdgeInsets.all(12),
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
                    icon: const Icon(Icons.close, size: 20),
                    onPressed: onRemove,
                    visualDensity: VisualDensity.compact,
                    tooltip: 'Remove item',
                  ),
                ],
              ),

              // SKU and unit price
              Text(
                '${item.sku} • ${AppConstants.currencySymbol}${item.unitPrice.toStringAsFixed(2)} / ${item.unit}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: Colors.grey[600],
                ),
              ),

              const SizedBox(height: 12),

              // Quantity controls and totals
              Row(
                children: [
                  // Quantity controls
                  _buildQuantityControls(context),

                  const SizedBox(width: 16),

                  // Discount button
                  _buildDiscountButton(context),

                  const Spacer(),

                  // Line total
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      if (item.hasDiscount) ...[
                        // Original amount (struck through)
                        Text(
                          '${AppConstants.currencySymbol}${item.grossAmount.toStringAsFixed(2)}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            decoration: TextDecoration.lineThrough,
                            color: Colors.grey,
                          ),
                        ),
                        // Discount amount
                        Text(
                          '-${AppConstants.currencySymbol}${discountAmount.toStringAsFixed(2)}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: Colors.green,
                          ),
                        ),
                      ],
                      // Net amount
                      Text(
                        '${AppConstants.currencySymbol}${netAmount.toStringAsFixed(2)}',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: item.hasDiscount ? Colors.green[700] : null,
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

  Widget _buildQuantityControls(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey[300]!),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Decrement button
          IconButton(
            icon: const Icon(Icons.remove),
            onPressed: item.quantity > 1
                ? () => onQuantityChanged(item.quantity - 1)
                : null,
            visualDensity: VisualDensity.compact,
            iconSize: 20,
          ),
          // Quantity display
          Container(
            constraints: const BoxConstraints(minWidth: 40),
            alignment: Alignment.center,
            child: Text(
              '${item.quantity}',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ),
          // Increment button
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => onQuantityChanged(item.quantity + 1),
            visualDensity: VisualDensity.compact,
            iconSize: 20,
          ),
        ],
      ),
    );
  }

  Widget _buildDiscountButton(BuildContext context) {
    final hasDiscount = item.hasDiscount;
    final discountLabel = isPercentageDiscount
        ? '${item.discountValue.toStringAsFixed(0)}%'
        : '${AppConstants.currencySymbol}${item.discountValue.toStringAsFixed(0)}';

    return InkWell(
      onTap: onDiscountTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: hasDiscount ? Colors.green[50] : Colors.grey[100],
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: hasDiscount ? Colors.green : Colors.grey[300]!,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              hasDiscount ? Icons.local_offer : Icons.local_offer_outlined,
              size: 16,
              color: hasDiscount ? Colors.green : Colors.grey[600],
            ),
            const SizedBox(width: 4),
            Text(
              hasDiscount ? discountLabel : 'Discount',
              style: TextStyle(
                fontSize: 12,
                fontWeight: hasDiscount ? FontWeight.bold : FontWeight.normal,
                color: hasDiscount ? Colors.green[700] : Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
