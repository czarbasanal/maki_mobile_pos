import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:maki_mobile_pos/core/utils/shop_time.dart';
import 'package:maki_mobile_pos/core/utils/shop_time_cache.dart';
import 'package:maki_mobile_pos/data/repositories/shop_timezone_repository_impl.dart';
import 'package:maki_mobile_pos/domain/entities/shop_timezone_entity.dart';
import 'package:maki_mobile_pos/domain/repositories/shop_timezone_repository.dart';

/// Injectable clock (override in tests). Returns a real instant — shop-time
/// conversion happens downstream, so nothing here depends on the device zone.
final nowProvider = Provider<DateTime Function()>((ref) => DateTime.now);

final shopTimezoneRepositoryProvider = Provider<ShopTimezoneRepository>(
  (ref) => ShopTimezoneRepositoryImpl(),
);

/// Live shop timezone. Applying it to [ShopTimeConfig] here (rather than in
/// a widget) means extension getters and formatting helpers — which have no
/// `ref` — see the change at the same moment provider consumers do.
final shopTimezoneProvider = StreamProvider<ShopTimezoneEntity>((ref) {
  return ref.watch(shopTimezoneRepositoryProvider).watch().map((tz) {
    ShopTimeConfig.apply(
      timezoneId: tz.timezoneId,
      offsetMinutes: tz.offsetMinutes,
    );
    ShopTimeCache.save(tz);
    return tz;
  });
});

/// Offset in minutes east of UTC. Falls back to the ambient value (cache or
/// default) while the stream is loading or if it errors — never to the
/// device zone.
final shopOffsetProvider = Provider<int>((ref) {
  return ref.watch(shopTimezoneProvider).maybeWhen(
        data: (tz) => tz.offsetMinutes,
        orElse: () => ShopTimeConfig.offsetMinutes,
      );
});

/// "Now" as a shop **wall-clock** value — for day math and display.
/// Never persist its result; use [shopInstantNowProvider] for writes.
final shopNowProvider = Provider<DateTime Function()>((ref) {
  final now = ref.watch(nowProvider);
  final offset = ref.watch(shopOffsetProvider);
  return () => shopTimeOf(now(), offset);
});

/// "Now" as a real instant — for `createdAt` and query bounds.
final shopInstantNowProvider = Provider<DateTime Function()>((ref) {
  return ref.watch(nowProvider);
});
