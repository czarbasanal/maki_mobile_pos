import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// Date range presets.
enum DateRangePreset {
  today('Today'),
  yesterday('Yesterday'),
  thisWeek('This Week'),
  lastWeek('Last Week'),
  thisMonth('This Month'),
  lastMonth('Last Month'),
  custom('Custom');

  final String label;
  const DateRangePreset(this.label);
}

/// Widget for selecting date range with presets.
class DateRangePicker extends StatelessWidget {
  final DateTime startDate;
  final DateTime endDate;
  final DateRangePreset selectedPreset;
  final ValueChanged<DateRangePreset> onPresetChanged;
  final void Function(DateTime start, DateTime end) onCustomRangeSelected;

  const DateRangePicker({
    super.key,
    required this.startDate,
    required this.endDate,
    required this.selectedPreset,
    required this.onPresetChanged,
    required this.onCustomRangeSelected,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dateFormat = DateFormat('MMM d, y');

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Preset buttons
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: DateRangePreset.values.map((preset) {
                final isSelected = selectedPreset == preset;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(preset.label),
                    selected: isSelected,
                    onSelected: (selected) {
                      if (preset == DateRangePreset.custom) {
                        _showCustomDatePicker(context);
                      } else {
                        onPresetChanged(preset);
                      }
                    },
                  ),
                );
              }).toList(),
            ),
          ),

          const SizedBox(height: 12),

          // Selected range display
          InkWell(
            onTap: () => _showCustomDatePicker(context),
            borderRadius: BorderRadius.circular(8),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer.withOpacity(0.3),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.calendar_today,
                    size: 16,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _isSameDay(startDate, endDate)
                        ? dateFormat.format(startDate)
                        : '${dateFormat.format(startDate)} - ${dateFormat.format(endDate)}',
                    style: TextStyle(
                      fontWeight: FontWeight.w500,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    Icons.arrow_drop_down,
                    color: theme.colorScheme.primary,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showCustomDatePicker(BuildContext context) async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: DateTimeRange(start: startDate, end: endDate),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).colorScheme,
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      onCustomRangeSelected(picked.start, picked.end);
    }
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }
}
