import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:intl/intl.dart';
import 'package:maki_mobile_pos/core/theme/theme.dart';

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

/// Widget for selecting a date range. Two side-by-side controls span the
/// viewport width — a preset dropdown on the left and the active date
/// range pill on the right (which also opens a custom range picker on tap).
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

  static const double _controlHeight = 48;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dateFormat = DateFormat('MMM d, y');
    final isDark = theme.brightness == Brightness.dark;
    final hairline =
        isDark ? AppColors.darkHairline : AppColors.lightHairline;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        border: Border(bottom: BorderSide(color: hairline)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Preset dropdown.
          Expanded(child: _buildPresetDropdown(context, theme)),
          const SizedBox(width: AppSpacing.sm),
          // Active date range pill — opens the custom range picker.
          Expanded(child: _buildDatePill(context, theme, dateFormat)),
        ],
      ),
    );
  }

  Widget _buildPresetDropdown(BuildContext context, ThemeData theme) {
    final primary = theme.colorScheme.primary;
    final outlineBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppRadius.md),
      borderSide: BorderSide(color: primary),
    );
    return SizedBox(
      height: _controlHeight,
      child: DropdownButtonFormField<DateRangePreset>(
        initialValue: selectedPreset,
        // Forces a fresh rebuild when the parent's selectedPreset changes
        // (e.g. user picks a custom range via the date pill, which sets
        // preset to .custom externally).
        key: ValueKey('preset:${selectedPreset.name}'),
        isDense: true,
        isExpanded: true,
        icon: Icon(CupertinoIcons.chevron_down, size: 16, color: primary),
        style: TextStyle(
          fontWeight: FontWeight.w500,
          color: primary,
          fontSize: 14,
        ),
        decoration: InputDecoration(
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.sm + 4,
            vertical: AppSpacing.sm,
          ),
          prefixIcon: Icon(
            CupertinoIcons.calendar_today,
            size: 16,
            color: primary,
          ),
          prefixIconConstraints: const BoxConstraints(
            minWidth: 32,
            minHeight: 0,
          ),
          border: outlineBorder,
          enabledBorder: outlineBorder,
          focusedBorder: outlineBorder,
        ),
        items: DateRangePreset.values
            .map((p) => DropdownMenuItem<DateRangePreset>(
                  value: p,
                  child: Text(p.label),
                ))
            .toList(),
        onChanged: (preset) {
          if (preset == null) return;
          if (preset == DateRangePreset.custom) {
            _showCustomDatePicker(context);
          } else {
            onPresetChanged(preset);
          }
        },
      ),
    );
  }

  Widget _buildDatePill(
    BuildContext context,
    ThemeData theme,
    DateFormat dateFormat,
  ) {
    final primary = theme.colorScheme.primary;
    final label = _isSameDay(startDate, endDate)
        ? dateFormat.format(startDate)
        : '${dateFormat.format(startDate)} – ${dateFormat.format(endDate)}';

    return SizedBox(
      height: _controlHeight,
      child: InkWell(
        onTap: () => _showCustomDatePicker(context),
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.sm + 4,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(color: primary),
          ),
          child: Row(
            children: [
              Icon(CupertinoIcons.calendar, size: 16, color: primary),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontWeight: FontWeight.w500,
                    color: primary,
                    fontSize: 14,
                  ),
                ),
              ),
              const SizedBox(width: 4),
              Icon(CupertinoIcons.chevron_down, size: 16, color: primary),
            ],
          ),
        ),
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
