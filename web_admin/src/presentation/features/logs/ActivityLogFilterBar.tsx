// Filter controls for /admin/logs. Owns only its dropdown's open/closed
// state — every filter value lives in the page so Search can snapshot them.

import { useState } from 'react';
import { ChevronDownIcon, FunnelIcon } from '@heroicons/react/24/outline';
import {
  ALL_ACTIVITY_TYPES,
  activityTypeDisplayName,
  type ActivityType,
} from '@/domain/entities';
import { DateRangePicker } from '@/presentation/components/common/DateRangePicker';
import type { DateRange } from '@/domain/reports/dateRange';
import { cn } from '@/core/utils/cn';

const inputCls =
  'rounded-md border border-light-border bg-light-card px-tk-md py-[8px] text-bodySmall text-light-text outline-none focus:border-light-text';

export function ActivityLogFilterBar({
  types,
  onTypes,
  onRange,
  startTime,
  endTime,
  onStartTime,
  onEndTime,
  dirty,
  disabled,
  onSearch,
}: {
  types: ActivityType[];
  onTypes: (next: ActivityType[]) => void;
  onRange: (next: DateRange) => void;
  startTime: string;
  endTime: string;
  onStartTime: (v: string) => void;
  onEndTime: (v: string) => void;
  dirty: boolean;
  disabled: boolean;
  onSearch: () => void;
}) {
  const [open, setOpen] = useState(false);

  // Rebuilt in enum order, never click order, so an identical selection is
  // always the same array shape.
  function toggle(t: ActivityType) {
    const next = new Set(types);
    if (next.has(t)) next.delete(t);
    else next.add(t);
    onTypes(ALL_ACTIVITY_TYPES.filter((x) => next.has(x)));
  }

  const label =
    types.length === 0
      ? 'All operations'
      : types.length === 1
        ? '1 operation'
        : `${types.length} operations`;

  return (
    <div className="flex flex-wrap items-center gap-tk-sm">
      <div className="relative">
        <button
          type="button"
          onClick={() => setOpen((v) => !v)}
          className="flex items-center gap-tk-xs rounded-md border border-light-border bg-light-card px-tk-md py-tk-sm text-bodySmall text-light-text hover:bg-light-subtle"
        >
          <FunnelIcon className="h-3.5 w-3.5" />
          {label}
          <ChevronDownIcon className="h-3.5 w-3.5" />
        </button>
        {open ? (
          <>
            <div className="fixed inset-0 z-10" onClick={() => setOpen(false)} />
            <div className="absolute left-0 z-20 mt-tk-xs max-h-80 w-64 overflow-y-auto rounded-md border border-light-hairline bg-light-card p-tk-sm shadow-lg">
              <button
                type="button"
                onClick={() => onTypes([])}
                className="mb-tk-xs w-full rounded-md px-tk-sm py-tk-xs text-left text-bodySmall text-light-text-secondary hover:bg-light-subtle"
              >
                Clear — all operations
              </button>
              {ALL_ACTIVITY_TYPES.map((t) => (
                <label
                  key={t}
                  className="flex cursor-pointer items-center gap-tk-sm rounded-md px-tk-sm py-tk-xs text-bodySmall text-light-text hover:bg-light-subtle"
                >
                  <input
                    type="checkbox"
                    aria-label={activityTypeDisplayName[t]}
                    checked={types.includes(t)}
                    onChange={() => toggle(t)}
                  />
                  {activityTypeDisplayName[t]}
                </label>
              ))}
            </div>
          </>
        ) : null}
      </div>

      <DateRangePicker defaultPreset="today" onChange={onRange} />

      <input
        type="time"
        aria-label="Start time"
        className={inputCls}
        value={startTime}
        onChange={(e) => onStartTime(e.target.value)}
      />
      <span className="text-light-text-hint">–</span>
      <input
        type="time"
        aria-label="End time"
        className={inputCls}
        value={endTime}
        onChange={(e) => onEndTime(e.target.value)}
      />

      <button
        type="button"
        disabled={disabled}
        onClick={onSearch}
        className={cn(
          'rounded-md px-tk-lg py-tk-sm text-bodySmall font-semibold',
          disabled
            ? 'cursor-not-allowed bg-light-subtle text-light-text-hint'
            : 'bg-light-text text-light-background hover:opacity-90',
        )}
      >
        Search
      </button>

      {dirty ? (
        <span className="text-bodySmall text-light-text-secondary">
          Filters changed — tap Search.
        </span>
      ) : null}
    </div>
  );
}
