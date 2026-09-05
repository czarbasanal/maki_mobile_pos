// The one table for the whole admin (spec §7). Never write a bare <table>
// in a screen again — extend this instead.
import { clsx } from 'clsx';
import { Fragment, type ReactNode } from 'react';
import { ChevronRightIcon } from '@heroicons/react/24/outline';
import { Checkbox } from './Checkbox';
import { IconButton } from './IconButton';
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
  /** Expandable rows (Sales report's lines-under-the-sale): a leading chevron
   *  column toggles a full-width band under the row. The chevron never fires
   *  the row's own click. */
  expansion?: {
    isExpanded: (row: T) => boolean;
    onToggle: (row: T) => void;
    render: (row: T) => ReactNode;
    /** Accessible name for the toggle, e.g. "Show lines for SALE-…". */
    label: (row: T) => string;
  };
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
  expansion,
  foot,
}: DataTableProps<T>) {
  if (!loading && rows.length === 0) {
    return <>{empty ?? <EmptyState message="Nothing here yet" />}</>;
  }

  const allSelected =
    !!selection && rows.length > 0 && rows.every((r) => selection.selectedKeys.has(rowKey(r)));
  const someSelected =
    !!selection && !allSelected && rows.some((r) => selection.selectedKeys.has(rowKey(r)));

  const leadingCells = (selection ? 1 : 0) + (expansion ? 1 : 0);

  return (
    <div className="overflow-x-auto">
      <table className="w-full border-collapse" style={minWidth ? { minWidth } : undefined}>
        <thead>
          <tr className="border-y border-line bg-surface-2">
            {expansion ? <th className="w-[36px] px-2 py-2" /> : null}
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
                  {expansion ? (
                    <td className="px-2 py-2.5">
                      <Skeleton width="14px" height="12px" />
                    </td>
                  ) : null}
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
            : rows.map((row) => {
                const open = expansion?.isExpanded(row) ?? false;
                return (
                <Fragment key={rowKey(row)}>
                <tr
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
                    open && 'border-b-0',
                    rowClassName?.(row),
                  )}
                >
                  {expansion ? (
                    <td className="px-2 py-2.5 align-top">
                      <IconButton
                        title={expansion.label(row)}
                        aria-expanded={open}
                        onClick={(e) => {
                          e.stopPropagation();
                          expansion.onToggle(row);
                        }}
                      >
                        <ChevronRightIcon
                          className={clsx('h-3.5 w-3.5 transition-transform', open && 'rotate-90')}
                        />
                      </IconButton>
                    </td>
                  ) : null}
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
                {open && expansion ? (
                  <tr data-expansion className="border-b border-line-2 last:border-b-0">
                    <td colSpan={columns.length + leadingCells} className="border-t border-line-2 bg-surface-2 px-4 py-3">
                      {expansion.render(row)}
                    </td>
                  </tr>
                ) : null}
                </Fragment>
                );
              })}
        </tbody>
        {foot && !loading ? <tfoot>{foot}</tfoot> : null}
      </table>
    </div>
  );
}
