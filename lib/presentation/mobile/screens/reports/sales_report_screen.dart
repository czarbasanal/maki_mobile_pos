import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:maki_mobile_pos/config/router/router.dart';
import 'package:maki_mobile_pos/core/constants/role_permissions.dart';
import 'package:maki_mobile_pos/core/enums/enums.dart';
import 'package:maki_mobile_pos/core/extensions/navigation_extensions.dart';
import 'package:maki_mobile_pos/core/theme/theme.dart';
import 'package:maki_mobile_pos/core/utils/report_date_range.dart';
import 'package:maki_mobile_pos/presentation/providers/providers.dart';
import 'package:maki_mobile_pos/presentation/mobile/widgets/reports/reports_widgets.dart';
import 'package:maki_mobile_pos/presentation/shared/widgets/common/common_widgets.dart';

/// Sales report dashboard with summary and analytics.
class SalesReportScreen extends ConsumerStatefulWidget {
  const SalesReportScreen({super.key});

  @override
  ConsumerState<SalesReportScreen> createState() => _SalesReportScreenState();
}

class _SalesReportScreenState extends ConsumerState<SalesReportScreen> {
  late DateTime _startDate;
  late DateTime _endDate;
  DateRangePreset _selectedPreset = DateRangePreset.today;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _startDate = DateTime(now.year, now.month, now.day);
    _endDate = DateTime(now.year, now.month, now.day, 23, 59, 59);
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider).valueOrNull;
    final dailyOnly =
        user != null && RolePermissions.isDailyReportsOnly(user.role);

    if (dailyOnly) {
      // Force today regardless of any prior state — non-admin roles cannot
      // view historical data.
      final now = DateTime.now();
      _startDate = DateTime(now.year, now.month, now.day);
      _endDate = DateTime(now.year, now.month, now.day, 23, 59, 59);
      _selectedPreset = DateRangePreset.today;
    }

    final params = DateRangeParams(
      startDate: _startDate,
      endDate: _endDate,
    );

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(LucideIcons.chevronLeft),
          onPressed: () => context.goBackOr(RoutePaths.reports),
        ),
        title: const Text('Sales Report'),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(salesSummaryProvider(params));
          ref.invalidate(topSellingProductsProvider(TopSellingParams(
            startDate: _startDate,
            endDate: _endDate,
          )));
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Date range picker — replaced by a warning for today-only roles.
              if (dailyOnly)
                const ReportsWarningBanner(
                  icon: LucideIcons.lock,
                  title: "Showing today's sales only. "
                      'Contact an admin for historical reports.',
                )
              else
                DateRangePicker(
                  startDate: _startDate,
                  endDate: _endDate,
                  selectedPreset: _selectedPreset,
                  onPresetChanged: _handlePresetChange,
                  onCustomRangeSelected: _handleCustomRange,
                ),

              // Sales summary
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 2, 16, 12),
                child: SalesSummaryCard(
                  startDate: _startDate,
                  endDate: _endDate,
                ),
              ),

              // Top selling products
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: TopProductsCard(
                  startDate: _startDate,
                  endDate: _endDate,
                ),
              ),

              // Payment method breakdown
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: _buildPaymentBreakdown(),
              ),

              // More reports — historical, so only for non-daily-only roles.
              if (user != null && !dailyOnly) ...[
                if (RolePermissions.hasPermission(
                    user.role, Permission.viewProfitReports))
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                    child: _ReportNavTile(
                      icon: LucideIcons.trendingUp,
                      title: 'Profit Report',
                      subtitle: 'Cost, gross profit, and margin',
                      onTap: () => context.pushNamed(RouteNames.profitReport),
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                  child: _ReportNavTile(
                    icon: LucideIcons.wrench,
                    title: 'Labor Report',
                    subtitle: 'Service revenue by mechanic',
                    onTap: () => context.pushNamed(RouteNames.laborReport),
                  ),
                ),
              ],

              // End-of-day closing entry
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: _EodTile(
                  onTap: () => context.pushNamed(RouteNames.endOfDay),
                ),
              ),

              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPaymentBreakdown() {
    final params = DateRangeParams(
      startDate: _startDate,
      endDate: _endDate,
    );

    final summaryAsync = ref.watch(salesSummaryProvider(params));

    return summaryAsync.when(
      data: (summary) {
        final total = summary.netAmount;
        if (total == 0) return const SizedBox.shrink();

        final theme = Theme.of(context);
        return AppCard(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(LucideIcons.wallet,
                      color: theme.colorScheme.primary, size: 19),
                  const SizedBox(width: 9),
                  Text(
                    'Payment Methods',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              ...() {
                final entries = summary.byPaymentMethod.entries
                    .where((entry) => entry.value > 0)
                    .toList();
                return [
                  for (var i = 0; i < entries.length; i++)
                    _buildPaymentMethodRow(
                      entries[i].key,
                      entries[i].value,
                      total > 0 ? (entries[i].value / total * 100) : 0,
                      isLast: i == entries.length - 1,
                    ),
                ];
              }(),
            ],
          ),
        );
      },
      loading: () => const AppCard(
        padding: EdgeInsets.all(32),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (_, __) => const SizedBox.shrink(),
    );
  }

  Widget _buildPaymentMethodRow(
    PaymentMethod method,
    double amount,
    num percentage, {
    required bool isLast,
  }) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    final isDark = theme.brightness == Brightness.dark;
    final hairline = AppColors.hairline(isDark);
    return Padding(
      padding: EdgeInsets.only(bottom: isLast ? 0 : 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                method.displayName,
                style: const TextStyle(
                    fontWeight: FontWeight.w600, fontSize: 13),
              ),
              Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: '₱${amount.toStringAsFixed(2)}',
                      style: TextStyle(
                        color: theme.colorScheme.onSurface,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    TextSpan(
                      text: ' · ${percentage.toStringAsFixed(1)}%',
                      style: TextStyle(color: muted),
                    ),
                  ],
                  style: const TextStyle(fontSize: 12.5),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.pill),
            child: LinearProgressIndicator(
              value: percentage / 100,
              backgroundColor: hairline,
              valueColor: AlwaysStoppedAnimation<Color>(
                PaymentMethodStyle.barFill(method, dark: isDark),
              ),
              minHeight: 7,
            ),
          ),
        ],
      ),
    );
  }

  void _handlePresetChange(DateRangePreset preset) {
    if (preset == DateRangePreset.custom) return; // dropdown never emits custom
    final range = dateRangeForPreset(preset, DateTime.now());
    setState(() {
      _startDate = range.start;
      _endDate = range.end;
      _selectedPreset = preset;
    });
  }

  void _handleCustomRange(DateTime start, DateTime end) {
    setState(() {
      _startDate = start;
      _endDate = DateTime(end.year, end.month, end.day, 23, 59, 59);
      _selectedPreset = DateRangePreset.custom;
    });
  }
}

/// End-of-Day closing entry tile.
/// A tappable navigation tile linking to a sub-report (profit / labor).
class _ReportNavTile extends StatelessWidget {
  const _ReportNavTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    final dark = theme.brightness == Brightness.dark;
    return AppCard(
      radius: AppRadius.field,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      onTap: onTap,
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: dark ? const Color(0x1FE8B84C) : const Color(0x12283E46),
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(icon, size: 21, color: theme.colorScheme.primary),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    fontSize: 14.5,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  subtitle,
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: muted, fontSize: 12),
                ),
              ],
            ),
          ),
          Icon(LucideIcons.chevronRight, size: 18, color: muted),
        ],
      ),
    );
  }
}

class _EodTile extends StatelessWidget {
  const _EodTile({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    final dark = theme.brightness == Brightness.dark;
    return AppCard(
      radius: AppRadius.field,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      onTap: onTap,
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color:
                  dark ? const Color(0x1FE8B84C) : const Color(0x12283E46),
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(LucideIcons.circleDollarSign,
                size: 21, color: theme.colorScheme.primary),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'End-of-Day Closing',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    fontSize: 14.5,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  'Reconcile the cash drawer',
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: muted, fontSize: 12),
                ),
              ],
            ),
          ),
          Icon(LucideIcons.chevronRight, size: 18, color: muted),
        ],
      ),
    );
  }
}
