import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:maki_mobile_pos/config/router/router.dart';
import 'package:maki_mobile_pos/core/extensions/navigation_extensions.dart';
import 'package:maki_mobile_pos/core/extensions/num_extensions.dart';
import 'package:maki_mobile_pos/core/theme/theme.dart';
import 'package:maki_mobile_pos/core/utils/labor_report.dart';
import 'package:maki_mobile_pos/presentation/providers/providers.dart';
import 'package:maki_mobile_pos/presentation/shared/widgets/common/common_widgets.dart';
import 'package:intl/intl.dart';

/// Labor (service) report — total labor revenue and a per-mechanic breakdown
/// for the selected range. Reads [laborReportProvider], which derives the
/// figures from the raw sales in range.
class LaborReportScreen extends ConsumerStatefulWidget {
  const LaborReportScreen({super.key});

  @override
  ConsumerState<LaborReportScreen> createState() => _LaborReportScreenState();
}

class _LaborReportScreenState extends ConsumerState<LaborReportScreen> {
  DateTimeRange _dateRange = DateTimeRange(
    start: DateTime.now().subtract(const Duration(days: 30)),
    end: DateTime.now(),
  );

  DateRangeParams get _params => DateRangeParams(
        startDate: DateTime(_dateRange.start.year, _dateRange.start.month,
            _dateRange.start.day),
        endDate: DateTime(_dateRange.end.year, _dateRange.end.month,
            _dateRange.end.day, 23, 59, 59),
      );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dateFormat = DateFormat('MMM d, y');
    final reportAsync = ref.watch(laborReportProvider(_params));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Labor Report'),
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
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(laborReportProvider(_params)),
        child: ListView(
          children: [
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
                      _LaborChangeButton(onTap: _selectDateRange),
                    ],
                  ),
                ),
              ),
            ),
            reportAsync.when(
              loading: () => const Padding(
                padding: EdgeInsets.fromLTRB(16, 16, 16, 0),
                child: SizedBox(height: 300, child: ListSkeleton()),
              ),
              error: (e, _) => Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                child: ErrorStateView(
                  message: 'Failed to load labor report: $e',
                  onRetry: () => ref.invalidate(laborReportProvider(_params)),
                ),
              ),
              data: (report) => _buildBody(theme, report),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(ThemeData theme, LaborReportData report) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: Row(
            children: [
              Expanded(
                child: _LaborMetricCard(
                  title: 'Total Labor',
                  value: report.totalLabor.toCurrency(),
                  icon: LucideIcons.wrench,
                  accent: AppColors.success,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _LaborMetricCard(
                  title: 'Service Sales',
                  value: '${report.serviceSaleCount}',
                  icon: LucideIcons.receipt,
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 6),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Labor by Mechanic',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
                fontSize: 15,
              ),
            ),
          ),
        ),
        if (report.byMechanic.isEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 24, 16, 0),
            child: EmptyStateView(
              icon: LucideIcons.wrench,
              title: 'No labor recorded',
              subtitle: 'Service sales with labor will appear here.',
            ),
          )
        else
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              children: [
                for (final m in report.byMechanic)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: _MechanicLaborRow(entry: m, theme: theme),
                  ),
              ],
            ),
          ),
      ],
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

class _MechanicLaborRow extends StatelessWidget {
  const _MechanicLaborRow({required this.entry, required this.theme});

  final LaborByMechanic entry;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    final isDark = theme.brightness == Brightness.dark;
    final muted = theme.colorScheme.onSurfaceVariant;
    return AppCard(
      radius: 12,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.mechanicName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    fontSize: 13.5,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${entry.jobCount} ${entry.jobCount == 1 ? 'job' : 'jobs'}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: muted,
                    fontSize: 11.5,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Text(
            entry.laborTotal.toCurrency(),
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
              fontSize: 14,
              color: AppColors.successText(isDark),
            ),
          ),
        ],
      ),
    );
  }
}

class _LaborChangeButton extends StatelessWidget {
  const _LaborChangeButton({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    final border = dark ? AppColors.darkInputBorder : const Color(0xFFD9DEDD);
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

class _LaborMetricCard extends StatelessWidget {
  const _LaborMetricCard({
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
