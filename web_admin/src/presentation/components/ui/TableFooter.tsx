// The table-card pagination footer (JO/Inventory guides): surface-2 band
// inside the card, mono "1–25 of 1,647" on the left, Rows-per-page as
// 25/50/100 mono buttons plus Prev/Next pills on the right. Callers hide it
// on empty states (footer under an empty state is noise) — render only when
// rows exist.
import { cn } from '@/core/utils/cn';
import type { PageSize } from '@/presentation/hooks/usePageSize';

const FOOTER_SIZES = [25, 50, 100] as const;

export function TableFooter({
  total,
  page,
  pageSize,
  onPage,
  onPageSize,
}: {
  total: number;
  page: number;
  pageSize: number;
  onPage: (next: number) => void;
  onPageSize: (next: PageSize) => void;
}) {
  const totalPages = Math.max(1, Math.ceil(total / pageSize));
  // A persisted odd size (the old selector offered up to 1000) joins the row
  // so the stored choice stays visible and reversible.
  const sizes: number[] = FOOTER_SIZES.includes(pageSize as (typeof FOOTER_SIZES)[number])
    ? [...FOOTER_SIZES]
    : [...FOOTER_SIZES, pageSize].sort((a, b) => a - b);

  return (
    <div className="flex items-center gap-3 border-t border-line bg-surface-2 px-5 py-3">
      <span className="font-mono text-[11.5px] text-ink-3">
        {((page - 1) * pageSize + 1).toLocaleString('en-PH')}–
        {Math.min(page * pageSize, total).toLocaleString('en-PH')} of {total.toLocaleString('en-PH')}
      </span>
      <div className="ml-auto flex items-center gap-2">
        <span className="text-[11.5px] text-ink-3">Rows per page</span>
        <div className="flex gap-[3px]">
          {sizes.map((n) => (
            <button
              key={n}
              type="button"
              onClick={() => onPageSize(n as PageSize)}
              className={cn(
                'rounded-[7px] px-[9px] py-1 font-mono text-[11.5px]',
                n === pageSize ? 'bg-surface font-semibold text-ink' : 'text-ink-3 hover:text-ink-2',
              )}
            >
              {n}
            </button>
          ))}
        </div>
        <div className="ml-1.5 flex gap-[5px]">
          <button
            type="button"
            onClick={() => onPage(page - 1)}
            disabled={page <= 1}
            className="rounded-[8px] border border-line px-[11px] py-[5px] text-[11.5px] text-ink-2 hover:border-accent-line hover:text-ink disabled:cursor-not-allowed disabled:text-ink-3 disabled:hover:border-line"
          >
            Prev
          </button>
          <button
            type="button"
            onClick={() => onPage(page + 1)}
            disabled={page >= totalPages}
            className="rounded-[8px] border border-line px-[11px] py-[5px] text-[11.5px] text-ink-2 hover:border-accent-line hover:text-ink disabled:cursor-not-allowed disabled:text-ink-3 disabled:hover:border-line"
          >
            Next
          </button>
        </div>
      </div>
    </div>
  );
}
