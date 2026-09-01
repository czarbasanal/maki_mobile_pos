// Bordered − qty + stepper (POS guide §2 cart line): 30px tall, radius 9px,
// mono count. The floor is the caller's business rule (default 1).
import { MinusIcon, PlusIcon } from '@heroicons/react/24/outline';

export interface StepperProps {
  value: number;
  onChange: (next: number) => void;
  min?: number;
  /** Accessible name for the count, e.g. "Quantity of Brake shoe". */
  label: string;
}

export function Stepper({ value, onChange, min = 1, label }: StepperProps) {
  return (
    <div className="inline-flex h-[30px] items-stretch overflow-hidden rounded-field border border-line">
      <button
        type="button"
        aria-label={`Decrease ${label}`}
        disabled={value <= min}
        onClick={() => onChange(Math.max(min, value - 1))}
        className="px-2 text-ink-2 transition-[color] hover:bg-surface-2 disabled:opacity-40"
      >
        <MinusIcon className="h-3.5 w-3.5" />
      </button>
      <span
        aria-label={label}
        className="flex min-w-[34px] items-center justify-center border-x border-line font-mono text-amount text-ink"
      >
        {value}
      </span>
      <button
        type="button"
        aria-label={`Increase ${label}`}
        onClick={() => onChange(value + 1)}
        className="px-2 text-ink-2 transition-[color] hover:bg-surface-2"
      >
        <PlusIcon className="h-3.5 w-3.5" />
      </button>
    </div>
  );
}
