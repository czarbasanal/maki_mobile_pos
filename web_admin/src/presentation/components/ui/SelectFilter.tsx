// Custom dropdown filter (JO guide §A) — a labeled trigger whose border and
// value light up in --accent-text while a filter is active, over a floating
// option menu with a tick slot and right-aligned mono counts. Built once here;
// every list screen's dropdown filter goes through this, never a native
// <select> (which can't show counts or the active-filter treatment).
//
// Dismissal contract (the part that's easy to forget): the menu closes on
// select, on clicking the trigger again, on a mousedown anywhere outside the
// wrapper, and on Escape.
import { useEffect, useRef, useState } from 'react';
import { useEscapeLayer } from './escapeLayers';
import { clsx } from 'clsx';
import { cn } from '@/core/utils/cn';
import { ChevronDownIcon, CheckIcon } from '@heroicons/react/24/outline';

export interface SelectFilterOption {
  value: string;
  label: string;
  /** Right-aligned mono count; omit to hide. */
  count?: number;
}

export function SelectFilter({
  label,
  value,
  options,
  onChange,
  /** Shown (and selectable) as the "no filter" row, e.g. "All mechanics". */
  allLabel,
  allTriggerLabel,
  triggerClassName,
}: {
  label: string;
  /** '' = no filter (the allLabel row). */
  value: string;
  options: SelectFilterOption[];
  onChange: (value: string) => void;
  /** Omit for a plain required select — no "no filter" row is rendered and
   *  '' is never offered (the product modal's Unit field). */
  allLabel?: string;
  /** Shorter trigger text for the unfiltered state (e.g. "All"); the menu
   *  row keeps the full allLabel. */
  allTriggerLabel?: string;
  /** Extra classes merged onto the trigger (tailwind-merge) — form contexts
   *  use it to match input height/surface (e.g. the product modal). */
  triggerClassName?: string;
}) {
  const [open, setOpen] = useState(false);
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

  const active = value !== '';
  const current = options.find((o) => o.value === value);

  const pick = (next: string) => {
    onChange(next);
    setOpen(false);
  };

  return (
    <div ref={wrapper} className="relative">
      <button
        type="button"
        aria-haspopup="listbox"
        aria-expanded={open}
        onClick={() => setOpen((o) => !o)}
        className={cn(
          'flex min-w-[186px] items-center gap-2 rounded-ctl border bg-surface px-[13px] py-[9px] text-left shadow-card',
          active ? 'border-accent-text' : 'border-line',
          triggerClassName,
        )}
      >
        <span className="flex min-w-0 flex-1 items-center gap-2">
          <span className="text-micro text-ink-3">{label}</span>
          <span
            className={clsx(
              'truncate text-ctl-sm font-semibold',
              active ? 'text-accent-text' : 'text-ink',
            )}
          >
            {current?.label ?? allTriggerLabel ?? allLabel ?? ''}
          </span>
        </span>
        <ChevronDownIcon
          className={clsx('h-3.5 w-3.5 shrink-0 text-ink-3 transition-transform', open && 'rotate-180')}
        />
      </button>

      {open ? (
        <div
          role="listbox"
          aria-label={label}
          className="absolute left-0 top-[calc(100%+6px)] z-40 max-h-64 min-w-full overflow-y-auto rounded-card border border-line bg-surface p-[5px] shadow-card"
        >
          {allLabel !== undefined ? (
            <Option
              label={allLabel}
              selected={!active}
              onPick={() => pick('')}
            />
          ) : null}
          {options.map((o) => (
            <Option
              key={o.value}
              label={o.label}
              count={o.count}
              selected={o.value === value}
              onPick={() => pick(o.value)}
            />
          ))}
        </div>
      ) : null}
    </div>
  );
}

function Option({
  label,
  count,
  selected,
  onPick,
}: {
  label: string;
  count?: number;
  selected: boolean;
  onPick: () => void;
}) {
  return (
    <button
      type="button"
      role="option"
      aria-selected={selected}
      onClick={onPick}
      className={clsx(
        'flex w-full items-center gap-2 whitespace-nowrap rounded-field px-2.5 py-1.5 text-left text-ctl-sm',
        selected ? 'bg-accent-soft font-semibold text-accent-text' : 'text-ink hover:bg-surface-2',
      )}
    >
      <span className="w-[14px] shrink-0">
        {selected ? <CheckIcon className="h-3.5 w-3.5 text-accent-text" /> : null}
      </span>
      <span className="min-w-0 flex-1 truncate">{label}</span>
      {count !== undefined ? (
        <span className="pl-3 font-mono text-micro text-ink-3">{count}</span>
      ) : null}
    </button>
  );
}
