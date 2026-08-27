// Shop-timezone helpers — the TypeScript half of lib/core/utils/shop_time.dart.
//
// The shop runs on one configured timezone (settings/general, default
// Asia/Manila UTC+8). Every calendar computation — "what day is it", range
// boundaries, day grouping — uses that zone rather than the browser's, so a
// laptop set to another timezone still agrees with the mobile app and with
// the Firestore rules' phDay().
//
// Two representations, kept strictly apart:
//   * instant — a real point in time. What Firestore stores. Never shifted
//     before writing.
//   * shop wall time — an instant shifted by the shop offset so its UTC
//     getters read shop-local. For day math and display only; convert back
//     with instantOf() before using it as a query bound.
//
// Only fixed-offset (no-DST) zones are supported, so plain offset arithmetic
// is exact. Do NOT use date-fns' startOfDay/endOfDay on wall values — they
// read local getters and would double-shift.

export const DEFAULT_SHOP_OFFSET_MINUTES = 480;
export const DEFAULT_SHOP_TIMEZONE_ID = 'Asia/Manila';

export interface ShopTimezone {
  timezoneId: string;
  offsetMinutes: number;
}

const MINUTE_MS = 60_000;

let ambient: ShopTimezone = {
  timezoneId: DEFAULT_SHOP_TIMEZONE_ID,
  offsetMinutes: DEFAULT_SHOP_OFFSET_MINUTES,
};

/** Set from the settings doc at bootstrap and on every change. */
export function setAmbientShopTimezone(tz: ShopTimezone): void {
  ambient = tz;
}

export function getAmbientShopTimezone(): ShopTimezone {
  return ambient;
}

export function shopOffsetMinutes(): number {
  return ambient.offsetMinutes;
}

/** Shop wall-clock view of `instant`. Read it with getUTC*. Do not persist. */
export function shopTimeOf(instant: Date, offsetMinutes = shopOffsetMinutes()): Date {
  return new Date(instant.getTime() + offsetMinutes * MINUTE_MS);
}

/** The real instant for a shop wall-clock value — inverse of shopTimeOf. */
export function instantOf(wall: Date, offsetMinutes = shopOffsetMinutes()): Date {
  return new Date(wall.getTime() - offsetMinutes * MINUTE_MS);
}

/** Builds a shop wall-clock value from calendar fields (month is 1-based). */
export function shopWall(
  year: number,
  month: number,
  day: number,
  hour = 0,
  minute = 0,
  second = 0,
  ms = 0,
): Date {
  return new Date(Date.UTC(year, month - 1, day, hour, minute, second, ms));
}

/** yyyymmdd int in shop time — must equal the rules' phDay(). */
export function shopDayInt(instant: Date, offsetMinutes = shopOffsetMinutes()): number {
  const w = shopTimeOf(instant, offsetMinutes);
  return w.getUTCFullYear() * 10000 + (w.getUTCMonth() + 1) * 100 + w.getUTCDate();
}

/** Instant of shop midnight for the shop day containing `instant`. */
export function shopStartOfDay(instant: Date, offsetMinutes = shopOffsetMinutes()): Date {
  const w = shopTimeOf(instant, offsetMinutes);
  return instantOf(
    shopWall(w.getUTCFullYear(), w.getUTCMonth() + 1, w.getUTCDate()),
    offsetMinutes,
  );
}

/** Instant of the last millisecond of that shop day. */
export function shopEndOfDay(instant: Date, offsetMinutes = shopOffsetMinutes()): Date {
  const w = shopTimeOf(instant, offsetMinutes);
  return instantOf(
    shopWall(w.getUTCFullYear(), w.getUTCMonth() + 1, w.getUTCDate(), 23, 59, 59, 999),
    offsetMinutes,
  );
}

/** YYYYMMDD in shop time — the sale-counter key. */
export function shopDateKey(instant: Date, offsetMinutes = shopOffsetMinutes()): string {
  return `${shopDayInt(instant, offsetMinutes)}`;
}

/** yyyy-MM-dd in shop time — closing doc ids, pay-period dates. */
export function shopIsoDate(instant: Date, offsetMinutes = shopOffsetMinutes()): string {
  const w = shopTimeOf(instant, offsetMinutes);
  const y = w.getUTCFullYear();
  const m = `${w.getUTCMonth() + 1}`.padStart(2, '0');
  const d = `${w.getUTCDate()}`.padStart(2, '0');
  return `${y}-${m}-${d}`;
}

/** Formats an instant for display in the shop's zone. */
export function formatInShopZone(
  instant: Date,
  options: Intl.DateTimeFormatOptions,
  timezoneId = ambient.timezoneId,
): string {
  return new Intl.DateTimeFormat('en-PH', { ...options, timeZone: timezoneId }).format(instant);
}
