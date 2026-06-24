import 'package:flutter/material.dart';
import 'package:maki_mobile_pos/core/theme/theme.dart';

/// A label/value row for totals panels (cart, checkout, drafts).
///
/// Two variants:
/// - normal: 13px muted label + 13px value (optionally [valueColor]-tinted).
/// - [isTotal]: 15px label + a 26px primary-colored "hero" value.
///
/// In both variants the label is flexible and ellipsizes so a long label
/// (e.g. "Subtotal · 1234 items", "Labor · {mechanic}") can never overflow
/// the row — the value is the anchor and always stays fully visible.
class SummaryRow extends StatelessWidget {
  const SummaryRow({
    super.key,
    required this.label,
    required this.value,
    this.isTotal = false,
    this.valueColor,
  });

  final String label;
  final String value;
  final bool isTotal;

  /// Tints the value (e.g. green for a discount). Ignored when [isTotal] —
  /// the total always uses the primary color.
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (isTotal) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          Expanded(
            child: Text(
              label,
              style:
                  const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
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

    final muted = theme.colorScheme.onSurfaceVariant;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Text(
            label,
            style: TextStyle(fontSize: 13, color: muted),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
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
