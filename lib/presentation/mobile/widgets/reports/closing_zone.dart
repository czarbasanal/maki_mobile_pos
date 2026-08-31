import 'package:flutter/material.dart';
import 'package:maki_mobile_pos/core/constants/app_constants.dart';
import 'package:maki_mobile_pos/core/extensions/num_extensions.dart';
import 'package:maki_mobile_pos/core/theme/theme.dart';

/// Whether a row moves cash on hand, and which way.
///
/// Only cash-on-hand terms carry a sign. Reference figures (gross parts,
/// labor, non-cash and its tenders, shop fees, total expenses) and results
/// (expected, counted) carry none — a sign on them would imply they add to or
/// deduct from the drawer, which they do not.
enum ZoneSign { none, plus, minus }

/// One line inside a [ClosingZone].
class ZoneRow {
  const ZoneRow({
    required this.label,
    required this.value,
    this.sign = ZoneSign.none,
    this.indented = false,
  });

  final String label;
  final double value;
  final ZoneSign sign;

  /// Breaks down the row above it — GCash under Non-cash sales, Cash expenses
  /// under Total expenses.
  final bool indented;

  String get formatted {
    final amount =
        '${AppConstants.currencySymbol}${value.toCurrencyWithoutSymbol()}';
    switch (sign) {
      case ZoneSign.plus:
        return '+$amount';
      // U+2212 MINUS SIGN, not a hyphen: it aligns with the digits.
      case ZoneSign.minus:
        return '−$amount';
      case ZoneSign.none:
        return amount;
    }
  }
}

/// A recessed group in the closing summary, ending with the single line it
/// resolves to.
///
/// The pattern is the whole idea of the layout: every group states its result
/// last, above a hairline, so scanning the block vertically gives four numbers
/// — cash sales, shop fees, cash expenses, counted cash — before any detail is
/// read. Thirteen flat rows gave no such affordance.
class ClosingZone extends StatelessWidget {
  const ClosingZone({
    super.key,
    required this.icon,
    required this.heading,
    required this.rows,
    required this.result,
    this.resultLeading,
  });

  final IconData icon;
  final String heading;
  final List<ZoneRow> rows;

  /// The line the zone resolves to, set apart above a hairline.
  final ZoneRow result;

  /// Optional widget immediately before the result's value — the variance chip
  /// on Counted cash.
  final Widget? resultLeading;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final muted = isDark ? const Color(0xFF93A0A3) : const Color(0xFF6E787B);
    final refValue = isDark ? const Color(0xFFD6DDDE) : const Color(0xFF3C4749);
    final subLabel = isDark ? const Color(0xFF6C797C) : const Color(0xFF9AA2A4);
    final subValue = isDark ? const Color(0xFFAEC0C6) : const Color(0xFF5A6468);
    final zoneHairline =
        isDark ? const Color(0xFF223032) : const Color(0xFFEDEDED);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF152125) : const Color(0xFFFAFAFA),
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 13, color: muted),
              const SizedBox(width: 7),
              Text(
                heading,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.7,
                  color: muted,
                ),
              ),
            ],
          ),
          for (final row in rows)
            Padding(
              padding: EdgeInsets.only(
                  top: 3, bottom: 3, left: row.indented ? 14 : 0),
              child: _line(
                row,
                labelColor: row.indented ? subLabel : muted,
                valueColor: row.indented ? subValue : refValue,
                labelSize: 12.5,
                valueSize: row.indented ? 12.5 : 13,
                valueWeight: FontWeight.w500,
              ),
            ),
          Container(
            margin: const EdgeInsets.only(top: 8),
            padding: const EdgeInsets.only(top: 8),
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: zoneHairline)),
            ),
            child: _line(
              result,
              labelColor: theme.colorScheme.onSurface,
              valueColor: theme.colorScheme.onSurface,
              labelSize: 13,
              labelWeight: FontWeight.w600,
              valueSize: 14.5,
              valueWeight: FontWeight.w700,
              leading: resultLeading,
            ),
          ),
        ],
      ),
    );
  }

  Widget _line(
    ZoneRow row, {
    required Color labelColor,
    required Color valueColor,
    required double labelSize,
    required double valueSize,
    required FontWeight valueWeight,
    FontWeight labelWeight = FontWeight.w400,
    Widget? leading,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Flexible(
          child: Text(
            row.label,
            style: TextStyle(
              fontSize: labelSize,
              fontWeight: labelWeight,
              color: labelColor,
            ),
          ),
        ),
        const SizedBox(width: 10),
        if (leading != null) ...[leading, const SizedBox(width: 8)],
        Text(
          row.formatted,
          style: TextStyle(
            fontSize: valueSize,
            fontWeight: valueWeight,
            color: valueColor,
            // Figtree everywhere but the hand-over panel; tabular so the
            // column of amounts lines up without a mono face.
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ],
    );
  }
}
