// Choice chip — the spec's shared filter-chip treatment (§7 FilterBar):
// active takes the accent tint, inactive stays on surface.
import { clsx } from 'clsx';
import type { ReactNode } from 'react';

export interface ChipProps {
  active: boolean;
  onClick: () => void;
  children: ReactNode;
}

export function Chip({ active, onClick, children }: ChipProps) {
  return (
    <button
      type="button"
      aria-pressed={active}
      onClick={onClick}
      className={clsx(
        'rounded-pill border px-3 py-[5px] text-ctl-sm font-medium transition-[color]',
        active
          ? 'border-accent-text bg-accent-soft text-accent-text'
          : 'border-line bg-surface text-ink-2 hover:text-ink',
      )}
    >
      {children}
    </button>
  );
}
