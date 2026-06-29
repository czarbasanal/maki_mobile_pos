import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:maki_mobile_pos/config/router/router.dart';
import 'package:maki_mobile_pos/core/constants/app_constants.dart';
import 'package:maki_mobile_pos/core/extensions/navigation_extensions.dart';
import 'package:maki_mobile_pos/core/theme/theme.dart';
import 'package:maki_mobile_pos/presentation/shared/widgets/common/common_widgets.dart';
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
    final dateFormat = DateFormat('MMM d, y');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profit Report'),
        leading: IconButton(
          icon: const Icon(LucideIcons.chevronLeft),
          onPressed: () => context.goBackOr(RoutePaths.reports),
        ),
        actions: [
          IconButton(
            icon: const Icon(LucideIcons.calendar),
            onPressed: _selectDateRange,
          ),
        ],
      ),
      body: Column(
        children: [
          // Date strip with a Change pill.
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
            child: AppCard(
              radius: AppRadius.md,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: SizedBox(
                height: 48,
                child: Row(
                  children: [
                    Icon(LucideIcons.calendar,
                        size: 18, color: theme.colorScheme.primary),
                    const SizedBox(width: 11),
                    Expanded(
                      child: Text(
                        '${dateFormat.format(_dateRange.start)} – ${dateFormat.format(_dateRange.end)}',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w500,
                          fontSize: 13.5,
                        ),
                      ),
                    ),
                    _ChangeButton(onTap: _selectDateRange),
                  ],
                ),
              ),
            ),
          ),
          // Summary cards — profit + margin keep success accent.
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _ProfitMetricCard(
                        title: 'Total Revenue',
                        value: '${AppConstants.currencySymbol}0.00',
                        icon: LucideIcons.banknote,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _ProfitMetricCard(
                        title: 'Total Cost',
                        value: '${AppConstants.currencySymbol}0.00',
                        icon: LucideIcons.wallet,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: _ProfitMetricCard(
                        title: 'Gross Profit',
                        value: '${AppConstants.currencySymbol}0.00',
                        icon: LucideIcons.trendingUp,
                        accent: AppColors.success,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _ProfitMetricCard(
                        title: 'Profit Margin',
                        value: '0.0%',
                        icon: LucideIcons.percent,
                        accent: AppColors.success,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          // Profit by product header
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 6),
            child: Row(
              children: [
                Text(
                  'Profit by Product',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                ),
                const Spacer(),
                Text(
                  'View All',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.primary,
                  ),
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
                  Container(
                    width: 66,
                    height: 66,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isDark
                          ? const Color(0x0DFFFFFF)
                          : const Color(0x0F283E46),
                    ),
                    child: Icon(LucideIcons.trendingUp,
                        size: 30, color: theme.colorScheme.outline),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    'No profit data available',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                    ),
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

/// Small outlined "Change" pill in the date strip.
class _ChangeButton extends StatelessWidget {
  const _ChangeButton({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    final border =
        dark ? AppColors.darkInputBorder : const Color(0xFFD9DEDD);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.pill),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppRadius.pill),
          border: Border.all(color: border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(LucideIcons.pencil, size: 12, color: theme.colorScheme.primary),
            const SizedBox(width: 4),
            Text(
              'Change',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Outlined metric card for the Profit Report (matches Sales Summary metrics).
class _ProfitMetricCard extends StatelessWidget {
  const _ProfitMetricCard({
    required this.title,
    required this.value,
    required this.icon,
    this.accent,
  });

  final String title;
  final String value;
  final IconData icon;
  final Color? accent;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    final isDark = theme.brightness == Brightness.dark;
    final hairline = AppColors.hairline(isDark);
    final valueColor =
        accent == AppColors.success ? AppColors.successText(isDark) : null;

    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : AppColors.lightCard,
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: accent ?? hairline),
        boxShadow: isDark
            ? null
            : const [
                BoxShadow(
                  color: Color(0x0A111C1D),
                  blurRadius: 3,
                  offset: Offset(0, 1),
                ),
              ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 15, color: accent ?? muted),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  title,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: accent ?? muted,
                    fontWeight: FontWeight.w500,
                    fontSize: 11,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w700,
              fontSize: 18,
              color: valueColor ?? theme.colorScheme.onSurface,
            ),
          ),
        ],
      ),
    );
  }
}
