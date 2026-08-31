import 'package:flutter_test/flutter_test.dart';
import 'package:maki_mobile_pos/core/utils/shop_time.dart';

/// `closedAt` is a real instant (`DateTime.now()` at close, `Timestamp.toDate()`
/// on read, which returns a device-LOCAL DateTime). Formatting it directly
/// renders the handset's clock, not the shop's — right only by coincidence on
/// a phone that happens to sit in the shop's timezone, which is the very
/// assumption the shop-timezone feature exists to remove.
void main() {
  const phOffset = 480; // UTC+8

  test('a day closed at 9:24 PM shop time reads 21:24 whatever the device',
      () {
    // 2026-08-30 21:24 PH == 13:24Z.
    final instant = DateTime.utc(2026, 8, 30, 13, 24);

    final shop = shopTimeOf(instant, phOffset);
    expect(shop.hour, 21);
    expect(shop.minute, 24);
    expect(shop.day, 30);
  });

  test('a close just before shop midnight keeps its own date', () {
    // 23:50 PH on the 30th == 15:50Z on the 30th.
    final instant = DateTime.utc(2026, 8, 30, 15, 50);
    final shop = shopTimeOf(instant, phOffset);

    expect(shop.day, 30);
    expect(shop.hour, 23);
  });

  test('a close just after shop midnight belongs to the next date', () {
    // 00:10 PH on the 31st == 16:10Z on the 30th. A device on UTC+2 would
    // render this as 18:10 on the 30th — a different day AND a different time.
    final instant = DateTime.utc(2026, 8, 30, 16, 10);
    final shop = shopTimeOf(instant, phOffset);

    expect(shop.day, 31);
    expect(shop.hour, 0);
    expect(shop.minute, 10);
  });
}
