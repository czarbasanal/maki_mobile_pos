// Hourly sales bucketing for the dashboard chart (spec §5.2). Pure; hours
// are SHOP-WALL hours via shopTimeOf, so a shift's buckets don't drift with
// the viewer's device timezone.
import { saleGrandTotal, saleIsVoided, type Sale } from '../entities';
import { shopTimeOf } from '../time/shopTime';

export interface HourBucket {
  hour: number; // 0–23, shop wall clock
  count: number;
  gross: number;
}

export const DEFAULT_OPEN_HOUR = 8;
export const DEFAULT_CLOSE_HOUR = 20;

export function bucketSalesByHour(sales: Sale[]): HourBucket[] {
  const byHour = new Map<number, { count: number; gross: number }>();
  for (const sale of sales) {
    if (saleIsVoided(sale)) continue;
    const hour = shopTimeOf(sale.createdAt).getUTCHours();
    const bucket = byHour.get(hour) ?? { count: 0, gross: 0 };
    bucket.count += 1;
    bucket.gross += saleGrandTotal(sale);
    byHour.set(hour, bucket);
  }
  const hours = [...byHour.keys()];
  const first = Math.min(DEFAULT_OPEN_HOUR, ...hours);
  const last = Math.max(DEFAULT_CLOSE_HOUR, ...hours);
  const buckets: HourBucket[] = [];
  for (let hour = first; hour <= last; hour++) {
    buckets.push({ hour, ...(byHour.get(hour) ?? { count: 0, gross: 0 }) });
  }
  return buckets;
}

export function peakHour(buckets: HourBucket[]): number | null {
  let best: HourBucket | null = null;
  for (const bucket of buckets) {
    if (bucket.count > 0 && (best === null || bucket.count > best.count)) best = bucket;
  }
  return best ? best.hour : null;
}

export function formatHourLabel(hour: number, withMinutes = false): string {
  const h12 = hour % 12 === 0 ? 12 : hour % 12;
  const suffix = hour < 12 ? 'AM' : 'PM';
  return withMinutes ? `${h12}:00 ${suffix}` : `${h12} ${suffix}`;
}
