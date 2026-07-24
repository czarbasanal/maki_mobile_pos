import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:maki_mobile_pos/core/constants/app_constants.dart';
import 'package:maki_mobile_pos/core/extensions/num_extensions.dart';
import 'package:maki_mobile_pos/core/theme/theme.dart';
import 'package:maki_mobile_pos/domain/entities/daily_closing_entity.dart';
import 'package:maki_mobile_pos/presentation/mobile/widgets/reports/closing_widgets.dart';

/// "After close" drift card: sales and cash recorded after the day was
/// closed, split into sale items (management's share) vs labor fees (the
/// mechanics'), plus the updated drawer and handoff figures. Shared by the
/// closed EOD view and the closing-history detail so both render identically.
class AfterCloseCard extends StatelessWidget {
  const AfterCloseCard({super.key, required this.activity});

  final PostCloseActivity activity;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    String peso(double v) =>
        '${AppConstants.currencySymbol}${v.toCurrencyWithoutSymbol()}';
    String signed(double v) =>
        '${v >= 0 ? '+' : '-'}${AppConstants.currencySymbol}${v.abs().toCurrencyWithoutSymbol()}';
    final showLaborSplit = activity.laborDelta.abs() > 0.005;

    return ClosingSectionCard(
      icon: LucideIcons.clock,
      title: 'After close',
      iconColor: AppColors.warningIcon(isDark),
      children: [
        ClosingKvRow(
          label: 'Sales after close',
          value: '${activity.extraSales >= 0 ? '+' : ''}${activity.extraSales}'
              ' · ${signed(activity.grossDelta)}',
        ),
        ClosingKvRow(
          label: 'Cash collected after close',
          value: signed(activity.cashSalesDelta),
        ),
        if (showLaborSplit) ...[
          ClosingKvRow(
            label: 'Sale items',
            value: signed(activity.cashSalesDelta - activity.laborDelta),
            indented: true,
          ),
          ClosingKvRow(
            label: 'Labor fees',
            value: signed(activity.laborDelta),
            indented: true,
          ),
        ],
        if (activity.cashExpensesDelta.abs() > 0.005)
          ClosingKvRow(
            label: 'Cash expenses after close',
            value: signed(-activity.cashExpensesDelta),
          ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 11),
          child: Divider(height: 1, color: AppColors.hairline(isDark)),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Updated cash on hand',
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w600, fontSize: 15),
            ),
            Text(
              peso(activity.updatedCashOnHand),
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: theme.colorScheme.primary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClosingKvRow(
          label: 'Updated for management',
          value: peso(activity.updatedForManagement),
        ),
        ClosingKvRow(
          label: 'For mechanics (whole day)',
          value: peso(activity.currentLaborRevenue),
        ),
      ],
    );
  }
}
