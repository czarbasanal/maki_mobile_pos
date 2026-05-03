import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:maki_mobile_pos/config/router/router.dart';
import 'package:maki_mobile_pos/core/constants/app_constants.dart';
import 'package:maki_mobile_pos/core/extensions/navigation_extensions.dart';
import 'package:maki_mobile_pos/core/theme/theme.dart';
import 'package:intl/intl.dart';

/// Screen displaying profit reports.
class ProfitReportScreen extends ConsumerStatefulWidget {
  const ProfitReportScreen({super.key});

  @override
  ConsumerState<ProfitReportScreen> createState() => _ProfitReportScreenState();
}

class _ProfitReportScreenState extends ConsumerState<ProfitReportScreen> {
  DateTimeRange _dateRange = DateTimeRange(
    start: DateTime.now().subtract(const Duration(days: 30)),
    end: DateTime.now(),
  );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    final isDark = theme.brightness == Brightness.dark;
    final hairline =
        isDark ? AppColors.darkHairline : AppColors.lightHairline;
    final dateFormat = DateFormat('MMM d, y');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profit Report'),
        leading: IconButton(
          icon: const Icon(CupertinoIcons.back),
          onPressed: () => context.goBackOr(RoutePaths.reports),
        ),
        actions: [
          IconButton(
            icon: const Icon(CupertinoIcons.calendar),
            onPressed: _selectDateRange,
          ),
        ],
      ),
      body: Column(
        children: [
          // Date range strip — flat with hairline bottom border
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.sm + 4,
            ),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: hairline)),
            ),
            child: Row(
              children: [
                Icon(CupertinoIcons.calendar, size: 18, color: muted),
                const SizedBox(width: AppSpacing.sm),
                Text(
                  '${dateFormat.format(_dateRange.start)} - ${dateFormat.format(_dateRange.end)}',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const Spacer(),
                TextButton(
                  onPressed: _selectDateRange,
                  child: const Text('Change'),
                ),
              ],
            ),
          ),
          // Summary cards — neutral icons; profit and margin keep success
          // accent because positive profit is meaningful.
          Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Row(
              children: [
                Expanded(
                  child: _buildSummaryCard(
                    'Total Revenue',
                    '${AppConstants.currencySymbol}0.00',
                    CupertinoIcons.money_dollar_circle,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm + 4),
                Expanded(
                  child: _buildSummaryCard(
                    'Total Cost',
                    '${AppConstants.currencySymbol}0.00',
                    Icons.money_off,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            child: Row(
              children: [
                Expanded(
                  child: _buildSummaryCard(
                    'Gross Profit',
                    '${AppConstants.currencySymbol}0.00',
                    CupertinoIcons.arrow_up_right,
                    accent: AppColors.success,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm + 4),
                Expanded(
                  child: _buildSummaryCard(
                    'Profit Margin',
                    '0.0%',
                    CupertinoIcons.percent,
                    accent: AppColors.success,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          // Profit by product header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            child: Row(
              children: [
                Text(
                  'Profit by Product',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                TextButton(
                  onPressed: () {},
                  child: const Text('View All'),
                ),
              ],
            ),
          ),
          // Empty state
          Expanded(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    CupertinoIcons.arrow_up_right,
                    size: 56,
                    color: muted,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    'No profit data available',
                    style: theme.textTheme.titleMedium?.copyWith(color: muted),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Make some sales to see profit reports',
                    style: theme.textTheme.bodySmall?.copyWith(color: muted),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard(
    String title,
    String value,
    IconData icon, {
    Color? accent,
  }) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    final iconColor = accent ?? muted;
    final valueColor = accent ?? theme.colorScheme.onSurface;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 20, color: iconColor),
            const SizedBox(height: AppSpacing.sm),
            Text(
              title,
              style: theme.textTheme.bodySmall?.copyWith(color: muted),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w600,
                color: valueColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _selectDateRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: _dateRange,
    );
    if (picked != null) {
      setState(() => _dateRange = picked);
    }
  }
}
