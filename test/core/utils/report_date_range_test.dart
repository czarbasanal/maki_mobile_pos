import 'package:flutter_test/flutter_test.dart';
import 'package:maki_mobile_pos/core/utils/report_date_range.dart';
import 'package:maki_mobile_pos/presentation/mobile/widgets/reports/date_range_picker.dart';

void main() {
  final now = DateTime(2026, 7, 1, 14, 30); // fixed anchor

  test('today = midnight..23:59:59 same day', () {
    final r = dateRangeForPreset(DateRangePreset.today, now);
    expect(r.start, DateTime(2026, 7, 1));
    expect(r.end, DateTime(2026, 7, 1, 23, 59, 59));
  });

  test('yesterday = the prior day', () {
    final r = dateRangeForPreset(DateRangePreset.yesterday, now);
    expect(r.start, DateTime(2026, 6, 30));
    expect(r.end, DateTime(2026, 6, 30, 23, 59, 59));
  });

  test('thisWeek starts on a Monday on/before now', () {
    final r = dateRangeForPreset(DateRangePreset.thisWeek, now);
    expect(r.start.weekday, DateTime.monday);
    expect(r.start.isAfter(now), isFalse);
    expect(now.difference(r.start).inDays, lessThan(7));
  });

  test('thisMonth starts on the 1st', () {
    final r = dateRangeForPreset(DateRangePreset.thisMonth, now);
    expect(r.start, DateTime(2026, 7, 1));
  });

  test('lastMonth spans the whole previous month', () {
    final r = dateRangeForPreset(DateRangePreset.lastMonth, now);
    expect(r.start, DateTime(2026, 6, 1));
    expect(r.end, DateTime(2026, 6, 30, 23, 59, 59));
  });

  test('thisQuarter: July is Q3 -> starts July 1', () {
    final r = dateRangeForPreset(DateRangePreset.thisQuarter, now);
    expect(r.start, DateTime(2026, 7, 1));
  });

  test('thisYear starts Jan 1', () {
    final r = dateRangeForPreset(DateRangePreset.thisYear, now);
    expect(r.start, DateTime(2026, 1, 1));
  });

  test('custom falls back to today', () {
    final r = dateRangeForPreset(DateRangePreset.custom, now);
    expect(r.start, DateTime(2026, 7, 1));
  });
}
