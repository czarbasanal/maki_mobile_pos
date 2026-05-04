import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:maki_mobile_pos/core/constants/app_constants.dart';
import 'package:maki_mobile_pos/core/enums/enums.dart';
import 'package:maki_mobile_pos/core/theme/theme.dart';
import 'package:maki_mobile_pos/domain/entities/receiving_entity.dart';
import 'package:maki_mobile_pos/presentation/providers/providers.dart';

/// Row displaying a receiving line item.
class ReceivingItemRow extends ConsumerWidget {
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
  Widget build(BuildContext context, WidgetRef ref) {
    final card = _buildCard(context, ref);
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

  /// Subtitle text for the line. Selling price is shown to everyone (when we
  /// have the product loaded); cost is admin-only.
  String _buildSubtitle({
    required bool isAdmin,
    required double? sellingPrice,
  }) {
    final symbol = AppConstants.currencySymbol;
    final parts = <String>[];
    if (isAdmin) {
      parts.add('Cost $symbol${item.unitCost.toStringAsFixed(2)}');
    }
    if (sellingPrice != null) {
      parts.add('Sells $symbol${sellingPrice.toStringAsFixed(2)}');
    }
    final pricing = parts.join(' • ');
    return pricing.isEmpty ? item.unit : '$pricing • ${item.unit}';
  }

  Widget _buildCard(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isAdmin =
        ref.watch(currentUserProvider).valueOrNull?.role == UserRole.admin;

    // Resolve the parent product once — used for both the cost-diff badge
    // (admin only) and the selling-price display (everyone).
    final product = item.productId == null
        ? null
        : ref.watch(productByIdProvider(item.productId!)).asData?.value;

    // Diff badge — admin only. In edit mode it warns the user that completion
    // will spawn a variation. In read-only (history detail), only rendered
    // for lines that already became a variation.
    Widget? costDiffBadge;
    final showDiffBadge = isAdmin && (!readOnly || item.isNewVariation);
    if (showDiffBadge && product != null) {
      final delta = item.unitCost - product.cost;
      if (delta.abs() > 0.01) {
        final up = delta > 0;
        final color = up ? AppColors.errorDark : AppColors.successDark;
        costDiffBadge = Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            border: Border.all(color: color),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                up ? CupertinoIcons.arrow_up : CupertinoIcons.arrow_down,
                size: 11,
                color: color,
              ),
              const SizedBox(width: 2),
              Text(
                '${AppConstants.currencySymbol}${delta.abs().toStringAsFixed(2)}',
                style: TextStyle(
                  fontSize: 10,
                  color: color,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        );
      }
    }
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
                      style: AppTextStyles.productName,
                      maxLines: 2,
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
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            _buildSubtitle(
                              isAdmin: isAdmin,
                              sellingPrice: product?.price,
                            ),
                            style: TextStyle(
                              fontSize: 12,
                              color: theme.colorScheme.primary,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (costDiffBadge != null) ...[
                          const SizedBox(width: 6),
                          costDiffBadge,
                        ],
                      ],
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

              // Total — peso amount admin-only; staff just sees the qty.
              SizedBox(
                width: 80,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    if (isAdmin)
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
