import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:maki_mobile_pos/config/router/router.dart';
import 'package:maki_mobile_pos/core/constants/app_constants.dart';
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
  SaleStatus? _statusFilter;
  String? _cashierFilter;
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
    final theme = Theme.of(context);
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
          icon: const Icon(CupertinoIcons.back),
          onPressed: () => context.goBackOr(RoutePaths.dashboard),
        ),
        title: const Text('Sales History'),
        actions: [
          IconButton(
            icon: const Icon(CupertinoIcons.line_horizontal_3_decrease),
            tooltip: 'Filters',
            onPressed: _showFilterSheet,
          ),
          IconButton(
            icon: const Icon(CupertinoIcons.chart_bar),
            tooltip: 'Reports',
            onPressed: () => _navigateToReports(context),
          ),
        ],
      ),
      body: Column(
        children: [
          // Date range picker — hidden when role is restricted to today.
          if (!dailyOnly)
            DateRangePicker(
              startDate: _startDate,
              endDate: _endDate,
              selectedPreset: _selectedPreset,
              onPresetChanged: _handlePresetChange,
              onCustomRangeSelected: _handleCustomRange,
            ),

          // Active filters display
          if (_statusFilter != null || _cashierFilter != null)
            _buildActiveFilters(theme),

          // Sales list
          Expanded(
            child: _buildSalesList(),
          ),
        ],
      ),
    );
  }

  Widget _buildActiveFilters(ThemeData theme) {
    final muted = theme.colorScheme.onSurfaceVariant;
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      child: Row(
        children: [
          Icon(
            CupertinoIcons.line_horizontal_3_decrease,
            size: 16,
            color: muted,
          ),
          const SizedBox(width: AppSpacing.sm),
          if (_statusFilter != null)
            Padding(
              padding: const EdgeInsets.only(right: AppSpacing.sm),
              child: Chip(
                label: Text(_statusFilter!.displayName),
                deleteIcon: const Icon(CupertinoIcons.xmark, size: 16),
                onDeleted: () {
                  setState(() => _statusFilter = null);
                },
                visualDensity: VisualDensity.compact,
              ),
            ),
          if (_cashierFilter != null)
            Chip(
              label: Text('Cashier: $_cashierFilter'),
              deleteIcon: const Icon(CupertinoIcons.xmark, size: 16),
              onDeleted: () {
                setState(() => _cashierFilter = null);
              },
              visualDensity: VisualDensity.compact,
            ),
          const Spacer(),
          TextButton(
            onPressed: _clearFilters,
            child: const Text('Clear all'),
          ),
        ],
      ),
    );
  }

  Widget _buildSalesList() {
    final params = DateRangeParams(
      startDate: _startDate,
      endDate: _endDate,
      status: _statusFilter,
      cashierId: _cashierFilter,
    );

    final salesAsync = ref.watch(salesByDateRangeProvider(params));

    return salesAsync.when(
      data: (sales) {
        if (sales.isEmpty) {
          return const EmptyStateView(
            icon: CupertinoIcons.doc_text,
            title: 'No Sales Found',
            subtitle: 'Try adjusting your date range or filters',
          );
        }

        // Group sales by date
        final groupedSales = _groupSalesByDate(sales);

        return RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(salesByDateRangeProvider(params));
          },
          child: ListView.builder(
            itemCount: groupedSales.length,
            padding: const EdgeInsets.only(bottom: 16),
            itemBuilder: (context, index) {
              final dateGroup = groupedSales.entries.elementAt(index);
              return _buildDateGroup(dateGroup.key, dateGroup.value);
            },
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
    final hairline =
        isDark ? AppColors.darkHairline : AppColors.lightHairline;
    final dateFormat = DateFormat('EEEE, MMMM d, y');
    final isToday = _isToday(date);

    final completedSales = sales.where((s) => s.status == SaleStatus.completed);
    final dailyTotal = completedSales.fold(0.0, (sum, s) => sum + s.grandTotal);
    final dailyCount = completedSales.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Date header — flat with hairline borders
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm + 4,
          ),
          decoration: BoxDecoration(
            border: Border(
              top: BorderSide(color: hairline),
              bottom: BorderSide(color: hairline),
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isToday ? 'Today' : dateFormat.format(date),
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      '$dailyCount sale${dailyCount != 1 ? 's' : ''}',
                      style: theme.textTheme.bodySmall?.copyWith(color: muted),
                    ),
                  ],
                ),
              ),
              Text(
                '${AppConstants.currencySymbol}${dailyTotal.toStringAsFixed(2)}',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.primary,
                ),
              ),
            ],
          ),
        ),
        ...sales.map((sale) => _buildSaleItem(sale)),
      ],
    );
  }

  Widget _buildSaleItem(SaleEntity sale) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    final timeFormat = DateFormat('h:mm a');
    final isVoided = sale.status == SaleStatus.voided;

    return ListTile(
      onTap: () => _navigateToSaleDetail(sale),
      // Outlined leading glyph; no tinted background.
      leading: Icon(
        isVoided ? CupertinoIcons.xmark_circle : CupertinoIcons.doc_text,
        color: isVoided ? AppColors.error : muted,
        size: 24,
      ),
      title: Row(
        children: [
          Expanded(
            child: Text(
              sale.saleNumber,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                decoration: isVoided ? TextDecoration.lineThrough : null,
                color: isVoided ? muted : null,
              ),
            ),
          ),
          if (isVoided)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AppRadius.sm),
                border: Border.all(color: AppColors.error),
              ),
              child: const Text(
                'VOID',
                style: TextStyle(
                  color: AppColors.error,
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.6,
                ),
              ),
            ),
        ],
      ),
      subtitle: Text(
        '${timeFormat.format(sale.createdAt)} • ${sale.cashierName} • ${sale.totalItemCount} items',
        style: theme.textTheme.bodySmall?.copyWith(color: muted),
      ),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            '${AppConstants.currencySymbol}${sale.grandTotal.toStringAsFixed(2)}',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: isVoided ? muted : null,
              decoration: isVoided ? TextDecoration.lineThrough : null,
            ),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                sale.paymentMethod == PaymentMethod.cash
                    ? CupertinoIcons.money_dollar
                    : CupertinoIcons.device_phone_portrait,
                size: 14,
                color: muted,
              ),
              const SizedBox(width: 4),
              Text(
                sale.paymentMethod.displayName,
                style: theme.textTheme.bodySmall?.copyWith(color: muted),
              ),
            ],
          ),
        ],
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

  void _showFilterSheet() {
    showModalBottomSheet(
      context: context,
      builder: (context) => _FilterSheet(
        currentStatus: _statusFilter,
        currentCashier: _cashierFilter,
        onApply: (status, cashier) {
          setState(() {
            _statusFilter = status;
            _cashierFilter = cashier;
          });
          Navigator.pop(context);
        },
      ),
    );
  }

  void _clearFilters() {
    setState(() {
      _statusFilter = null;
      _cashierFilter = null;
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

/// Bottom sheet for additional filters.
class _FilterSheet extends ConsumerWidget {
  final SaleStatus? currentStatus;
  final String? currentCashier;
  final void Function(SaleStatus?, String?) onApply;

  const _FilterSheet({
    required this.currentStatus,
    required this.currentCashier,
    required this.onApply,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    SaleStatus? selectedStatus = currentStatus;
    String? selectedCashier = currentCashier;

    return StatefulBuilder(
      builder: (context, setState) {
        return Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Filters',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 20),

              // Status filter
              const Text(
                'Status',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [
                  ChoiceChip(
                    label: const Text('All'),
                    selected: selectedStatus == null,
                    onSelected: (selected) {
                      if (selected) {
                        setState(() => selectedStatus = null);
                      }
                    },
                  ),
                  ...SaleStatus.values.map((status) => ChoiceChip(
                        label: Text(status.displayName),
                        selected: selectedStatus == status,
                        onSelected: (selected) {
                          setState(() {
                            selectedStatus = selected ? status : null;
                          });
                        },
                      )),
                ],
              ),

              const SizedBox(height: 24),

              // Apply button
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => onApply(selectedStatus, selectedCashier),
                  child: const Text('Apply Filters'),
                ),
              ),

              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }
}
