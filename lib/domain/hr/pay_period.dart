/// Pay-period helpers — port of web_admin/src/domain/hr/payPeriod.ts and
/// weekdays.ts. The wire format is a LOCAL calendar date string 'YYYY-MM-DD';
/// no timezone ever enters the contract.
///
/// Internally dates are stepped as [DateTime.utc] values built from calendar
/// components: the test/CI machine is rarely in shop time, and stepping a
/// LOCAL DateTime by `Duration(days: 7)` can skip or repeat a calendar day
/// across a DST transition. UTC has no DST, so day arithmetic is exact; only
/// the y/m/d components are ever read back out.
library;

/// A 7-day pay period. [dates] always holds exactly seven 'YYYY-MM-DD'
/// strings; [start] and [end] are its first and last entries.
class PayPeriod {
  final String start;
  final String end;
  final List<String> dates;

  const PayPeriod({required this.start, required this.end, required this.dates});
}

String _iso(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

PayPeriod _periodFromStart(DateTime startUtc) {
  final dates = List.generate(
    7,
    (k) => _iso(DateTime.utc(startUtc.year, startUtc.month, startUtc.day + k)),
  );
  return PayPeriod(start: dates[0], end: dates[6], dates: dates);
}

/// The 7-day period containing [anchor], starting on ISO weekday
/// [weekStartDay] (1 = Monday … 7 = Sunday) — snaps to the most recent start
/// day on or before the anchor. Dart's [DateTime.weekday] is already ISO 1–7.
PayPeriod payPeriodFor(DateTime anchor, int weekStartDay) {
  final a = DateTime.utc(anchor.year, anchor.month, anchor.day);
  final diff = (a.weekday - weekStartDay + 7) % 7;
  return _periodFromStart(DateTime.utc(a.year, a.month, a.day - diff));
}

/// Shifts [p] by whole weeks (negative allowed), rebuilding all 7 dates.
PayPeriod shiftPeriod(PayPeriod p, int weeks) {
  final parts = p.start.split('-').map(int.parse).toList();
  return _periodFromStart(
    DateTime.utc(parts[0], parts[1], parts[2] + weeks * 7),
  );
}

const _weekdayLabels = [
  'Monday',
  'Tuesday',
  'Wednesday',
  'Thursday',
  'Friday',
  'Saturday',
  'Sunday',
];

/// Label for an ISO weekday 1–7; empty string for anything else.
String weekdayLabel(int day) =>
    day >= 1 && day <= 7 ? _weekdayLabels[day - 1] : '';

/// Parses a 'YYYY-MM-DD' wire date as a LOCAL calendar date (for display
/// formatting). Never use [DateTime.parse] on wire dates elsewhere — it
/// yields UTC for bare dates in some contexts and the display day can shift.
DateTime parseIsoLocalDate(String iso) {
  final p = iso.split('-').map(int.parse).toList();
  return DateTime(p[0], p[1], p[2]);
}
