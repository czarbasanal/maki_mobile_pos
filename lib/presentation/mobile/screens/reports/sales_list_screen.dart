import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:maki_mobile_pos/config/router/router.dart';
import 'package:maki_mobile_pos/core/extensions/num_extensions.dart';
import 'package:maki_mobile_pos/core/constants/role_permissions.dart';
import 'package:maki_mobile_pos/core/enums/enums.dart';
import 'package:maki_mobile_pos/core/extensions/navigation_extensions.dart';
import 'package:maki_mobile_pos/core/theme/theme.dart';
import 'package:maki_mobile_pos/domain/entities/entities.dart';
import 'package:maki_mobile_pos/presentation/providers/providers.dart';
import 'package:maki_mobile_pos/presentation/mobile/widgets/reports/reports_widgets.dart';
import 'package:maki_mobile_pos/presentation/shared/widgets/common/common_widgets.dart';
import 'package:intl/intl.dart';

/// Screen displaying list of sales with filtering options.
class SalesListScreen extends ConsumerStatefulWidget {
  const SalesListScreen({super.key});

  @override
  ConsumerState<SalesListScreen> createState() => _SalesListScreenState();
}

class _SalesListScreenState extends ConsumerState<SalesListScreen> {
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
      final now = DateTime.now();
      _startDate = DateTime(now.year, now.month, now.day);
      _endDate = DateTime(now.year, now.month, now.day, 23, 59, 59);
      _selectedPreset = DateRangePreset.today;
    }

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(LucideIcons.chevronLeft),
          onPressed: () => context.goBackOr(RoutePaths.dashboard),
        ),
        title: const Text('Sales History'),
        actions: [
          IconButton(
            icon: const Icon(LucideIcons.barChart3),
            tooltip: 'Reports',
            onPressed: () => _navigateToReports(context),
          ),
        ],
      ),
      body: Column(
        children: [
          // Date range picker — replaced by the forced-today banner for roles
          // restricted to the current day.
          if (dailyOnly)
            const ReportsWarningBanner(
              icon: LucideIcons.alertTriangle,
              title: "Showing today's sales only",
              subtitle: "Your role can view the current day's sales.",
            )
          else
            DateRangePicker(
              startDate: _startDate,
              endDate: _endDate,
              selectedPreset: _selectedPreset,
              onPresetChanged: _handlePresetChange,
              onCustomRangeSelected: _handleCustomRange,
            ),

          // Sales list
          Expanded(child: _buildSalesList(dailyOnly)),
        ],
      ),
    );
  }

  Widget _buildSalesList(bool dailyOnly) {
    final params = DateRangeParams(
      startDate: _startDate,
      endDate: _endDate,
    );

    final salesAsync = ref.watch(salesByDateRangeProvider(params));

    return salesAsync.when(
      data: (sales) {
        if (sales.isEmpty) {
          return const EmptyStateView(
            icon: LucideIcons.fileText,
            title: 'No Sales Found',
            subtitle: 'Try adjusting your date range or filters',
          );
        }

        final groupedSales = _groupSalesByDate(sales);

        return RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(salesByDateRangeProvider(params));
          },
          child: ListView(
            padding: const EdgeInsets.only(bottom: 16),
            children: [
              for (final entry in groupedSales.entries)
                _buildDateGroup(entry.key, entry.value),
              if (dailyOnly) const _EarlierDaysFooter(),
            ],
          ),
        );
      },
      loading: () => const LoadingView(),
      error: (error, _) => ErrorStateView(
        message: 'Failed to load sales\n$error',
        onRetry: () => ref.invalidate(salesByDateRangeProvider(params)),
      ),
    );
  }

  Widget _buildDateGroup(DateTime date, List<SaleEntity> sales) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    final isDark = theme.brightness == Brightness.dark;
    final hairline = AppColors.hairline(isDark);
    final dateFormat = DateFormat('EEEE, MMMM d');
    final isToday = _isToday(date);

    final completedSales = sales.where((s) => s.status == SaleStatus.completed);
    final dailyTotal = completedSales.fold(0.0, (sum, s) => sum + s.grandTotal);
    final dailyCount = completedSales.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Day header — on canvas, baseline-aligned.
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 4, 18, 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isToday ? 'Today' : dateFormat.format(date),
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      '$dailyCount sale${dailyCount != 1 ? 's' : ''}',
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: muted, fontSize: 12),
                    ),
                  ],
                ),
              ),
              Text(
                dailyTotal.toCurrency(),
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                  color: theme.colorScheme.primary,
                ),
              ),
            ],
          ),
        ),
        // Day card holding the sale rows.
        AppCard(
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 14),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
          child: Column(
            children: [
              for (var i = 0; i < sales.length; i++) ...[
                _buildSaleItem(sales[i]),
                if (i != sales.length - 1)
                  Divider(height: 1, color: hairline),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSaleItem(SaleEntity sale) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    final isDark = theme.brightness == Brightness.dark;
    final timeFormat = DateFormat('h:mm a');
    final isVoided = sale.status == SaleStatus.voided;

    final leadBg = isVoided
        ? (isDark ? const Color(0x29F44336) : const Color(0x1AF44336))
        : (isDark ? const Color(0x0DFFFFFF) : const Color(0x12283E46));
    final leadColor = isVoided
        ? (isDark ? AppColors.errorOnDark : AppColors.error)
        : (isDark ? const Color(0xFF9FB0B0) : theme.colorScheme.primary);

    return InkWell(
      onTap: () => _navigateToSaleDetail(sale),
      borderRadius: BorderRadius.circular(AppRadius.sm),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 11),
        child: Row(
          children: [
            // Leading tinted square.
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: leadBg,
                borderRadius: BorderRadius.circular(11),
              ),
              child: Icon(
                isVoided ? LucideIcons.xCircle : LucideIcons.fileText,
                size: 19,
                color: leadColor,
              ),
            ),
            const SizedBox(width: 12),
            // Middle.
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          sale.saleNumber,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontFamily: 'RobotoMono',
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.2,
                            color: isVoided ? AppColors.lightTextHint : null,
                            decoration:
                                isVoided ? TextDecoration.lineThrough : null,
                          ),
                        ),
                      ),
                      if (isVoided) ...[
                        const SizedBox(width: 7),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 4, vertical: 1),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(5),
                            border: Border.all(color: AppColors.error),
                          ),
                          child: const Text(
                            'VOID',
                            style: TextStyle(
                              color: AppColors.error,
                              fontSize: 9,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${timeFormat.format(sale.createdAt)} • ${sale.cashierName} • ${sale.totalItemCount} item${sale.totalItemCount == 1 ? '' : 's'}',
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: muted, fontSize: 12),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            // Trailing: total + payment pill.
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  sale.grandTotal.toCurrency(),
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                    color: isVoided ? muted : null,
                    decoration: isVoided ? TextDecoration.lineThrough : null,
                  ),
                ),
                const SizedBox(height: 4),
                _PaymentPill(method: sale.paymentMethod),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _handlePresetChange(DateRangePreset preset) {
    final now = DateTime.now();
    DateTime start;
    DateTime end = DateTime(now.year, now.month, now.day, 23, 59, 59);

    switch (preset) {
      case DateRangePreset.today:
        start = DateTime(now.year, now.month, now.day);
        break;
      case DateRangePreset.yesterday:
        final yesterday = now.subtract(const Duration(days: 1));
        start = DateTime(yesterday.year, yesterday.month, yesterday.day);
        end = DateTime(
            yesterday.year, yesterday.month, yesterday.day, 23, 59, 59);
        break;
      case DateRangePreset.thisWeek:
        final weekStart = now.subtract(Duration(days: now.weekday - 1));
        start = DateTime(weekStart.year, weekStart.month, weekStart.day);
        break;
      case DateRangePreset.lastWeek:
        final lastWeekStart = now.subtract(Duration(days: now.weekday + 6));
        final lastWeekEnd = now.subtract(Duration(days: now.weekday));
        start = DateTime(
            lastWeekStart.year, lastWeekStart.month, lastWeekStart.day);
        end = DateTime(
            lastWeekEnd.year, lastWeekEnd.month, lastWeekEnd.day, 23, 59, 59);
        break;
      case DateRangePreset.thisMonth:
        start = DateTime(now.year, now.month, 1);
        break;
      case DateRangePreset.lastMonth:
        final lastMonth = DateTime(now.year, now.month - 1, 1);
        start = lastMonth;
        end = DateTime(now.year, now.month, 0, 23, 59, 59);
        break;
      case DateRangePreset.thisQuarter:
        final firstMonth = ((now.month - 1) ~/ 3) * 3 + 1;
        start = DateTime(now.year, firstMonth, 1);
        break;
      case DateRangePreset.thisYear:
        start = DateTime(now.year, 1, 1);
        break;
      case DateRangePreset.custom:
        return; // Don't change dates for custom
    }

    setState(() {
      _startDate = start;
      _endDate = end;
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

  void _navigateToSaleDetail(SaleEntity sale) {
    context.push('${RoutePaths.reports}/sale/${sale.id}');
  }

  void _navigateToReports(BuildContext context) {
    context.push(RoutePaths.salesReport);
  }

  Map<DateTime, List<SaleEntity>> _groupSalesByDate(List<SaleEntity> sales) {
    final grouped = <DateTime, List<SaleEntity>>{};
    for (final sale in sales) {
      final date = DateTime(
        sale.createdAt.year,
        sale.createdAt.month,
        sale.createdAt.day,
      );
      grouped.putIfAbsent(date, () => []).add(sale);
    }
    return grouped;
  }

  bool _isToday(DateTime date) {
    final now = DateTime.now();
    return date.year == now.year &&
        date.month == now.month &&
        date.day == now.day;
  }
}

/// Pill summarizing a sale's payment method (icon + label, method-tinted).
class _PaymentPill extends StatelessWidget {
  const _PaymentPill({required this.method});
  final PaymentMethod method;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final fg = PaymentMethodStyle.pillFg(method, dark: dark);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: PaymentMethodStyle.pillBg(method, dark: dark),
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(PaymentMethodStyle.iconFor(method), size: 12, color: fg),
          const SizedBox(width: 4),
          Text(
            method.displayName,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.3,
              color: fg,
            ),
          ),
        ],
      ),
    );
  }
}

/// Footer shown to daily-only roles below the single Today group.
class _EarlierDaysFooter extends StatelessWidget {
  const _EarlierDaysFooter();

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(LucideIcons.lock, size: 13, color: muted),
          const SizedBox(width: 7),
          Text(
            'Earlier days are not available for your role',
            style: TextStyle(fontSize: 12, color: muted),
          ),
        ],
      ),
    );
  }
}
