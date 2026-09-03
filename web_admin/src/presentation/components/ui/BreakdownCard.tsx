// The summary-row breakdown card (Receiving pipeline / Suppliers directory):
// a label with the total right-aligned in mono, then rows — color square,
// label, mono count. A row with onClick IS a filter and shows active
// styling; a row without one renders as a plain div, never a button with no
// effect (suppliers guide §2 — identical markup for interactive and
// non-interactive rows is the bug).
import { cn } from '@/core/utils/cn';

export interface BreakdownRow {
  key: string;
  label: string;
  /** Token color for the square, e.g. 'var(--pos)'. */
  color: string;
  count: number;
  active?: boolean;
  onClick?: () => void;
}

export function BreakdownCard({
  label,
  total,
  rows,
}: {
  label: string;
  /** Right-aligned mono header figure, e.g. "14 suppliers". */
  total: string;
  rows: BreakdownRow[];
}) {
  return (
    <div className="flex flex-col gap-[11px] rounded-card border border-line bg-surface px-[17px] py-[15px] shadow-card">
      <div className="flex items-baseline gap-[9px]">
        <span className="text-[11.5px] font-medium text-ink-2">{label}</span>
        <span className="ml-auto font-mono text-[11.5px] text-ink-3">{total}</span>
      </div>
      <div className="flex flex-col gap-[7px]">
        {rows.map((r) => {
          const inner = (
            <>
              <span
                aria-hidden
                className="h-[7px] w-[7px] shrink-0 rounded-[2px]"
                style={{ background: r.color }}
              />
              <span
                className={cn(
                  'text-[12px]',
                  r.active ? 'font-semibold text-ink' : 'font-medium text-ink-2',
                )}
              >
                {r.label}
              </span>
              <span className="ml-auto font-mono text-[13px] font-semibold text-ink">
                {r.count}
              </span>
            </>
          );
          return r.onClick ? (
            <button
              key={r.key}
              type="button"
              aria-pressed={r.active}
              onClick={r.onClick}
              className="flex items-center gap-2 py-[2px] text-left"
            >
              {inner}
            </button>
          ) : (
            <div key={r.key} className="flex items-center gap-2 py-[2px]">
              {inner}
            </div>
          );
        })}
      </div>
    </div>
  );
}
