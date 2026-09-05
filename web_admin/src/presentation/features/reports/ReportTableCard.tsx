// The table card every report body ends in: a 14px/600 title with either a
// mono count chip or a dim range note, then the DataTable (which owns the
// inner overflow-x scroller — a card with overflow:hidden alone clips columns).
import type { ReactNode } from 'react';

export function ReportTableCard({
  title,
  count,
  note,
  action,
  children,
}: {
  title: string;
  count?: number;
  note?: string;
  /** Right-aligned control (e.g. Expand all). Sits after the note. */
  action?: ReactNode;
  children: ReactNode;
}) {
  return (
    <section className="overflow-hidden rounded-card border border-line bg-surface shadow-card">
      <div className="flex items-center gap-2.5 border-b border-line-2 px-5 py-[15px]">
        <h2 className="text-card-title text-ink">{title}</h2>
        {count !== undefined ? (
          <span className="rounded-[6px] bg-surface-3 px-[7px] py-[2px] font-mono text-[10.5px] font-semibold text-ink-2">
            {count.toLocaleString('en-PH')}
          </span>
        ) : null}
        {note ? <span className="ml-auto text-[11.5px] text-ink-3">{note}</span> : null}
        {action ? <div className={note ? 'flex items-center' : 'ml-auto flex items-center'}>{action}</div> : null}
      </div>
      {children}
    </section>
  );
}
