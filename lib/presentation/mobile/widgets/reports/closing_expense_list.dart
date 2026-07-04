import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:maki_mobile_pos/core/constants/app_constants.dart';
import 'package:maki_mobile_pos/core/extensions/num_extensions.dart';
import 'package:maki_mobile_pos/domain/entities/expense_entity.dart';

/// Itemized expense rows inside the EOD "Expenses" card. Every same-day
/// expense is included in the closing by default; removing one excludes it
/// from the reconciliation (the expense record itself is untouched) and the
/// row stays visible, greyed with a Restore action, until the day is closed.
class ClosingExpenseList extends StatelessWidget {
  const ClosingExpenseList({
    super.key,
    required this.expenses,
    required this.excludedIds,
    required this.onToggle,
    this.enabled = true,
  });

  final List<ExpenseEntity> expenses;
  final Set<String> excludedIds;
  final void Function(String expenseId) onToggle;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (final e in expenses)
          _ExpenseRow(
            expense: e,
            excluded: excludedIds.contains(e.id),
            enabled: enabled,
            onToggle: () => onToggle(e.id),
          ),
      ],
    );
  }
}

class _ExpenseRow extends StatelessWidget {
  const _ExpenseRow({
    required this.expense,
    required this.excluded,
    required this.enabled,
    required this.onToggle,
  });

  final ExpenseEntity expense;
  final bool excluded;
  final bool enabled;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    final strike = TextStyle(
      decoration: excluded ? TextDecoration.lineThrough : null,
      color: excluded ? muted : null,
    );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  expense.description,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: strike.copyWith(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  expense.paidVia.displayName,
                  style: TextStyle(fontSize: 11.5, color: muted),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '${AppConstants.currencySymbol}${expense.amount.toCurrencyWithoutSymbol()}',
            style: strike.copyWith(
              fontSize: 13.5,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: 4),
          if (excluded)
            TextButton(
              onPressed: enabled ? onToggle : null,
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                minimumSize: const Size(0, 30),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                textStyle: const TextStyle(
                    fontSize: 12.5, fontWeight: FontWeight.w600),
              ),
              child: const Text('Restore'),
            )
          else
            IconButton(
              icon: const Icon(LucideIcons.x, size: 16),
              color: muted,
              tooltip: 'Remove from closing',
              visualDensity: VisualDensity.compact,
              onPressed: enabled ? onToggle : null,
            ),
        ],
      ),
    );
  }
}
