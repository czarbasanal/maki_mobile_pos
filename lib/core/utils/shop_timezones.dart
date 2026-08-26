import 'package:maki_mobile_pos/core/utils/shop_time.dart';

/// One selectable shop timezone.
///
/// Only fixed-offset (no-DST) zones are listed: the offset is stored in
/// `settings/general.tzOffsetMinutes` and read by the Firestore rules,
/// which have no timezone database and cannot follow a DST transition.
class ShopTimezoneOption {
  final String id; // IANA name, e.g. 'Asia/Manila'
  final String label; // What the picker shows
  final int offsetMinutes;

  const ShopTimezoneOption({
    required this.id,
    required this.label,
    required this.offsetMinutes,
  });
}

/// Curated catalog. MIRRORED in web_admin/src/domain/time/shopTimezones.ts —
/// keep ids and offsets in lock-step across both surfaces.
const List<ShopTimezoneOption> kShopTimezones = [
  ShopTimezoneOption(id: 'Asia/Manila', label: 'Philippines (Manila)', offsetMinutes: 480),
  ShopTimezoneOption(id: 'Asia/Singapore', label: 'Singapore', offsetMinutes: 480),
  ShopTimezoneOption(id: 'Asia/Hong_Kong', label: 'Hong Kong', offsetMinutes: 480),
  ShopTimezoneOption(id: 'Asia/Shanghai', label: 'China (Shanghai)', offsetMinutes: 480),
  ShopTimezoneOption(id: 'Asia/Kuala_Lumpur', label: 'Malaysia (Kuala Lumpur)', offsetMinutes: 480),
  ShopTimezoneOption(id: 'Asia/Tokyo', label: 'Japan (Tokyo)', offsetMinutes: 540),
  ShopTimezoneOption(id: 'Asia/Seoul', label: 'South Korea (Seoul)', offsetMinutes: 540),
  ShopTimezoneOption(id: 'Asia/Bangkok', label: 'Thailand (Bangkok)', offsetMinutes: 420),
  ShopTimezoneOption(id: 'Asia/Jakarta', label: 'Indonesia (Jakarta)', offsetMinutes: 420),
  ShopTimezoneOption(id: 'Asia/Ho_Chi_Minh', label: 'Vietnam (Ho Chi Minh)', offsetMinutes: 420),
  ShopTimezoneOption(id: 'Asia/Kolkata', label: 'India (Kolkata)', offsetMinutes: 330),
  ShopTimezoneOption(id: 'Asia/Dubai', label: 'UAE (Dubai)', offsetMinutes: 240),
  ShopTimezoneOption(id: 'Australia/Brisbane', label: 'Australia (Brisbane)', offsetMinutes: 600),
  ShopTimezoneOption(id: 'Pacific/Guam', label: 'Guam', offsetMinutes: 600),
  ShopTimezoneOption(id: 'UTC', label: 'UTC', offsetMinutes: 0),
];

/// The catalog entry for [id], or null when the stored id is unknown
/// (e.g. written by a newer client). Callers fall back to the stored
/// offset, never to the device zone.
ShopTimezoneOption? shopTimezoneById(String id) {
  for (final tz in kShopTimezones) {
    if (tz.id == id) return tz;
  }
  return null;
}

/// '+08:00' / '-05:00' — for the picker subtitle.
String formatOffset(int offsetMinutes) {
  final sign = offsetMinutes < 0 ? '-' : '+';
  final abs = offsetMinutes.abs();
  final h = (abs ~/ 60).toString().padLeft(2, '0');
  final m = (abs % 60).toString().padLeft(2, '0');
  return '$sign$h:$m';
}

/// The default option, guaranteed present.
ShopTimezoneOption get defaultShopTimezone =>
    shopTimezoneById(kDefaultShopTimezoneId)!;
