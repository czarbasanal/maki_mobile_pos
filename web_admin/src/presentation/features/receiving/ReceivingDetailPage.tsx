import { useEffect } from 'react';
import { Link, useParams } from 'react-router-dom';
import { useReceiving } from '@/presentation/hooks/useReceiving';
import { formatMoney } from '@/core/utils/money';
import { LoadingView } from '@/presentation/components/common/LoadingView';
import { ErrorView } from '@/presentation/components/common/ErrorView';
import { EmptyState } from '@/presentation/components/common/EmptyState';
import { RoutePaths } from '@/presentation/router/routePaths';
import { ReceivingStatusBadge } from './ReceivingStatusBadge';

const dtFmt = new Intl.DateTimeFormat('en-PH', { dateStyle: 'medium', timeStyle: 'short' });

export function ReceivingDetailPage() {
  const { id = '' } = useParams();
  const { data: receiving, isLoading, error } = useReceiving(id);

  useEffect(() => {
    document.title = 'Receiving detail · MAKI POS Admin';
  }, []);

  if (isLoading) {
    return (
      <div className="p-tk-xl">
        <LoadingView label="Loading receiving…" />
      </div>
    );
  }
  if (error) {
    return (
      <div className="p-tk-xl">
        <ErrorView title="Could not load receiving" message={(error as Error).message} />
      </div>
    );
  }
  if (!receiving) {
    return (
      <div className="p-tk-xl">
        <EmptyState
          title="Receiving not found"
          description="It may have been removed."
          action={
            <Link to={RoutePaths.receiving} className="text-light-text underline">
              Back to receiving
            </Link>
          }
        />
      </div>
    );
  }

  return (
    <div className="space-y-tk-lg px-tk-xl py-tk-lg">
      <header className="space-y-tk-xs">
        <Link
          to={RoutePaths.receiving}
          className="text-bodySmall text-light-text-secondary hover:underline"
        >
          ← Back to receiving
        </Link>
        <div className="flex items-center gap-tk-md">
          <h1 className="text-headingMedium font-semibold tracking-tight text-light-text">
            {receiving.referenceNumber}
          </h1>
          <ReceivingStatusBadge status={receiving.status} />
        </div>
        <p className="text-bodySmall text-light-text-secondary">
          {receiving.supplierName ?? 'No supplier'} ·{' '}
          {dtFmt.format(receiving.completedAt ?? receiving.createdAt)} · {receiving.createdByName}
        </p>
      </header>

      <section className="overflow-hidden rounded-lg border border-light-hairline bg-light-card">
        <table className="w-full text-bodySmall">
          <thead className="border-b border-light-hairline bg-light-subtle text-light-text-secondary">
            <tr>
              <th className="px-tk-md py-tk-sm text-left font-medium">Item</th>
              <th className="px-tk-md py-tk-sm text-right font-medium">Qty</th>
              <th className="px-tk-md py-tk-sm text-right font-medium">Unit cost</th>
              <th className="px-tk-md py-tk-sm text-right font-medium">Line total</th>
            </tr>
          </thead>
          <tbody className="divide-y divide-light-hairline">
            {receiving.items.map((it, index) => (
              // Legacy/web-written items can have an empty id; fall back to the
              // (stable, non-reordering) array index so keys stay unique.
              <tr key={it.id || index}>
                <td className="px-tk-md py-tk-sm">
                  <span className="font-medium text-light-text">{it.name}</span>
                  <span className="ml-tk-sm text-light-text-hint">{it.sku}</span>
                  {it.isNewVariation ? (
                    <span className="ml-tk-sm rounded-full bg-info-light px-tk-sm py-[1px] text-[10px] font-semibold uppercase text-info-dark">
                      New variation
                    </span>
                  ) : null}
                </td>
                <td className="px-tk-md py-tk-sm text-right tabular-nums">{it.quantity}</td>
                <td className="px-tk-md py-tk-sm text-right tabular-nums">
                  {formatMoney(it.unitCost)}
                </td>
                <td className="px-tk-md py-tk-sm text-right tabular-nums">
                  {formatMoney(it.unitCost * it.quantity)}
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      </section>

      <section className="ml-auto w-full max-w-sm space-y-tk-xs rounded-lg border border-light-hairline bg-light-card p-tk-lg text-bodySmall">
        <div className="flex justify-between">
          <span className="text-light-text-secondary">Total items</span>
          <span className="tabular-nums text-light-text">{receiving.totalQuantity}</span>
        </div>
        <div className="flex justify-between border-t border-light-hairline pt-tk-xs">
          <span className="font-semibold text-light-text">Total cost</span>
          <span className="tabular-nums font-semibold text-light-text">
            {formatMoney(receiving.totalCost)}
          </span>
        </div>
      </section>
    </div>
  );
}
