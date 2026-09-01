// The purchase-order log: three tabs over the statuses that already exist in
// the data, so nothing new had to be invented to describe a buying trip.
import { useEffect, useMemo, useState } from 'react';
import { Link } from 'react-router-dom';
import { usePurchaseOrders } from '@/presentation/hooks/usePurchaseOrders';
import { LoadingView } from '@/presentation/components/common/LoadingView';
import { ErrorView } from '@/presentation/components/common/ErrorView';
import { EmptyState } from '@/presentation/components/common/EmptyState';
import { RoutePaths } from '@/presentation/router/routePaths';
import { formatMoney } from '@/core/utils/money';
import { cn } from '@/core/utils/cn';
import { isPendingPurchaseOrder, type PurchaseOrder } from '@/domain/entities';

type Tab = 'pending' | 'completed' | 'cancelled';

const TABS: { key: Tab; label: string }[] = [
  { key: 'pending', label: 'Pending' },
  { key: 'completed', label: 'Completed' },
  { key: 'cancelled', label: 'Cancelled' },
];

const dateFmt = new Intl.DateTimeFormat('en-PH', {
  month: 'short',
  day: 'numeric',
  year: 'numeric',
});

export function PurchaseOrdersPage() {
  const { data: orders, isLoading, error } = usePurchaseOrders();
  const [tab, setTab] = useState<Tab>('pending');

  useEffect(() => {
    document.title = 'Purchase Orders · MAKI POS Admin';
  }, []);

  const byTab = useMemo(() => {
    const all = orders ?? [];
    return {
      // Draft and ordered together: both are unfinished business — one still
      // being written, one out being bought.
      pending: all.filter(isPendingPurchaseOrder),
      completed: all.filter((o) => o.status === 'received'),
      cancelled: all.filter((o) => o.status === 'cancelled'),
    };
  }, [orders]);

  if (error) return <ErrorView title="Could not load purchase orders" message={error.message} />;
  if (isLoading) return <LoadingView label="Loading purchase orders…" />;

  const rows = byTab[tab];

  return (
    <div className="space-y-tk-lg">
      <div className="flex justify-end">
        <Link
          to={RoutePaths.purchaseOrderNew}
          className="rounded-md bg-light-text px-tk-md py-tk-sm text-bodySmall font-semibold text-light-background hover:bg-primary-dark"
        >
          New purchase order
        </Link>
      </div>

      <div className="flex gap-tk-lg border-b border-light-hairline">
        {TABS.map((t) => (
          <button
            key={t.key}
            type="button"
            onClick={() => setTab(t.key)}
            className={cn(
              'flex items-center gap-tk-xs pb-tk-sm text-bodySmall',
              tab === t.key
                ? 'border-b-2 border-light-text font-semibold text-light-text'
                : 'text-light-text-secondary hover:text-light-text',
            )}
          >
            {t.label}
            <span className="text-[12px] text-light-text-hint">
              {byTab[t.key].length}
            </span>
          </button>
        ))}
      </div>

      {rows.length === 0 ? (
        <EmptyState
          title={`Nothing ${tab}`}
          description={
            tab === 'pending'
              ? 'Start a purchase order to plan a buying trip.'
              : 'Orders show up here once they reach this state.'
          }
        />
      ) : (
        <div className="overflow-hidden rounded-lg border border-light-hairline bg-light-card">
          <table className="w-full text-bodySmall">
            <thead className="border-b border-light-hairline bg-light-subtle text-light-text-secondary">
              <tr>
                <th className="px-tk-md py-tk-sm text-left font-medium">Reference</th>
                <th className="px-tk-md py-tk-sm text-right font-medium">Parts</th>
                <th className="px-tk-md py-tk-sm text-right font-medium">Units</th>
                <th className="px-tk-md py-tk-sm text-right font-medium">Amount</th>
                <th className="px-tk-md py-tk-sm text-left font-medium">Created</th>
                <th className="px-tk-md py-tk-sm text-left font-medium">Status</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-light-hairline">
              {rows.map((po) => (
                <tr key={po.id}>
                  <td className="px-tk-md py-tk-sm">
                    <Link
                      to={`${RoutePaths.purchaseOrders}/${po.id}`}
                      className="font-mono font-medium text-light-text hover:underline"
                    >
                      {po.referenceNumber}
                    </Link>
                  </td>
                  <td className="px-tk-md py-tk-sm text-right tabular-nums">{po.items.length}</td>
                  <td className="px-tk-md py-tk-sm text-right tabular-nums">{po.totalQuantity}</td>
                  <td className="px-tk-md py-tk-sm text-right tabular-nums font-semibold">
                    {formatMoney(po.totalCost)}
                  </td>
                  <td className="px-tk-md py-tk-sm text-light-text-secondary">
                    {dateFmt.format(po.createdAt)} · {po.createdByName}
                  </td>
                  <td className="px-tk-md py-tk-sm">
                    <StatusPill status={po.status} />
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      )}
    </div>
  );
}

function StatusPill({ status }: { status: PurchaseOrder['status'] }) {
  const tone =
    status === 'received'
      ? 'bg-success-light/40 text-success-dark'
      : status === 'cancelled'
        ? 'bg-light-subtle text-light-text-hint'
        : 'bg-warning-light/40 text-warning-dark';
  const label =
    status === 'received'
      ? 'Completed'
      : status === 'ordered'
        ? 'Out buying'
        : status === 'cancelled'
          ? 'Cancelled'
          : 'Draft';
  return (
    <span className={cn('rounded-full px-tk-sm py-[1px] text-[11px] font-semibold uppercase tracking-wider', tone)}>
      {label}
    </span>
  );
}
