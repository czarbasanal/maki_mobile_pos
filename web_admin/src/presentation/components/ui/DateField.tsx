// Single-date calendar field (date-range-calendar handoff, single-date
// mode) — the ONE date control for record forms (expense date, receiving's
// Received), replacing native <input type="date">. Same conventions as
// DateRangeControl: every cell carries a YYYY-MM-DD key and comparisons are
// plain string compares — no Date-instance timezone traps; "today" is the
// SHOP day and later days are not pickable (these are historical fields).
// Dismissal contract: pick, re-clicking the trigger, outside mousedown,
// Escape (layered).
import { useEffect, useMemo, useRef, useState } from 'react';
import { CalendarDaysIcon, ChevronLeftIcon, ChevronRightIcon } from '@heroicons/react/24/outline';
import { useEscapeLayer } from './escapeLayers';
import { inputCls } from './formKit';
import { shopIsoDate } from '@/domain/time/shopTime';
import { cn } from '@/core/utils/cn';

const DOW = ['S', 'M', 'T', 'W', 'T', 'F', 'S'];
const pad = (n: number) => String(n).padStart(2, '0');
const keyOf = (y: number, m: number, d: number) => `${y}-${pad(m + 1)}-${pad(d)}`;

function fmt(key: string): string {
  const [y, m, d] = key.split('-').map(Number);
  return new Date(y, m - 1, d).toLocaleDateString('en-US', {
    month: 'short',
    day: 'numeric',
    year: 'numeric',
  });
}

export function DateField({
  value,
  onChange,
  ariaLabel,
  className,
}: {
  /** YYYY-MM-DD; callers keep it valid (empty never renders here). */
  value: string;
  onChange: (v: string) => void;
  /** Accessible name for the trigger — wrap in a group Field, never a
   *  <label> (it would steal the button's name). */
  ariaLabel: string;
  /** Merged onto the trigger (tailwind-merge). */
  className?: string;
}) {
  const [open, setOpen] = useState(false);
  const today = shopIsoDate(new Date());
  const seed = value || today;
  const [month, setMonth] = useState(() => {
    const [y, m] = seed.split('-').map(Number);
    return { y, m: m - 1 };
  });
  const wrapper = useRef<HTMLDivElement>(null);

  useEscapeLayer(open, () => setOpen(false));
  useEffect(() => {
    if (!open) return;
    const onMouseDown = (e: MouseEvent) => {
      if (wrapper.current && !wrapper.current.contains(e.target as Node)) setOpen(false);
    };
    document.addEventListener('mousedown', onMouseDown, true);
    return () => document.removeEventListener('mousedown', onMouseDown, true);
  }, [open]);

  const toggle = () => {
    if (!open) {
      // Re-seat the grid on the current value each open — a stale month
      // after an external value change reads as the wrong calendar.
      const [y, m] = (value || today).split('-').map(Number);
      setMonth({ y, m: m - 1 });
    }
    setOpen((o) => !o);
  };

  const cells = useMemo(() => {
    const firstDow = new Date(month.y, month.m, 1).getDay();
    const daysInMonth = new Date(month.y, month.m + 1, 0).getDate();
    const prevDays = new Date(month.y, month.m, 0).getDate();
    // Always 42 cells — six weeks, constant grid height across months.
    return Array.from({ length: 42 }, (_, i) => {
      const n = i - firstDow + 1;
      const inMonth = n >= 1 && n <= daysInMonth;
      let y = month.y;
      let m = month.m;
      let d = n;
      if (n < 1) {
        m -= 1;
        d = prevDays + n;
        if (m < 0) {
          m = 11;
          y -= 1;
        }
      } else if (n > daysInMonth) {
        m += 1;
        d = n - daysInMonth;
        if (m > 11) {
          m = 0;
          y += 1;
        }
      }
      const key = keyOf(y, m, d);
      const pickable = inMonth && key <= today;
      return { key, day: d, inMonth, pickable };
    });
  }, [month, today]);

  const monthLabel = new Date(month.y, month.m, 1).toLocaleDateString('en-US', {
    month: 'long',
    year: 'numeric',
  });

  return (
    <div ref={wrapper} className="relative">
      <button
        type="button"
        aria-label={ariaLabel}
        aria-haspopup="dialog"
        aria-expanded={open}
        onClick={toggle}
        className={cn(
          inputCls(false),
          'flex items-center justify-between gap-2 text-left font-mono',
          className,
        )}
      >
        <span>{value ? fmt(value) : 'Pick a date'}</span>
        <CalendarDaysIcon className="h-4 w-4 shrink-0 text-ink-3" />
      </button>

      {open ? (
        <div
          role="dialog"
          aria-label={ariaLabel}
          className="absolute left-0 top-[calc(100%+8px)] z-50 flex w-[296px] flex-col gap-3 rounded-card border border-line bg-surface p-3.5 shadow-[0_20px_48px_-16px_rgba(0,0,0,0.32)]"
        >
          <div className="flex items-center gap-2">
            <button
              type="button"
              title="Previous month"
              onClick={() => setMonth((c) => (c.m === 0 ? { y: c.y - 1, m: 11 } : { y: c.y, m: c.m - 1 }))}
              className="flex h-[26px] w-[26px] shrink-0 items-center justify-center rounded-[8px] text-ink-2 hover:bg-surface-3 hover:text-ink"
            >
              <ChevronLeftIcon className="h-3.5 w-3.5" />
            </button>
            <span className="flex-1 text-center text-ctl-sm font-semibold tracking-[-0.1px] text-ink">
              {monthLabel}
            </span>
            <button
              type="button"
              title="Next month"
              onClick={() => setMonth((c) => (c.m === 11 ? { y: c.y + 1, m: 0 } : { y: c.y, m: c.m + 1 }))}
              className="flex h-[26px] w-[26px] shrink-0 items-center justify-center rounded-[8px] text-ink-2 hover:bg-surface-3 hover:text-ink"
            >
              <ChevronRightIcon className="h-3.5 w-3.5" />
            </button>
          </div>

          <div className="grid grid-cols-7 gap-[2px]">
            {DOW.map((d, i) => (
              <span
                key={`${d}${i}`}
                className="pb-1 pt-[2px] text-center text-[9.5px] font-semibold uppercase tracking-[0.6px] text-ink-3"
              >
                {d}
              </span>
            ))}
            {cells.map((c) => {
              const selected = c.key === value;
              const isToday = c.key === today;
              return (
                <button
                  key={c.key}
                  type="button"
                  aria-label={c.pickable ? c.key : undefined}
                  aria-disabled={!c.pickable || undefined}
                  tabIndex={c.pickable ? 0 : -1}
                  onClick={
                    c.pickable
                      ? () => {
                          onChange(c.key);
                          setOpen(false);
                        }
                      : undefined
                  }
                  className={cn(
                    'flex h-8 items-center justify-center rounded-[8px] font-mono text-[12px]',
                    c.pickable ? 'cursor-pointer' : 'cursor-default',
                    selected
                      ? 'bg-accent font-semibold text-accent-ink'
                      : isToday
                        ? 'font-semibold text-accent-text'
                        : c.pickable
                          ? 'text-ink-2 hover:bg-surface-2'
                          : 'text-ink-3',
                  )}
                >
                  {c.day}
                </button>
              );
            })}
          </div>
        </div>
      ) : null}
    </div>
  );
}
