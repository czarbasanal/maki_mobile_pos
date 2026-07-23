import { useMemo, useState } from 'react';
import { TrashIcon } from '@heroicons/react/24/outline';
import { useProducts } from '@/presentation/hooks/useProducts';
import type { CartStore } from '@/presentation/stores/cartStore';
import { lowStockLines } from '@/domain/sales/cart';
import { saleItemNet } from '@/domain/entities/SaleItem';
import { DiscountType } from '@/domain/enums/DiscountType';
import { formatMoney } from '@/core/utils/money';
import { LaborSection } from './LaborSection';
import { CartTotals } from './CartTotals';

export function CartBuilder({ store }: { store: CartStore }) {
  const { data: products } = useProducts();
  const lines = store((s) => s.lines);
  const discountType = store((s) => s.discountType);
  const addLine = store((s) => s.addLine);
  const setQty = store((s) => s.setQty);
  const setLineDiscount = store((s) => s.setLineDiscount);
  const removeLine = store((s) => s.removeLine);
  const setDiscountType = store((s) => s.setDiscountType);
  const laborLines = store((s) => s.laborLines);

  const [search, setSearch] = useState('');
  const isPct = discountType === DiscountType.percentage;

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
            the Checkout/Save-draft card down the page. */}
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
                  <button key={p.id} type="button" onClick={() => addLine(p)}
                    className="flex w-full items-center justify-between gap-tk-md px-tk-md py-tk-sm text-left hover:bg-light-subtle">
                    <span>
                      <span className="block text-bodySmall text-light-text">{p.name}</span>
                      <span className="block text-[12px] text-light-text-hint">{p.sku} · {p.quantity} on hand</span>
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
            <label className="flex items-center gap-tk-sm text-[12px] text-light-text-secondary">
              Discount
              <select value={discountType} onChange={(e) => setDiscountType(e.target.value as DiscountType)}
                className="rounded-md border border-light-border bg-light-card px-tk-sm py-[6px] text-[12px]">
                <option value={DiscountType.amount}>₱ amount</option>
                <option value={DiscountType.percentage}>%</option>
              </select>
            </label>
          </div>
          {lines.length === 0 ? (
            <p className="px-tk-md py-tk-lg text-center text-bodySmall text-light-text-hint">Cart is empty.</p>
          ) : (
            <ul className="divide-y divide-light-hairline">
              {lines.map((l) => (
                <li key={l.productId} className="space-y-tk-xs px-tk-md py-tk-sm">
                  <div className="flex items-center justify-between gap-tk-sm">
                    <span className="text-bodySmall text-light-text">{l.name}</span>
                    <button type="button" onClick={() => removeLine(l.productId)} className="text-light-text-hint hover:text-error">
                      <TrashIcon className="h-4 w-4" />
                    </button>
                  </div>
                  <div className="flex items-center gap-tk-sm text-[12px] text-light-text-secondary">
                    <label className="flex items-center gap-tk-xs">
                      Qty
                      <input type="number" min={1} value={l.quantity}
                        onChange={(e) => setQty(l.productId, Number(e.target.value))}
                        className="w-16 rounded-md border border-light-border px-tk-sm py-[4px]" />
                    </label>
                    <label className="flex items-center gap-tk-xs">
                      {isPct ? '%' : '₱'} off
                      <input type="number" min={0} step="0.01" value={l.discountValue}
                        onChange={(e) => setLineDiscount(l.productId, Number(e.target.value))}
                        className="w-20 rounded-md border border-light-border px-tk-sm py-[4px]" />
                    </label>
                    <span className="ml-auto font-medium text-light-text">{formatMoney(saleItemNet(l, isPct))}</span>
                  </div>
                  {lowStock.has(l.productId) ? <p className="text-[11px] text-warning-dark">⚠ exceeds on-hand stock</p> : null}
                </li>
              ))}
            </ul>
          )}
          <LaborSection store={store} />
          <CartTotals lines={lines} discountType={discountType} laborLines={laborLines} />
        </div>
      </section>
    </div>
  );
}
