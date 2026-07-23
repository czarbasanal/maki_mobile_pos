import 'package:flutter_test/flutter_test.dart';
import 'package:maki_mobile_pos/core/utils/job_order_number.dart';

void main() {
  final jul23 = DateTime(2026, 7, 23, 14, 30);

  group('jobOrderPrefixFor', () {
    test('formats as JO-MMDDYY-', () {
      expect(jobOrderPrefixFor(jul23), 'JO-072326-');
      expect(jobOrderPrefixFor(DateTime(2027, 1, 5)), 'JO-010527-');
    });
  });

  group('nextJobOrderNumber', () {
    test('starts at 001 when no job orders exist for the day', () {
      expect(nextJobOrderNumber(jul23, const []), 'JO-072326-001');
    });

    test('increments past the highest sequence for today', () {
      expect(
        nextJobOrderNumber(jul23, const [
          'JO-072326-001',
          'JO-072326-003', // gap: 002 was deleted — never reuse
          'Juan / ABC-123', // legacy customer/plate names ignored
          'JO-072226-009', // yesterday's numbering ignored
        ]),
        'JO-072326-004',
      );
    });

    test('grows past 999 without truncating', () {
      expect(
        nextJobOrderNumber(jul23, const ['JO-072326-999']),
        'JO-072326-1000',
      );
    });

    test('ignores malformed suffixes on today\'s prefix', () {
      expect(
        nextJobOrderNumber(jul23, const ['JO-072326-abc', 'JO-072326-']),
        'JO-072326-001',
      );
    });
  });
}
