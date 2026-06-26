import 'package:flutter/material.dart';
import 'package:maki_mobile_pos/core/theme/theme.dart';
import 'package:maki_mobile_pos/core/utils/batch_import.dart';
import 'package:maki_mobile_pos/presentation/shared/widgets/common/common_widgets.dart';

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

/// Theme-aware (fill, text) pair for a status chip/badge.
({Color fill, Color fg}) _matchTone(bool dark) =>
    (fill: AppColors.successFill(dark), fg: AppColors.successText(dark));

({Color fill, Color fg}) _variationTone(bool dark) => (
      fill: AppColors.warningIcon(dark).withValues(alpha: dark ? 0.18 : 0.13),
      fg: AppColors.warningBadgeText(dark),
    );

({Color fill, Color fg}) _newTone(bool dark) => (
      fill: AppColors.info.withValues(alpha: dark ? 0.20 : 0.13),
      fg: AppColors.infoBadgeText(dark),
    );

({Color fill, Color fg}) _errorTone(bool dark) => (
      fill: AppColors.error.withValues(alpha: dark ? 0.18 : 0.12),
      fg: AppColors.errorText(dark),
    );

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
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Wrap(
      spacing: AppSpacing.xs,
      runSpacing: AppSpacing.xs,
      children: [
        _Chip(label: 'Match', count: existing, tone: _matchTone(dark)),
        _Chip(
          label: 'Cost variation',
          count: mismatch,
          tone: _variationTone(dark),
        ),
        _Chip(label: 'New product', count: newProducts, tone: _newTone(dark)),
        if (errors > 0)
          _Chip(label: 'Errors', count: errors, tone: _errorTone(dark)),
      ],
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.label, required this.count, required this.tone});

  final String label;
  final int count;
  final ({Color fill, Color fg}) tone;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 6),
      decoration: BoxDecoration(
        color: tone.fill,
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Text(
        '$label · $count',
        style: TextStyle(
          color: tone.fg,
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
    final dark = Theme.of(context).brightness == Brightness.dark;
    final fg = AppColors.errorText(dark);
    return Container(
      padding: const EdgeInsets.all(AppSpacing.sm + 4),
      decoration: BoxDecoration(
        color: AppColors.error.withValues(alpha: dark ? 0.12 : 0.07),
        border: Border.all(
          color: AppColors.error.withValues(alpha: dark ? 0.45 : 0.40),
        ),
        borderRadius: BorderRadius.circular(AppRadius.field),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Skipped rows',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: fg,
            ),
          ),
          const SizedBox(height: 4),
          for (final e in errors)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                '$e',
                style: TextStyle(color: fg, fontSize: 12),
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

  ({String label, ({Color fill, Color fg}) tone}) _badge(bool dark) {
    if (c is ExistingMatchRow) {
      return (label: 'Match', tone: _matchTone(dark));
    }
    if (c is CostMismatchRow) {
      return (label: 'Variation', tone: _variationTone(dark));
    }
    return (label: 'New', tone: _newTone(dark));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    final muted = theme.colorScheme.onSurfaceVariant;
    final badge = _badge(dark);
    final row = c.row;
    return AppCard(
      radius: AppRadius.field,
      margin: const EdgeInsets.only(bottom: AppSpacing.xs),
      padding: const EdgeInsets.all(AppSpacing.sm + 4),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  row.name,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  '${row.sku} • ${row.quantity} ${row.unit} • cost ${row.cost.toStringAsFixed(2)}',
                  style: TextStyle(
                    fontFamily: 'RobotoMono',
                    fontSize: 12,
                    color: muted,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.sm + 2,
              vertical: 3,
            ),
            decoration: BoxDecoration(
              color: badge.tone.fill,
              borderRadius: BorderRadius.circular(AppRadius.pill),
            ),
            child: Text(
              badge.label,
              style: TextStyle(
                color: badge.tone.fg,
                fontWeight: FontWeight.w600,
                fontSize: 11,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
