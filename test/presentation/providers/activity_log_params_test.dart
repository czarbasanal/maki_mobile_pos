import 'package:flutter_test/flutter_test.dart';
import 'package:maki_mobile_pos/domain/entities/entities.dart';
import 'package:maki_mobile_pos/presentation/providers/activity_log_provider.dart';

void main() {
  test('two identical selections compare equal and hash alike', () {
    // Production never hands us a canonicalized const list: the operations
    // picker rebuilds a fresh one on every chip tap via
    // `ActivityType.values.where(...).toList(growable: false)`. Build one
    // side that way and leave the other a const literal, so the two lists
    // are equal in content but NOT the same instance — the only shape that
    // actually exercises the element-wise comparison.
    final picked = ActivityType.values
        .where({ActivityType.sale, ActivityType.login}.contains)
        .toList(growable: false);
    const literal = [ActivityType.login, ActivityType.sale];
    expect(identical(picked, literal), isFalse,
        reason: 'the two lists must be distinct instances or this test '
            'proves nothing about list-aware equality');

    final a = ActivityLogParams(
      types: picked,
      startDate: DateTime(2026, 7, 28),
      endDate: DateTime(2026, 7, 28, 23, 59, 59, 999),
    );
    final b = ActivityLogParams(
      types: literal,
      startDate: DateTime(2026, 7, 28),
      endDate: DateTime(2026, 7, 28, 23, 59, 59, 999),
    );

    expect(a, b);
    expect(a.hashCode, b.hashCode);
  });

  test('a different type selection is not equal', () {
    const a = ActivityLogParams(types: [ActivityType.sale]);
    const b = ActivityLogParams(types: [ActivityType.login]);

    expect(a, isNot(b));
  });

  test('a different window is not equal', () {
    final a = ActivityLogParams(startDate: DateTime(2026, 7, 28));
    final b = ActivityLogParams(startDate: DateTime(2026, 7, 27));

    expect(a, isNot(b));
  });

  test('the default limit is the search cap', () {
    const params = ActivityLogParams();
    expect(params.limit, kActivityLogSearchLimit);
    expect(kActivityLogSearchLimit, 500);
  });
}
