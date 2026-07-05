import { endOfDay, startOfDay, subDays } from 'date-fns';

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
    start: startOfDay(subDays(now, windowDays)),
    end: endOfDay(subDays(now, 1)),
  };
}
