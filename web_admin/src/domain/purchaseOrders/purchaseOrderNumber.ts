import { shopDateKey, shopOffsetMinutes } from '@/domain/time/shopTime';

/**
 * Human purchase-order number: `PO-YYYYMMDD-NNN`, matching the format mobile
 * writes so the two surfaces produce one series.
 *
 * The sequence comes from a counter document allocated inside the create
 * transaction — NOT from counting today's orders, which is how mobile does it
 * and how receivings do it. Counting means two clients creating an order in
 * the same moment get the same number, and creating several at once makes that
 * likely rather than theoretical.
 *
 * The key is in SHOP time: a browser-local one would roll a day early or late
 * and restart the series mid-afternoon.
 */
export function purchaseOrderCounterKey(
  date: Date,
  offsetMinutes: number = shopOffsetMinutes(),
): string {
  return shopDateKey(date, offsetMinutes);
}

export function formatPurchaseOrderNumber(
  date: Date,
  seq: number,
  offsetMinutes: number = shopOffsetMinutes(),
): string {
  return `PO-${purchaseOrderCounterKey(date, offsetMinutes)}-${`${seq}`.padStart(3, '0')}`;
}
