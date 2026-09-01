import { clsx } from 'clsx';
import type { ReactNode } from 'react';

export type Tone = 'positive' | 'warning' | 'negative' | 'neutral';
export type BadgeShape = 'pill' | 'chip';

const toneCls: Record<Tone, string> = {
  positive: 'bg-pos-soft text-pos',
  warning: 'bg-accent-soft text-accent-text',
  negative: 'bg-neg-soft text-neg',
  neutral: 'bg-surface-3 text-ink-3',
};

export function Badge({
  tone = 'neutral',
  shape = 'pill',
  children,
}: {
  tone?: Tone;
  shape?: BadgeShape;
  children: ReactNode;
}) {
  return (
    <span
      className={clsx(
        'inline-flex items-center whitespace-nowrap',
        shape === 'pill'
          ? 'rounded-pill px-2.5 py-0.5 text-pill'
          : 'rounded-chip px-1.5 py-0.5 font-mono text-micro font-semibold',
        toneCls[tone],
      )}
    >
      {children}
    </span>
  );
}
