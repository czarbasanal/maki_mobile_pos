import 'package:flutter/material.dart';
import 'package:maki_mobile_pos/core/constants/app_constants.dart';
import 'package:maki_mobile_pos/core/extensions/num_extensions.dart';
import 'package:maki_mobile_pos/core/theme/theme.dart';
import 'package:maki_mobile_pos/presentation/mobile/widgets/reports/closing_widgets.dart';

/// End-of-day cash handoff split: labor fees go to the mechanics (always in
/// cash from the drawer, whatever tender the customer used), the rest of the
/// counted drawer goes to management. Rendered inside the Cash reconciliation
/// card (EOD review + closed view) and the closing-history detail.
class ClosingHandoffRows extends StatelessWidget {
  const ClosingHandoffRows({
    super.key,
    required this.laborFees,
    required this.forManagement,
    this.dense = false,
  });

  /// Whole-day labor fees owed to mechanics.
  final double laborFees;

  /// Counted cash minus [laborFees].
  final double forManagement;

  final bool dense;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    String peso(double v) =>
        '${AppConstants.currencySymbol}${v.toCurrencyWithoutSymbol()}';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: EdgeInsets.symmetric(vertical: dense ? 8 : 11),
          child: Divider(height: 1, color: AppColors.hairline(isDark)),
        ),
        ClosingKvRow(
          label: 'Labor fees → mechanics',
          value: peso(laborFees),
          dense: dense,
        ),
        ClosingKvRow(
          label: 'Sale items → management',
          value: peso(forManagement),
          dense: dense,
        ),
      ],
    );
  }
}
