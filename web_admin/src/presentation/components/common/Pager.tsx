import { PAGE_SIZE_OPTIONS, type PageSize } from '@/presentation/hooks/usePageSize';

// Shared client-side pager for the app's main tables/lists. The parent owns
// `page` state, slices its (already-filtered) items with
// `items.slice((page - 1) * pageSize, page * pageSize)`, and must reset
// `page` to 1 whenever its filters change (search/category/date-range/etc.)
// so a stale page number can't point past the end of a shorter result set.
//
// Pass `onPageSize` to offer the rows-per-page selector — see usePageSize for
// the per-table persistence.
export function Pager({
  total,
  page,
  onPage,
  pageSize = 25,
  onPageSize,
}: {
  total: number;
  page: number;
  onPage: (next: number) => void;
  pageSize?: number;
  onPageSize?: (next: PageSize) => void;
}) {
  // Hide only when no offered size would paginate this list. Measuring
  // against the SMALLEST option rather than the current one keeps the
  // selector reachable after picking a size big enough to fit everything —
  // otherwise it would vanish and there'd be no way back down to 25.
  const threshold = onPageSize ? PAGE_SIZE_OPTIONS[0] : pageSize;
  if (total <= threshold) return null;

  const totalPages = Math.max(1, Math.ceil(total / pageSize));
  const start = (page - 1) * pageSize + 1;
  const end = Math.min(page * pageSize, total);

  return (
    <div className="flex items-center justify-between gap-tk-md px-tk-md py-tk-sm text-bodySmall text-light-text-secondary">
      <span>
        {start}–{end} of {total}
      </span>
      <div className="flex items-center gap-tk-md">
        {onPageSize ? (
          <label className="flex items-center gap-tk-xs">
            <span>Rows per page</span>
            <select
              value={pageSize}
              onChange={(e) => onPageSize(Number(e.target.value) as PageSize)}
              className="rounded-md border border-light-border bg-light-card px-tk-sm py-[4px] text-bodySmall text-light-text outline-none focus:border-light-text"
            >
              {PAGE_SIZE_OPTIONS.map((n) => (
                <option key={n} value={n}>
                  {n}
                </option>
              ))}
            </select>
          </label>
        ) : null}
        <div className="flex items-center gap-tk-xs">
          <button
            type="button"
            onClick={() => onPage(page - 1)}
            disabled={page <= 1}
            className="rounded-md border border-light-border px-tk-sm py-[4px] text-bodySmall text-light-text hover:bg-light-subtle disabled:cursor-not-allowed disabled:opacity-40 disabled:hover:bg-transparent"
          >
            Prev
          </button>
          <button
            type="button"
            onClick={() => onPage(page + 1)}
            disabled={page >= totalPages}
            className="rounded-md border border-light-border px-tk-sm py-[4px] text-bodySmall text-light-text hover:bg-light-subtle disabled:cursor-not-allowed disabled:opacity-40 disabled:hover:bg-transparent"
          >
            Next
          </button>
        </div>
      </div>
    </div>
  );
}
