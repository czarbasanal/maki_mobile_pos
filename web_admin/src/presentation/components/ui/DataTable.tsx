// The one table for the whole admin (spec §7). Never write a bare <table>
// in a screen again — extend this instead.
import { clsx } from 'clsx';
import type { ReactNode } from 'react';
import { EmptyState } from './EmptyState';
import { Skeleton } from './Skeleton';

export interface Column<T> {
  key: string;
  header: string;
  align?: 'left' | 'right' | 'center';
  width?: string;
  mono?: boolean;
  render: (row: T) => ReactNode;
}

export interface DataTableProps<T> {
  columns: Array<Column<T>>;
  rows: T[];
  rowKey: (row: T) => string;
  onRowClick?: (row: T) => void;
  loading?: boolean;
  skeletonRows?: number;
  empty?: ReactNode;
  /** Intrinsic min-content width of the table (e.g. '820px'). The wrapper is
   *  the horizontal scroller, so narrow viewports scroll instead of clipping
   *  the last columns behind the card's rounded overflow:hidden (JO guide §A). */
  minWidth?: string;
}

const alignCls = { left: 'text-left', right: 'text-right', center: 'text-center' } as const;

export function DataTable<T>({
  columns,
  rows,
  rowKey,
  onRowClick,
  loading = false,
  skeletonRows = 8,
  empty,
  minWidth,
}: DataTableProps<T>) {
  if (!loading && rows.length === 0) {
    return <>{empty ?? <EmptyState message="Nothing here yet" />}</>;
  }

  return (
    <div className="overflow-x-auto">
      <table className="w-full border-collapse" style={minWidth ? { minWidth } : undefined}>
        <thead>
          <tr className="border-y border-line bg-surface-2">
            {columns.map((col) => (
              <th
                key={col.key}
                style={col.width ? { width: col.width } : undefined}
                className={clsx('px-4 py-2 text-micro-caps uppercase text-ink-3', alignCls[col.align ?? 'left'])}
              >
                {col.header}
              </th>
            ))}
          </tr>
        </thead>
        <tbody>
          {loading
            ? Array.from({ length: skeletonRows }, (_, i) => (
                <tr key={i} className="border-b border-line-2 last:border-b-0">
                  {columns.map((col) => (
                    <td key={col.key} className="px-4 py-2.5">
                      <Skeleton height="12px" />
                    </td>
                  ))}
                </tr>
              ))
            : rows.map((row) => (
                <tr
                  key={rowKey(row)}
                  onClick={onRowClick ? () => onRowClick(row) : undefined}
                  onKeyDown={
                    onRowClick
                      ? (e) => {
                          if (e.key === 'Enter' || e.key === ' ') {
                            if (e.key === ' ') {
                              e.preventDefault();
                            }
                            onRowClick(row);
                          }
                        }
                      : undefined
                  }
                  tabIndex={onRowClick ? 0 : undefined}
                  className={clsx(
                    'border-b border-line-2 last:border-b-0',
                    onRowClick && 'cursor-pointer hover:bg-surface-2 focus:outline-none focus-visible:bg-surface-2',
                  )}
                >
                  {columns.map((col) => (
                    <td
                      key={col.key}
                      className={clsx(
                        'px-4 py-2.5 text-cell text-ink',
                        col.mono && 'font-mono',
                        col.align === 'right' && 'text-amount',
                        alignCls[col.align ?? 'left'],
                      )}
                    >
                      {col.render(row)}
                    </td>
                  ))}
                </tr>
              ))}
        </tbody>
      </table>
    </div>
  );
}
