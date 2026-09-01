import { useMemo, useState } from 'react';
import { TrashIcon } from '@heroicons/react/24/outline';
import { useProducts } from '@/presentation/hooks/useProducts';
import type { CartStore } from '@/presentation/stores/cartStore';
import { lowStockLines } from '@/domain/sales/cart';
import {
  saleItemDisplayName,
  saleItemGross,
  saleItemHasOption,
  saleItemNet,
  saleItemOptionSets,
  saleItemOptionSetsCaption,
} from '@/domain/entities/SaleItem';
import { DiscountType } from '@/domain/enums/DiscountType';
import { productHasSellingOptions, type Product } from '@/domain/entities/Product';
import { formatMoney } from '@/core/utils/money';
import { cn } from '@/core/utils/cn';
import { LaborSection } from './LaborSection';
import { FeeSection } from './FeeSection';
import { DiscountDialog } from './DiscountDialog';
import { CartTotals } from './CartTotals';
import { SellingOptionDialog } from './SellingOptionDialog';
import { displaySku } from '@/domain/products/sku';

export function CartBuilder({ store }: { store: CartStore }) {
  const { data: products } = useProducts();
  const lines = store((s) => s.lines);
  const discountType = store((s) => s.discountType);
  const addLine = store((s) => s.addLine);
  const addLineWithOption = store((s) => s.addLineWithOption);
  const setQty = store((s) => s.setQty);
  const setLineDiscount = store((s) => s.setLineDiscount);
  const removeLine = store((s) => s.removeLine);
  const setDiscountType = store((s) => s.setDiscountType);
  const laborLines = store((s) => s.laborLines);
  const feeLines = store((s) => s.feeLines);

  const [search, setSearch] = useState('');
  // Product with selling options awaiting the picker's decision. Every path
  // that puts a product on this ticket must route through this gate — the
  // base price is not directly sellable once a product carries options.
  const [pending, setPending] = useState<Product | null>(null);
  const [discountLineId, setDiscountLineId] = useState<string | null>(null);
  const isPct = discountType === DiscountType.percentage;
  const discountLine = lines.find((l) => l.id === discountLineId) ?? null;

  const handlePick = (p: Product) => {
    if (!productHasSellingOptions(p)) {
      addLine(p);
      return;
    }
    setPending(p);
  };

  const active = useMemo(() => (products ?? []).filter((p) => p.isActive), [products]);
  const results = useMemo(() => {
    const q = search.trim().toLowerCase();
    if (!q) return [];
    return active.filter((p) => p.name.toLowerCase().includes(q) || p.sku.toLowerCase().includes(q)).slice(0, 50);
  }, [active, search]);
  const lowStock = useMemo(() => lowStockLines(lines, active), [lines, active]);

  return (
    <div className="grid grid-cols-1 gap-tk-lg lg:grid-cols-2">
      <section>
        {/* The results panel overlays the content below (absolute, anchored
            to the input) — an in-flow panel here grows the column and shoves
            the Checkout/Save-as-Job-Order card down the page. */}
        <div className="relative">
          <input
            type="text"
            value={search}
            onChange={(e) => setSearch(e.target.value)}
            placeholder="Search products by name or SKU"
            className="w-full rounded-md border border-light-border bg-light-card px-tk-md py-[10px] text-bodySmall text-light-text outline-none focus:border-light-text"
          />
          {search.trim() ? (
            <div className="absolute left-0 right-0 top-full z-20 mt-tk-xs max-h-[50vh] divide-y divide-light-hairline overflow-y-auto rounded-lg border border-light-hairline bg-light-card shadow-lg">
              {results.length === 0 ? (
                <p className="px-tk-md py-tk-lg text-center text-bodySmall text-light-text-hint">
                  No matches.
                </p>
              ) : (
                results.map((p) => (
                  <button key={p.id} type="button" onClick={() => handlePick(p)}
                    className="flex w-full items-center justify-between gap-tk-md px-tk-md py-tk-sm text-left hover:bg-light-subtle">
                    <span>
                      <span className="block text-bodySmall text-light-text">{p.name}</span>
                      <span className="block text-[12px] text-light-text-hint">{displaySku(p.sku)} · {p.quantity} on hand</span>
                    </span>
                    <span className="text-bodySmall font-medium text-light-text">{formatMoney(p.price)}</span>
                  </button>
                ))
              )}
            </div>
          ) : null}
        </div>
      </section>

      <section className="space-y-tk-md">
        <div className="rounded-lg border border-light-hairline bg-light-card">
          <div className="flex items-center justify-between border-b border-light-hairline px-tk-md py-tk-sm">
            <span className="text-bodyMedium font-semibold text-light-text">Cart</span>
            {/* The discount-type toggle lives in the per-line DiscountDialog
                (mobile parity) — a header-level select could silently wipe
                every line's discount on a stray change. */}
          </div>
          {lines.length === 0 ? (
            <p className="px-tk-md py-tk-lg text-center text-bodySmall text-light-text-hint">Cart is empty.</p>
          ) : (
            <ul className="divide-y divide-light-hairline">
              {lines.map((l) => {
                // Mirrors OrderSummary's name + caption treatment — this row
                // is the cart's own render site and must not fall back to
                // the bare product name (that's what left two option lines
                // of one product indistinguishable except by the money
                // column).
                const caption = saleItemOptionSetsCaption(l);
                return (
                  <li key={l.id} className="space-y-tk-xs px-tk-md py-tk-sm">
                    <div className="flex items-center justify-between gap-tk-sm">
                      <span className="min-w-0">
                        <span className="block text-bodySmall text-light-text">{saleItemDisplayName(l)}</span>
                        {caption ? (
                          <span className="block text-[12px] text-light-text-hint">{caption}</span>
                        ) : null}
                      </span>
                      <button type="button" onClick={() => removeLine(l.id)} className="text-light-text-hint hover:text-error">
                        <TrashIcon className="h-4 w-4" />
                      </button>
                    </div>
                    <div className="flex items-center gap-tk-sm text-[12px] text-light-text-secondary">
                      <label className="flex items-center gap-tk-xs">
                        {/* An option line's box shows SETS (setQty takes sets); quantity itself is always
                            pieces. The label must say so — otherwise the cashier can't tell whether they're
                            typing sets or pieces into a money-entry field. */}
                        {saleItemHasOption(l) ? 'Sets' : 'Qty'}
                        <input type="number" min={1} value={saleItemOptionSets(l) ?? l.quantity}
                          onChange={(e) => setQty(l.id, Number(e.target.value))}
                          className="w-16 rounded-md border border-light-border px-tk-sm py-[4px]" />
                      </label>
                      <button
                        type="button"
                        onClick={() => setDiscountLineId(l.id)}
                        className={cn(
                          'rounded-md border border-light-border px-tk-sm py-[4px] text-[12px] hover:bg-light-subtle',
                          l.discountValue > 0
                            ? 'font-medium text-success-dark'
                            : 'text-light-text-secondary',
                        )}
                      >
                        {l.discountValue > 0
                          ? isPct
                            ? `${l.discountValue}% off`
                            : `${formatMoney(l.discountValue)} off`
                          : 'Discount'}
                      </button>
                      <span className="ml-auto font-medium text-light-text">{formatMoney(saleItemNet(l, isPct))}</span>
                    </div>
                    {lowStock.has(l.productId) ? <p className="text-[11px] text-warning-dark">⚠ exceeds on-hand stock</p> : null}
                  </li>
                );
              })}
            </ul>
          )}
          <LaborSection store={store} />
          <FeeSection store={store} />
          <CartTotals lines={lines} discountType={discountType} laborLines={laborLines} feeLines={feeLines} />
        </div>
      </section>

      {discountLine ? (
        <DiscountDialog
          key={`${discountLine.id}:${discountType}`}
          open
          onClose={() => setDiscountLineId(null)}
          itemName={saleItemDisplayName(discountLine)}
          currentDiscount={discountLine.discountValue}
          discountType={discountType}
          maxAmount={saleItemGross(discountLine)}
          hasOtherDiscounts={lines.some((o) => o.id !== discountLine.id && o.discountValue > 0)}
          onApply={(value) => setLineDiscount(discountLine.id, value)}
          onTypeChange={setDiscountType}
        />
      ) : null}

      {pending ? (
        <SellingOptionDialog
          product={pending}
          onPick={(option) => {
            addLineWithOption(pending, option);
            setPending(null);
          }}
          onClose={() => setPending(null)}
        />
      ) : null}
    </div>
  );
}
