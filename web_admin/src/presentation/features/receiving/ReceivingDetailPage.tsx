// Receiving detail — per design/maki-pos-receiving-redesign §B: one card,
// four bands. Identity + actions, the facts strip (supplier / received /
// recorded by / total cost — the fix for the old buried subtitle line), the
// items table full width (SKU as its own scannable column, Margin new), then
// totals and the expected-value band. Retail value and Expected profit are
// client-derived projections at today's prices; the receipt's own totals
// come from the document, never recomputed.
import { useEffect } from 'react';
import { useNavigate, useParams } from 'react-router-dom';
import { PrinterIcon } from '@heroicons/react/24/outline';
import { useReceiving } from '@/presentation/hooks/useReceiving';
import { useProducts } from '@/presentation/hooks/useProducts';
import { formatMoney } from '@/core/utils/money';
import { marginPct, marginToneClass } from '@/domain/products/margin';
import { formatInShopZone } from '@/domain/time/shopTime';
import { LoadingView } from '@/presentation/components/common/LoadingView';
import { ErrorView } from '@/presentation/components/common/ErrorView';
import { EmptyState } from '@/presentation/components/common/EmptyState';
import { ProductImage } from '@/presentation/components/common/ProductImage';
import { RoutePaths } from '@/presentation/router/routePaths';
import { Badge } from '@/presentation/components/ui/Badge';
import { BackButton } from '@/presentation/components/ui/BackButton';
import { Fact } from '@/presentation/components/ui/Fact';
import { Button } from '@/presentation/components/ui/Button';
import { CopyButton } from '@/presentation/components/ui/CopyButton';
import { statusTone } from '@/presentation/components/ui/statusTone';
import { displaySku } from '@/domain/products/sku';
import { cn } from '@/core/utils/cn';
import type { Receiving } from '@/domain/entities';

const STATUS_LABEL: Record<Receiving['status'], string> = {
  draft: 'Draft',
  completed: 'Completed',
  cancelled: 'Cancelled',
};

export function ReceivingDetailPage() {
  const { id = '' } = useParams();
  const navigate = useNavigate();
  const { data: receiving, isLoading, error } = useReceiving(id);

  useEffect(() => {
    document.title = 'Receiving detail · MAKI POS Admin';
  }, []);

  // Receiving items denormalize cost (and, since the supplier/price fix, a
  // variation's unitPrice) but not every selling price — the rest resolve
  // from the product's CURRENT price. Hooks can't sit behind the guards.
  const { data: allProducts } = useProducts();

  if (isLoading) return <LoadingView label="Loading receiving…" />;
  if (error) {
    return <ErrorView title="Could not load receiving" message={(error as Error).message} />;
  }
  if (!receiving) {
    return (
      <EmptyState
        title="Receiving not found"
        description="It may have been removed."
        action={
          <button
            type="button"
            onClick={() => navigate(RoutePaths.receiving)}
            className="text-ink underline"
          >
            Back
          </button>
        }
      />
    );
  }

  const priceByProductId = new Map((allProducts ?? []).map((p) => [p.id, p.price]));
  const imageByProductId = new Map((allProducts ?? []).map((p) => [p.id, p.imageUrl]));
  const sellPriceOf = (it: (typeof receiving.items)[number]): number | null =>
    it.unitPrice ?? priceByProductId.get(it.newProductId ?? it.productId ?? '') ?? null;

  const when = receiving.completedAt ?? receiving.createdAt;
  const totalUnits = receiving.totalQuantity;

  // Projections at these prices — lines whose product is gone (no price to
  // project with) are left out of both sides so the pair stays comparable.
  let retail = 0;
  let pricedCost = 0;
  for (const it of receiving.items) {
    const price = sellPriceOf(it);
    if (price == null) continue;
    retail += price * it.quantity;
    pricedCost += it.unitCost * it.quantity;
  }

  return (
    <div className="flex flex-col gap-3 print:hidden">
      <BackButton onClick={() => navigate(RoutePaths.receiving)} />

      <section className="overflow-hidden rounded-card border border-line bg-surface shadow-card">
        {/* Band 1 — identity and actions */}
        <div className="flex flex-wrap items-center gap-3 border-b border-line-2 px-5 py-4">
          <span className="flex items-center gap-2 font-mono text-[19px] font-semibold tracking-[-0.6px] text-ink">
            {receiving.referenceNumber}
            <CopyButton value={receiving.referenceNumber} label="reference" />
          </span>
          <Badge tone={statusTone(receiving.status)}>{STATUS_LABEL[receiving.status]}</Badge>
          <div className="ml-auto flex gap-2">
            <Button
              variant="primary"
              size="sm"
              icon={<PrinterIcon className="h-3.5 w-3.5" />}
              onClick={() => window.print()}
            >
              Print slip
            </Button>
          </div>
        </div>

        {/* Band 2 — the facts strip */}
        <div className="grid grid-cols-[repeat(auto-fit,minmax(170px,1fr))] divide-x divide-line-2 border-b border-line-2">
          <Fact
            label="Supplier"
            value={receiving.supplierName ?? 'No supplier'}
            sub={receiving.supplierName ? 'Delivered by' : 'Walk-in or unrecorded'}
            dim={!receiving.supplierName}
          />
          <Fact
            label="Received"
            value={formatInShopZone(when, { hour: 'numeric', minute: '2-digit', hour12: true })}
            sub={`${formatInShopZone(when, { month: 'short', day: 'numeric', year: 'numeric' })} · ${formatInShopZone(when, { weekday: 'short' })}`}
            mono
          />
          <Fact
            label="Recorded by"
            value={receiving.createdByName || '—'}
            sub="Recorded this receipt"
          />
          <Fact
            label="Total cost"
            value={formatMoney(receiving.totalCost)}
            sub={`${totalUnits} units in`}
            mono
          />
        </div>

        {/* Band 3 — items, full width */}
        <div className="overflow-x-auto">
          <table className="w-full min-w-[760px] border-collapse">
            <thead>
              <tr className="border-b border-line-2 bg-surface-2">
                <Th className="px-5">Item</Th>
                <Th className="w-[132px]">SKU</Th>
                <Th className="w-[60px] px-3 text-right">Qty</Th>
                <Th className="w-[96px] px-3 text-right">Unit cost</Th>
                <Th className="w-[96px] px-3 text-right">Sell price</Th>
                <Th className="w-[78px] px-3 text-right">Margin</Th>
                <Th className="w-[110px] px-5 text-right">Line total</Th>
              </tr>
            </thead>
            <tbody>
              {receiving.items.map((it, index) => {
                const price = sellPriceOf(it);
                const margin = price != null ? marginPct(price, it.unitCost) : null;
                return (
                  // Legacy/web-written items can have an empty id; the index
                  // fallback stays unique in this non-reordering list.
                  <tr key={it.id || index} className="border-b border-line-2 last:border-b-0">
                    <td className="px-5 py-3">
                      <div className="flex min-w-0 items-center gap-3">
                        <ProductImage
                          src={imageByProductId.get(it.newProductId ?? it.productId ?? '')}
                          alt={it.name}
                          size="sm"
                          className="h-9 w-9 shrink-0 rounded-[9px]"
                        />
                        <span className="min-w-0 text-ctl-sm font-medium text-ink">
                          {it.name}
                          {it.isNewVariation ? (
                            <span className="ml-1.5 rounded-[5px] bg-info-soft px-[7px] py-0.5 text-[9.5px] font-bold tracking-[0.8px] text-info">
                              NEW VARIATION
                            </span>
                          ) : null}
                        </span>
                      </div>
                    </td>
                    <td className="px-3.5 py-3">
                      <span className="flex items-center gap-1.5 whitespace-nowrap font-mono text-[12px] text-ink-2">
                        {displaySku(it.sku)}
                        <CopyButton value={it.sku} label="SKU" />
                      </span>
                    </td>
                    <td className="px-3 py-3 text-right font-mono text-ctl-sm text-ink">
                      {it.quantity}
                    </td>
                    <td className="px-3 py-3 text-right font-mono text-ctl-sm text-ink-2">
                      {formatMoney(it.unitCost)}
                    </td>
                    <td className="px-3 py-3 text-right font-mono text-ctl-sm text-ink-2">
                      {price == null ? '—' : formatMoney(price)}
                    </td>
                    <td
                      className={cn(
                        'px-3 py-3 text-right font-mono text-[12px] font-semibold',
                        marginToneClass(margin),
                      )}
                    >
                      {margin == null ? '—' : `${margin}%`}
                    </td>
                    <td className="px-5 py-3 text-right font-mono text-[13px] font-semibold text-ink">
                      {formatMoney(it.unitCost * it.quantity)}
                    </td>
                  </tr>
                );
              })}
            </tbody>
          </table>
        </div>

        {/* Band 4 — totals, then the expected-value band */}
        <div className="flex justify-end border-t border-line px-5 py-3.5">
          <div className="flex w-full max-w-[340px] flex-col gap-[9px]">
            <Row label="Lines" value={String(receiving.items.length)} />
            <Row label="Total units" value={String(totalUnits)} />
            <div className="flex items-baseline justify-between border-t border-line pt-[11px]">
              <span className="text-[13.5px] font-semibold text-ink">Total cost</span>
              <span className="tnum font-mono text-[23px] font-semibold tracking-[-1px] text-ink">
                {formatMoney(receiving.totalCost)}
              </span>
            </div>
          </div>
        </div>

        <div className="flex justify-end border-t border-line-2 bg-surface-2 px-5 py-3.5">
          <div className="flex w-full max-w-[340px] flex-col gap-[9px]">
            <span className="text-[10px] font-semibold uppercase tracking-[1px] text-ink-3">
              Expected at these prices
            </span>
            <Row label="Retail value" value={formatMoney(retail)} />
            <div className="flex justify-between text-cell">
              <span className="text-ink-2">Expected profit</span>
              <span className="font-mono tabular-nums text-pos">
                {formatMoney(retail - pricedCost)}
              </span>
            </div>
          </div>
        </div>
      </section>
    </div>
  );
}

function Th({ children, className }: { children: React.ReactNode; className?: string }) {
  return (
    <th
      className={cn(
        'px-3.5 py-2.5 text-left text-micro-caps uppercase text-ink-3',
        className,
      )}
    >
      {children}
    </th>
  );
}

function Row({ label, value }: { label: string; value: string }) {
  return (
    <div className="flex justify-between text-cell">
      <span className="text-ink-2">{label}</span>
      <span className="font-mono tabular-nums text-ink">{value}</span>
    </div>
  );
}
