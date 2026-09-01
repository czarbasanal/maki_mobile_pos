// The POS register surface (design/MAKI-POS-Handoff "POS Register"):
// catalog column (hero search + results card) beside the cart column.
// Shared by the POS screen and the Job Order editor via the `store` prop;
// the POS screen passes its Checkout/Save actions through `actions`.
import { useEffect, useMemo, useRef, useState, type ReactNode } from 'react';
import { ArrowPathIcon, TrashIcon } from '@heroicons/react/24/outline';
import { useProducts } from '@/presentation/hooks/useProducts';
import { useCostCode } from '@/presentation/hooks/useCostCode';
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
import { displaySku } from '@/domain/products/sku';
import { findByScannedCode, matchesPosQuery } from '@/domain/products/posSearch';
import { encodeCostCode } from '@/domain/entities/CostCode';
import { SearchInput } from '@/presentation/components/ui/SearchInput';
import { CopyButton } from '@/presentation/components/ui/CopyButton';
import { IconButton } from '@/presentation/components/ui/IconButton';
import { Stepper } from '@/presentation/components/ui/Stepper';
import { toast } from '@/presentation/components/ui/toast';
import { Dialog } from '@/presentation/components/common/Dialog';
import { ProductImage } from '@/presentation/components/common/ProductImage';
import { LaborSection } from './LaborSection';
import { FeeSection } from './FeeSection';
import { DiscountDialog } from './DiscountDialog';
import { CartTotals } from './CartTotals';
import { SellingOptionDialog } from './SellingOptionDialog';

function OnHandChip({ quantity }: { quantity: number }) {
  const tone =
    quantity <= 0
      ? 'bg-neg-soft text-neg'
      : quantity <= 5
        ? 'bg-accent-soft text-accent-text'
        : 'bg-surface-3 text-ink-2';
  return (
    <span
      className={cn(
        'shrink-0 rounded-chip px-1.5 py-0.5 font-mono text-kpi-label font-semibold tabular-nums',
        tone,
      )}
    >
      {quantity <= 0 ? 'none' : quantity}
    </span>
  );
}

export function CartBuilder({
  store,
  actions,
  searchDebounce = 250,
  allowReset = true,
}: {
  store: CartStore;
  actions?: ReactNode;
  /** Test hook — production keeps the guide's 250ms. */
  searchDebounce?: number;
  /** The POS reset-sale control; Job Order editing hides it (Cancel/Save
   *  are that screen's own verbs). */
  allowReset?: boolean;
}) {
  const { data: products } = useProducts();
  const { data: costCode } = useCostCode();
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
  const clear = store((s) => s.clear);

  const [search, setSearch] = useState('');
  const [highlight, setHighlight] = useState(0);
  // Product with selling options awaiting the picker's decision. Every path
  // that puts a product on this ticket must route through this gate — the
  // base price is not directly sellable once a product carries options.
  const [pending, setPending] = useState<Product | null>(null);
  const [discountLineId, setDiscountLineId] = useState<string | null>(null);
  const [confirmReset, setConfirmReset] = useState(false);
  const searchRef = useRef<HTMLInputElement>(null);
  const isPct = discountType === DiscountType.percentage;
  const discountLine = lines.find((l) => l.id === discountLineId) ?? null;

  const addToCart = (p: Product) => {
    // Out of stock refuses with a toast, not a hidden row — the clerk still
    // needs to see the part exists (POS guide §2).
    if (p.quantity <= 0) {
      toast.error('Out of stock', p.name);
      return;
    }
    if (productHasSellingOptions(p)) {
      setPending(p);
      return;
    }
    addLine(p);
    toast.success('Added to cart', p.name);
  };

  const active = useMemo(() => (products ?? []).filter((p) => p.isActive), [products]);
  const results = useMemo(() => {
    if (!search.trim()) return [];
    return active.filter((p) => matchesPosQuery(p, search)).slice(0, 50);
  }, [active, search]);
  const lowStock = useMemo(() => lowStockLines(lines, active), [lines, active]);

  useEffect(() => setHighlight(0), [search]);

  // Register keyboard map: `/` or Ctrl/Cmd+K focuses search from anywhere.
  useEffect(() => {
    const onKey = (e: KeyboardEvent) => {
      const inField =
        e.target instanceof HTMLElement && ['INPUT', 'TEXTAREA', 'SELECT'].includes(e.target.tagName);
      if ((e.key === '/' && !inField) || (e.key.toLowerCase() === 'k' && (e.metaKey || e.ctrlKey))) {
        e.preventDefault();
        searchRef.current?.focus();
      }
    };
    document.addEventListener('keydown', onKey);
    return () => document.removeEventListener('keydown', onKey);
  }, []);

  // Enter resolves, in order: exact scan (barcode/SKU — a wedge scanner types
  // the code and sends Enter), a sole search result, the highlighted row.
  const submitSearch = (rawText: string) => {
    const code = rawText.trim();
    if (!code) return;
    const scanned = findByScannedCode(active, code);
    const target = scanned ?? (results.length === 1 ? results[0] : results[highlight] ?? null);
    if (!target) {
      toast.error('Product not found', code);
      return;
    }
    setSearch('');
    addToCart(target);
  };

  return (
    <div className="grid items-start gap-4 overflow-x-auto min-[1000px]:grid-cols-[minmax(480px,1fr)_minmax(360px,420px)]">
      {/* ---- Catalog column ---- */}
      <section className="order-2 min-w-0 space-y-tk-xs min-[1000px]:order-1">
        <SearchInput
          value={search}
          onChange={setSearch}
          debounce={searchDebounce}
          variant="hero"
          autoFocus
          inputRef={searchRef}
          placeholder="Search part name or SKU — scan barcode"
          onKeyDown={(e, currentText) => {
            if (e.key === 'Enter') {
              e.preventDefault();
              submitSearch(currentText);
            } else if (e.key === 'ArrowDown') {
              e.preventDefault();
              setHighlight((h) => Math.min(results.length - 1, h + 1));
            } else if (e.key === 'ArrowUp') {
              e.preventDefault();
              setHighlight((h) => Math.max(0, h - 1));
            } else if (e.key === 'Escape') {
              setSearch('');
            }
          }}
        />
        {search.trim() ? (
          <p className="px-1 font-mono text-ctl-sm text-ink-3">
            {results.length} {results.length === 1 ? 'part' : 'parts'}
          </p>
        ) : null}

        {search.trim() ? (
          <div className="overflow-hidden rounded-card border border-line bg-surface shadow-card">
            <div className="flex items-center justify-between border-b border-line-2 px-[18px] py-2">
              <span className="text-micro-caps uppercase text-ink-3">Part</span>
              <span className="text-micro-caps uppercase text-ink-3">On hand · Price</span>
            </div>
            <div className="max-h-[calc(100vh-300px)] divide-y divide-line-2 overflow-y-auto">
              {results.length === 0 ? (
                <div className="px-[18px] py-8 text-center">
                  <p className="text-cell text-ink-2">No parts match &ldquo;{search.trim()}&rdquo;</p>
                  <p className="mt-1 text-micro text-ink-3">Check the SKU, or search a shorter term.</p>
                </div>
              ) : (
                results.map((p, i) => (
                  <div
                    key={p.id}
                    onClick={() => addToCart(p)}
                    className={cn(
                      'flex cursor-pointer items-center gap-3 px-[18px] py-[13px]',
                      i === highlight ? 'bg-surface-2' : 'hover:bg-surface-2',
                    )}
                  >
                    <ProductImage src={p.imageUrl} alt={p.name} size="sm" />
                    <div className="min-w-0 flex-1">
                      <p className="truncate text-nav text-ink">{p.name}</p>
                      <span
                        className="flex items-center gap-[7px] font-mono text-pill text-ink-3"
                        onClick={(e) => e.stopPropagation()}
                      >
                        {displaySku(p.sku)}
                        <CopyButton value={p.sku} label="SKU" />
                      </span>
                    </div>
                    <OnHandChip quantity={p.quantity} />
                    <span className="w-[96px] shrink-0 text-right font-mono text-inv-figure tabular-nums text-ink">
                      {formatMoney(p.price)}
                    </span>
                    <button
                      type="button"
                      onClick={(e) => {
                        e.stopPropagation();
                        addToCart(p);
                      }}
                      className="w-[74px] shrink-0 rounded-field bg-accent py-1.5 text-ctl-sm font-semibold text-accent-ink hover:brightness-95"
                    >
                      Add
                    </button>
                  </div>
                ))
              )}
            </div>
          </div>
        ) : null}
      </section>

      {/* ---- Cart column ---- */}
      <section className="order-1 min-w-0 min-[1000px]:order-2">
        <div className="rounded-card border border-line bg-surface shadow-card">
          <div className="flex items-center justify-between border-b border-line-2 px-[18px] py-3">
            <span className="text-card-title text-ink">Cart</span>
            <span className="flex items-center gap-2">
              {lines.length > 0 ? (
                <span className="rounded-chip bg-surface-3 px-1.5 py-0.5 font-mono text-micro font-semibold text-ink-2">
                  {lines.length}
                </span>
              ) : null}
              {allowReset && (lines.length > 0 || laborLines.length > 0 || feeLines.length > 0) && (
                <button
                  type="button"
                  onClick={() => setConfirmReset(true)}
                  className="inline-flex items-center gap-1 rounded-field border border-line px-2 py-1 text-ctl-sm text-ink-2 transition-[color] hover:bg-neg-soft hover:text-neg"
                >
                  <ArrowPathIcon className="h-3.5 w-3.5" />
                  Reset cart
                </button>
              )}
            </span>
          </div>

          {lines.length === 0 ? (
            <div className="px-[18px] py-8 text-center">
              <p className="text-cell text-ink-2">Cart is empty</p>
              <p className="mt-1 text-micro text-ink-3">Search a part and press Add to start a sale.</p>
            </div>
          ) : (
            <ul className="max-h-[300px] divide-y divide-line-2 overflow-y-auto">
              {lines.map((l) => {
                const caption = saleItemOptionSetsCaption(l);
                return (
                  <li key={l.id} className="space-y-2 px-[18px] py-3">
                    <div className="flex items-start justify-between gap-2">
                      <div className="min-w-0">
                        <p className="text-amount font-medium text-ink">{saleItemDisplayName(l)}</p>
                        <p className="flex items-center gap-1.5 font-mono text-micro text-ink-3">
                          {displaySku(l.sku)} · {formatMoney(l.unitPrice)} / {l.unit}
                          {costCode ? (
                            /* Encoded cost (mobile cost_code_pill parity) —
                               readable by staff without exposing the number. */
                            <span className="rounded-chip bg-surface-3 px-1 py-px text-micro font-semibold text-ink-2">
                              {encodeCostCode(costCode, l.unitCost)}
                            </span>
                          ) : null}
                        </p>
                        {caption ? <p className="text-micro text-ink-3">{caption}</p> : null}
                      </div>
                      <IconButton title={`Remove ${l.name}`} tone="danger" onClick={() => removeLine(l.id)}>
                        <TrashIcon className="h-3.5 w-3.5" />
                      </IconButton>
                    </div>
                    <div className="flex items-center gap-2">
                      <Stepper
                        value={saleItemOptionSets(l) ?? l.quantity}
                        onChange={(v) => setQty(l.id, v)}
                        label={`${saleItemHasOption(l) ? 'Sets' : 'Quantity'} of ${l.name}`}
                      />
                      <button
                        type="button"
                        onClick={() => setDiscountLineId(l.id)}
                        className={cn(
                          'rounded-field border border-line px-2.5 py-1 text-ctl-sm transition-[color] hover:bg-surface-2',
                          l.discountValue > 0 ? 'font-medium text-pos' : 'text-ink-2',
                        )}
                      >
                        {l.discountValue > 0
                          ? isPct
                            ? `${l.discountValue}% off`
                            : `${formatMoney(l.discountValue)} off`
                          : 'Discount'}
                      </button>
                      <span className="ml-auto font-mono text-inv-figure tabular-nums text-ink">
                        {formatMoney(saleItemNet(l, isPct))}
                      </span>
                    </div>
                    {lowStock.has(l.productId) ? (
                      <p className="text-micro text-accent-text">⚠ exceeds on-hand stock</p>
                    ) : null}
                  </li>
                );
              })}
            </ul>
          )}

          <LaborSection store={store} />
          <FeeSection store={store} />
          <CartTotals lines={lines} discountType={discountType} laborLines={laborLines} feeLines={feeLines} />
        </div>

        {actions ? <div className="mt-tk-md">{actions}</div> : null}
      </section>

      {pending ? (
        <SellingOptionDialog
          product={pending}
          onPick={(option) => {
            addLineWithOption(pending, option);
            toast.success('Added to cart', `${pending.name} · ${option.label}`);
            setPending(null);
          }}
          onClose={() => setPending(null)}
        />
      ) : null}

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

      <Dialog open={confirmReset} onClose={() => setConfirmReset(false)} title="Reset cart?">
        <p className="text-cell text-ink-2">
          This clears items, labor &amp; fees, mechanic, and the motorcycle model.
        </p>
        <div className="mt-tk-md flex justify-end gap-tk-sm">
          <button
            type="button"
            onClick={() => setConfirmReset(false)}
            className="rounded-ctl border border-line px-tk-md py-tk-sm text-ctl-md text-ink-2 hover:bg-surface-2"
          >
            Cancel
          </button>
          <button
            type="button"
            onClick={() => {
              clear();
              setConfirmReset(false);
              toast.info('Cart cleared');
            }}
            className="rounded-ctl bg-neg-soft px-tk-md py-tk-sm text-ctl-md font-medium text-neg hover:brightness-95"
          >
            Reset
          </button>
        </div>
      </Dialog>
    </div>
  );
}
