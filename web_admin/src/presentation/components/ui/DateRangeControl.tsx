// Segmented date presets + the Custom pill's calendar popover, per
// design/maki-pos-date-range-calendar: ONE calendar — first click sets From,
// second sets To, a click before From swaps the pair (never an error), a
// click with both set starts over. Hover previews the span only while To is
// empty. Apply is explicit (dimmed until both ends exist); the applied span
// replaces the word "Custom" on the pill so the active filter stays legible.
//
// Every cell carries a YYYY-MM-DD key and comparisons are plain string
// compares — no Date-instance timezone traps. The parent turns the applied
// strings into a DateRange via instantOf(shopWall); "today" is the SHOP day.
// Dismissal contract: Apply, re-clicking Custom, outside mousedown, Escape.
import { useEffect, useMemo, useRef, useState } from 'react';
import { ChevronLeftIcon, ChevronRightIcon } from '@heroicons/react/24/outline';
import { Segmented } from './Segmented';
import { shopIsoDate } from '@/domain/time/shopTime';
import { cn } from '@/core/utils/cn';

const DOW = ['S', 'M', 'T', 'W', 'T', 'F', 'S'];
const pad = (n: number) => String(n).padStart(2, '0');
const keyOf = (y: number, m: number, d: number) => `${y}-${pad(m + 1)}-${pad(d)}`;

function fmt(key: string | null): string | null {
  if (!key) return null;
  const [y, m, d] = key.split('-').map(Number);
  return new Date(y, m - 1, d).toLocaleDateString('en-US', {
    month: 'short',
    day: 'numeric',
    year: 'numeric',
  });
}

function fmtShort(key: string): string {
  const [y, m, d] = key.split('-').map(Number);
  return new Date(y, m - 1, d).toLocaleDateString('en-US', { month: 'short', day: 'numeric' });
}

export function DateRangeControl<T extends string>({
  options,
  value,
  onChange,
  customStart,
  customEnd,
  onCustomStart,
  onCustomEnd,
  customValue = 'custom' as T,
  label = 'Date range',
}: {
  options: Array<{ value: T; label: string }>;
  value: T;
  onChange: (value: T) => void;
  customStart: string;
  customEnd: string;
  onCustomStart: (v: string) => void;
  onCustomEnd: (v: string) => void;
  /** Which option value means "custom" (opens the calendar). */
  customValue?: T;
  label?: string;
}) {
  const [open, setOpen] = useState(false);
  // Selection is exactly three nullable keys — anything more drifts.
  const [from, setFrom] = useState<string | null>(customStart || null);
  const [to, setTo] = useState<string | null>(customEnd || null);
  const [hover, setHover] = useState<string | null>(null);
  const today = shopIsoDate(new Date());
  const [month, setMonth] = useState(() => {
    const seed = customStart || today;
    const [y, m] = seed.split('-').map(Number);
    return { y, m: m - 1 };
  });
  const wrapper = useRef<HTMLDivElement>(null);

  useEffect(() => {
    if (!open) return;
    const onMouseDown = (e: MouseEvent) => {
      if (wrapper.current && !wrapper.current.contains(e.target as Node)) {
        setOpen(false);
        setHover(null);
      }
    };
    const onKeyDown = (e: KeyboardEvent) => {
      if (e.key === 'Escape') {
        setOpen(false);
        setHover(null);
      }
    };
    document.addEventListener('mousedown', onMouseDown, true);
    document.addEventListener('keydown', onKeyDown, true);
    return () => {
      document.removeEventListener('mousedown', onMouseDown, true);
      document.removeEventListener('keydown', onKeyDown, true);
    };
  }, [open]);

  const pickDay = (key: string) => {
    if (!from || (from && to)) {
      setFrom(key);
      setTo(null);
      setHover(null);
    } else if (key < from) {
      // Reversed selection swaps — never an error.
      setFrom(key);
      setTo(from);
      setHover(null);
    } else {
      setTo(key);
      setHover(null);
    }
  };

  // Hover previews the range only while From is set and To is empty.
  const end = to ?? (from && !to ? hover : null);
  const lo = from && end ? (end < from ? end : from) : null;
  const hi = from && end ? (end < from ? from : end) : null;

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
      // Historical screens: no future ranges (guide §5 — maxDate defaults to
      // today). Future days render like adjacent-month cells.
      const pickable = inMonth && key <= today;
      return { key, day: d, inMonth, pickable };
    });
  }, [month, today]);

  const applied = value === customValue && customStart && customEnd;
  const pillOptions = useMemo(
    () =>
      options.map((o) =>
        o.value === customValue && applied
          ? { ...o, label: `${fmtShort(customStart)} – ${fmtShort(customEnd)}` }
          : o,
      ),
    [options, customValue, applied, customStart, customEnd],
  );

  const canApply = !!from && !!to;
  const apply = () => {
    if (!from || !to) return;
    onCustomStart(from);
    onCustomEnd(to);
    setOpen(false);
    setHover(null);
  };

  const monthLabel = new Date(month.y, month.m, 1).toLocaleDateString('en-US', {
    month: 'long',
    year: 'numeric',
  });

  return (
    <div ref={wrapper} className="relative">
      <Segmented
        label={label}
        options={pillOptions}
        value={value}
        onChange={(v) => {
          onChange(v);
          setOpen(v === customValue ? !open || value !== customValue : false);
        }}
      />
      {open && value === customValue ? (
        <div
          role="dialog"
          aria-label="Pick a date range"
          className="absolute right-0 top-[calc(100%+8px)] z-50 flex w-[296px] flex-col gap-3 rounded-card border border-line bg-surface p-3.5 shadow-[0_20px_48px_-16px_rgba(0,0,0,0.32)]"
        >
          <div className="flex items-center gap-2.5 rounded-ctl border border-line bg-surface-2 px-[11px] py-[9px]">
            <div className="flex min-w-0 flex-1 flex-col gap-[2px]">
              <span className="text-[9.5px] font-semibold uppercase tracking-[0.9px] text-ink-3">
                From
              </span>
              <span className={cn('font-mono text-ctl-sm font-semibold', from ? 'text-ink' : 'text-ink-3')}>
                {fmt(from) ?? 'Pick a date'}
              </span>
            </div>
            <span className="text-[13px] text-ink-3">–</span>
            <div className="flex min-w-0 flex-1 flex-col gap-[2px]">
              <span className="text-[9.5px] font-semibold uppercase tracking-[0.9px] text-ink-3">
                To
              </span>
              <span className={cn('font-mono text-ctl-sm font-semibold', to ? 'text-ink' : 'text-ink-3')}>
                {fmt(to) ?? (from ? 'Pick a date' : '—')}
              </span>
            </div>
          </div>

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
              const inRange = !!lo && !!hi && c.key > lo && c.key < hi;
              const isEdge =
                c.key === from || c.key === to || (!!from && !to && c.key === hover);
              const isToday = c.key === today;
              // Endpoints keep the radius only on their outer side so the
              // range reads as one continuous bar (single day keeps all four).
              const radius =
                isEdge && lo && hi && lo !== hi
                  ? c.key === lo
                    ? 'rounded-l-[8px] rounded-r-none'
                    : c.key === hi
                      ? 'rounded-r-[8px] rounded-l-none'
                      : 'rounded-none'
                  : inRange
                    ? 'rounded-none'
                    : 'rounded-[8px]';
              return (
                <button
                  key={c.key}
                  type="button"
                  aria-label={c.pickable ? c.key : undefined}
                  aria-disabled={!c.pickable || undefined}
                  tabIndex={c.pickable ? 0 : -1}
                  onClick={c.pickable ? () => pickDay(c.key) : undefined}
                  onMouseEnter={
                    c.pickable && from && !to ? () => setHover(c.key) : undefined
                  }
                  className={cn(
                    'flex h-8 items-center justify-center font-mono text-[12px]',
                    radius,
                    c.pickable ? 'cursor-pointer' : 'cursor-default',
                    isEdge
                      ? 'bg-accent font-semibold text-accent-ink'
                      : inRange
                        ? 'bg-accent-soft font-medium text-accent-text'
                        : isToday
                          ? 'font-semibold text-accent-text'
                          : c.pickable
                            ? 'text-ink-2'
                            : 'text-ink-3',
                  )}
                >
                  {c.day}
                </button>
              );
            })}
          </div>

          <div className="flex items-center gap-2 border-t border-line-2 pt-[11px]">
            <span className="text-[11px] text-ink-3">
              {!from ? 'Click a day to start' : !to ? 'Click a second day to end' : 'Range set'}
            </span>
            <button
              type="button"
              onClick={() => {
                setFrom(null);
                setTo(null);
                setHover(null);
              }}
              className="ml-auto text-[11.5px] text-ink-3 hover:text-neg"
            >
              Reset
            </button>
            <button
              type="button"
              onClick={apply}
              aria-disabled={!canApply || undefined}
              className={cn(
                'rounded-[9px] bg-accent px-[13px] py-[7px] text-[12px] font-semibold text-accent-ink',
                !canApply && 'cursor-default opacity-[.45]',
              )}
            >
              Apply
            </button>
          </div>
        </div>
      ) : null}
    </div>
  );
}
