import { useEffect, useMemo, useState, type ReactNode } from 'react';
import { useNavigate } from 'react-router-dom';
import { TrashIcon } from '@heroicons/react/24/outline';
import { useJobOrders } from '@/presentation/hooks/useJobOrders';
import { useDeleteJobOrder } from '@/presentation/hooks/useJobOrderMutations';
import { useCartStore } from '@/presentation/stores/cartStore';
import { cartGrandTotal } from '@/domain/sales/cart';
import { formatMoney } from '@/core/utils/money';
import { RoutePaths } from '@/presentation/router/routePaths';
import { LoadingView } from '@/presentation/components/common/LoadingView';
import { ErrorView } from '@/presentation/components/common/ErrorView';
import { EmptyState } from '@/presentation/components/common/EmptyState';
import { Pager } from '@/presentation/components/common/Pager';
import { usePageClamp } from '@/presentation/hooks/usePageClamp';
import { usePageSize } from '@/presentation/hooks/usePageSize';
import { cn } from '@/core/utils/cn';
import type { JobOrder } from '@/domain/entities';
import { DateRangePicker } from '@/presentation/components/common/DateRangePicker';
import { resolvePreset, type DateRange } from '@/domain/reports/dateRange';

const dateFmt = new Intl.DateTimeFormat('en-PH', { month: 'short', day: 'numeric' });

function Th({ children, className }: { children: ReactNode; className?: string }) {
  return <th className={cn('px-tk-md py-tk-sm text-left font-medium', className)}>{children}</th>;
}
function Td({ children, className }: { children: ReactNode; className?: string }) {
  return <td className={cn('px-tk-md py-tk-sm', className)}>{children}</td>;
}

export function JobOrdersPage() {
  useEffect(() => {
    document.title = 'Job Orders · MAKI POS Admin';
  }, []);

  const { data: jobOrders, isLoading, error } = useJobOrders();
  const lines = useCartStore((s) => s.lines);
  const loadJobOrder = useCartStore((s) => s.loadJobOrder);
  const deleteJobOrder = useDeleteJobOrder();
  const navigate = useNavigate();

  // Today by default: the list is opened to work the day's tickets, and it
  // used to render every job order ever created, newest first.
  const [range, setRange] = useState<DateRange | null>(() => resolvePreset('today'));

  const inRange = useMemo(() => {
    const all = jobOrders ?? [];
    if (!range) return all;
    return all.filter(
      (jo) => jo.createdAt >= range.start && jo.createdAt <= range.end,
    );
  }, [jobOrders, range]);

  // A bike left overnight is still an open ticket. Filtering by date would
  // hide it, so say how many are out there rather than losing them quietly.
  const openOutsideRange = useMemo(() => {
    if (!range) return 0;
    return (jobOrders ?? []).filter(
      (jo) =>
        !jo.isConverted &&
        (jo.createdAt < range.start || jo.createdAt > range.end),
    ).length;
  }, [jobOrders, range]);

  const [page, setPage] = useState(1);
  const [pageSize, setPageSize] = usePageSize('jobOrders');
  usePageClamp(page, setPage, inRange.length, pageSize);
  const paged = useMemo(
    () => inRange.slice((page - 1) * pageSize, page * pageSize),
    [inRange, page, pageSize],
  );

  const onResume = (jobOrder: JobOrder) => {
    if (lines.length > 0 && !window.confirm('Replace the current cart with this Job Order?')) return;
    loadJobOrder(jobOrder);
    navigate(RoutePaths.pos);
  };
  const onDelete = (jobOrder: JobOrder) => {
    if (!window.confirm(`Delete Job Order "${jobOrder.name}"?`)) return;
    deleteJobOrder.mutate({ id: jobOrder.id, name: jobOrder.name });
  };

  return (
    <div className="space-y-tk-xl px-tk-xl py-tk-lg">
      <header className="space-y-tk-sm">
        <h1 className="text-headingMedium font-semibold tracking-tight text-light-text">Job Orders</h1>
        <div className="flex flex-wrap items-center gap-tk-sm">
          <DateRangePicker onChange={setRange} defaultPreset="today" />
          {range ? (
            <button
              type="button"
              onClick={() => setRange(null)}
              className="rounded-md border border-light-border px-tk-md py-[8px] text-bodySmall text-light-text hover:bg-light-subtle"
            >
              Show all dates
            </button>
          ) : (
            <button
              type="button"
              onClick={() => setRange(resolvePreset('today'))}
              className="rounded-md border border-light-border px-tk-md py-[8px] text-bodySmall text-light-text hover:bg-light-subtle"
            >
              Back to today
            </button>
          )}
        </div>
        {openOutsideRange > 0 ? (
          <p className="text-bodySmall text-light-text-secondary">
            {openOutsideRange} open job order{openOutsideRange === 1 ? '' : 's'}{' '}
            outside this range.{' '}
            <button
              type="button"
              onClick={() => setRange(null)}
              className="underline hover:text-light-text"
            >
              Show all dates
            </button>
          </p>
        ) : null}
        <p className="mt-tk-xs text-bodySmall text-light-text-secondary">
          Service tickets — resume an open one into the POS, or open a billed one to view its sale.
        </p>
      </header>

      {deleteJobOrder.error ? (
        <p className="rounded-md border border-error-light bg-error-light/40 px-tk-md py-tk-sm text-bodySmall text-error-dark">
          Could not delete the Job Order: {deleteJobOrder.error.message}
        </p>
      ) : null}

      {error ? (
        <ErrorView title="Could not load Job Orders" message={error.message} />
      ) : isLoading || !jobOrders ? (
        <LoadingView label="Loading…" />
      ) : jobOrders.length === 0 ? (
        <EmptyState title="No Job Orders yet" description="Hold a cart from the POS with “Save as Job Order”." />
      ) : (
        <div className="overflow-hidden rounded-lg border border-light-hairline bg-light-card">
          <table className="w-full text-bodySmall">
            <thead className="border-b border-light-hairline bg-light-subtle text-light-text-secondary">
              <tr>
                <Th>JO #</Th>
                <Th>Status</Th>
                <Th>Mechanic</Th>
                <Th>Motorcycle</Th>
                <Th className="text-right">Total</Th>
                <Th>Date</Th>
                <Th className="text-right">&nbsp;</Th>
              </tr>
            </thead>
            <tbody className="divide-y divide-light-hairline">
              {paged.map((jo) => {
                const billed = jo.isConverted;
                const total = cartGrandTotal(jo.items, jo.laborLines, jo.discountType, jo.feeLines);
                return (
                  <tr key={jo.id} className={cn(!billed && 'hover:bg-light-subtle')}>
                    <Td
                      className={cn(
                        'font-mono font-medium',
                        billed ? 'text-light-text-hint' : 'text-light-text',
                      )}
                    >
                      {jo.name}
                    </Td>
                    <Td>
                      {billed ? (
                        <span className="rounded-full bg-light-subtle px-tk-sm py-[1px] text-[11px] font-semibold uppercase tracking-wider text-light-text-hint">
                          Billed
                        </span>
                      ) : (
                        <span className="rounded-full bg-success-light/40 px-tk-sm py-[1px] text-[11px] font-semibold uppercase tracking-wider text-success-dark">
                          Open
                        </span>
                      )}
                    </Td>
                    <Td className={billed ? 'text-light-text-hint' : 'text-light-text-secondary'}>
                      {jo.mechanicName ?? '—'}
                    </Td>
                    <Td className={billed ? 'text-light-text-hint' : 'text-light-text-secondary'}>
                      {jo.motorcycleModel ?? '—'}
                    </Td>
                    <Td
                      className={cn(
                        'text-right font-semibold tabular-nums',
                        billed ? 'text-light-text-hint' : 'text-light-text',
                      )}
                    >
                      {formatMoney(total)}
                    </Td>
                    <Td className={billed ? 'text-light-text-hint' : 'text-light-text-secondary'}>
                      {dateFmt.format(jo.createdAt)}
                    </Td>
                    <Td className="text-right">
                      <div className="flex items-center justify-end gap-tk-sm">
                        {billed ? (
                          // The edit route refuses converted JOs ("already
                          // billed out"), so View goes to the converted sale
                          // — the record that actually holds the data now.
                          jo.convertedToSaleId ? (
                            <button
                              type="button"
                              onClick={() =>
                                navigate(RoutePaths.saleDetail.replace(':id', jo.convertedToSaleId!))
                              }
                              className="rounded-md border border-light-border px-tk-md py-[6px] text-[12px] font-medium text-light-text-secondary hover:bg-light-subtle"
                            >
                              View sale
                            </button>
                          ) : null
                        ) : (
                          <>
                            <button
                              type="button"
                              onClick={() => navigate(`${RoutePaths.jobOrders}/${jo.id}`)}
                              className="rounded-md border border-light-border px-tk-md py-[6px] text-[12px] font-medium text-light-text hover:bg-light-subtle"
                            >
                              Edit
                            </button>
                            <button
                              type="button"
                              onClick={() => onResume(jo)}
                              className="rounded-md bg-light-text px-tk-md py-[6px] text-[12px] font-semibold text-light-background hover:bg-primary-dark"
                            >
                              Resume
                            </button>
                            <button
                              type="button"
                              onClick={() => onDelete(jo)}
                              className="text-light-text-hint hover:text-error"
                              aria-label="Delete Job Order"
                            >
                              <TrashIcon className="h-4 w-4" />
                            </button>
                          </>
                        )}
                      </div>
                    </Td>
                  </tr>
                );
              })}
            </tbody>
          </table>
          <Pager total={jobOrders.length} page={page} onPage={setPage} pageSize={pageSize}
            onPageSize={(n) => { setPageSize(n); setPage(1); }} />
        </div>
      )}
    </div>
  );
}
