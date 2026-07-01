import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:maki_mobile_pos/core/theme/theme.dart';
import 'package:maki_mobile_pos/presentation/shared/widgets/common/common_widgets.dart';

/// Date range presets.
enum DateRangePreset {
  today('Today'),
  yesterday('Yesterday'),
  thisWeek('This Week'),
  lastWeek('Last Week'),
  thisMonth('This Month'),
  lastMonth('Last Month'),
  thisQuarter('This Quarter'),
  thisYear('This Year'),
  custom('Custom');

  final String label;
  const DateRangePreset(this.label);
}

/// Widget for selecting a date range. Two side-by-side `AppCard` pills span the
/// viewport width — a preset dropdown on the left and the active date range
/// pill on the right (which also opens a custom range picker on tap).
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

  static const double _controlHeight = 46;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dateFormat = DateFormat('MMM d, y');

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Preset dropdown (≈1 : 1.3 ratio so the date never clips).
          Expanded(flex: 10, child: _buildPresetDropdown(context, theme)),
          const SizedBox(width: AppSpacing.sm),
          Expanded(flex: 13, child: _buildDatePill(context, theme, dateFormat)),
        ],
      ),
    );
  }

  Widget _buildPresetDropdown(BuildContext context, ThemeData theme) {
    final primary = theme.colorScheme.primary;
    final muted = theme.colorScheme.onSurfaceVariant;
    // PopupMenuButton (not a bare DropdownButton) so the ENTIRE pill — icon,
    // label, chevron and padding — is the tap target, not just the label text.
    return AppCard(
      radius: AppRadius.md,
      padding: EdgeInsets.zero,
      child: PopupMenuButton<DateRangePreset>(
        initialValue: selectedPreset,
        tooltip: 'Change date range',
        position: PopupMenuPosition.under,
        padding: EdgeInsets.zero,
        onSelected: (preset) {
          if (preset == DateRangePreset.custom) {
            _showCustomDatePicker(context);
          } else {
            onPresetChanged(preset);
          }
        },
        itemBuilder: (context) => DateRangePreset.values
            .map((p) => PopupMenuItem<DateRangePreset>(
                  value: p,
                  child: Text(p.label),
                ))
            .toList(),
        child: SizedBox(
          height: _controlHeight,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 13),
            child: Row(
              children: [
                Icon(LucideIcons.calendarDays, size: 17, color: primary),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    selectedPreset.label,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: theme.colorScheme.onSurface,
                      fontSize: 14,
                    ),
                  ),
                ),
                Icon(LucideIcons.chevronDown, size: 16, color: muted),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDatePill(
    BuildContext context,
    ThemeData theme,
    DateFormat dateFormat,
  ) {
    final primary = theme.colorScheme.primary;
    final muted = theme.colorScheme.onSurfaceVariant;
    final label = _isSameDay(startDate, endDate)
        ? dateFormat.format(startDate)
        : '${dateFormat.format(startDate)} – ${dateFormat.format(endDate)}';

    return AppCard(
      radius: AppRadius.md,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      onTap: () => _showCustomDatePicker(context),
      child: SizedBox(
        height: _controlHeight,
        child: Row(
          children: [
            Icon(LucideIcons.calendar, size: 17, color: primary),
            const SizedBox(width: 7),
            Expanded(
              child: Text(
                label,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontWeight: FontWeight.w500,
                  color: theme.colorScheme.onSurface,
                  fontSize: 13,
                ),
              ),
            ),
            const SizedBox(width: 4),
            Icon(LucideIcons.chevronDown, size: 16, color: muted),
          ],
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
