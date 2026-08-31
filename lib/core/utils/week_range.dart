/// Date-range helpers (week-to-date and month-to-date).
///
/// The app uses a Monday→Sunday work week. Calendar months follow the
/// ambient locale's month-of-year. These helpers are pure (take the
/// reference [DateTime] explicitly) so they're trivially unit-testable
/// without a clock abstraction.
library;

import 'package:maki_mobile_pos/core/utils/shop_time.dart';

/// A Monday-start week range with the count of days elapsed within it.
///
/// [start] is midnight of the current week's Monday. [end] is the
/// reference timestamp passed in (typically `DateTime.now()`). [daysElapsed]
/// is 1 for Monday through 7 for Sunday — used as the divisor for
/// per-day averages within the week so far.
class WeekToDate {
  final DateTime start;
  final DateTime end;
  final int daysElapsed;

  const WeekToDate({
    required this.start,
    required this.end,
    required this.daysElapsed,
  });
}

/// Computes the Monday-anchored week-to-date range for [now].
WeekToDate weekToDate(DateTime now) {
  final weekday = now.weekday; // Monday = 1 ... Sunday = 7
  // Subtracting (weekday - 1) days from `now` lands on this week's Monday.
  // Using the y/m/d constructor with a negative day rolls correctly across
  // month and year boundaries (e.g. Jan 1 Wed → Dec 30 Mon).
  final monday = DateTime(now.year, now.month, now.day - (weekday - 1));
  return WeekToDate(start: monday, end: now, daysElapsed: weekday);
}

/// A month-to-date range with the count of *completed* past days within it.
///
/// [start] is midnight of the 1st of the current month. [end] is the
/// reference timestamp passed in (typically `DateTime.now()`).
/// [daysElapsed] is the count of fully-elapsed past days within the
/// current month, excluding today since today is still in progress
/// (e.g. 0 on the 1st, 14 on the 15th, 30 on the 31st). It serves as the
/// divisor for per-day averages — including today would dilute the
/// average with a partial-day figure. Differs intentionally from
/// [WeekToDate]'s convention of counting today.
class MonthToDate {
  final DateTime start;
  final DateTime end;
  final int daysElapsed;

  const MonthToDate({
    required this.start,
    required this.end,
    required this.daysElapsed,
  });
}

/// Computes the month-to-date range for [now]. [daysElapsed] excludes
/// today (see [MonthToDate]); on the 1st of the month it is 0, and the
/// `avgDailyFromGross` guard returns 0 to avoid divide-by-zero.
MonthToDate monthToDate(DateTime now) {
  final start = DateTime(now.year, now.month, 1);
  return MonthToDate(start: start, end: now, daysElapsed: now.day - 1);
}

/// Average daily value = total gross divided by elapsed days.
/// Returns 0 when [daysElapsed] is non-positive (defensive).
double avgDailyFromGross(double gross, int daysElapsed) {
  if (daysElapsed <= 0) return 0;
  return gross / daysElapsed;
}

/// The last 7 *completed* days: midnight seven days before [now] through the
/// end of yesterday (23:59:59.999). A rolling window, so unlike [MonthToDate]
/// it never resets on the 1st.
///
/// [days] is both the span and the divisor for the Avg Daily card: a quiet or
/// closed day inside the window is a real ₱0 day and stays in the average.
class RollingWindow {
  final DateTime start;
  final DateTime end;
  final int days;

  const RollingWindow({
    required this.start,
    required this.end,
    required this.days,
  });
}

/// The rolling last-[days]-completed-days range ending yesterday, as real
/// instants in the shop's timezone.
///
/// [today] is a shop WALL midnight (what `businessDayProvider` returns) — its
/// calendar fields are the shop day. Both bounds go back through
/// [offsetMinutes], because `getSalesByDateRange` uses the bounds it is given:
/// building them with the device-local `DateTime(...)` constructor would slide
/// the whole window by the handset's distance from shop time.
///
/// The y/m/d constructor rolls negative days correctly across month and year
/// boundaries.
RollingWindow rollingDays(DateTime today, int days, int offsetMinutes) {
  final firstDay = shopWall(today.year, today.month, today.day - days);
  final lastDay = shopWall(today.year, today.month, today.day - 1);
  return RollingWindow(
    start: instantOf(firstDay, offsetMinutes),
    end: instantOf(
        shopWall(lastDay.year, lastDay.month, lastDay.day, 23, 59, 59, 999),
        offsetMinutes),
    days: days,
  );
}

