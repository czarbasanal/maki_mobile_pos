// The payroll generator's 7-day attendance grid — a dumb controlled widget
// (state lives in PayslipDraftController). Port of web's WeekGrid: every cell
// is always tappable (future dates included) and a tap cycles
// present → absent → dayOff. Colors mirror web: green / red / neutral.
import 'package:flutter/material.dart';
import 'package:maki_mobile_pos/core/theme/theme.dart';
import 'package:maki_mobile_pos/domain/entities/entities.dart';
import 'package:maki_mobile_pos/domain/hr/pay_period.dart';

class WeekGrid extends StatelessWidget {
  const WeekGrid({super.key, required this.days, required this.onTapDay});

  final List<PayslipDay> days;
  final void Function(int index) onTapDay;

  static const _statusLabel = {
    DayStatus.present: 'Present',
    DayStatus.absent: 'Absent',
    DayStatus.dayOff: 'Day off',
  };

  static const _weekdayShort = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;

    Color bg(DayStatus s) => switch (s) {
          DayStatus.present => dark ? const Color(0x2E2E7D32) : const Color(0xFFE8F0EC),
          DayStatus.absent => dark ? const Color(0x2EB23B3B) : const Color(0xFFF6E4E4),
          DayStatus.dayOff => dark ? const Color(0x1F93A0A3) : const Color(0xFFF0F1F1),
        };
    Color fg(DayStatus s) => switch (s) {
          DayStatus.present => dark ? const Color(0xFF8FE39A) : const Color(0xFF2F7D5B),
          DayStatus.absent => dark ? const Color(0xFFE58C8C) : const Color(0xFFB23B3B),
          DayStatus.dayOff => theme.colorScheme.onSurfaceVariant,
        };

    return Row(
      children: [
        for (var i = 0; i < days.length; i++)
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: InkWell(
                borderRadius: BorderRadius.circular(AppRadius.sm),
                onTap: () => onTapDay(i),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                    color: bg(days[i].status),
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                  ),
                  child: Column(
                    children: [
                      Text(
                        _cellLabel(days[i].date),
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _statusLabel[days[i].status]!,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: fg(days[i].status),
                          fontWeight: FontWeight.w700,
                          fontSize: 10,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  /// "Mon 7/20" — weekday from the LOCAL-parsed date, month/day unpadded
  /// (web's cell label).
  static String _cellLabel(String isoDate) {
    final d = parseIsoLocalDate(isoDate);
    return '${_weekdayShort[d.weekday - 1]} ${d.month}/${d.day}';
  }
}
