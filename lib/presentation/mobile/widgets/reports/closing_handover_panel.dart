import 'package:flutter/material.dart';
import 'package:maki_mobile_pos/core/constants/app_constants.dart';
import 'package:maki_mobile_pos/core/extensions/num_extensions.dart';
import 'package:maki_mobile_pos/core/theme/theme.dart';

/// One mechanic's share of the day's labor fees.
class HandoverShare {
  const HandoverShare({required this.name, required this.amount});
  final String name;
  final double amount;
}

/// End-of-day cash hand-over: labor fees go to the mechanics (always in cash
/// from the drawer, whatever tender the customer used), the rest of the
/// counted drawer goes to management.
///
/// Presented as its own block rather than more key-value rows: these two
/// figures decide who physically receives which cash, so they are the
/// conclusion of the summary rather than another line item. It leads with the
/// counted cash so a reader can see the two parts add up to it.
class ClosingHandoverPanel extends StatelessWidget {
  const ClosingHandoverPanel({
    super.key,
    required this.countedCash,
    required this.laborFees,
    required this.forManagement,
    this.shares,
    this.dense = false,
  });

  /// The drawer total being divided.
  final double countedCash;

  /// Whole-day labor fees owed to mechanics — from the frozen closing.
  final double laborFees;

  /// Counted cash minus [laborFees].
  final double forManagement;

  /// Per-mechanic breakdown of [laborFees], when the caller can supply it.
  ///
  /// These come from live sales while [laborFees] comes from the closing
  /// snapshot, so the two can disagree once a sale is voided after close. The
  /// snapshot stays authoritative and the panel says so rather than showing
  /// figures that silently fail to add up.
  final List<HandoverShare>? shares;

  final bool dense;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final muted = theme.colorScheme.onSurfaceVariant;
    final hairline = AppColors.hairline(isDark);
    String peso(double v) =>
        '${AppConstants.currencySymbol}${v.toCurrencyWithoutSymbol()}';

    final list = shares ?? const <HandoverShare>[];
    final sharesTotal = list.fold<double>(0, (a, s) => a + s.amount);
    final mismatch = list.isNotEmpty && (sharesTotal - laborFees).abs() > 0.01;

    return Container(
      margin: EdgeInsets.only(top: dense ? 10 : 14),
      padding: EdgeInsets.fromLTRB(12, dense ? 10 : 12, 12, dense ? 10 : 12),
      decoration: BoxDecoration(
        border: Border.all(color: hairline),
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'CASH HAND-OVER',
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.1,
              color: muted,
            ),
          ),
          const SizedBox(height: 8),
          _line(context, 'Counted', peso(countedCash), emphasis: false),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 7),
            child: Divider(height: 1, color: hairline),
          ),
          _line(context, 'To mechanics', peso(laborFees), emphasis: true),
          for (final s in list)
            Padding(
              padding: const EdgeInsets.only(left: 14, top: 4),
              child: _line(context, s.name, peso(s.amount), sub: true),
            ),
          if (mismatch)
            Padding(
              padding: const EdgeInsets.only(left: 14, top: 5),
              child: Text(
                'Named shares total ${peso(sharesTotal)} — they read current '
                'sales, while the ${peso(laborFees)} above is what was frozen '
                'at closing.',
                style: TextStyle(fontSize: 11, height: 1.35, color: muted),
              ),
            ),
          const SizedBox(height: 6),
          _line(context, 'To management', peso(forManagement), emphasis: true),
        ],
      ),
    );
  }

  Widget _line(
    BuildContext context,
    String label,
    String value, {
    bool emphasis = false,
    bool sub = false,
  }) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    final size = sub ? 12.5 : (dense ? 13.5 : 14.5);
    final labelStyle = TextStyle(
      fontSize: size,
      color: sub ? theme.colorScheme.outline : muted,
    );
    final valueStyle = TextStyle(
      fontSize: size,
      fontWeight: emphasis ? FontWeight.w700 : FontWeight.w500,
      color: sub ? theme.colorScheme.outline : theme.colorScheme.onSurface,
      fontFamily: AppTextStyles.monoFontFamily,
    );
    return Row(
      children: [
        Expanded(child: Text(label, style: labelStyle)),
        const SizedBox(width: 10),
        Text(value, style: valueStyle),
      ],
    );
  }
}
