// New purchase order — per design/maki-pos-purchase-orders-redesign §B,
// assembled from the shared library. The builder starts from what the shelf
// actually needs (the reorder engine) and lets the buyer argue with it:
// suggested = max(0, ceil(rate × cover) − onHand), driven by the Movement
// window and Cover segmented controls in the header card. Changing either
// recomputes every line and DISCARDS manual overrides — the rows underneath
// changed, and silently mixing old overrides with new suggestions would lie.
// The sticky action bar keeps the total in view on a 200-line order.
import { useEffect, useMemo, useState } from 'react';
import { startOfDay } from 'date-fns';
import { useNavigate } from 'react-router-dom';
import { ArrowPathIcon } from '@heroicons/react/24/outline';
import { REORDER_SALES_CAP, useReorderSuggestions } from '@/presentation/hooks/useReorderSuggestions';
import { useCreatePurchaseOrder } from '@/presentation/hooks/usePurchaseOrders';
import { CappedNotice } from '@/presentation/components/common/CappedNotice';
import { ErrorView } from '@/presentation/components/common/ErrorView';
import { RoutePaths } from '@/presentation/router/routePaths';
import { formatMoney } from '@/core/utils/money';
import { displaySku } from '@/domain/products/sku';
import { cn } from '@/core/utils/cn';
import type { ReorderParams } from '@/domain/reorder/computeReorderSuggestions';
import type { BuyingListRow } from '@/domain/reorder/buyingListRows';
import type { PurchaseOrderItem } from '@/domain/entities';
import { BackButton } from '@/presentation/components/ui/BackButton';
import { Button } from '@/presentation/components/ui/Button';
import { CopyButton } from '@/presentation/components/ui/CopyButton';
import { DataTable, type Column } from '@/presentation/components/ui/DataTable';
import { NoMatchesState } from '@/presentation/components/ui/TableEmptyStates';
import { Segmented } from '@/presentation/components/ui/Segmented';
import { StickyActionBar } from '@/presentation/components/ui/StickyActionBar';
import { ViewChips } from '@/presentation/components/ui/ViewChips';

const WINDOW_OPTIONS = [
  { value: '7', label: '7 days' },
  { value: '30', label: '30 days' },
  { value: '90', label: '90 days' },
];
const COVER_OPTIONS = [
  { value: '7', label: '7 days' },
  { value: '14', label: '14 days' },
  { value: '30', label: '30 days' },
];

type Scope = 'needs' | 'out' | 'low';

export function PurchaseOrderBuilderPage() {
  const todayKey = startOfDay(new Date()).getTime();
  const now = useMemo(() => new Date(todayKey), [todayKey]);
  const [windowDays, setWindowDays] = useState(30);
  const [coverDays, setCoverDays] = useState(14);
  const params: ReorderParams = { windowDays, coverDays };
  const { rows, isLoading, error, capped } = useReorderSuggestions(params, now);
  const create = useCreatePurchaseOrder();
  const navigate = useNavigate();
  const [scope, setScope] = useState<Scope>('needs');

  // Ticked lines and quantity edits, both keyed by product id. Recomputing
  // the suggestions resets them — the rows underneath have changed. Edits
  // are RAW STRINGS so backspacing to empty doesn't snap to 1 mid-typing;
  // an empty/invalid field falls back to the suggestion (and commits back
  // to it on blur).
  const [picked, setPicked] = useState<Set<string>>(new Set());
  const [qty, setQty] = useState<Record<string, string>>({});
  useEffect(() => {
    setPicked(new Set(rows.map((r) => r.product.id)));
    setQty({});
  }, [rows]);

  useEffect(() => {
    document.title = 'New purchase order · MAKI POS Admin';
  }, []);

  const isLow = (r: BuyingListRow) => !r.outOfStock && r.product.quantity <= 10;
  const scopeCounts = useMemo(
    () => ({
      needs: rows.length,
      out: rows.filter((r) => r.outOfStock).length,
      low: rows.filter(isLow).length,
    }),
    [rows],
  );
  const visible = useMemo(
    () =>
      scope === 'needs' ? rows : rows.filter((r) => (scope === 'out' ? r.outOfStock : isLow(r))),
    [rows, scope],
  );

  const qtyOf = (id: string, fallback: number) => {
    const raw = qty[id];
    if (raw === undefined) return fallback;
    const n = Math.floor(Number(raw));
    return Number.isFinite(n) && n >= 1 ? n : fallback;
  };
  const chosen = rows.filter((r) => picked.has(r.product.id));
  const totalUnits = chosen.reduce((n, r) => n + qtyOf(r.product.id, r.suggestedQty), 0);
  const totalCost = chosen.reduce(
    (n, r) => n + qtyOf(r.product.id, r.suggestedQty) * r.product.cost,
    0,
  );
  // How many stops the trip is.
  const supplierCount = new Set(chosen.map((r) => r.supplierName ?? '(not set)')).size;

  function toggle(id: string) {
    setPicked((prev) => {
      const next = new Set(prev);
      if (next.has(id)) next.delete(id);
      else next.add(id);
      return next;
    });
  }
  function toggleAll() {
    const allVisiblePicked = visible.every((r) => picked.has(r.product.id));
    setPicked((prev) => {
      const next = new Set(prev);
      for (const r of visible) {
        if (allVisiblePicked) next.delete(r.product.id);
        else next.add(r.product.id);
      }
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
    const created = await create.mutateAsync({
      items,
      notes: null,
      status,
      // Provenance: what produced these numbers.
      windowDays,
      coverDays,
    });
    navigate(`${RoutePaths.purchaseOrders}/${created.id}`);
  }

  const columns: Array<Column<BuyingListRow>> = [
    {
      key: 'part', header: 'Part',
      render: (r) => (
        <span className="flex items-center gap-2 text-ctl-sm font-medium text-ink">
          {r.product.name}
          {r.outOfStock ? (
            <span className="rounded-[5px] bg-neg-soft px-[7px] py-0.5 text-[9.5px] font-bold tracking-[0.8px] text-neg">
              OUT
            </span>
          ) : isLow(r) ? (
            <span className="rounded-[5px] bg-accent-soft px-[7px] py-0.5 text-[9.5px] font-bold tracking-[0.8px] text-accent-text">
              LOW
            </span>
          ) : null}
        </span>
      ),
    },
    {
      key: 'sku', header: 'SKU', width: '132px', mono: true,
      render: (r) => (
        <span className="flex items-center gap-1.5 text-[12px] text-ink-2">
          {displaySku(r.product.sku)}
          <CopyButton value={r.product.sku} label="SKU" />
        </span>
      ),
    },
    {
      key: 'supplier', header: 'Buy from',
      render: (r) =>
        r.supplierName ? (
          <span className="text-ctl-sm">{r.supplierName}</span>
        ) : (
          // "Nobody has decided yet" — a task, not missing data.
          <span className="text-ink-3">Not set</span>
        ),
    },
    {
      key: 'onHand', header: 'On hand', align: 'right', width: '78px', mono: true,
      render: (r) => (
        <span
          className={cn(
            r.product.quantity <= 0
              ? 'text-neg'
              : r.product.quantity <= 10
                ? 'text-accent-text'
                : 'text-ink-2',
          )}
        >
          {r.product.quantity}
        </span>
      ),
    },
    {
      key: 'sold', header: `Sold ${windowDays}d`, align: 'right', width: '86px', mono: true,
      render: (r) => (
        <span className="text-ink-2">{Math.round(r.velocityPerDay * windowDays)}</span>
      ),
    },
    {
      key: 'qty', header: 'Qty', align: 'right', width: '104px',
      render: (r) => {
        const id = r.product.id;
        const overridden = qty[id] !== undefined && qtyOf(id, r.suggestedQty) !== r.suggestedQty;
        return (
          <span className="flex items-center justify-end gap-1">
            {overridden ? (
              <button
                type="button"
                title={`Reset to suggested (${r.suggestedQty})`}
                onClick={() =>
                  setQty((prev) => {
                    const next = { ...prev };
                    delete next[id];
                    return next;
                  })
                }
                className="flex h-5 w-5 items-center justify-center rounded-[6px] text-ink-3 hover:bg-surface-3 hover:text-ink-2"
              >
                <ArrowPathIcon className="h-3 w-3" />
              </button>
            ) : null}
            <input
              type="number"
              min={1}
              aria-label={`Quantity for ${r.product.name}`}
              value={qty[id] ?? String(r.suggestedQty)}
              onChange={(e) => setQty((prev) => ({ ...prev, [id]: e.target.value }))}
              onBlur={() =>
                setQty((prev) => {
                  const raw = prev[id];
                  if (raw === undefined) return prev;
                  const n = Math.floor(Number(raw));
                  const next = { ...prev };
                  // Empty/invalid or back at the suggestion — drop the edit.
                  if (!Number.isFinite(n) || n < 1 || n === r.suggestedQty) delete next[id];
                  else next[id] = String(n);
                  return next;
                })
              }
              className={cn(
                'w-14 rounded-field border bg-surface px-1.5 py-1 text-right font-mono text-ctl-sm text-ink outline-none',
                // A touched number must look touched — the buyer has to tell
                // their edits from the system's suggestions.
                overridden ? 'border-accent-text' : 'border-line',
              )}
            />
          </span>
        );
      },
    },
    {
      key: 'cost', header: 'Cost', align: 'right', width: '96px', mono: true,
      render: (r) => <span className="text-ink-2">{formatMoney(r.product.cost)}</span>,
    },
    {
      key: 'amount', header: 'Amount', align: 'right', width: '110px', mono: true,
      render: (r) =>
        picked.has(r.product.id) ? (
          <span className="text-[13px] font-semibold">
            {formatMoney(qtyOf(r.product.id, r.suggestedQty) * r.product.cost)}
          </span>
        ) : (
          <span className="text-ink-3">—</span>
        ),
    },
  ];

  if (error) return <ErrorView title="Could not build the list" message={error.message} />;

  return (
    <div className="flex flex-col gap-3">
      <BackButton onClick={() => navigate(RoutePaths.purchaseOrders)} />

      {/* Header card — the two dials that drive every suggested quantity. */}
      <div className="flex flex-wrap items-center gap-x-6 gap-y-3 rounded-card border border-line bg-surface px-[17px] py-[15px] shadow-card">
        <div className="flex items-center gap-2.5">
          <span className="text-[11.5px] font-medium text-ink-2">Movement window</span>
          <Segmented
            label="Movement window"
            options={WINDOW_OPTIONS}
            value={String(windowDays)}
            onChange={(v) => setWindowDays(Number(v))}
          />
        </div>
        <div className="flex items-center gap-2.5">
          <span className="text-[11.5px] font-medium text-ink-2">Cover</span>
          <Segmented
            label="Cover"
            options={COVER_OPTIONS}
            value={String(coverDays)}
            onChange={(v) => setCoverDays(Number(v))}
          />
        </div>
        <span className="text-[11px] text-ink-3">
          Changing either recomputes every line and discards manual edits.
        </span>
      </div>

      <CappedNotice capped={capped}>
        Velocity is computed from the most recent{' '}
        {REORDER_SALES_CAP.toLocaleString('en-US')} sales — it may be understated for this
        window.
      </CappedNotice>

      <div className="flex flex-wrap items-center gap-2">
        <ViewChips
          options={[
            { value: 'needs' as const, label: 'Needs buying', count: scopeCounts.needs },
            { value: 'out' as const, label: 'Out of stock', count: scopeCounts.out },
            { value: 'low' as const, label: 'Low stock', count: scopeCounts.low },
          ]}
          value={scope}
          onChange={setScope}
        />
      </div>

      <section className="overflow-hidden rounded-card border border-line bg-surface shadow-card">
        <DataTable
          columns={columns}
          rows={visible}
          rowKey={(r) => r.product.id}
          loading={isLoading}
          minWidth="1080px"
          selection={{
            selectedKeys: picked,
            onToggle: toggle,
            onToggleAll: toggleAll,
            rowLabel: (r) => `Include ${r.product.name}`,
          }}
          rowClassName={(r) => (picked.has(r.product.id) ? undefined : 'bg-surface-2 opacity-60')}
          empty={
            <NoMatchesState
              title={scope === 'needs' ? 'Nothing to buy' : 'Nothing in this scope'}
              hint={
                scope === 'needs'
                  ? 'Nothing is out of stock, and nothing is due to run out inside the cover period.'
                  : 'Try another scope, or widen the movement window.'
              }
            />
          }
        />
      </section>

      {create.error ? (
        <p className="rounded-ctl border border-neg bg-neg-soft px-tk-md py-tk-sm text-ctl-sm text-neg">
          {create.error.message}
        </p>
      ) : null}

      <StickyActionBar
        figures={[
          { label: 'Lines', value: String(chosen.length) },
          { label: 'Units', value: String(totalUnits) },
          { label: 'Suppliers', value: String(supplierCount) },
        ]}
      >
        <span className="flex items-baseline gap-2">
          <span className="text-[11.5px] text-ink-3">Estimated cost</span>
          <span className="tnum font-mono text-[23px] font-semibold tracking-[-1px] text-ink">
            {formatMoney(totalCost)}
          </span>
        </span>
        <Button disabled={chosen.length === 0 || create.isPending} onClick={() => save('draft')}>
          Save draft
        </Button>
        <Button
          variant="primary"
          disabled={chosen.length === 0 || create.isPending}
          onClick={() => save('ordered')}
        >
          {create.isPending ? 'Saving…' : 'Create purchase order'}
        </Button>
      </StickyActionBar>
    </div>
  );
}
