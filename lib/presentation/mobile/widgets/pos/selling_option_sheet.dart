import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:maki_mobile_pos/core/extensions/num_extensions.dart';
import 'package:maki_mobile_pos/core/theme/theme.dart';
import 'package:maki_mobile_pos/core/utils/sku_generator.dart';
import 'package:maki_mobile_pos/domain/entities/entities.dart';
import 'package:maki_mobile_pos/presentation/shared/widgets/common/app_card.dart';

/// Opens the must-pick-one selling-option sheet for [product].
///
/// Every path that puts a product on a ticket must call this whenever
/// [ProductEntity.hasSellingOptions] is true — the base [ProductEntity.price]
/// is not directly sellable once a product carries options. Always shown
/// even for a single option: this sheet is the only surface where the
/// whole-set price is visible before it lands on the ticket.
///
/// Resolves to the tapped [SellingOptionEntity], or `null` if dismissed
/// (back gesture / tap outside) without picking one — callers must add
/// nothing to the ticket in that case.
Future<SellingOptionEntity?> showSellingOptionSheet(
  BuildContext context,
  ProductEntity product,
) {
  return showModalBottomSheet<SellingOptionEntity>(
    context: context,
    isScrollControlled: true,
    builder: (context) => _SellingOptionSheet(product: product),
  );
}

class _SellingOptionSheet extends StatelessWidget {
  const _SellingOptionSheet({required this.product});

  final ProductEntity product;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    // Bounded so a product with many options (kMaxSellingOptions = 10) still
    // scrolls within the screen instead of overflowing it.
    final maxHeight = MediaQuery.sizeOf(context).height * 0.85;

    return SafeArea(
      top: false,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxHeight),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: theme.dividerColor,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Text(
                product.name,
                style: AppTextStyles.productName.copyWith(fontSize: 15),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Text(
                SkuGenerator.displaySku(product.sku),
                style: AppTextStyles.code.copyWith(color: muted),
              ),
              const SizedBox(height: 3),
              Text(
                '${product.quantity} ${product.unit} on hand',
                style: theme.textTheme.bodySmall?.copyWith(color: muted),
              ),
              const SizedBox(height: AppSpacing.md),
              for (final option in product.sellingOptions) ...[
                _OptionRow(product: product, option: option),
                const SizedBox(height: AppSpacing.sm),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// One selectable row: label + set price, pieces + per-piece price as
/// captions. Neutral surface (AppCard) — color is reserved for the low-stock
/// warning only, never as a row accent.
class _OptionRow extends StatelessWidget {
  const _OptionRow({required this.product, required this.option});

  final ProductEntity product;
  final SellingOptionEntity option;

  /// The POS warns rather than blocks on low stock (see [lowStockLines]
  /// elsewhere in the register) — this row must stay tappable either way.
  bool get _shortOnStock => option.pieces > product.quantity;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final muted = theme.colorScheme.onSurfaceVariant;

    return AppCard(
      onTap: () => Navigator.of(context).pop(option),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  option.label,
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 3),
                Row(
                  children: [
                    Text(
                      '${option.pieces} ${product.unit}',
                      style:
                          theme.textTheme.bodySmall?.copyWith(color: muted),
                    ),
                    if (_shortOnStock) ...[
                      const SizedBox(width: 6),
                      Icon(
                        LucideIcons.alertTriangle,
                        size: 13,
                        color: AppColors.warningIcon(isDark),
                      ),
                      const SizedBox(width: 2),
                      Text(
                        'Low stock',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: AppColors.warningIcon(isDark),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                option.price.toCurrency(),
                style: theme.textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 2),
              Text(
                '${option.pricePerPiece.toCurrency()}/pc',
                style: theme.textTheme.bodySmall?.copyWith(color: muted),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
