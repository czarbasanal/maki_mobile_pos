import 'package:flutter_test/flutter_test.dart';
import 'package:maki_mobile_pos/domain/entities/entities.dart';
import 'package:maki_mobile_pos/presentation/providers/activity_log_provider.dart';

void main() {
  test('two identical selections compare equal and hash alike', () {
    final a = ActivityLogParams(
      types: const [ActivityType.sale, ActivityType.login],
      startDate: DateTime(2026, 7, 28),
      endDate: DateTime(2026, 7, 28, 23, 59, 59, 999),
    );
    final b = ActivityLogParams(
      types: const [ActivityType.sale, ActivityType.login],
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
