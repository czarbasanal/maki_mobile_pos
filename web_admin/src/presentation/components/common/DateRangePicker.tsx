import { useState } from 'react';
import {
  PRESET_LABELS,
  resolvePreset,
  type DateRange,
  type RangePreset,
} from '@/domain/reports/dateRange';
import { instantOf, shopIsoDate, shopWall } from '@/domain/time/shopTime';

const inputCls =
  'rounded-md border border-light-border bg-light-card px-tk-md py-[8px] text-bodySmall text-light-text outline-none focus:border-light-text';

const PRESETS: RangePreset[] = [
  'today',
  'yesterday',
  'last7',
  'last30',
  'thisMonth',
  'custom',
];

/**
 * Preset dropdown + (for 'custom') two native date inputs. Calls `onChange`
 * with a concrete {start,end} whenever the effective range changes. The parent
 * owns the range; default preset is 'last7' unless overridden with defaultPreset,
 * and must match the parent's initial.
 *
 * NOTE: this predates useDateRangeControlState (src/presentation/hooks) and
 * doesn't share it — this component owns its preset/custom-date state
 * internally and only pushes the resolved DateRange out via onChange, so
 * there's no parent-visible preset/customStart/customEnd to lift into the
 * shared hook without changing this component's API. JobOrdersPage,
 * ReceivingListPage and ExpensesPage (the reskinned pages, which DO expose
 * that state to drive DateRangeControl) use the shared hook instead.
 */
export function DateRangePicker({
  onChange,
  defaultPreset = 'last7',
}: {
  onChange: (range: DateRange) => void;
  defaultPreset?: Exclude<RangePreset, 'custom'>;
}) {
  const [preset, setPreset] = useState<RangePreset>(defaultPreset);
  const [customStart, setCustomStart] = useState('');
  const [customEnd, setCustomEnd] = useState('');

  function selectPreset(next: RangePreset) {
    setPreset(next);
    if (next !== 'custom') onChange(resolvePreset(next));
  }

  function applyCustom(startStr: string, endStr: string) {
    setCustomStart(startStr);
    setCustomEnd(endStr);
    if (startStr && endStr) {
      // The inputs give plain yyyy-MM-dd — the SHOP calendar days the operator
      // means. `new Date(str)` would parse them as UTC midnight and then shift
      // by the browser zone, an off-by-one anywhere outside the shop.
      const [sy, sm, sd] = startStr.split('-').map(Number);
      const [ey, em, ed] = endStr.split('-').map(Number);
      onChange({
        start: instantOf(shopWall(sy, sm, sd)),
        end: instantOf(shopWall(ey, em, ed, 23, 59, 59, 999)),
      });
    }
  }

  return (
    <div className="flex flex-wrap items-center gap-tk-sm">
      <select
        aria-label="Date range"
        className={inputCls}
        value={preset}
        onChange={(e) => selectPreset(e.target.value as RangePreset)}
      >
        {PRESETS.map((p) => (
          <option key={p} value={p}>
            {PRESET_LABELS[p]}
          </option>
        ))}
      </select>

      {preset === 'custom' ? (
        <>
          <input
            type="date"
            aria-label="Start date"
            className={inputCls}
            value={customStart}
            max={customEnd || shopIsoDate(new Date())}
            onChange={(e) => applyCustom(e.target.value, customEnd)}
          />
          <span className="text-light-text-hint">–</span>
          <input
            type="date"
            aria-label="End date"
            className={inputCls}
            value={customEnd}
            min={customStart}
            max={shopIsoDate(new Date())}
            onChange={(e) => applyCustom(customStart, e.target.value)}
          />
        </>
      ) : null}
    </div>
  );
}
