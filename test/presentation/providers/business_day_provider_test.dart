import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maki_mobile_pos/core/utils/shop_time.dart';
import 'package:maki_mobile_pos/presentation/providers/business_day_provider.dart';
import 'package:maki_mobile_pos/presentation/providers/shop_time_provider.dart';

/// Mutable clock so tests can move "now" forward without waiting on a
/// real [Timer] or the wall clock. It returns real **instants** — the
/// provider does the shop-time conversion — so these tests give the same
/// answer on a machine in any timezone.
class _FakeClock {
  DateTime now;
  _FakeClock(this.now);
  DateTime call() => now;
}

/// The instant at which the shop clock reads the given wall time.
DateTime atShop(int y, int mo, int d, [int h = 0, int mi = 0]) =>
    instantOf(shopWall(y, mo, d, h, mi), kDefaultShopOffsetMinutes);

void main() {
  late _FakeClock clock;

  ProviderContainer makeContainer({int offset = kDefaultShopOffsetMinutes}) {
    final container = ProviderContainer(
      overrides: [
        nowProvider.overrideWithValue(clock.call),
        shopOffsetProvider.overrideWithValue(offset),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  setUp(() {
    clock = _FakeClock(atShop(2026, 7, 24, 14, 0));
  });

  test('initial state is the shop-midnight-truncated fake now', () {
    final container = makeContainer();
    expect(container.read(businessDayProvider), shopWall(2026, 7, 24));
  });

  test('recheck after crossing shop midnight advances the business day', () {
    final container = makeContainer();
    expect(container.read(businessDayProvider), shopWall(2026, 7, 24));

    clock.now = atShop(2026, 7, 25, 0, 30);
    container.read(businessDayProvider.notifier).recheck();

    expect(container.read(businessDayProvider), shopWall(2026, 7, 25));
  });

  test('recheck across a month boundary advances the business day', () {
    clock = _FakeClock(atShop(2026, 7, 31, 23, 30));
    final container = makeContainer();
    expect(container.read(businessDayProvider), shopWall(2026, 7, 31));

    clock.now = atShop(2026, 8, 1, 0, 5);
    container.read(businessDayProvider.notifier).recheck();

    expect(container.read(businessDayProvider), shopWall(2026, 8, 1));
  });

  test('recheck across a year boundary advances the business day', () {
    clock = _FakeClock(atShop(2026, 12, 31, 23, 45));
    final container = makeContainer();
    expect(container.read(businessDayProvider), shopWall(2026, 12, 31));

    clock.now = atShop(2027, 1, 1, 0, 1);
    container.read(businessDayProvider.notifier).recheck();

    expect(container.read(businessDayProvider), shopWall(2027, 1, 1));
  });

  test('same-day recheck is a no-op — no rebuild is emitted', () {
    final container = makeContainer();
    var notifications = 0;
    container.listen(
      businessDayProvider,
      (prev, next) => notifications++,
      fireImmediately: false,
    );

    // Still July 24 in shop time, just later in the day.
    clock.now = atShop(2026, 7, 24, 20, 0);
    container.read(businessDayProvider.notifier).recheck();

    expect(container.read(businessDayProvider), shopWall(2026, 7, 24));
    expect(notifications, 0);
  });

  test('the day follows the SHOP offset, not the device zone', () {
    // 2026-07-24 16:30 UTC is already July 25 at +480 but still July 24
    // at -300. Same instant, two shops, two business days.
    clock = _FakeClock(DateTime.utc(2026, 7, 24, 16, 30));

    expect(makeContainer().read(businessDayProvider), shopWall(2026, 7, 25));
    expect(
      makeContainer(offset: -300).read(businessDayProvider),
      shopWall(2026, 7, 24),
    );
  });
}
