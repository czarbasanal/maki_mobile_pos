import 'package:flutter/material.dart' show DateTimeRange;
import 'package:maki_mobile_pos/presentation/mobile/widgets/reports/date_range_picker.dart';

/// Maps a [DateRangePreset] to a concrete [DateTimeRange] anchored at [now].
/// Start is midnight; end is 23:59:59 of the last day. Callers never pass
/// [DateRangePreset.custom] (the picker routes custom selections to its own
/// date-range picker via onCustomRangeSelected); it falls back to today.
DateTimeRange dateRangeForPreset(DateRangePreset preset, DateTime now) {
  DateTime start;
  DateTime end = DateTime(now.year, now.month, now.day, 23, 59, 59);
  switch (preset) {
    case DateRangePreset.today:
      start = DateTime(now.year, now.month, now.day);
      break;
    case DateRangePreset.yesterday:
      final y = now.subtract(const Duration(days: 1));
      start = DateTime(y.year, y.month, y.day);
      end = DateTime(y.year, y.month, y.day, 23, 59, 59);
      break;
    case DateRangePreset.thisWeek:
      final ws = now.subtract(Duration(days: now.weekday - 1));
      start = DateTime(ws.year, ws.month, ws.day);
      break;
    case DateRangePreset.lastWeek:
      final lws = now.subtract(Duration(days: now.weekday + 6));
      final lwe = now.subtract(Duration(days: now.weekday));
      start = DateTime(lws.year, lws.month, lws.day);
      end = DateTime(lwe.year, lwe.month, lwe.day, 23, 59, 59);
      break;
    case DateRangePreset.thisMonth:
      start = DateTime(now.year, now.month, 1);
      break;
    case DateRangePreset.lastMonth:
      start = DateTime(now.year, now.month - 1, 1);
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
      start = DateTime(now.year, now.month, now.day);
      break;
  }
  return DateTimeRange(start: start, end: end);
}
