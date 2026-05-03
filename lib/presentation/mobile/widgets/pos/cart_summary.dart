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
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        children: [
          _buildSummaryRow(
            context,
            'Items',
            '${cart.totalItemCount} (${cart.uniqueProductCount} products)',
            isSecondary: true,
          ),
          const SizedBox(height: AppSpacing.sm),
          _buildSummaryRow(
            context,
            'Subtotal',
            '${AppConstants.currencySymbol}${cart.subtotal.toStringAsFixed(2)}',
          ),
          if (cart.hasDiscount) ...[
            const SizedBox(height: 4),
            _buildSummaryRow(
              context,
              'Discount',
              '-${AppConstants.currencySymbol}${cart.totalDiscount.toStringAsFixed(2)}',
              valueColor: AppColors.successDark,
            ),
          ],
          const SizedBox(height: AppSpacing.sm),
          const Divider(height: 1),
          const SizedBox(height: AppSpacing.sm),
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
    final muted = theme.colorScheme.onSurfaceVariant;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: isTotal
              ? theme.textTheme.titleLarge
                  ?.copyWith(fontWeight: FontWeight.w600)
              : isSecondary
                  ? theme.textTheme.bodySmall?.copyWith(color: muted)
                  : theme.textTheme.bodyMedium,
        ),
        Text(
          value,
          style: isTotal
              ? theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.primary,
                )
              : isSecondary
                  ? theme.textTheme.bodySmall?.copyWith(color: muted)
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
