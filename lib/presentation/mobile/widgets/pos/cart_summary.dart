import 'package:flutter/material.dart';
import 'package:maki_mobile_pos/core/constants/app_constants.dart';
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
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Item count
          _buildSummaryRow(
            context,
            'Items',
            '${cart.totalItemCount} (${cart.uniqueProductCount} products)',
            isSecondary: true,
          ),

          const SizedBox(height: 8),

          // Subtotal
          _buildSummaryRow(
            context,
            'Subtotal',
            '${AppConstants.currencySymbol}${cart.subtotal.toStringAsFixed(2)}',
          ),

          // Discount (if any)
          if (cart.hasDiscount) ...[
            const SizedBox(height: 4),
            _buildSummaryRow(
              context,
              'Discount',
              '-${AppConstants.currencySymbol}${cart.totalDiscount.toStringAsFixed(2)}',
              valueColor: Colors.green,
            ),
          ],

          const SizedBox(height: 8),
          const Divider(height: 1),
          const SizedBox(height: 8),

          // Grand Total
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
    bool isSecondary = false,
    Color? valueColor,
  }) {
    final theme = Theme.of(context);

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: isTotal
              ? theme.textTheme.titleLarge
                  ?.copyWith(fontWeight: FontWeight.bold)
              : isSecondary
                  ? theme.textTheme.bodySmall?.copyWith(color: Colors.grey[600])
                  : theme.textTheme.bodyMedium,
        ),
        Text(
          value,
          style: isTotal
              ? theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.primary,
                )
              : isSecondary
                  ? theme.textTheme.bodySmall?.copyWith(color: Colors.grey[600])
                  : theme.textTheme.bodyMedium?.copyWith(
                      color: valueColor,
                      fontWeight: valueColor != null
                          ? FontWeight.w600
                          : FontWeight.normal,
                    ),
        ),
      ],
    );
  }
}
