// Curated shop-timezone catalog.
//
// MIRRORED in lib/core/utils/shop_timezones.dart — keep ids, labels, offsets
// and order in lock-step across both surfaces.
//
// Only fixed-offset (no-DST) zones are listed: the offset is stored in
// settings/general.tzOffsetMinutes and read by the Firestore rules, which
// have no timezone database and cannot follow a DST transition.

import { DEFAULT_SHOP_TIMEZONE_ID } from './shopTime';

export interface ShopTimezoneOption {
  /** IANA name, e.g. 'Asia/Manila'. */
  id: string;
  /** What the picker shows. */
  label: string;
  offsetMinutes: number;
}

export const SHOP_TIMEZONES: readonly ShopTimezoneOption[] = [
  { id: 'Asia/Manila', label: 'Philippines (Manila)', offsetMinutes: 480 },
  { id: 'Asia/Singapore', label: 'Singapore', offsetMinutes: 480 },
  { id: 'Asia/Hong_Kong', label: 'Hong Kong', offsetMinutes: 480 },
  { id: 'Asia/Shanghai', label: 'China (Shanghai)', offsetMinutes: 480 },
  { id: 'Asia/Kuala_Lumpur', label: 'Malaysia (Kuala Lumpur)', offsetMinutes: 480 },
  { id: 'Asia/Tokyo', label: 'Japan (Tokyo)', offsetMinutes: 540 },
  { id: 'Asia/Seoul', label: 'South Korea (Seoul)', offsetMinutes: 540 },
  { id: 'Asia/Bangkok', label: 'Thailand (Bangkok)', offsetMinutes: 420 },
  { id: 'Asia/Jakarta', label: 'Indonesia (Jakarta)', offsetMinutes: 420 },
  { id: 'Asia/Ho_Chi_Minh', label: 'Vietnam (Ho Chi Minh)', offsetMinutes: 420 },
  { id: 'Asia/Kolkata', label: 'India (Kolkata)', offsetMinutes: 330 },
  { id: 'Asia/Dubai', label: 'UAE (Dubai)', offsetMinutes: 240 },
  { id: 'Australia/Brisbane', label: 'Australia (Brisbane)', offsetMinutes: 600 },
  { id: 'Pacific/Guam', label: 'Guam', offsetMinutes: 600 },
  { id: 'UTC', label: 'UTC', offsetMinutes: 0 },
];

/**
 * The catalog entry for `id`, or undefined when the stored id is unknown
 * (e.g. written by a newer client). Callers fall back to the stored offset,
 * never to the browser zone.
 */
export function shopTimezoneById(id: string): ShopTimezoneOption | undefined {
  return SHOP_TIMEZONES.find((tz) => tz.id === id);
}

/** '+08:00' / '-05:00' — for the picker subtitle. */
export function formatOffset(offsetMinutes: number): string {
  const sign = offsetMinutes < 0 ? '-' : '+';
  const abs = Math.abs(offsetMinutes);
  const h = `${Math.floor(abs / 60)}`.padStart(2, '0');
  const m = `${abs % 60}`.padStart(2, '0');
  return `${sign}${h}:${m}`;
}

/** The default option, guaranteed present. */
export const DEFAULT_SHOP_TIMEZONE = shopTimezoneById(
  DEFAULT_SHOP_TIMEZONE_ID,
) as ShopTimezoneOption;
