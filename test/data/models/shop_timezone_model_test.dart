import 'package:flutter_test/flutter_test.dart';
import 'package:maki_mobile_pos/data/models/shop_timezone_model.dart';
import 'package:maki_mobile_pos/domain/entities/shop_timezone_entity.dart';

void main() {
  group('ShopTimezoneEntity.defaults', () {
    test('is Asia/Manila at +480', () {
      expect(ShopTimezoneEntity.defaults.timezoneId, 'Asia/Manila');
      expect(ShopTimezoneEntity.defaults.offsetMinutes, 480);
    });
  });

  group('ShopTimezoneModel.fromMap', () {
    test('a missing doc reads as the defaults', () {
      expect(ShopTimezoneModel.fromMap(null).toEntity(), ShopTimezoneEntity.defaults);
    });

    test('an empty doc reads as the defaults', () {
      expect(ShopTimezoneModel.fromMap(const {}).toEntity(), ShopTimezoneEntity.defaults);
    });

    test('reads a stored timezone', () {
      final e = ShopTimezoneModel.fromMap(const {
        'timezoneId': 'Asia/Tokyo',
        'tzOffsetMinutes': 540,
      }).toEntity();
      expect(e.timezoneId, 'Asia/Tokyo');
      expect(e.offsetMinutes, 540);
    });

    test('ignores unrelated keys in the shared general doc', () {
      final e = ShopTimezoneModel.fromMap(const {
        'timezoneId': 'Asia/Dubai',
        'tzOffsetMinutes': 240,
        'someOtherGeneralSetting': true,
      }).toEntity();
      expect(e.offsetMinutes, 240);
    });

    test('falls back to the default offset when the value is out of range', () {
      final e = ShopTimezoneModel.fromMap(const {
        'timezoneId': 'Bad/Zone',
        'tzOffsetMinutes': 99999,
      }).toEntity();
      expect(e.offsetMinutes, 480);
    });

    test('falls back to the default offset when the value is not an int', () {
      final e = ShopTimezoneModel.fromMap(const {
        'timezoneId': 'Asia/Manila',
        'tzOffsetMinutes': 'eight',
      }).toEntity();
      expect(e.offsetMinutes, 480);
    });
  });

  group('ShopTimezoneModel.toMap', () {
    test('writes both fields plus audit keys', () {
      final map = ShopTimezoneModel.fromEntity(
        const ShopTimezoneEntity(timezoneId: 'Asia/Tokyo', offsetMinutes: 540),
      ).toMap(updatedBy: 'uid-1');
      expect(map['timezoneId'], 'Asia/Tokyo');
      expect(map['tzOffsetMinutes'], 540);
      expect(map['updatedBy'], 'uid-1');
      expect(map.containsKey('updatedAt'), isTrue);
    });
  });
}
