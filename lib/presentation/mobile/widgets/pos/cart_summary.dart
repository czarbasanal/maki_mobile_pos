import 'package:flutter/material.dart';
import 'package:maki_mobile_pos/core/constants/app_constants.dart';
import 'package:maki_mobile_pos/core/theme/theme.dart';
import 'package:maki_mobile_pos/presentation/providers/cart_provider.dart';
import 'package:maki_mobile_pos/presentation/shared/widgets/common/summary_row.dart';

/// Displays cart totals: subtotal, discount, and grand total.
class CartSummary extends StatelessWidget {
  final CartState cart;

  const CartSummary({
    super.key,
    required this.cart,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final itemCount = cart.totalItemCount;
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        children: [
          // Item count folded into the Subtotal label — matches the handoff.
          SummaryRow(
            label: 'Subtotal · $itemCount item${itemCount == 1 ? '' : 's'}',
            value:
                '${AppConstants.currencySymbol}${cart.subtotal.toStringAsFixed(2)}',
          ),
          if (cart.hasDiscount) ...[
            const SizedBox(height: 6),
            SummaryRow(
              label: 'Discount',
              value:
                  '-${AppConstants.currencySymbol}${cart.totalDiscount.toStringAsFixed(2)}',
              valueColor: AppColors.successText(isDark),
            ),
          ],
          if (cart.laborLines.isNotEmpty) ...[
            const SizedBox(height: 6),
            SummaryRow(
              label: 'Labor',
              value:
                  '${AppConstants.currencySymbol}${cart.laborSubtotal.toStringAsFixed(2)}',
            ),
          ],
          const SizedBox(height: AppSpacing.sm + 1),
          const Divider(height: 1),
          const SizedBox(height: AppSpacing.sm + 1),
          SummaryRow(
            label: 'Total',
            value:
                '${AppConstants.currencySymbol}${cart.grandTotal.toStringAsFixed(2)}',
            isTotal: true,
          ),
        ],
      ),
    );
  }
}
