import { endOfDay, startOfDay, startOfMonth, subDays } from 'date-fns';

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
 * Resolves a FIXED preset (not 'custom') to a concrete date range.
 * `now` is injectable so this stays deterministic in tests.
 */
export function resolvePreset(
  preset: Exclude<RangePreset, 'custom'>,
  now: Date = new Date(),
): DateRange {
  switch (preset) {
    case 'today':
      return { start: startOfDay(now), end: endOfDay(now) };
    case 'yesterday': {
      const y = subDays(now, 1);
      return { start: startOfDay(y), end: endOfDay(y) };
    }
    case 'last7':
      return { start: startOfDay(subDays(now, 6)), end: endOfDay(now) };
    case 'last30':
      return { start: startOfDay(subDays(now, 29)), end: endOfDay(now) };
    case 'thisMonth':
      return { start: startOfMonth(now), end: endOfDay(now) };
  }
}
