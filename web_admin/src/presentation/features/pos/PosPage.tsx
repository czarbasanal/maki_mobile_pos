import { useEffect, useMemo, useState } from 'react';
import { TrashIcon } from '@heroicons/react/24/outline';
import { useProducts } from '@/presentation/hooks/useProducts';
import { useCheckout } from '@/presentation/hooks/useCheckout';
import { usePaymentDraft } from '@/presentation/hooks/usePaymentDraft';
import { useCartStore } from '@/presentation/stores/cartStore';
import { cartSubtotal, cartDiscount, cartGrandTotal, lowStockLines } from '@/domain/sales/cart';
import { describedLaborLines, cartLaborSubtotal } from '@/domain/sales/labor';
import { saleItemNet } from '@/domain/entities/SaleItem';
import { DiscountType } from '@/domain/enums/DiscountType';
import { formatMoney } from '@/core/utils/money';
import { cn } from '@/core/utils/cn';
import { PaymentSection } from './PaymentSection';
import { LaborSection } from './LaborSection';

export function PosPage() {
  const { data: products } = useProducts();
  const lines = useCartStore((s) => s.lines);
  const discountType = useCartStore((s) => s.discountType);
  const addLine = useCartStore((s) => s.addLine);
  const setQty = useCartStore((s) => s.setQty);
  const setLineDiscount = useCartStore((s) => s.setLineDiscount);
  const removeLine = useCartStore((s) => s.removeLine);
  const setDiscountType = useCartStore((s) => s.setDiscountType);
  const laborLines = useCartStore((s) => s.laborLines);
  const mechanicId = useCartStore((s) => s.mechanicId);
  const mechanicName = useCartStore((s) => s.mechanicName);
  const clear = useCartStore((s) => s.clear);
  const checkout = useCheckout();

  const [search, setSearch] = useState('');
  const [done, setDone] = useState<string | null>(null);

  const isPct = discountType === DiscountType.percentage;
  const subtotal = cartSubtotal(lines, discountType);
  const discount = cartDiscount(lines, discountType);
  const grandTotal = cartGrandTotal(lines, laborLines, discountType);
  const labor = cartLaborSubtotal(laborLines);
  const pay = usePaymentDraft(grandTotal);

  useEffect(() => {
    document.title = 'POS';
  }, []);

  // Dismiss the previous sale's success banner once a new cart is started.
  useEffect(() => {
    if (lines.length > 0) setDone(null);
  }, [lines.length]);

  // Auto-dismiss the success banner a few seconds after a completed sale.
  useEffect(() => {
    if (!done) return;
    const t = setTimeout(() => setDone(null), 4000);
    return () => clearTimeout(t);
  }, [done]);

  const active = useMemo(() => (products ?? []).filter((p) => p.isActive), [products]);
  const results = useMemo(() => {
    const q = search.trim().toLowerCase();
    if (!q) return [];
    return active
      .filter((p) => p.name.toLowerCase().includes(q) || p.sku.toLowerCase().includes(q))
      .slice(0, 50);
  }, [active, search]);

  const lowStock = useMemo(() => lowStockLines(lines, active), [lines, active]);
  const canComplete = lines.length > 0 && pay.isValid && !checkout.isPending;

  const onComplete = async () => {
    try {
      const sale = await checkout.mutateAsync({
        lines,
        discountType,
        paymentMethod: pay.paymentMethod,
        tenders: pay.tenders,
        amountReceived: pay.amountReceived,
        changeGiven: pay.changeGiven,
        laborLines: describedLaborLines(laborLines),
        mechanicId,
        mechanicName,
      });
      setDone(sale.saleNumber);
      pay.reset();
      clear();
    } catch {
      // surfaced via checkout.error
    }
  };

  return (
    <div className="grid grid-cols-1 gap-tk-lg px-tk-xl py-tk-lg lg:grid-cols-2">
      {/* Left: product search */}
      <section className="space-y-tk-md">
        <h1 className="text-headingMedium font-semibold tracking-tight text-light-text">POS</h1>
        <input
          type="text"
          value={search}
          onChange={(e) => setSearch(e.target.value)}
          placeholder="Search products by name or SKU"
          className="w-full rounded-md border border-light-border bg-light-card px-tk-md py-[10px] text-bodySmall text-light-text outline-none focus:border-light-text"
        />
        <div className="divide-y divide-light-hairline rounded-lg border border-light-hairline bg-light-card">
          {results.length === 0 ? (
            <p className="px-tk-md py-tk-lg text-center text-bodySmall text-light-text-hint">
              {search.trim() ? 'No matches.' : 'Type to search products.'}
            </p>
          ) : (
            results.map((p) => (
              <button
                key={p.id}
                type="button"
                onClick={() => addLine(p)}
                className="flex w-full items-center justify-between gap-tk-md px-tk-md py-tk-sm text-left hover:bg-light-subtle"
              >
                <span>
                  <span className="block text-bodySmall text-light-text">{p.name}</span>
                  <span className="block text-[12px] text-light-text-hint">
                    {p.sku} · {p.quantity} on hand
                  </span>
                </span>
                <span className="text-bodySmall font-medium text-light-text">{formatMoney(p.price)}</span>
              </button>
            ))
          )}
        </div>
      </section>

      {/* Right: cart + payment */}
      <section className="space-y-tk-md">
        {done ? (
          <p className="rounded-md border border-success-light bg-success-light/40 px-tk-md py-tk-sm text-bodySmall text-success-dark">
            Sale <span className="font-mono">{done}</span> completed.
          </p>
        ) : null}
        {checkout.error ? (
          <p className="rounded-md border border-error-light bg-error-light/40 px-tk-md py-tk-sm text-bodySmall text-error-dark">
            {checkout.error.message}
          </p>
        ) : null}

        <div className="rounded-lg border border-light-hairline bg-light-card">
          <div className="flex items-center justify-between border-b border-light-hairline px-tk-md py-tk-sm">
            <span className="text-bodyMedium font-semibold text-light-text">Cart</span>
            <label className="flex items-center gap-tk-sm text-[12px] text-light-text-secondary">
              Discount
              <select
                value={discountType}
                onChange={(e) => setDiscountType(e.target.value as DiscountType)}
                className="rounded-md border border-light-border bg-light-card px-tk-sm py-[6px] text-[12px]"
              >
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
                    <button
                      type="button"
                      onClick={() => removeLine(l.productId)}
                      className="text-light-text-hint hover:text-error"
                    >
                      <TrashIcon className="h-4 w-4" />
                    </button>
                  </div>
                  <div className="flex items-center gap-tk-sm text-[12px] text-light-text-secondary">
                    <label className="flex items-center gap-tk-xs">
                      Qty
                      <input
                        type="number"
                        min={1}
                        value={l.quantity}
                        onChange={(e) => setQty(l.productId, Number(e.target.value))}
                        className="w-16 rounded-md border border-light-border px-tk-sm py-[4px]"
                      />
                    </label>
                    <label className="flex items-center gap-tk-xs">
                      {isPct ? '%' : '₱'} off
                      <input
                        type="number"
                        min={0}
                        step="0.01"
                        value={l.discountValue}
                        onChange={(e) => setLineDiscount(l.productId, Number(e.target.value))}
                        className="w-20 rounded-md border border-light-border px-tk-sm py-[4px]"
                      />
                    </label>
                    <span className="ml-auto font-medium text-light-text">
                      {formatMoney(saleItemNet(l, isPct))}
                    </span>
                  </div>
                  {lowStock.has(l.productId) ? (
                    <p className="text-[11px] text-warning-dark">⚠ exceeds on-hand stock</p>
                  ) : null}
                </li>
              ))}
            </ul>
          )}

          <LaborSection />

          <dl className="space-y-tk-xs border-t border-light-hairline px-tk-md py-tk-sm text-bodySmall">
            <Row label="Subtotal" value={formatMoney(subtotal)} />
            <Row label="Discount" value={`− ${formatMoney(discount)}`} />
            <Row label="Labor" value={formatMoney(labor)} />
            <Row label="Total" value={formatMoney(grandTotal)} strong />
          </dl>
        </div>

        <div className="space-y-tk-sm rounded-lg border border-light-hairline bg-light-card p-tk-md">
          <PaymentSection pay={pay} grandTotal={grandTotal} />
          <button
            type="button"
            disabled={!canComplete}
            onClick={onComplete}
            className={cn(
              'w-full rounded-md bg-light-text px-tk-md py-tk-sm text-bodySmall font-semibold text-light-background hover:bg-primary-dark',
              !canComplete && 'cursor-not-allowed opacity-60',
            )}
          >
            {checkout.isPending ? 'Completing…' : 'Complete sale'}
          </button>
        </div>
      </section>
    </div>
  );
}

function Row({ label, value, strong }: { label: string; value: string; strong?: boolean }) {
  return (
    <div className="flex justify-between">
      <dt className="text-light-text-hint">{label}</dt>
      <dd className={cn('text-light-text', strong && 'font-semibold')}>{value}</dd>
    </div>
  );
}
