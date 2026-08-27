import {
  instantOf,
  shopEndOfDay,
  shopOffsetMinutes,
  shopStartOfDay,
  shopTimeOf,
  shopWall,
} from '@/domain/time/shopTime';

export interface DateRange {
  start: Date;
  end: Date;
}

export type RangePreset =
  | 'today'
  | 'yesterday'
  | 'last7'
  | 'last30'
  | 'thisMonth'
  | 'custom';

export const PRESET_LABELS: Record<RangePreset, string> = {
  today: 'Today',
  yesterday: 'Yesterday',
  last7: 'Last 7 days',
  last30: 'Last 30 days',
  thisMonth: 'This month',
  custom: 'Custom range',
};

/**
 * Resolves a FIXED preset (not 'custom') to a concrete range, computed in the
 * shop's timezone and returned as instants ready for Firestore bounds.
 * `now` and `offsetMinutes` are injectable so this stays deterministic in tests.
 */
export function resolvePreset(
  preset: Exclude<RangePreset, 'custom'>,
  now: Date = new Date(),
  offsetMinutes: number = shopOffsetMinutes(),
): DateRange {
  const dayBefore = (d: Date, n: number) => new Date(d.getTime() - n * 86_400_000);
  const end = shopEndOfDay(now, offsetMinutes);

  switch (preset) {
    case 'today':
      return { start: shopStartOfDay(now, offsetMinutes), end };
    case 'yesterday': {
      const y = dayBefore(now, 1);
      return { start: shopStartOfDay(y, offsetMinutes), end: shopEndOfDay(y, offsetMinutes) };
    }
    case 'last7':
      return { start: shopStartOfDay(dayBefore(now, 6), offsetMinutes), end };
    case 'last30':
      return { start: shopStartOfDay(dayBefore(now, 29), offsetMinutes), end };
    case 'thisMonth': {
      const w = shopTimeOf(now, offsetMinutes);
      return {
        start: instantOf(shopWall(w.getUTCFullYear(), w.getUTCMonth() + 1, 1), offsetMinutes),
        end,
      };
    }
  }
}
