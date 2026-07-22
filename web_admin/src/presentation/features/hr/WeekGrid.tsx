// Renders the 7 day-cells of a pay period. Clicking a cell cycles its status
// present -> absent -> dayOff -> present; the default seed (all present,
// last day off) is applied by usePayslipDraft, not here — this component is
// a plain, controlled renderer of whatever `days` it's given.

import { cn } from '@/core/utils/cn';
import { nextDayStatus } from './usePayslipDraft';
import type { DayStatus, PayslipDay } from '@/domain/hr/types';

const WEEKDAY_LABELS = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];

const STATUS_LABEL: Record<DayStatus, string> = {
  present: 'Present',
  absent: 'Absent',
  dayOff: 'Day off',
};

const STATUS_STYLE: Record<DayStatus, string> = {
  present: 'border-success-light bg-success-light/30 text-success-dark',
  absent: 'border-error-light bg-error-light/30 text-error-dark',
  dayOff: 'border-light-border bg-light-subtle text-light-text-secondary',
};

function dayLabel(iso: string): string {
  const [y, m, d] = iso.split('-').map(Number);
  const date = new Date(y, m - 1, d);
  return `${WEEKDAY_LABELS[date.getDay()]} ${m}/${d}`;
}

export function WeekGrid({
  days,
  setDay,
}: {
  days: PayslipDay[];
  setDay: (date: string, status: DayStatus) => void;
}) {
  return (
    <div className="grid grid-cols-7 gap-tk-xs">
      {days.map((day) => (
        <button
          key={day.date}
          type="button"
          onClick={() => setDay(day.date, nextDayStatus(day.status))}
          className={cn(
            'flex flex-col items-center gap-0.5 rounded-md border px-tk-xs py-tk-sm text-[11px]',
            STATUS_STYLE[day.status],
          )}
        >
          <span className="font-medium">{dayLabel(day.date)}</span>
          <span>{STATUS_LABEL[day.status]}</span>
        </button>
      ))}
    </div>
  );
}
