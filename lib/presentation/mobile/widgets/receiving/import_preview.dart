import 'package:flutter/material.dart';
import 'package:maki_mobile_pos/core/theme/theme.dart';
import 'package:maki_mobile_pos/core/utils/batch_import.dart';

/// Shared preview of a parsed + classified CSV import: summary chips, a
/// skipped-rows error list, and one tile per classified row. Used by both the
/// batch import screen and the inline receiving CSV dialog.
class ImportPreview extends StatelessWidget {
  const ImportPreview({
    super.key,
    required this.parseResult,
    required this.classified,
  });

  final ParseResult parseResult;
  final List<ClassifiedRow> classified;

  @override
  Widget build(BuildContext context) {
    final existing = classified.whereType<ExistingMatchRow>().length;
    final mismatch = classified.whereType<CostMismatchRow>().length;
    final newProducts = classified.whereType<NewProductRow>().length;
    final errors = parseResult.errors;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SummaryChips(
          existing: existing,
          mismatch: mismatch,
          newProducts: newProducts,
          errors: errors.length,
        ),
        if (errors.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.sm),
          _ErrorList(errors: errors),
        ],
        const SizedBox(height: AppSpacing.md),
        for (final c in classified) _ClassifiedRowTile(c: c),
      ],
    );
  }
}

// ---- moved verbatim from batch_import_screen.dart ----

class _SummaryChips extends StatelessWidget {
  const _SummaryChips({
    required this.existing,
    required this.mismatch,
    required this.newProducts,
    required this.errors,
  });

  final int existing;
  final int mismatch;
  final int newProducts;
  final int errors;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: AppSpacing.xs,
      runSpacing: AppSpacing.xs,
      children: [
        _Chip(label: 'Match', count: existing, color: AppColors.success),
        _Chip(
          label: 'Cost variation',
          count: mismatch,
          color: AppColors.warningDark,
        ),
        _Chip(label: 'New product', count: newProducts, color: AppColors.info),
        if (errors > 0)
          _Chip(label: 'Errors', count: errors, color: AppColors.error),
      ],
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.label, required this.count, required this.color});

  final String label;
  final int count;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: 6,
      ),
      decoration: BoxDecoration(
        color: color.withAlpha(0x22),
        border: Border.all(color: color),
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Text(
        '$label · $count',
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w600,
          fontSize: 12,
        ),
      ),
    );
  }
}

class _ErrorList extends StatelessWidget {
  const _ErrorList({required this.errors});

  final List<ParseError> errors;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.sm + 4),
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.error),
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Skipped rows:',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: AppColors.error,
            ),
          ),
          const SizedBox(height: 4),
          for (final e in errors)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                '$e',
                style: const TextStyle(color: AppColors.error, fontSize: 12),
              ),
            ),
        ],
      ),
    );
  }
}

class _ClassifiedRowTile extends StatelessWidget {
  const _ClassifiedRowTile({required this.c});

  final ClassifiedRow c;

  ({String label, Color color}) _badge() {
    if (c is ExistingMatchRow) {
      return (label: 'Match', color: AppColors.success);
    }
    if (c is CostMismatchRow) {
      return (label: 'Variation', color: AppColors.warningDark);
    }
    return (label: 'New', color: AppColors.info);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    final badge = _badge();
    final row = c.row;
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: AppSpacing.xs),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
        side: BorderSide(color: theme.dividerColor),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.sm + 4),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    row.name,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    '${row.sku} • ${row.quantity} ${row.unit} • cost ${row.cost.toStringAsFixed(2)}',
                    style: theme.textTheme.bodySmall?.copyWith(color: muted),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.sm,
                vertical: 4,
              ),
              decoration: BoxDecoration(
                color: badge.color.withAlpha(0x22),
                borderRadius: BorderRadius.circular(AppRadius.pill),
              ),
              child: Text(
                badge.label,
                style: TextStyle(
                  color: badge.color,
                  fontWeight: FontWeight.w600,
                  fontSize: 11,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
