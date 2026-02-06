import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:maki_mobile_pos/core/constants/app_constants.dart';
import 'package:maki_mobile_pos/core/enums/enums.dart';
import 'package:maki_mobile_pos/domain/entities/entities.dart';
import 'package:maki_mobile_pos/presentation/providers/providers.dart';
import 'package:maki_mobile_pos/presentation/screens/reports/reports.dart';
import 'package:maki_mobile_pos/presentation/screens/sales/sale_detail_screen.dart';
import 'package:maki_mobile_pos/presentation/widgets/reports/reports_widgets.dart';
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

    return Scaffold(
      appBar: AppBar(
        title: const Text('Sales History'),
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list),
            tooltip: 'Filters',
            onPressed: _showFilterSheet,
          ),
          IconButton(
            icon: const Icon(Icons.analytics_outlined),
            tooltip: 'Reports',
            onPressed: () => _navigateToReports(context),
          ),
        ],
      ),
      body: Column(
        children: [
          // Date range picker
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
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          const Icon(Icons.filter_alt, size: 16, color: Colors.grey),
          const SizedBox(width: 8),
          if (_statusFilter != null)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Chip(
                label: Text(_statusFilter!.displayName),
                deleteIcon: const Icon(Icons.close, size: 16),
                onDeleted: () {
                  setState(() => _statusFilter = null);
                },
                visualDensity: VisualDensity.compact,
              ),
            ),
          if (_cashierFilter != null)
            Chip(
              label: Text('Cashier: $_cashierFilter'),
              deleteIcon: const Icon(Icons.close, size: 16),
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
          return _buildEmptyState();
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
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => _buildErrorState(error),
    );
  }

  Widget _buildDateGroup(DateTime date, List<SaleEntity> sales) {
    final theme = Theme.of(context);
    final dateFormat = DateFormat('EEEE, MMMM d, y');
    final isToday = _isToday(date);

    // Calculate daily totals
    final completedSales = sales.where((s) => s.status == SaleStatus.completed);
    final dailyTotal = completedSales.fold(0.0, (sum, s) => sum + s.grandTotal);
    final dailyCount = completedSales.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Date header
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          color: Colors.grey[100],
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isToday ? 'Today' : dateFormat.format(date),
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      '$dailyCount sale${dailyCount != 1 ? 's' : ''}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                '${AppConstants.currencySymbol}${dailyTotal.toStringAsFixed(2)}',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.primary,
                ),
              ),
            ],
          ),
        ),

        // Sales for this date
        ...sales.map((sale) => _buildSaleItem(sale)),
      ],
    );
  }

  Widget _buildSaleItem(SaleEntity sale) {
    final theme = Theme.of(context);
    final timeFormat = DateFormat('h:mm a');
    final isVoided = sale.status == SaleStatus.voided;

    return ListTile(
      onTap: () => _navigateToSaleDetail(sale),
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: isVoided ? Colors.red[50] : Colors.green[50],
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(
          isVoided ? Icons.cancel : Icons.receipt_long,
          color: isVoided ? Colors.red : Colors.green,
          size: 24,
        ),
      ),
      title: Row(
        children: [
          Expanded(
            child: Text(
              sale.saleNumber,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                decoration: isVoided ? TextDecoration.lineThrough : null,
                color: isVoided ? Colors.grey : null,
              ),
            ),
          ),
          if (isVoided)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.red,
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Text(
                'VOID',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
        ],
      ),
      subtitle: Text(
        '${timeFormat.format(sale.createdAt)} • ${sale.cashierName} • ${sale.totalItemCount} items',
        style: TextStyle(
          color: isVoided ? Colors.grey : Colors.grey[600],
        ),
      ),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            '${AppConstants.currencySymbol}${sale.grandTotal.toStringAsFixed(2)}',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: isVoided ? Colors.grey : null,
              decoration: isVoided ? TextDecoration.lineThrough : null,
            ),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                sale.paymentMethod == PaymentMethod.cash
                    ? Icons.money
                    : Icons.phone_android,
                size: 14,
                color: Colors.grey[500],
              ),
              const SizedBox(width: 4),
              Text(
                sale.paymentMethod.displayName,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: Colors.grey[500],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.receipt_long, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'No Sales Found',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Try adjusting your date range or filters',
              style: TextStyle(color: Colors.grey[500]),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState(Object error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: Colors.red[400]),
            const SizedBox(height: 16),
            Text(
              'Failed to load sales',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              error.toString(),
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[500]),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: () {
                ref.invalidate(salesByDateRangeProvider(DateRangeParams(
                  startDate: _startDate,
                  endDate: _endDate,
                )));
              },
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
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
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SaleDetailScreen(saleId: sale.id),
      ),
    );
  }

  void _navigateToReports(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const SalesReportScreen(),
      ),
    );
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
