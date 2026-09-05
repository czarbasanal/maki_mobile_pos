// The two table-card empty states every list screen carries (JO/Inventory/
// Receiving guides): the FIRST-RUN teach (52px accent tile + copy + primary
// actions — condition is total count, never the filtered count) and the
// NO-MATCHES state whose copy points back at the filters.
import type { ReactNode } from 'react';
import { cn } from '@/core/utils/cn';

export function FirstRunState({
  icon,
  title,
  description,
  children,
  tone = 'accent',
}: {
  /** A ~24px glyph, rendered inside the tile. */
  icon: ReactNode;
  /** 'accent' is the first-run teach; 'muted' is the reports empty-RANGE
   *  state (surface-2 tile, plain border) — "nothing happened", not "get started". */
  tone?: 'accent' | 'muted';
  title: string;
  description: string;
  /** Primary action(s); omit when the viewer lacks the permission. */
  children?: ReactNode;
}) {
  return (
    <div className="flex flex-col items-center gap-[5px] px-6 py-16 text-center">
      <div
        className={cn(
          'mb-[9px] flex h-[52px] w-[52px] items-center justify-center rounded-[15px] border',
          tone === 'muted' ? 'border-line bg-surface-2' : 'border-accent-line bg-accent-soft',
        )}
      >
        {icon}
      </div>
      <span className="text-[14.5px] font-semibold tracking-[-0.2px] text-ink">{title}</span>
      <span className="max-w-[340px] text-ctl-sm text-ink-3 [text-wrap:pretty]">{description}</span>
      {children ? <div className="mt-3.5 flex gap-[9px]">{children}</div> : null}
    </div>
  );
}

export function NoMatchesState({
  title,
  hint,
  onClear,
}: {
  title: string;
  hint: string;
  /** Omit to hide the Clear button (e.g. nothing is actually filtered). */
  onClear?: () => void;
}) {
  return (
    <div className="flex flex-col items-center gap-[7px] px-5 py-[52px] text-center">
      <span className="text-[13px] font-medium text-ink-2">{title}</span>
      <span className="text-[12px] text-ink-3">{hint}</span>
      {onClear ? (
        <button
          type="button"
          onClick={onClear}
          className="mt-1.5 rounded-ctl border border-line px-3.5 py-2 text-[12px] font-medium text-ink-2 hover:border-accent-line hover:text-ink"
        >
          Clear filters
        </button>
      ) : null}
    </div>
  );
}
