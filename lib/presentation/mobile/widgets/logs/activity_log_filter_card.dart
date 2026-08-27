import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:maki_mobile_pos/core/theme/theme.dart';
import 'package:maki_mobile_pos/core/utils/shop_time.dart';
import 'package:maki_mobile_pos/domain/entities/activity_log_entity.dart';
import 'package:maki_mobile_pos/presentation/mobile/widgets/reports/date_range_picker.dart';
import 'package:maki_mobile_pos/presentation/shared/widgets/common/common_widgets.dart';

final _timeFmt = DateFormat('h:mm a');
final _dayFmt = DateFormat('MMM d');

/// One-line description of the active filters, shown when the card is
/// collapsed. The time span is omitted when the window covers whole days,
/// which is the common case and would otherwise be noise.
String activityFilterSummary({
  required DateTime start,
  required DateTime end,
  required int typeCount,
  DateTime? now,
}) {
  final today = now ?? DateTime.now();
  final sameDay = start.year == end.year &&
      start.month == end.month &&
      start.day == end.day;

  String datePart;
  if (sameDay) {
    final yesterday = today.subtract(const Duration(days: 1));
    if (start.year == today.year &&
        start.month == today.month &&
        start.day == today.day) {
      datePart = 'Today';
    } else if (start.year == yesterday.year &&
        start.month == yesterday.month &&
        start.day == yesterday.day) {
      datePart = 'Yesterday';
    } else {
      datePart = _dayFmt.format(start);
    }
  } else {
    datePart = '${_dayFmt.format(start)} – ${_dayFmt.format(end)}';
  }

  final wholeDays = start.hour == 0 &&
      start.minute == 0 &&
      end.hour == 23 &&
      end.minute == 59;
  final timePart =
      wholeDays ? null : '${_timeFmt.format(start)}–${_timeFmt.format(end)}';

  final opsPart = typeCount == 0
      ? 'All operations'
      : typeCount == 1
          ? '1 operation'
          : '$typeCount operations';

  return [datePart, if (timePart != null) timePart, opsPart].join(' · ');
}

/// Filter panel for the activity-log screen. Holds no state — the screen owns
/// every value and every change is reported through a callback.
class ActivityLogFilterCard extends StatelessWidget {
  const ActivityLogFilterCard({
    super.key,
    required this.expanded,
    required this.selectedTypes,
    required this.preset,
    required this.startDate,
    required this.endDate,
    required this.startTime,
    required this.endTime,
    required this.dirty,
    required this.onToggleExpanded,
    required this.onTypesChanged,
    required this.onPresetChanged,
    required this.onCustomRangeSelected,
    required this.onStartTimeChanged,
    required this.onEndTimeChanged,
    required this.onSearch,
  });

  final bool expanded;
  final List<ActivityType> selectedTypes;
  final DateRangePreset preset;
  final DateTime startDate;
  final DateTime endDate;
  final TimeOfDay startTime;
  final TimeOfDay endTime;
  final bool dirty;
  final VoidCallback onToggleExpanded;
  final ValueChanged<List<ActivityType>> onTypesChanged;
  final ValueChanged<DateRangePreset> onPresetChanged;
  final void Function(DateTime start, DateTime end) onCustomRangeSelected;
  final ValueChanged<TimeOfDay> onStartTimeChanged;
  final ValueChanged<TimeOfDay> onEndTimeChanged;
  final VoidCallback onSearch;

  bool get _rangeValid {
    final s = _at(startDate, startTime);
    final e = _at(endDate, endTime);
    return !s.isAfter(e);
  }

  /// The chosen day + time as a shop **wall-clock** value. [day] arrives as
  /// an instant (a `dateRangeForPreset` bound); the summary text and the
  /// start <= end check both want it read in shop time.
  static DateTime _at(DateTime day, TimeOfDay t) {
    final w = day.inShopTime;
    return shopWall(w.year, w.month, w.day, t.hour, t.minute);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.hairline(isDark))),
      ),
      child: expanded ? _expandedView(context) : _collapsedView(context),
    );
  }

  Widget _collapsedView(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onToggleExpanded,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        child: Row(
          children: [
            Icon(LucideIcons.slidersHorizontal,
                size: 16, color: theme.colorScheme.onSurfaceVariant),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                activityFilterSummary(
                  start: _at(startDate, startTime),
                  end: _at(endDate, endTime),
                  now: DateTime.now().inShopTime,
                  typeCount: selectedTypes.length,
                ),
                style: theme.textTheme.bodySmall
                    ?.copyWith(fontWeight: FontWeight.w600),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Icon(LucideIcons.chevronDown,
                size: 18, color: theme.colorScheme.onSurfaceVariant),
          ],
        ),
      ),
    );
  }

  Widget _expandedView(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // The operations list is two dozen chips. Capping and scrolling the
        // control area keeps the card from crowding the results off a short
        // phone, and keeps Search pinned and always tappable below it.
        ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 320),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                DateRangePicker(
                  startDate: startDate,
                  endDate: endDate,
                  selectedPreset: preset,
                  onPresetChanged: onPresetChanged,
                  onCustomRangeSelected: onCustomRangeSelected,
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                  child: Row(
                    children: [
                      Expanded(
                        child: _TimePill(
                          label: 'From',
                          value: startTime,
                          onChanged: onStartTimeChanged,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: _TimePill(
                          label: 'To',
                          value: endTime,
                          onChanged: onEndTimeChanged,
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                  child: _OperationsPicker(
                    selected: selectedTypes,
                    onChanged: onTypesChanged,
                  ),
                ),
              ],
            ),
          ),
        ),
        if (dirty)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Text(
              'Filters changed — tap Search.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        if (!_rangeValid)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Text(
              'Start must be before end.',
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.error),
            ),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
          child: SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _rangeValid ? onSearch : null,
              child: const Text('Search'),
            ),
          ),
        ),
      ],
    );
  }
}

/// A tap-to-pick time pill. Uses the platform time picker.
class _TimePill extends StatelessWidget {
  const _TimePill({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final TimeOfDay value;
  final ValueChanged<TimeOfDay> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AppCard(
      radius: AppRadius.md,
      padding: EdgeInsets.zero,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.md),
        onTap: () async {
          final picked =
              await showTimePicker(context: context, initialTime: value);
          if (picked != null) onChanged(picked);
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          child: Row(
            children: [
              Text(
                label,
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
              const Spacer(),
              Text(
                value.format(context),
                style: theme.textTheme.bodyMedium
                    ?.copyWith(fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Multi-select over every activity type. Selection is always rebuilt in
/// canonical enum order so two identical selections compare equal.
class _OperationsPicker extends StatelessWidget {
  const _OperationsPicker({required this.selected, required this.onChanged});

  final List<ActivityType> selected;
  final ValueChanged<List<ActivityType>> onChanged;

  void _toggle(ActivityType type) {
    final next = selected.contains(type)
        ? selected.where((t) => t != type).toSet()
        : {...selected, type};
    onChanged(
      ActivityType.values.where(next.contains).toList(growable: false),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'OPERATIONS',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.6,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const Spacer(),
            if (selected.isNotEmpty)
              TextButton(
                onPressed: () => onChanged(const []),
                child: const Text('All'),
              ),
          ],
        ),
        const SizedBox(height: 4),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final type in ActivityType.values)
              FilterChip(
                label: Text(type.displayName),
                selected: selected.contains(type),
                onSelected: (_) => _toggle(type),
              ),
          ],
        ),
      ],
    );
  }
}
