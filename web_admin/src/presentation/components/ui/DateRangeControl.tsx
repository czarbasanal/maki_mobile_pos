// Segmented date presets + the Custom pill's popover (JO guide §A foresaw
// it: "put it as a fifth pill opening a popover"). The popover holds the
// browser's OWN date inputs — no custom calendar — and closes on outside
// mousedown, Escape, or picking another preset. Dates are SHOP calendar
// days; the parent turns them into a DateRange via instantOf(shopWall).
import { useEffect, useRef, useState } from 'react';
import { Segmented } from './Segmented';
import { shopIsoDate } from '@/domain/time/shopTime';

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
  /** Which option value means "custom" (opens the popover). */
  customValue?: T;
  label?: string;
}) {
  const [open, setOpen] = useState(false);
  const wrapper = useRef<HTMLDivElement>(null);

  useEffect(() => {
    if (!open) return;
    const onMouseDown = (e: MouseEvent) => {
      if (wrapper.current && !wrapper.current.contains(e.target as Node)) setOpen(false);
    };
    const onKeyDown = (e: KeyboardEvent) => {
      if (e.key === 'Escape') setOpen(false);
    };
    document.addEventListener('mousedown', onMouseDown, true);
    document.addEventListener('keydown', onKeyDown, true);
    return () => {
      document.removeEventListener('mousedown', onMouseDown, true);
      document.removeEventListener('keydown', onKeyDown, true);
    };
  }, [open]);

  return (
    <div ref={wrapper} className="relative">
      <Segmented
        label={label}
        options={options}
        value={value}
        onChange={(v) => {
          onChange(v);
          setOpen(v === customValue);
        }}
      />
      {open && value === customValue ? (
        <div className="absolute right-0 top-[calc(100%+6px)] z-40 flex items-center gap-2 rounded-[12px] border border-line bg-surface p-3 shadow-[0_18px_44px_-14px_rgba(0,0,0,0.3)]">
          <input
            type="date"
            aria-label="Start date"
            value={customStart}
            max={customEnd || shopIsoDate(new Date())}
            onChange={(e) => onCustomStart(e.target.value)}
          />
          <span className="text-ink-3">–</span>
          <input
            type="date"
            aria-label="End date"
            value={customEnd}
            min={customStart}
            max={shopIsoDate(new Date())}
            onChange={(e) => onCustomEnd(e.target.value)}
          />
        </div>
      ) : null}
    </div>
  );
}
