// One buying list. The supplier column is the point: it is filled in as you
// work the route, not decided up front.
import { useEffect } from 'react';
import { useParams } from 'react-router-dom';
import {
  useCancelPurchaseOrder,
  usePurchaseOrder,
  useUpdatePurchaseOrder,
} from '@/presentation/hooks/usePurchaseOrders';
import { useSuppliers } from '@/presentation/hooks/useSuppliers';
import { LoadingView } from '@/presentation/components/common/LoadingView';
import { ErrorView } from '@/presentation/components/common/ErrorView';
import { EmptyState } from '@/presentation/components/common/EmptyState';
import { BackLink } from '@/presentation/components/common/BackLink';
import { RoutePaths } from '@/presentation/router/routePaths';
import { formatMoney } from '@/core/utils/money';
import { displaySku } from '@/domain/products/sku';
import { isPendingPurchaseOrder } from '@/domain/entities';

export function PurchaseOrderDetailPage() {
  const { id = '' } = useParams();
  const { data: po, isLoading, error } = usePurchaseOrder(id);
  const { data: suppliers } = useSuppliers();
  const update = useUpdatePurchaseOrder();
  const cancel = useCancelPurchaseOrder();

  useEffect(() => {
    document.title = 'Purchase order · MAKI POS Admin';
  }, []);

  if (error) return <ErrorView title="Could not load the purchase order" message={error.message} />;
  if (isLoading) return <LoadingView label="Loading purchase order…" />;
  if (!po) {
    return <EmptyState title="Purchase order not found" description="It may have been deleted." />;
  }

  const editable = isPendingPurchaseOrder(po);

  function setLineSupplier(lineId: string, supplierId: string) {
    if (!po) return;
    const supplier = (suppliers ?? []).find((s) => s.id === supplierId) ?? null;
    update.mutate({
      id: po.id,
      patch: {
        items: po.items.map((i) =>
          i.id === lineId
            ? { ...i, supplierId: supplier?.id ?? null, supplierName: supplier?.name ?? null }
            : i,
        ),
      },
    });
  }

  return (
    <div className="space-y-tk-lg">
      <header className="space-y-tk-xs">
        <BackLink fallback={RoutePaths.purchaseOrders} />
        <div className="flex flex-wrap items-baseline justify-between gap-tk-md">
          <h2 className="font-mono text-headingMedium font-semibold tracking-tight text-light-text">
            {po.referenceNumber}
          </h2>
          <span className="text-bodySmall text-light-text-secondary">
            {po.items.length} parts · {po.totalQuantity} units ·{' '}
            <span className="font-semibold text-light-text">{formatMoney(po.totalCost)}</span>
          </span>
        </div>
        <p className="text-bodySmall text-light-text-secondary">
          Created by {po.createdByName}. Set where each part was bought as you go.
          {po.windowDays != null && po.coverDays != null ? (
            <span className="block text-[12px] text-light-text-hint">
              Quantities suggested from a {po.windowDays}-day movement window with{' '}
              {po.coverDays} days of cover.
            </span>
          ) : null}
        </p>
      </header>

      {editable ? (
        <div className="flex flex-wrap gap-tk-sm">
          {po.status === 'draft' ? (
            <button
              type="button"
              onClick={() => update.mutate({ id: po.id, patch: { status: 'ordered' } })}
              className="rounded-md bg-light-text px-tk-md py-tk-sm text-bodySmall font-semibold text-light-background hover:bg-primary-dark"
            >
              Confirm PO
            </button>
          ) : null}
          <button
            type="button"
            onClick={() => {
              if (window.confirm(`Cancel ${po.referenceNumber}?`)) cancel.mutate(po);
            }}
            className="rounded-md border border-light-border px-tk-md py-tk-sm text-bodySmall font-medium text-light-text hover:bg-light-subtle"
          >
            Cancel this order
          </button>
        </div>
      ) : null}

      <div className="overflow-x-auto rounded-lg border border-light-hairline bg-light-card">
        <table className="w-full min-w-[680px] text-bodySmall">
          <thead className="border-b border-light-hairline bg-light-subtle text-light-text-secondary">
            <tr>
              <th className="px-tk-md py-tk-sm text-left font-medium">Part</th>
              <th className="px-tk-md py-tk-sm text-right font-medium">Qty</th>
              <th className="px-tk-md py-tk-sm text-right font-medium">Amount</th>
              <th className="px-tk-md py-tk-sm text-left font-medium">Bought from</th>
            </tr>
          </thead>
          <tbody className="divide-y divide-light-hairline">
            {po.items.map((i) => (
              <tr key={i.id}>
                <td className="px-tk-md py-tk-sm">
                  <span className="font-medium text-light-text">{i.name}</span>
                  <br />
                  <span className="font-mono text-[12px] text-light-text-hint">
                    {displaySku(i.sku)}
                  </span>
                </td>
                <td className="px-tk-md py-tk-sm text-right tabular-nums">{i.quantity}</td>
                <td className="px-tk-md py-tk-sm text-right tabular-nums">
                  {formatMoney(i.unitCost * i.quantity)}
                </td>
                <td className="px-tk-md py-tk-sm">
                  {editable ? (
                    <select
                      aria-label={`Supplier for ${i.name}`}
                      value={i.supplierId ?? ''}
                      onChange={(e) => setLineSupplier(i.id, e.target.value)}
                      className="rounded-md border border-light-border bg-light-card px-tk-sm py-[5px] text-bodySmall text-light-text"
                    >
                      <option value="">Not set yet</option>
                      {(suppliers ?? []).map((s) => (
                        <option key={s.id} value={s.id}>{s.name}</option>
                      ))}
                    </select>
                  ) : (
                    <span className={i.supplierName ? 'text-light-text' : 'text-light-text-hint'}>
                      {i.supplierName ?? 'Not set'}
                    </span>
                  )}
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>
    </div>
  );
}
