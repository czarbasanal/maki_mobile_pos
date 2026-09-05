// Bottom-pinned action bar (PO guide §B/§D): summary figures left, the
// primary money figure and actions right, on --surface with a top border
// and an upward shadow. Stays visible while a long table scrolls — the
// buyer adjusting quantities is watching that total.
import type { ReactNode } from 'react';
import { cn } from '@/core/utils/cn';

export function StickyActionBar({
  figures,
  children,
}: {
  /** Left side: label/value pairs. `tone: 'pos'` highlights one figure in
   *  the positive-money color (receiving guide §2's Retail value, sitting
   *  beside the always-neutral Lines/Units in figures). */
  figures: Array<{ label: string; value: string; tone?: 'pos' }>;
  /** Right side: the money figure + action buttons. */
  children: ReactNode;
}) {
  return (
    <div className="sticky bottom-0 z-30 flex flex-wrap items-center gap-x-6 gap-y-2 border-t border-line bg-surface px-5 py-3 shadow-[0_-10px_28px_-16px_rgba(16,24,40,0.18)]">
      {figures.map((f) => (
        <span key={f.label} className="flex items-baseline gap-1.5">
          <span className="text-[11.5px] text-ink-3">{f.label}</span>
          <span
            className={cn(
              'font-mono text-[13px] font-semibold',
              f.tone === 'pos' ? 'text-pos' : 'text-ink',
            )}
          >
            {f.value}
          </span>
        </span>
      ))}
      <div className="ml-auto flex items-center gap-2.5">{children}</div>
    </div>
  );
}
