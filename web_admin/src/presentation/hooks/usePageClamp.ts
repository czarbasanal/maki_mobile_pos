import { useEffect } from 'react';

// Companion to <Pager>: when the list shrinks under a parked page (a delete
// or deactivate on a later page, a live snapshot update), the slice can go
// empty — and once total drops to <= pageSize the Pager unmounts entirely,
// leaving no Prev button to escape with. Snap to the last page that still
// has rows. Filter-driven resets to page 1 stay the parent's job.
export function usePageClamp(
  page: number,
  setPage: (page: number) => void,
  total: number,
  pageSize: number,
): void {
  useEffect(() => {
    const totalPages = Math.max(1, Math.ceil(total / pageSize));
    if (page > totalPages) setPage(totalPages);
  }, [page, setPage, total, pageSize]);
}
