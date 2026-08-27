import { shopDateKey, shopOffsetMinutes } from '@/domain/time/shopTime';

/**
 * YYYYMMDD key for the daily sale counter (settings/sale_counters), in SHOP
 * time. This runs inside the same transaction whose drawer_state write the
 * rules check against phDay() — a browser-local key could disagree by a day.
 */
export function counterKey(date: Date, offsetMinutes: number = shopOffsetMinutes()): string {
  return shopDateKey(date, offsetMinutes);
}

/** Human sale number: SALE-YYYYMMDD-NNN (sequence zero-padded to >= 3). */
export function formatSaleNumber(
  date: Date,
  seq: number,
  offsetMinutes: number = shopOffsetMinutes(),
): string {
  return `SALE-${counterKey(date, offsetMinutes)}-${`${seq}`.padStart(3, '0')}`;
}
