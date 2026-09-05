import { clsx } from 'clsx';
import type { ReactNode } from 'react';

export type Tone = 'positive' | 'warning' | 'negative' | 'info' | 'neutral';
export type BadgeShape = 'pill' | 'chip' | 'tag';

const toneCls: Record<Tone, string> = {
  positive: 'bg-pos-soft text-pos',
  warning: 'bg-accent-soft text-accent-text',
  negative: 'bg-neg-soft text-neg',
  info: 'bg-info-soft text-info',
  neutral: 'bg-surface-3 text-ink-3',
};

export function Badge({
  tone = 'neutral',
  shape = 'pill',
  title,
  wrap = false,
  children,
}: {
  tone?: Tone;
  shape?: BadgeShape;
  /** Hover detail when the badge is a grouping of a rawer value (e.g. a reason group). */
  title?: string;
  /** Free-text content (a cashier's "Other" reason) may wrap instead of forcing the cell wide. */
  wrap?: boolean;
  children: ReactNode;
}) {
  return (
    <span
      title={title}
      className={clsx(
        'inline-flex items-center',
        wrap ? 'whitespace-normal [text-wrap:pretty]' : 'whitespace-nowrap',
        shape === 'pill' && 'rounded-pill px-2.5 py-0.5 text-pill',
        shape === 'chip' && 'rounded-chip px-1.5 py-0.5 font-mono text-micro font-semibold',
        // Non-mono 11px chip (suppliers guide §3 Terms column).
        shape === 'tag' && 'rounded-chip px-2 py-[3px] text-[11px] font-medium',
        toneCls[tone],
      )}
    >
      {children}
    </span>
  );
}
