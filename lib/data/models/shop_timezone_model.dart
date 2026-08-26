import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:maki_mobile_pos/domain/entities/shop_timezone_entity.dart';

/// Firestore mapping for the timezone keys of `settings/general`.
///
/// Reads are defensive: a missing doc, a missing key, a non-int value, or an
/// out-of-range offset all fall back to the default rather than throwing.
/// Getting this wrong would break the business day on every device, so the
/// safest possible value wins.
class ShopTimezoneModel {
  static const int _minOffset = -720;
  static const int _maxOffset = 840;

  final String timezoneId;
  final int offsetMinutes;

  const ShopTimezoneModel({
    required this.timezoneId,
    required this.offsetMinutes,
  });

  factory ShopTimezoneModel.fromMap(Map<String, dynamic>? map) {
    if (map == null) return _defaults;

    final rawId = map['timezoneId'];
    final rawOffset = map['tzOffsetMinutes'];

    final offset = rawOffset is int && rawOffset >= _minOffset && rawOffset <= _maxOffset
        ? rawOffset
        : ShopTimezoneEntity.defaults.offsetMinutes;
    final id = rawId is String && rawId.isNotEmpty
        ? rawId
        : ShopTimezoneEntity.defaults.timezoneId;

    return ShopTimezoneModel(timezoneId: id, offsetMinutes: offset);
  }

  factory ShopTimezoneModel.fromEntity(ShopTimezoneEntity e) =>
      ShopTimezoneModel(timezoneId: e.timezoneId, offsetMinutes: e.offsetMinutes);

  static ShopTimezoneModel get _defaults =>
      ShopTimezoneModel.fromEntity(ShopTimezoneEntity.defaults);

  /// Merge payload — `settings/general` is a shared bucket for future general
  /// settings, so this writes only the timezone keys plus audit fields.
  Map<String, dynamic> toMap({required String updatedBy}) => {
        'timezoneId': timezoneId,
        'tzOffsetMinutes': offsetMinutes,
        'updatedAt': FieldValue.serverTimestamp(),
        'updatedBy': updatedBy,
      };

  ShopTimezoneEntity toEntity() =>
      ShopTimezoneEntity(timezoneId: timezoneId, offsetMinutes: offsetMinutes);
}
