import { useState } from 'react';
import { endOfDay, format, startOfDay } from 'date-fns';
import {
  PRESET_LABELS,
  resolvePreset,
  type DateRange,
  type RangePreset,
} from '@/domain/reports/dateRange';

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
 * owns the range; default preset is 'last7' and must match the parent's initial.
 */
export function DateRangePicker({
  onChange,
}: {
  onChange: (range: DateRange) => void;
}) {
  const [preset, setPreset] = useState<RangePreset>('last7');
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
      onChange({
        start: startOfDay(new Date(startStr)),
        end: endOfDay(new Date(endStr)),
      });
    }
  }

  return (
    <div className="flex flex-wrap items-center gap-tk-sm">
      <select
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
            className={inputCls}
            value={customStart}
            max={customEnd || format(new Date(), 'yyyy-MM-dd')}
            onChange={(e) => applyCustom(e.target.value, customEnd)}
          />
          <span className="text-light-text-hint">–</span>
          <input
            type="date"
            className={inputCls}
            value={customEnd}
            min={customStart}
            max={format(new Date(), 'yyyy-MM-dd')}
            onChange={(e) => applyCustom(customStart, e.target.value)}
          />
        </>
      ) : null}
    </div>
  );
}
