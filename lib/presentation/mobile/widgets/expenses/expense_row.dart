import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:maki_mobile_pos/core/constants/app_constants.dart';
import 'package:maki_mobile_pos/core/theme/theme.dart';
import 'package:maki_mobile_pos/presentation/shared/widgets/common/common_widgets.dart';

final _expenseCurrency = NumberFormat.currency(
  symbol: AppConstants.currencySymbol,
  decimalDigits: 2,
);

/// One expense line, on the elevated theme. Neutral-by-default: every row is
/// the same muted `file-text` glyph in a neutral tile — no per-category or
/// per-payment color (08 handoff). Used by the dashboard (subtitle =
/// date • time) and history (subtitle = date • category).
class ExpenseRow extends StatelessWidget {
  const ExpenseRow({
    super.key,
    required this.description,
    required this.subtitle,
    required this.amount,
    this.hasReceipt = false,
    this.onTap,
    this.onLongPress,
  });

  final String description;
  final String subtitle;
  final double amount;

  /// Shows a small paperclip when the expense has a receipt photo attached.
  final bool hasReceipt;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    final muted = theme.colorScheme.onSurfaceVariant;

    final card = AppCard(
      radius: AppRadius.field,
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
      onTap: onTap,
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color:
                  dark ? const Color(0x1F93A0A3) : const Color(0x0F283E46),
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(LucideIcons.fileText, size: 20, color: muted),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  description,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: 14.5, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 12, color: muted),
                ),
              ],
            ),
          ),
          if (hasReceipt) ...[
            const SizedBox(width: 6),
            Icon(LucideIcons.paperclip, size: 14, color: muted),
          ],
          const SizedBox(width: 10),
          Text(
            _expenseCurrency.format(amount),
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );

    if (onLongPress == null) return card;
    return GestureDetector(onLongPress: onLongPress, child: card);
  }
}
