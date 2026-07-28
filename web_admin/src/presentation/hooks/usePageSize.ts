import { useCallback, useState } from 'react';

/** Row counts offered by the pager's rows-per-page selector. */
export const PAGE_SIZE_OPTIONS = [25, 50, 100, 500, 1000] as const;

export type PageSize = (typeof PAGE_SIZE_OPTIONS)[number];

export const DEFAULT_PAGE_SIZE: PageSize = 25;

const keyFor = (table: string) => `maki.pageSize.${table}`;

function read(table: string): PageSize {
  try {
    const raw = localStorage.getItem(keyFor(table));
    const parsed = Number(raw);
    // Anything not currently on the menu (junk, or a size we've since
    // dropped) falls back rather than paging by a number the UI can't show.
    return (PAGE_SIZE_OPTIONS as readonly number[]).includes(parsed)
      ? (parsed as PageSize)
      : DEFAULT_PAGE_SIZE;
  } catch {
    // Private mode / storage disabled — page at the default instead of dying.
    return DEFAULT_PAGE_SIZE;
  }
}

/**
 * Rows-per-page for one table, remembered per browser and kept independent
 * per `table` key so a big Inventory page doesn't also enlarge Sales.
 *
 * `table` must be a constant for the life of the component — the stored
 * value is read once on mount.
 */
export function usePageSize(table: string): [PageSize, (next: PageSize) => void] {
  const [size, setSize] = useState<PageSize>(() => read(table));

  const choose = useCallback(
    (next: PageSize) => {
      if (!(PAGE_SIZE_OPTIONS as readonly number[]).includes(next)) return;
      setSize(next);
      try {
        localStorage.setItem(keyFor(table), String(next));
      } catch {
        // Non-fatal: the choice still applies for this session.
      }
    },
    [table],
  );

  return [size, choose];
}
