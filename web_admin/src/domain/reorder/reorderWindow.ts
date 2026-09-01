import { subDays } from 'date-fns';
import { shopEndOfDay, shopStartOfDay } from '@/domain/time/shopTime';

/**
 * Sales window for reorder velocity: `windowDays` complete days ending
 * yesterday. Today's partial day is excluded so it never dilutes velocity
 * (parity with the mobile purchase-order window).
 */
export function reorderWindow(
  now: Date,
  windowDays: number,
): { start: Date; end: Date } {
  return {
    start: shopStartOfDay(subDays(now, windowDays)),
    end: shopEndOfDay(subDays(now, 1)),
  };
}
