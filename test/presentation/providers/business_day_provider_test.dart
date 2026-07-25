import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maki_mobile_pos/presentation/providers/business_day_provider.dart';

/// Mutable clock so tests can move "now" forward without waiting on a
/// real [Timer] or the wall clock.
class _FakeClock {
  DateTime now;
  _FakeClock(this.now);
  DateTime call() => now;
}

void main() {
  late _FakeClock clock;

  ProviderContainer makeContainer() {
    final container = ProviderContainer(
      overrides: [
        nowProvider.overrideWithValue(clock.call),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  setUp(() {
    clock = _FakeClock(DateTime(2026, 7, 24, 14, 0));
  });

  test('initial state is the midnight-truncated fake now', () {
    final container = makeContainer();
    expect(container.read(businessDayProvider), DateTime(2026, 7, 24));
  });

  test('recheck after crossing midnight advances the business day', () {
    final container = makeContainer();
    expect(container.read(businessDayProvider), DateTime(2026, 7, 24));

    clock.now = DateTime(2026, 7, 25, 0, 30);
    container.read(businessDayProvider.notifier).recheck();

    expect(container.read(businessDayProvider), DateTime(2026, 7, 25));
  });

  test('recheck across a month boundary advances the business day', () {
    clock = _FakeClock(DateTime(2026, 7, 31, 23, 30));
    final container = makeContainer();
    expect(container.read(businessDayProvider), DateTime(2026, 7, 31));

    clock.now = DateTime(2026, 8, 1, 0, 5);
    container.read(businessDayProvider.notifier).recheck();

    expect(container.read(businessDayProvider), DateTime(2026, 8, 1));
  });

  test('recheck across a year boundary advances the business day', () {
    clock = _FakeClock(DateTime(2026, 12, 31, 23, 45));
    final container = makeContainer();
    expect(container.read(businessDayProvider), DateTime(2026, 12, 31));

    clock.now = DateTime(2027, 1, 1, 0, 1);
    container.read(businessDayProvider.notifier).recheck();

    expect(container.read(businessDayProvider), DateTime(2027, 1, 1));
  });

  test('same-day recheck is a no-op — no rebuild is emitted', () {
    final container = makeContainer();
    var notifications = 0;
    container.listen(
      businessDayProvider,
      (prev, next) => notifications++,
      fireImmediately: false,
    );

    // Still July 24, just later in the day.
    clock.now = DateTime(2026, 7, 24, 20, 0);
    container.read(businessDayProvider.notifier).recheck();

    expect(container.read(businessDayProvider), DateTime(2026, 7, 24));
    expect(notifications, 0);
  });
}
