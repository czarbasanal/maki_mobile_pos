import { useMemo, useState } from 'react';
import { resolvePreset, type DateRange, type RangePreset } from '@/domain/reports/dateRange';
import { instantOf, shopWall } from '@/domain/time/shopTime';

/**
 * Preset + custom-start/custom-end state for a DateRangeControl, plus the
 * resolved DateRange — the shop-day range math shared by JobOrdersPage,
 * ReceivingListPage and ExpensesPage. A fixed preset resolves via
 * resolvePreset; 'custom' parses the two yyyy-MM-dd inputs as SHOP calendar
 * days via instantOf(shopWall(...)), with the end bound at 23:59:59.999
 * shop-wall. Until both custom dates are picked, the range falls back to
 * `defaultPreset`'s resolved range so the rows under it don't go empty.
 * `defaultPreset` itself can't be 'custom' — there'd be no dates to resolve
 * before the operator has picked any.
 */
export interface DateRangeControlSeed<T extends RangePreset> {
  preset?: T;
  customStart?: string;
  customEnd?: string;
}

export function useDateRangeControlState<T extends RangePreset>(
  defaultPreset: Exclude<T, 'custom'>,
  /** Initial state handed in from outside (e.g. the URL) — used on first render only. */
  seed: DateRangeControlSeed<T> = {},
) {
  const [preset, setPreset] = useState<T>(seed.preset ?? defaultPreset);
  const [customStart, setCustomStart] = useState(seed.customStart ?? '');
  const [customEnd, setCustomEnd] = useState(seed.customEnd ?? '');

  const range = useMemo<DateRange>(() => {
    if ((preset as RangePreset) === 'custom') {
      if (customStart && customEnd) {
        // Plain yyyy-MM-dd means the SHOP day the operator picked — parsing
        // via new Date() would shift by the browser zone.
        const [sy, sm, sd] = customStart.split('-').map(Number);
        const [ey, em, ed] = customEnd.split('-').map(Number);
        return {
          start: instantOf(shopWall(sy, sm, sd)),
          end: instantOf(shopWall(ey, em, ed, 23, 59, 59, 999)),
        };
      }
      // Until both dates are picked, keep the default range under the rows.
      return resolvePreset(defaultPreset as Exclude<RangePreset, 'custom'>);
    }
    return resolvePreset(preset as Exclude<RangePreset, 'custom'>);
  }, [preset, customStart, customEnd, defaultPreset]);

  return { preset, setPreset, customStart, setCustomStart, customEnd, setCustomEnd, range };
}
