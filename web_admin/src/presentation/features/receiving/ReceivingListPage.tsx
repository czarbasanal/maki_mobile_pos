import { useEffect, useState } from 'react';
import { Link, useNavigate } from 'react-router-dom';
import { ArrowUpTrayIcon } from '@heroicons/react/24/outline';
import { resolvePreset, type DateRange } from '@/domain/reports/dateRange';
import { useReceivings } from '@/presentation/hooks/useReceivings';
import { formatMoney } from '@/core/utils/money';
import { DateRangePicker } from '@/presentation/components/common/DateRangePicker';
import { LoadingView } from '@/presentation/components/common/LoadingView';
import { ErrorView } from '@/presentation/components/common/ErrorView';
import { EmptyState } from '@/presentation/components/common/EmptyState';
import { RoutePaths } from '@/presentation/router/routePaths';
import { ReceivingStatusBadge } from './ReceivingStatusBadge';

const dtFmt = new Intl.DateTimeFormat('en-PH', { dateStyle: 'medium', timeStyle: 'short' });

export function ReceivingListPage() {
  const [range, setRange] = useState<DateRange>(() => resolvePreset('last7'));
  const { data: receivings, isLoading, error } = useReceivings(range);
  const navigate = useNavigate();

  useEffect(() => {
    document.title = 'Receiving · MAKI POS Admin';
  }, []);

  return (
    <div className="space-y-tk-xl px-tk-xl py-tk-lg">
      <header className="flex flex-wrap items-end justify-between gap-tk-md">
        <div>
          <h1 className="text-headingMedium font-semibold tracking-tight text-light-text">
            Receiving
          </h1>
          <p className="mt-tk-xs text-bodySmall text-light-text-secondary">
            Stock received from suppliers in the selected range.
          </p>
        </div>
        <div className="flex flex-wrap items-center gap-tk-sm">
          <DateRangePicker onChange={setRange} />
          <button
            type="button"
            disabled
            title="Coming soon"
            className="inline-flex cursor-not-allowed items-center gap-tk-xs rounded-md border border-light-border px-tk-md py-[8px] text-bodySmall text-light-text opacity-50"
          >
            + New Receiving
          </button>
          <Link
            to={RoutePaths.bulkReceiving}
            className="inline-flex items-center gap-tk-xs rounded-md border border-light-border px-tk-md py-[8px] text-bodySmall text-light-text hover:bg-light-subtle"
          >
            <ArrowUpTrayIcon className="h-4 w-4" />
            Bulk import
          </Link>
        </div>
      </header>

      {error ? (
        <ErrorView title="Could not load receivings" message={error.message} />
      ) : isLoading ? (
        <div className="h-32">
          <LoadingView label="Loading receivings…" />
        </div>
      ) : !receivings || receivings.length === 0 ? (
        <EmptyState
          title="No receivings in this range"
          description="Try a wider date range, or use Bulk import to record received stock."
        />
      ) : (
        <section className="overflow-hidden rounded-lg border border-light-hairline bg-light-card">
          <table className="w-full text-bodySmall">
            <thead className="border-b border-light-hairline bg-light-subtle text-light-text-secondary">
              <tr>
                <th className="px-tk-md py-tk-sm text-left font-medium">Reference</th>
                <th className="px-tk-md py-tk-sm text-left font-medium">Date</th>
                <th className="px-tk-md py-tk-sm text-left font-medium">Supplier</th>
                <th className="px-tk-md py-tk-sm text-right font-medium">Items</th>
                <th className="px-tk-md py-tk-sm text-right font-medium">Total</th>
                <th className="px-tk-md py-tk-sm text-left font-medium">Status</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-light-hairline">
              {receivings.map((r) => (
                <tr
                  key={r.id}
                  onClick={() => navigate(`/receiving/bulk/${r.id}`)}
                  className="cursor-pointer hover:bg-light-subtle"
                >
                  <td className="px-tk-md py-tk-sm font-medium text-light-text">
                    {r.referenceNumber}
                  </td>
                  <td className="px-tk-md py-tk-sm text-light-text-secondary">
                    {dtFmt.format(r.completedAt ?? r.createdAt)}
                  </td>
                  <td className="px-tk-md py-tk-sm text-light-text-secondary">
                    {r.supplierName ?? '—'}
                  </td>
                  <td className="px-tk-md py-tk-sm text-right tabular-nums">{r.totalQuantity}</td>
                  <td className="px-tk-md py-tk-sm text-right tabular-nums">
                    {formatMoney(r.totalCost)}
                  </td>
                  <td className="px-tk-md py-tk-sm">
                    <ReceivingStatusBadge status={r.status} />
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </section>
      )}
    </div>
  );
}
