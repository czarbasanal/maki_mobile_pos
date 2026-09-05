// The one date scope for every report screen (reports guide §1): the shared
// segmented control's presets, the resolved range, and the note that frames
// each headline figure ("in the last 7 days"). Daily-only roles (cashier)
// clamp to today regardless of the control — derived, not forced into state.
//
// The range rides in the URL (?range=last7 · ?range=custom&from=&to=) so the
// index cards, the reports and the back button all share one scope, as the
// reference does — pick 30 days on the index, open Sales, see 30 days.
import { useEffect, useMemo } from 'react';
import { useSearchParams } from 'react-router-dom';
import { resolvePreset, type RangePreset } from '@/domain/reports/dateRange';
import { useDateRangeControlState } from '@/presentation/hooks/useDateRangeControlState';

export type ReportPreset = Extract<RangePreset, 'today' | 'last7' | 'last30'> | 'custom';

export const REPORT_RANGE_OPTIONS: Array<{ value: ReportPreset; label: string }> = [
  { value: 'today', label: 'Today' },
  { value: 'last7', label: '7 days' },
  { value: 'last30', label: '30 days' },
  { value: 'custom', label: 'Custom' },
];

const RANGE_NOTE: Record<ReportPreset, string> = {
  today: 'today',
  last7: 'in the last 7 days',
  last30: 'in the last 30 days',
  custom: 'in the selected range',
};

/** The next wider preset the empty states can offer; null when there is none. */
const WIDER: Record<ReportPreset, Exclude<ReportPreset, 'custom'> | null> = {
  today: 'last7',
  last7: 'last30',
  last30: null,
  custom: null,
};
const WIDEN_LABEL: Record<Exclude<ReportPreset, 'custom'>, string> = {
  today: 'Show today',
  last7: 'Show last 7 days',
  last30: 'Show last 30 days',
};

const PRESET_VALUES = new Set<string>(REPORT_RANGE_OPTIONS.map((o) => o.value));
const ISO_DAY = /^\d{4}-\d{2}-\d{2}$/;

/** Parses ?range / ?from / ?to; anything malformed reads as "not set". */
function seedFromSearch(params: URLSearchParams) {
  const range = params.get('range') ?? '';
  const from = params.get('from') ?? '';
  const to = params.get('to') ?? '';
  if (!PRESET_VALUES.has(range)) return {};
  if (range === 'custom') {
    return ISO_DAY.test(from) && ISO_DAY.test(to) && from <= to
      ? { preset: 'custom' as const, customStart: from, customEnd: to }
      : {};
  }
  return { preset: range as ReportPreset };
}

export function useReportRange(defaultPreset: Exclude<ReportPreset, 'custom'>, dailyOnly = false) {
  const [searchParams, setSearchParams] = useSearchParams();
  const ctl = useDateRangeControlState<ReportPreset>(defaultPreset, dailyOnly ? {} : seedFromSearch(searchParams));

  // Write the scope back (replace, never push — Back should leave the
  // report, not step through every pill click). Other params are preserved.
  const { preset, customStart, customEnd } = ctl;
  useEffect(() => {
    if (dailyOnly) return;
    const next = new URLSearchParams(searchParams);
    next.set('range', preset);
    if (preset === 'custom' && customStart && customEnd) {
      next.set('from', customStart);
      next.set('to', customEnd);
    } else {
      next.delete('from');
      next.delete('to');
    }
    if (next.toString() !== searchParams.toString()) setSearchParams(next, { replace: true });
  }, [dailyOnly, preset, customStart, customEnd, searchParams, setSearchParams]);
  const effectiveRange = useMemo(
    () => (dailyOnly ? resolvePreset('today') : ctl.range),
    [dailyOnly, ctl.range],
  );
  // A Custom pill with no applied dates is still scoped to the default —
  // the note must say so, not "in the selected range".
  const applied: ReportPreset =
    ctl.preset === 'custom' && !(ctl.customStart && ctl.customEnd) ? defaultPreset : ctl.preset;
  const wider = dailyOnly ? null : WIDER[ctl.preset];
  return {
    ...ctl,
    effectiveRange,
    rangeNote: dailyOnly ? RANGE_NOTE.today : RANGE_NOTE[applied],
    /** The empty states' recovery action — steps to the next WIDER preset; null when there is none. */
    widen: wider ? () => ctl.setPreset(wider) : null,
    widenLabel: wider ? WIDEN_LABEL[wider] : null,
  };
}

export type ReportRangeState = ReturnType<typeof useReportRange>;
