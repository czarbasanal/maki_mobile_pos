// Shared building blocks for the record-editing modals (ProductModal,
// SupplierModal, ExpenseModal): the control-height token, the input surface,
// a labeled Field wrapper, an uppercase SectionLabel, and the Record-history
// entry (label / person / timestamp as one three-line fact). Each modal used
// to carry a private copy of all five; this is the unified form.
import type { ReactNode } from 'react';
import { cn } from '@/core/utils/cn';
import { formatShopDateTime } from '@/domain/time/shopTime';

/** Every control in a shared-track row renders at ONE height — inputs,
 *  select triggers, buttons and tiles alike. Mixed natural heights read as
 *  misaligned. */
export const controlH = 'h-[42px]';

export function inputCls(hasError?: boolean): string {
  return cn(
    `${controlH} w-full rounded-ctl border bg-surface-2 px-3 py-2.5 text-[13px] text-ink outline-none transition-colors placeholder:text-ink-3`,
    hasError ? 'border-neg' : 'border-line focus:border-accent-line',
  );
}

export function Field({
  label,
  error,
  group = false,
  children,
}: {
  label: string;
  error?: string;
  /** Composite content (buttons, chips, dropdowns) must NOT sit in a <label>:
   *  a label associates with its first labelable descendant — buttons
   *  included — and steals their accessible name. */
  group?: boolean;
  children: ReactNode;
}) {
  const Tag = group ? 'div' : 'label';
  return (
    <Tag className="flex flex-col gap-[6px]">
      <span className="text-[11.5px] font-semibold text-ink-2">{label}</span>
      {children}
      {error ? <span className="text-[11.5px] text-neg">{error}</span> : null}
    </Tag>
  );
}

export function SectionLabel({ children }: { children: ReactNode }) {
  return (
    <span className="text-[10px] font-semibold uppercase tracking-[1px] text-ink-3">{children}</span>
  );
}

/** One record-history entry: label / person / timestamp as a three-line
 *  stack. Person and timestamp are ONE entry, not two fields — that is how
 *  the fact is spoken ("Bern updated it on Sep 1"). Unknown person shows an
 *  em dash rather than repeating the creator. */
export function HistoryEntry({
  label,
  who,
  when,
  /** Shown in place of the timestamp when `when` is null. ProductModal's
   *  default '—'; ExpenseModal passes 'Never edited'. */
  emptyWhenText = '—',
  /** Card-styled (bordered, inset) surface — ExpenseModal's Record history. */
  inset = false,
}: {
  label: string;
  who: string | null;
  when: Date | null;
  emptyWhenText?: string;
  inset?: boolean;
}) {
  // Blank-string author names exist in old docs; they get the em dash too.
  const name = who?.trim() ? who : null;
  return (
    <div
      className={cn(
        'flex flex-col gap-[3px]',
        inset && 'rounded-ctl border border-line bg-surface-2 px-3 py-2.5',
      )}
    >
      <span className="text-[10px] font-semibold uppercase tracking-[1px] text-ink-3">{label}</span>
      <span className={cn('text-[12.5px] font-medium', name ? 'text-ink' : 'text-ink-3')}>{name ?? '—'}</span>
      <span className="font-mono text-[10.5px] text-ink-3">{when ? formatShopDateTime(when) : emptyWhenText}</span>
    </div>
  );
}
