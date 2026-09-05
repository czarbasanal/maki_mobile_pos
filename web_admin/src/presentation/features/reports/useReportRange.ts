// The one date scope for every report screen (reports guide §1): the shared
// segmented control's presets, the resolved range, and the note that frames
// each headline figure ("in the last 7 days"). Daily-only roles (cashier)
// clamp to today regardless of the control — derived, not forced into state.
import { useMemo } from 'react';
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

export function useReportRange(defaultPreset: Exclude<ReportPreset, 'custom'>, dailyOnly = false) {
  const ctl = useDateRangeControlState<ReportPreset>(defaultPreset);
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
