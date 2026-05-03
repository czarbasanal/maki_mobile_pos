import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:maki_mobile_pos/core/constants/app_constants.dart';
import 'package:maki_mobile_pos/domain/entities/receiving_entity.dart';

/// Row displaying a receiving line item.
class ReceivingItemRow extends StatelessWidget {
  final ReceivingItemEntity item;
  final ValueChanged<int> onQuantityChanged;
  final VoidCallback onRemove;

  /// When true, hides the quantity steppers, the inline quantity input,
  /// the swipe-to-delete affordance, and the remove button. Used when
  /// viewing a completed receiving — its stock side effects have already
  /// been applied so the line items are immutable.
  final bool readOnly;

  /// Optional corrective path for completed receivings. When provided
  /// (and [readOnly] is true), a trailing pencil button opens the stock
  /// adjustment dialog scoped to this line's product.
  final VoidCallback? onAdjustStock;

  const ReceivingItemRow({
    super.key,
    required this.item,
    required this.onQuantityChanged,
    required this.onRemove,
    this.readOnly = false,
    this.onAdjustStock,
  });

  @override
  Widget build(BuildContext context) {
    final card = _buildCard(context);
    if (readOnly) return card;

    return Dismissible(
      key: Key(item.id),
      direction: DismissDirection.endToStart,
      background: Container(
        color: Colors.red,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 16),
        child: const Icon(CupertinoIcons.trash, color: Colors.white),
      ),
      onDismissed: (_) => onRemove(),
      child: card,
    );
  }

  Widget _buildCard(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              // Product info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.name,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Text(
                          item.sku,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                            fontFamily: 'monospace',
                          ),
                        ),
                        if (item.isNewVariation) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.blue[100],
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              'New Variant',
                              style: TextStyle(
                                fontSize: 10,
                                color: Colors.blue[700],
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${AppConstants.currencySymbol}${item.unitCost.toStringAsFixed(2)} / ${item.unit}',
                      style: TextStyle(
                        fontSize: 12,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  ],
                ),
              ),

              // Quantity controls — steppers + inline input in edit mode,
              // or the static received quantity when read-only.
              if (readOnly)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Text(
                    '×${item.quantity}',
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                    ),
                  ),
                )
              else
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(CupertinoIcons.minus_circle),
                      onPressed: item.quantity > 1
                          ? () => onQuantityChanged(item.quantity - 1)
                          : null,
                      visualDensity: VisualDensity.compact,
                    ),
                    SizedBox(
                      width: 50,
                      child: TextField(
                        controller:
                            TextEditingController(text: '${item.quantity}'),
                        textAlign: TextAlign.center,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly
                        ],
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(vertical: 8),
                          isDense: true,
                        ),
                        onSubmitted: (value) {
                          final qty = int.tryParse(value);
                          if (qty != null && qty > 0) {
                            onQuantityChanged(qty);
                          }
                        },
                      ),
                    ),
                    IconButton(
                      icon: const Icon(CupertinoIcons.plus_circle),
                      onPressed: () => onQuantityChanged(item.quantity + 1),
                      visualDensity: VisualDensity.compact,
                    ),
                  ],
                ),

              // Total
              SizedBox(
                width: 80,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '${AppConstants.currencySymbol}${item.totalCost.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      '${item.quantity} ${item.unit}',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),

              // Trailing action — Remove (X) in edit mode; Adjust stock
              // (pencil) on a completed line when a productId is available.
              if (!readOnly)
                IconButton(
                  icon: Icon(CupertinoIcons.xmark, color: Colors.grey[400]),
                  onPressed: onRemove,
                  visualDensity: VisualDensity.compact,
                )
              else if (onAdjustStock != null)
                IconButton(
                  icon: const Icon(CupertinoIcons.pencil),
                  tooltip: 'Adjust stock',
                  onPressed: onAdjustStock,
                  visualDensity: VisualDensity.compact,
                ),
            ],
          ),
        ),
    );
  }
}
