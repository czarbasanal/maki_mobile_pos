import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:maki_mobile_pos/config/router/router.dart';
import 'package:maki_mobile_pos/core/extensions/navigation_extensions.dart';
import 'package:maki_mobile_pos/presentation/mobile/widgets/reports/date_range_picker.dart';
import 'package:maki_mobile_pos/presentation/mobile/widgets/reports/top_products_card.dart';

/// Granular drill-down for top-selling products.
///
/// Reuses the project-wide [DateRangePicker] (preset dropdown + custom date
/// pill) — defaults to "Today". The body is the same [TopProductsCard]
/// the sales report uses, capped at 20 entries here so quarterly / yearly
/// windows surface more of the long-tail than the dashboard's 10.
class TopSellingScreen extends ConsumerStatefulWidget {
  const TopSellingScreen({super.key});

  @override
  ConsumerState<TopSellingScreen> createState() => _TopSellingScreenState();
}

class _TopSellingScreenState extends ConsumerState<TopSellingScreen> {
  static const int _limit = 20;

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
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(LucideIcons.chevronLeft),
          onPressed: () => context.goBackOr(RoutePaths.dashboard),
        ),
        title: const Text('Top Selling'),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            DateRangePicker(
              startDate: _startDate,
              endDate: _endDate,
              selectedPreset: _selectedPreset,
              onPresetChanged: _handlePresetChange,
              onCustomRangeSelected: _handleCustomRange,
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: TopProductsCard(
                startDate: _startDate,
                endDate: _endDate,
                limit: _limit,
              ),
            ),
            const SizedBox(height: 32),
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
