import 'package:flutter/material.dart';
import 'package:maki_mobile_pos/core/constants/app_constants.dart';
import 'package:maki_mobile_pos/core/theme/theme.dart';
import 'package:maki_mobile_pos/presentation/providers/cart_provider.dart';

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
          _buildSummaryRow(
            context,
            'Subtotal · $itemCount item${itemCount == 1 ? '' : 's'}',
            '${AppConstants.currencySymbol}${cart.subtotal.toStringAsFixed(2)}',
          ),
          if (cart.hasDiscount) ...[
            const SizedBox(height: 6),
            _buildSummaryRow(
              context,
              'Discount',
              '-${AppConstants.currencySymbol}${cart.totalDiscount.toStringAsFixed(2)}',
              valueColor: AppColors.successText(isDark),
            ),
          ],
          if (cart.laborLines.isNotEmpty) ...[
            const SizedBox(height: 6),
            _buildSummaryRow(
              context,
              'Labor',
              '${AppConstants.currencySymbol}${cart.laborSubtotal.toStringAsFixed(2)}',
            ),
          ],
          const SizedBox(height: AppSpacing.sm + 1),
          const Divider(height: 1),
          const SizedBox(height: AppSpacing.sm + 1),
          _buildSummaryRow(
            context,
            'Total',
            '${AppConstants.currencySymbol}${cart.grandTotal.toStringAsFixed(2)}',
            isTotal: true,
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryRow(
    BuildContext context,
    String label,
    String value, {
    bool isTotal = false,
    Color? valueColor,
  }) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;

    if (isTotal) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.5,
              color: theme.colorScheme.primary,
            ),
          ),
        ],
      );
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(fontSize: 13, color: muted)),
        Text(
          value,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: valueColor,
          ),
        ),
      ],
    );
  }
}
