import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maki_mobile_pos/core/utils/shop_time.dart';
import 'package:maki_mobile_pos/domain/entities/shop_timezone_entity.dart';
import 'package:maki_mobile_pos/domain/repositories/shop_timezone_repository.dart';
import 'package:maki_mobile_pos/presentation/providers/shop_time_provider.dart';

class _FakeRepo implements ShopTimezoneRepository {
  _FakeRepo(this.controller);
  final Stream<ShopTimezoneEntity> controller;

  @override
  Stream<ShopTimezoneEntity> watch() => controller;

  @override
  Future<ShopTimezoneEntity> get() async => ShopTimezoneEntity.defaults;

  @override
  Future<void> save(ShopTimezoneEntity settings, {required String updatedBy}) async {}
}

void main() {
  setUp(() {
    ShopTimeConfig.apply(
      timezoneId: kDefaultShopTimezoneId,
      offsetMinutes: kDefaultShopOffsetMinutes,
    );
  });

  ProviderContainer containerWith(
    Stream<ShopTimezoneEntity> stream, {
    DateTime? fixedNow,
  }) {
    return ProviderContainer(
      overrides: [
        shopTimezoneRepositoryProvider.overrideWithValue(_FakeRepo(stream)),
        if (fixedNow != null) nowProvider.overrideWithValue(() => fixedNow),
      ],
    );
  }

  test('shopOffsetProvider falls back to the default before data arrives', () {
    final c = containerWith(const Stream<ShopTimezoneEntity>.empty());
    addTearDown(c.dispose);
    expect(c.read(shopOffsetProvider), 480);
  });

  test('shopOffsetProvider reflects the stored timezone', () async {
    final c = containerWith(
      Stream.value(const ShopTimezoneEntity(timezoneId: 'Asia/Tokyo', offsetMinutes: 540)),
    );
    addTearDown(c.dispose);
    await c.read(shopTimezoneProvider.future);
    expect(c.read(shopOffsetProvider), 540);
  });

  test('a stored timezone updates the ambient config', () async {
    final c = containerWith(
      Stream.value(const ShopTimezoneEntity(timezoneId: 'Asia/Tokyo', offsetMinutes: 540)),
    );
    addTearDown(c.dispose);
    await c.read(shopTimezoneProvider.future);
    expect(ShopTimeConfig.offsetMinutes, 540);
    expect(ShopTimeConfig.timezoneId, 'Asia/Tokyo');
  });

  test('shopNowProvider returns shop wall time, not the device instant', () async {
    final instant = DateTime.utc(2026, 8, 26, 15, 30);
    final c = containerWith(
      Stream.value(const ShopTimezoneEntity(timezoneId: 'Asia/Manila', offsetMinutes: 480)),
      fixedNow: instant,
    );
    addTearDown(c.dispose);
    await c.read(shopTimezoneProvider.future);

    final wall = c.read(shopNowProvider)();
    expect(wall.day, 26);
    expect(wall.hour, 23);
    expect(c.read(shopInstantNowProvider)(), instant);
  });
}
