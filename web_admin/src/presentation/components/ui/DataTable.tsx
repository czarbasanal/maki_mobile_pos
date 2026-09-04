// The one table for the whole admin (spec §7). Never write a bare <table>
// in a screen again — extend this instead.
import { clsx } from 'clsx';
import type { ReactNode } from 'react';
import { Checkbox } from './Checkbox';
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
  /** Row selection (PO guide §D): a leading tokenized-checkbox column with an
   *  all/none/indeterminate header. */
  selection?: {
    selectedKeys: ReadonlySet<string>;
    onToggle: (key: string) => void;
    onToggleAll: () => void;
    /** Accessible name for a row's checkbox. */
    rowLabel: (row: T) => string;
  };
  /** Extra class for a row (e.g. greying an unselected line). */
  rowClassName?: (row: T) => string | undefined;
  /** Optional summary row (e.g. Expenses' "Total shown") rendered in a
   *  <tfoot> — a plain <tr> of <td>s, so the caller controls colSpan and
   *  alignment. Hidden whenever rows.length === 0 (the component returns
   *  `empty` instead of the table then) AND while `loading` — a stale total
   *  must never sit under a body of skeleton placeholder rows. */
  foot?: ReactNode;
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
  selection,
  rowClassName,
  foot,
}: DataTableProps<T>) {
  if (!loading && rows.length === 0) {
    return <>{empty ?? <EmptyState message="Nothing here yet" />}</>;
  }

  const allSelected =
    !!selection && rows.length > 0 && rows.every((r) => selection.selectedKeys.has(rowKey(r)));
  const someSelected =
    !!selection && !allSelected && rows.some((r) => selection.selectedKeys.has(rowKey(r)));

  return (
    <div className="overflow-x-auto">
      <table className="w-full border-collapse" style={minWidth ? { minWidth } : undefined}>
        <thead>
          <tr className="border-y border-line bg-surface-2">
            {selection ? (
              <th className="w-[38px] px-4 py-2">
                <Checkbox
                  checked={allSelected}
                  indeterminate={someSelected}
                  onChange={selection.onToggleAll}
                  label="Select all"
                />
              </th>
            ) : null}
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
                  {selection ? (
                    <td className="px-4 py-2.5">
                      <Skeleton height="12px" />
                    </td>
                  ) : null}
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
                    rowClassName?.(row),
                  )}
                >
                  {selection ? (
                    <td className="px-4 py-2.5">
                      <Checkbox
                        checked={selection.selectedKeys.has(rowKey(row))}
                        onChange={() => selection.onToggle(rowKey(row))}
                        label={selection.rowLabel(row)}
                      />
                    </td>
                  ) : null}
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
        {foot && !loading ? <tfoot>{foot}</tfoot> : null}
      </table>
    </div>
  );
}
