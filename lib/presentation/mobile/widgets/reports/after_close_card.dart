import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:maki_mobile_pos/core/constants/app_constants.dart';
import 'package:maki_mobile_pos/core/extensions/num_extensions.dart';
import 'package:maki_mobile_pos/core/theme/theme.dart';
import 'package:maki_mobile_pos/domain/entities/daily_closing_entity.dart';

/// One frozen line that may or may not have moved after the day was closed.
class _Line {
  const _Line(this.name, this.atClosing, this.delta, {this.countPrefix});

  final String name;
  final double atClosing;
  final double delta;

  /// Sales carries `+3 · ` before its amount.
  final String? countPrefix;

  bool get moved => delta.abs() > 0.005;
  double get updated => atClosing + delta;
}

/// What changed after the drawer was closed.
///
/// Reports movement only. It does not state the management/mechanics split or
/// the amounts to hand over — the hand-over panel below owns those, and once
/// drift exists it already shows the whole-day figures. Printing them in both
/// places gave the screen two answers to the same question.
///
/// This is the one place in the summary where lines are conditional: the
/// sealed block above shows every line including zeros, while here a line that
/// did not move is omitted and named in a note instead. Listing an unchanged
/// line with a `+₱0.00` would bury the ones that matter.
class AfterCloseCard extends StatelessWidget {
  const AfterCloseCard({super.key, required this.activity});

  final PostCloseActivity activity;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final muted = isDark ? const Color(0xFF93A0A3) : const Color(0xFF6E787B);
    final dim = isDark ? const Color(0xFFAEC0C6) : const Color(0xFF5A6468);
    final accent = isDark ? AppColors.darkAccent : AppColors.lightAccent;
    final tone = isDark ? const Color(0xFFF5B547) : const Color(0xFFF57C00);

    String peso(double v) =>
        '${AppConstants.currencySymbol}${v.toCurrencyWithoutSymbol()}';
    String signed(double v) =>
        '${v >= 0 ? '+' : '−'}${AppConstants.currencySymbol}'
        '${v.abs().toCurrencyWithoutSymbol()}';

    final lines = <_Line>[
      _Line('Sales', activity.closingGrossSales, activity.grossDelta,
          countPrefix: activity.extraSales != 0
              ? '${activity.extraSales >= 0 ? '+' : ''}${activity.extraSales} · '
              : null),
      _Line('Labor fees', activity.closingLaborRevenue, activity.laborDelta),
      _Line('Shop fees', activity.closingFeesRevenue, activity.feesDelta),
      _Line('Expenses', 0, activity.cashExpensesDelta),
    ];
    final moved = lines.where((l) => l.moved).toList();
    final held = lines.where((l) => !l.moved).toList();

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1B2C31) : Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: tone.withValues(alpha: 0.34)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(LucideIcons.clockAlert, size: 19, color: tone),
              const SizedBox(width: 9),
              Text('After close',
                  style: TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w700,
                      color: theme.colorScheme.onSurface)),
            ],
          ),
          if (held.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 5),
              child: Text(
                'Only the frozen lines that moved after closing are listed. '
                '${_nameList(held.map((l) => l.name).toList())} did not change.',
                style: TextStyle(fontSize: 11.5, height: 1.35, color: muted),
              ),
            ),
          const SizedBox(height: 10),

          // Frozen figures and the movement against them, recessed together.
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF152125) : const Color(0xFFFAFAFA),
              borderRadius: BorderRadius.circular(11),
            ),
            child: Column(
              children: [
                for (final l in moved)
                  _row('${l.name} at closing', peso(l.atClosing),
                      labelColor: muted, valueColor: dim, weight: FontWeight.w400),
                for (final l in moved)
                  _row(
                    '${l.name} after closing',
                    '${l.countPrefix ?? ''}${signed(l.delta)}',
                    labelColor: muted,
                    valueColor: theme.colorScheme.onSurface,
                    weight: FontWeight.w600,
                  ),
                _row('Cash collected after closing',
                    signed(activity.cashSalesDelta),
                    labelColor: muted,
                    valueColor: theme.colorScheme.onSurface,
                    weight: FontWeight.w600),
              ],
            ),
          ),
          const SizedBox(height: 8),

          for (final l in moved)
            _row('Updated ${l.name.toLowerCase()}', peso(l.updated),
                labelColor: theme.colorScheme.onSurface,
                valueColor: theme.colorScheme.onSurface,
                labelWeight: FontWeight.w600,
                labelSize: 13,
                valueSize: 14.5,
                weight: FontWeight.w700),

          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Divider(height: 1, color: AppColors.hairline(isDark)),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Updated cash on hand',
                  style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                      color: theme.colorScheme.onSurface)),
              Text(
                peso(activity.updatedCashOnHand),
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: accent,
                  fontFamily: AppTextStyles.monoFontFamily,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// "Expenses" · "Labor fees and Expenses" · "A, B and C" — generated from
  /// what actually held, never a fixed string.
  static String _nameList(List<String> names) {
    if (names.length == 1) return names.first;
    if (names.length == 2) return '${names.first} and ${names.last}';
    return '${names.sublist(0, names.length - 1).join(', ')} and ${names.last}';
  }

  Widget _row(
    String label,
    String value, {
    required Color labelColor,
    required Color valueColor,
    required FontWeight weight,
    FontWeight labelWeight = FontWeight.w400,
    double labelSize = 12.5,
    double valueSize = 12.5,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          Flexible(
            child: Text(label,
                style: TextStyle(
                    fontSize: labelSize,
                    fontWeight: labelWeight,
                    color: labelColor)),
          ),
          const SizedBox(width: 10),
          Text(
            value,
            style: TextStyle(
              fontSize: valueSize,
              fontWeight: weight,
              color: valueColor,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}
