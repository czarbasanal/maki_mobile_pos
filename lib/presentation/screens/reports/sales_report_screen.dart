import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:maki_mobile_pos/core/enums/enums.dart';
import 'package:maki_mobile_pos/presentation/providers/providers.dart';
import 'package:maki_mobile_pos/presentation/widgets/reports/reports_widgets.dart';

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
    final params = DateRangeParams(
      startDate: _startDate,
      endDate: _endDate,
    );

    return Scaffold(
      appBar: AppBar(
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
              // Date range picker
              DateRangePicker(
                startDate: _startDate,
                endDate: _endDate,
                selectedPreset: _selectedPreset,
                onPresetChanged: _handlePresetChange,
                onCustomRangeSelected: _handleCustomRange,
              ),

              // Sales summary
              Padding(
                padding: const EdgeInsets.all(16),
                child: SalesSummaryCard(
                  startDate: _startDate,
                  endDate: _endDate,
                ),
              ),

              // Top selling products
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: TopProductsCard(
                  startDate: _startDate,
                  endDate: _endDate,
                ),
              ),

              // Payment method breakdown
              Padding(
                padding: const EdgeInsets.all(16),
                child: _buildPaymentBreakdown(),
              ),

              const SizedBox(height: 32),
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

        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Payment Methods',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                ...summary.byPaymentMethod.entries.map((entry) {
                  final percentage =
                      total > 0 ? (entry.value / total * 100) : 0;
                  return _buildPaymentMethodRow(
                    entry.key.displayName,
                    entry.value,
                    percentage.toDouble(),
                    entry.key.color,
                  );
                }),
              ],
            ),
          ),
        );
      },
      loading: () => const Card(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Center(child: CircularProgressIndicator()),
        ),
      ),
      error: (_, __) => const SizedBox.shrink(),
    );
  }

  Widget _buildPaymentMethodRow(
    String method,
    double amount,
    double percentage,
    Color color,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(method),
              Text(
                '₱${amount.toStringAsFixed(2)} (${percentage.toStringAsFixed(1)}%)',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ],
          ),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: percentage / 100,
              backgroundColor: Colors.grey[200],
              valueColor: AlwaysStoppedAnimation<Color>(color),
              minHeight: 8,
            ),
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
        return;
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
}

/// Extension to add color to PaymentMethod.
extension PaymentMethodColor on PaymentMethod {
  Color get color {
    switch (this) {
      case PaymentMethod.cash:
        return Colors.green;
      case PaymentMethod.gcash:
        return Colors.blue;
    }
  }
}
