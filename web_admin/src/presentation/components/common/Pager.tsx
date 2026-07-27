// Shared client-side pager for the app's main tables/lists. The parent owns
// `page` state, slices its (already-filtered) items with
// `items.slice((page - 1) * pageSize, page * pageSize)`, and must reset
// `page` to 1 whenever its filters change (search/category/date-range/etc.)
// so a stale page number can't point past the end of a shorter result set.
export function Pager({
  total,
  page,
  onPage,
  pageSize = 25,
}: {
  total: number;
  page: number;
  onPage: (next: number) => void;
  pageSize?: number;
}) {
  if (total <= pageSize) return null;

  const totalPages = Math.max(1, Math.ceil(total / pageSize));
  const start = (page - 1) * pageSize + 1;
  const end = Math.min(page * pageSize, total);

  return (
    <div className="flex items-center justify-between gap-tk-md px-tk-md py-tk-sm text-bodySmall text-light-text-secondary">
      <span>
        {start}–{end} of {total}
      </span>
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
  );
}
