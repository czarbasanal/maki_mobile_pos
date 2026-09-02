// Segmented control (JO guide §A date range): pills in a --surface-3 trough,
// the active one lifted onto --surface. Every pill is nowrap — "7 days" must
// never wrap and double the control's height.
import { clsx } from 'clsx';

export function Segmented<T extends string>({
  options,
  value,
  onChange,
  label,
}: {
  options: Array<{ value: T; label: string }>;
  value: T;
  onChange: (value: T) => void;
  label: string;
}) {
  return (
    <div
      role="radiogroup"
      aria-label={label}
      className="flex items-center gap-1 rounded-[11px] bg-surface-3 p-[3px]"
    >
      {options.map((o) => (
        <button
          key={o.value}
          type="button"
          role="radio"
          aria-checked={o.value === value}
          onClick={() => onChange(o.value)}
          className={clsx(
            'whitespace-nowrap rounded-[8px] px-[13px] py-1.5 text-[12px] transition-[color]',
            o.value === value ? 'bg-surface font-semibold text-ink' : 'font-medium text-ink-2 hover:text-ink',
          )}
        >
          {o.label}
        </button>
      ))}
    </div>
  );
}
