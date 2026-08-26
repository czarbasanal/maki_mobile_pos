import 'package:equatable/equatable.dart';
import 'package:maki_mobile_pos/core/utils/shop_time.dart';

/// The shop-wide timezone (the `timezoneId` / `tzOffsetMinutes` keys of the
/// shared `settings/general` doc). A missing doc reads as [defaults], which
/// is also what the Firestore rules fall back to — so an unseeded database
/// behaves exactly like the pre-feature system.
class ShopTimezoneEntity extends Equatable {
  /// IANA name, for display and for the picker.
  final String timezoneId;

  /// Minutes east of UTC. The value all day math and the rules use.
  final int offsetMinutes;

  const ShopTimezoneEntity({
    required this.timezoneId,
    required this.offsetMinutes,
  });

  static const defaults = ShopTimezoneEntity(
    timezoneId: kDefaultShopTimezoneId,
    offsetMinutes: kDefaultShopOffsetMinutes,
  );

  ShopTimezoneEntity copyWith({String? timezoneId, int? offsetMinutes}) =>
      ShopTimezoneEntity(
        timezoneId: timezoneId ?? this.timezoneId,
        offsetMinutes: offsetMinutes ?? this.offsetMinutes,
      );

  @override
  List<Object?> get props => [timezoneId, offsetMinutes];
}
