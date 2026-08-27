import 'package:flutter/material.dart' show DateTimeRange;
import 'package:maki_mobile_pos/core/utils/shop_time.dart';
import 'package:maki_mobile_pos/presentation/mobile/widgets/reports/date_range_picker.dart';

/// Maps a [DateRangePreset] to a concrete [DateTimeRange] anchored at
/// [shopNow] — a shop **wall-clock** "now" (see shop_time.dart).
///
/// Boundaries are computed on wall values, then converted back to real
/// instants so they can be used directly as Firestore query bounds. Start is
/// shop midnight; end is the true end of the shop day (23:59:59.999) so an
/// inclusive `<=` query never drops a record created in the final second.
/// Callers never pass [DateRangePreset.custom] (the picker routes custom
/// selections to its own date-range picker via onCustomRangeSelected); it
/// falls back to today.
DateTimeRange dateRangeForPreset(
  DateRangePreset preset,
  DateTime shopNow,
  int offsetMinutes,
) {
  final now = shopNow;
  DateTime start;
  DateTime end = shopWall(now.year, now.month, now.day, 23, 59, 59, 999);
  switch (preset) {
    case DateRangePreset.today:
      start = shopWall(now.year, now.month, now.day);
      break;
    case DateRangePreset.yesterday:
      final y = now.subtract(const Duration(days: 1));
      start = shopWall(y.year, y.month, y.day);
      end = shopWall(y.year, y.month, y.day, 23, 59, 59, 999);
      break;
    case DateRangePreset.thisWeek:
      final ws = now.subtract(Duration(days: now.weekday - 1));
      start = shopWall(ws.year, ws.month, ws.day);
      break;
    case DateRangePreset.lastWeek:
      final lws = now.subtract(Duration(days: now.weekday + 6));
      final lwe = now.subtract(Duration(days: now.weekday));
      start = shopWall(lws.year, lws.month, lws.day);
      end = shopWall(lwe.year, lwe.month, lwe.day, 23, 59, 59, 999);
      break;
    case DateRangePreset.thisMonth:
      start = shopWall(now.year, now.month, 1);
      break;
    case DateRangePreset.lastMonth:
      start = shopWall(now.year, now.month - 1, 1);
      end = shopWall(now.year, now.month, 0, 23, 59, 59, 999);
      break;
    case DateRangePreset.thisQuarter:
      final firstMonth = ((now.month - 1) ~/ 3) * 3 + 1;
      start = shopWall(now.year, firstMonth, 1);
      break;
    case DateRangePreset.thisYear:
      start = shopWall(now.year, 1, 1);
      break;
    case DateRangePreset.custom:
      start = shopWall(now.year, now.month, now.day);
      break;
  }
  return DateTimeRange(
    start: instantOf(start, offsetMinutes),
    end: instantOf(end, offsetMinutes),
  );
}

/// The instant that *starts* the shop day whose calendar fields [pickedDay]
/// carries. Use for a day chosen in a date picker: its fields are the shop
/// calendar day the user meant, whatever zone the device is in.
DateTime shopDayStartInstant(DateTime pickedDay, int offsetMinutes) =>
    instantOf(
        shopWall(pickedDay.year, pickedDay.month, pickedDay.day), offsetMinutes);

/// The instant of the last millisecond of that same shop day — an inclusive
/// upper bound for a `<=` query.
DateTime shopDayEndInstant(DateTime pickedDay, int offsetMinutes) => instantOf(
    shopWall(pickedDay.year, pickedDay.month, pickedDay.day, 23, 59, 59, 999),
    offsetMinutes);
