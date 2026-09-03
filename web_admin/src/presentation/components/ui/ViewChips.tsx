// Saved-view chips with mono counts (JO/Inventory/Receiving guides): the
// active view takes the accent tint, every chip stays nowrap, and the count
// rides at 11px/70%. One component so the three list screens can't drift.
import { cn } from '@/core/utils/cn';

export interface ViewChipOption<T extends string> {
  value: T;
  label: string;
  count: number;
}

export function ViewChips<T extends string>({
  options,
  value,
  onChange,
}: {
  options: Array<ViewChipOption<T>>;
  value: T;
  onChange: (value: T) => void;
}) {
  return (
    <>
      {options.map((v) => (
        <button
          key={v.value}
          type="button"
          aria-pressed={value === v.value}
          onClick={() => onChange(v.value)}
          className={cn(
            'flex items-center gap-[7px] whitespace-nowrap rounded-pill border px-[13px] py-[7px] text-ctl-sm transition-[color]',
            value === v.value
              ? 'border-accent-text bg-accent-soft font-semibold text-accent-text'
              : 'border-line bg-surface font-medium text-ink-2 hover:text-ink',
          )}
        >
          {v.label}
          <span className="font-mono text-[11px] opacity-70">{v.count}</span>
        </button>
      ))}
    </>
  );
}
