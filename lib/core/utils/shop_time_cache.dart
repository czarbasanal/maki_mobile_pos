import 'package:maki_mobile_pos/core/utils/shop_time.dart';
import 'package:maki_mobile_pos/domain/entities/shop_timezone_entity.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Last-known shop timezone, persisted so a cold start (especially an
/// offline one) is already on shop time before the Firestore stream
/// delivers its first snapshot. Without this the first frames would compute
/// "today" from the default, which is wrong for a shop that changed zones.
class ShopTimeCache {
  ShopTimeCache._();

  static const _idKey = 'shop_timezone_id';
  static const _offsetKey = 'shop_timezone_offset_minutes';

  /// Applies the cached timezone to [ShopTimeConfig]. Never throws —
  /// a failure here must not block app startup.
  static Future<void> restore() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final id = prefs.getString(_idKey);
      final offset = prefs.getInt(_offsetKey);
      if (id != null && offset != null) {
        ShopTimeConfig.apply(timezoneId: id, offsetMinutes: offset);
      }
    } catch (_) {
      // Keep the default; the Firestore stream corrects it shortly.
    }
  }

  static Future<void> save(ShopTimezoneEntity tz) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_idKey, tz.timezoneId);
      await prefs.setInt(_offsetKey, tz.offsetMinutes);
    } catch (_) {
      // Caching is best-effort.
    }
  }
}
