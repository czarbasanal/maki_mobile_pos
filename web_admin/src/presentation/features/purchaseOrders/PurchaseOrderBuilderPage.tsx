// Planning a buying trip: what to buy, how many, and what it will cost.
//
// This is where the reorder engine now lives. It used to be a standalone
// report under Inventory that could only export a CSV — a list of what to buy
// with no way to act on it. Answering "what should I buy" and "buy it" are the
// same act, so they are the same screen.
import { useEffect, useMemo, useState } from 'react';
import { startOfDay } from 'date-fns';
import { useNavigate } from 'react-router-dom';
import { REORDER_SALES_CAP, useReorderSuggestions } from '@/presentation/hooks/useReorderSuggestions';
import { useCreatePurchaseOrder } from '@/presentation/hooks/usePurchaseOrders';
import { CappedNotice } from '@/presentation/components/common/CappedNotice';
import { LoadingView } from '@/presentation/components/common/LoadingView';
import { ErrorView } from '@/presentation/components/common/ErrorView';
import { EmptyState } from '@/presentation/components/common/EmptyState';
import { BackLink } from '@/presentation/components/common/BackLink';
import { RoutePaths } from '@/presentation/router/routePaths';
import { formatMoney } from '@/core/utils/money';
import { displaySku } from '@/domain/products/sku';
import { cn } from '@/core/utils/cn';
import type { ReorderParams } from '@/domain/reorder/computeReorderSuggestions';
import type { PurchaseOrderItem } from '@/domain/entities';

const WINDOWS = [7, 14, 30, 90];

export function PurchaseOrderBuilderPage() {
  const todayKey = startOfDay(new Date()).getTime();
  const now = useMemo(() => new Date(todayKey), [todayKey]);
  const [windowDays, setWindowDays] = useState(30);
  const [coverDays, setCoverDays] = useState(14);
  const params: ReorderParams = { windowDays, coverDays };
  const { rows, isLoading, error, capped } = useReorderSuggestions(params, now);
  const create = useCreatePurchaseOrder();
  const navigate = useNavigate();

  // Ticked lines and quantity edits, both keyed by product id. Recomputing the
  // suggestions resets them — the rows underneath have changed.
  const [picked, setPicked] = useState<Set<string>>(new Set());
  const [qty, setQty] = useState<Record<string, number>>({});
  useEffect(() => {
    setPicked(new Set(rows.map((r) => r.product.id)));
    setQty({});
  }, [rows]);

  useEffect(() => {
    document.title = 'New purchase order · MAKI POS Admin';
  }, []);

  const qtyOf = (id: string, fallback: number) => qty[id] ?? fallback;
  const allPicked = rows.length > 0 && picked.size === rows.length;
  const somePicked = picked.size > 0 && !allPicked;

  const chosen = rows.filter((r) => picked.has(r.product.id));
  const totalUnits = chosen.reduce((n, r) => n + qtyOf(r.product.id, r.suggestedQty), 0);
  const totalCost = chosen.reduce(
    (n, r) => n + qtyOf(r.product.id, r.suggestedQty) * r.product.cost,
    0,
  );

  function toggleAll() {
    setPicked(allPicked ? new Set() : new Set(rows.map((r) => r.product.id)));
  }

  function toggle(id: string) {
    setPicked((prev) => {
      const next = new Set(prev);
      if (next.has(id)) next.delete(id);
      else next.add(id);
      return next;
    });
  }

  async function save(status: 'draft' | 'ordered') {
    const items: PurchaseOrderItem[] = chosen.map((r) => ({
      id: crypto.randomUUID(),
      productId: r.product.id,
      sku: r.product.sku,
      name: r.product.name,
      quantity: qtyOf(r.product.id, r.suggestedQty),
      unit: r.product.unit,
      unitCost: r.product.cost,
      costCode: r.product.costCode ?? '',
      // Decided on the road, not here.
      supplierId: null,
      supplierName: null,
    }));
    const created = await create.mutateAsync({ items, notes: null, status });
    navigate(`${RoutePaths.purchaseOrders}/${created.id}`);
  }

  if (error) return <ErrorView title="Could not build the list" message={error.message} />;
  if (isLoading) return <LoadingView label="Working out what to buy…" />;

  return (
    <div className="space-y-tk-lg">
      <header className="space-y-tk-xs">
        <BackLink fallback={RoutePaths.purchaseOrders} />
        <div className="flex flex-wrap items-end justify-end gap-tk-md">
          <div className="flex items-center gap-tk-sm text-bodySmall text-light-text-secondary">
            <label className="flex items-center gap-tk-xs">
              Movement window
              <select
                aria-label="Movement window"
                value={windowDays}
                onChange={(e) => setWindowDays(Number(e.target.value))}
                className="rounded-md border border-light-border bg-light-card px-tk-sm py-[6px] text-light-text"
              >
                {WINDOWS.map((w) => <option key={w} value={w}>{w} days</option>)}
              </select>
            </label>
            <label className="flex items-center gap-tk-xs">
              Cover
              <select
                aria-label="Cover days"
                value={coverDays}
                onChange={(e) => setCoverDays(Number(e.target.value))}
                className="rounded-md border border-light-border bg-light-card px-tk-sm py-[6px] text-light-text"
              >
                {[7, 14, 30].map((d) => <option key={d} value={d}>{d} days</option>)}
              </select>
            </label>
          </div>
        </div>
      </header>

      <CappedNotice capped={capped}>
        Velocity is computed from the most recent{' '}
        {REORDER_SALES_CAP.toLocaleString('en-US')} sales — it may be
        understated for this window.
      </CappedNotice>

      {rows.length === 0 ? (
        <EmptyState
          title="Nothing to buy"
          description="Nothing is out of stock, and nothing is due to run out inside the cover period."
        />
      ) : (
        <>
          <div className="overflow-x-auto rounded-lg border border-light-hairline bg-light-card">
            <table className="w-full min-w-[720px] text-bodySmall">
              <thead className="border-b border-light-hairline bg-light-subtle text-light-text-secondary">
                <tr>
                  <th className="w-[38px] px-tk-md py-tk-sm">
                    <input
                      type="checkbox"
                      aria-label="Select all"
                      checked={allPicked}
                      ref={(el) => {
                        // Indeterminate is not an attribute — it only exists
                        // on the element, and it is what makes a partial
                        // selection legible instead of just "not all".
                        if (el) el.indeterminate = somePicked;
                      }}
                      onChange={toggleAll}
                    />
                  </th>
                  <th className="px-tk-md py-tk-sm text-left font-medium">Part</th>
                  <th className="px-tk-md py-tk-sm text-right font-medium">On hand</th>
                  <th className="px-tk-md py-tk-sm text-right font-medium">Qty</th>
                  <th className="px-tk-md py-tk-sm text-right font-medium">Cost</th>
                  <th className="px-tk-md py-tk-sm text-right font-medium">Amount</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-light-hairline">
                {rows.map((r) => {
                  const id = r.product.id;
                  const q = qtyOf(id, r.suggestedQty);
                  const on = picked.has(id);
                  return (
                    <tr key={id} className={cn(!on && 'opacity-50')}>
                      <td className="px-tk-md py-tk-sm">
                        <input
                          type="checkbox"
                          aria-label={`Include ${r.product.name}`}
                          checked={on}
                          onChange={() => toggle(id)}
                        />
                      </td>
                      <td className="px-tk-md py-tk-sm">
                        <span className="font-medium text-light-text">{r.product.name}</span>
                        {r.outOfStock ? (
                          <span className="ml-tk-sm rounded-full bg-error-light px-tk-sm py-[1px] text-[10px] font-semibold uppercase text-error-dark">
                            Out
                          </span>
                        ) : null}
                        <br />
                        <span className="font-mono text-[12px] text-light-text-hint">
                          {displaySku(r.product.sku)}
                        </span>
                        {r.supplierName ? (
                          <span className="ml-tk-sm text-[12px] text-light-text-hint">
                            {r.supplierName}
                          </span>
                        ) : null}
                      </td>
                      <td className="px-tk-md py-tk-sm text-right tabular-nums">{r.product.quantity}</td>
                      <td className="px-tk-md py-tk-sm text-right">
                        <input
                          type="number"
                          min={1}
                          aria-label={`Quantity for ${r.product.name}`}
                          value={q}
                          onChange={(e) =>
                            setQty((prev) => ({ ...prev, [id]: Math.max(1, Number(e.target.value) || 1) }))
                          }
                          className="w-[72px] rounded-md border border-light-border bg-light-card px-tk-sm py-[4px] text-right tabular-nums text-light-text"
                        />
                      </td>
                      <td className="px-tk-md py-tk-sm text-right tabular-nums">{formatMoney(r.product.cost)}</td>
                      <td className="px-tk-md py-tk-sm text-right tabular-nums font-medium">
                        {formatMoney(q * r.product.cost)}
                      </td>
                    </tr>
                  );
                })}
              </tbody>
            </table>
          </div>

          {create.error ? (
            <p className="rounded-md border border-error-light bg-error-light/40 px-tk-md py-tk-sm text-bodySmall text-error-dark">
              {create.error.message}
            </p>
          ) : null}

          <div className="flex flex-wrap items-center justify-between gap-tk-md rounded-lg border border-light-hairline bg-light-subtle px-tk-lg py-tk-md">
            <div>
              <p className="text-bodySmall text-light-text-secondary">
                {chosen.length} of {rows.length} parts · {totalUnits} units
              </p>
              <p className="text-headingSmall font-semibold tabular-nums text-light-text">
                {formatMoney(totalCost)}
              </p>
            </div>
            <div className="flex gap-tk-sm">
              <button
                type="button"
                disabled={chosen.length === 0 || create.isPending}
                onClick={() => save('draft')}
                className="rounded-md border border-light-border px-tk-lg py-tk-sm text-bodySmall font-medium text-light-text hover:bg-light-card disabled:opacity-50"
              >
                Save as draft
              </button>
              <button
                type="button"
                disabled={chosen.length === 0 || create.isPending}
                onClick={() => save('ordered')}
                className="rounded-md bg-light-text px-tk-lg py-tk-sm text-bodySmall font-semibold text-light-background hover:bg-primary-dark disabled:opacity-50"
              >
                {create.isPending ? 'Saving…' : 'Confirm PO'}
              </button>
            </div>
          </div>
        </>
      )}
    </div>
  );
}
