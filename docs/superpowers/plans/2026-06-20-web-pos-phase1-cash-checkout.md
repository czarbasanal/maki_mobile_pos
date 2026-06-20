# Web POS — Phase 1: Cart + Cash Checkout — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A working `/pos` cart + cash checkout that writes a real completed sale (atomic `sales` doc + `items` subcollection + `sale_counters` bump + per-line stock decrement), implementing the stubbed `FirestoreSaleRepository.create()`.

**Architecture:** Pure money/number helpers (TDD) → the atomic transaction in the repo → a Zustand cart store → a `/pos` page + `useCheckout` mutation. Cash-only; warn-but-allow oversell; stock decrement is inside the transaction.

**Tech Stack:** TypeScript / React, `firebase/firestore` transactions, Zustand, TanStack Query (mutation), Vitest.

## Global Constraints

- **Sale number `SALE-YYYYMMDD-NNN`** (NNN ≥ 3 digits), counter at `settings/sale_counters` keyed `YYYYMMDD` (local time), read-incremented-written **in the sale transaction**.
- **`firestore.rules` needs NO change** (verified): `sales` create + `sales/{id}/items` write + `settings/sale_counters` write are allowed for any valid active user. **The `products` update rule allows ONLY the keys `['quantity','updatedAt','updatedBy','updatedByName']`** — the stock-decrement write MUST write exactly those four and nothing else.
- **`/pos` is a `commonRoutes` entry** — no permission-guard change; just wire the page element.
- Cash only: `paymentMethod='cash'`, `tenders={cash: grandTotal}`, `changeGiven=max(0, received−total)`.
- **Write budget guard:** reject a cart over **200 lines** (2+2N ≤ 402 < 500 cap).
- Vitest resolves `@/` (per `vitest.config.ts`) — `@/` imports are fine everywhere, including tested modules.

---

## Task 1: Pure helpers — sale number + cart math (TDD)

**Files:**
- Create: `web_admin/src/domain/sales/saleNumber.ts` + `saleNumber.test.ts`
- Create: `web_admin/src/domain/sales/cart.ts` + `cart.test.ts`

**Interfaces:**
- Consumes: `saleSubtotal`/`saleTotalDiscount`/`saleGrandTotal` (`@/domain/entities/Sale`), `SaleItem`, `Product`, `DiscountType`, `PaymentMethod`.
- Produces: `counterKey(date): string`, `formatSaleNumber(date, seq): string`; `CartLine` (= `SaleItem`), `cartGrandTotal(lines, discountType): number`, `changeFor(total, received): number`, `cashTenders(total): Partial<Record<PaymentMethod, number>>`, `lowStockLines(lines, products): Set<string>`.

- [ ] **Step 1: Write the failing `saleNumber` tests**

`web_admin/src/domain/sales/saleNumber.test.ts`:
```ts
import { describe, expect, it } from 'vitest';
import { counterKey, formatSaleNumber } from './saleNumber';

describe('counterKey', () => {
  it('formats local YYYYMMDD, zero-padded', () => {
    expect(counterKey(new Date(2026, 0, 5))).toBe('20260105');
    expect(counterKey(new Date(2026, 11, 31))).toBe('20261231');
  });
});

describe('formatSaleNumber', () => {
  it('pads the sequence to at least 3 digits', () => {
    expect(formatSaleNumber(new Date(2026, 5, 20), 1)).toBe('SALE-20260620-001');
    expect(formatSaleNumber(new Date(2026, 5, 20), 42)).toBe('SALE-20260620-042');
    expect(formatSaleNumber(new Date(2026, 5, 20), 1234)).toBe('SALE-20260620-1234');
  });
});
```

- [ ] **Step 2: Write the failing `cart` tests**

`web_admin/src/domain/sales/cart.test.ts`:
```ts
import { describe, expect, it } from 'vitest';
import { cartGrandTotal, changeFor, cashTenders, lowStockLines } from './cart';
import { DiscountType } from '@/domain/enums/DiscountType';
import { PaymentMethod } from '@/domain/enums/PaymentMethod';
import type { Product } from '@/domain/entities';
import type { CartLine } from './cart';

const line = (over: Partial<CartLine> = {}): CartLine => ({
  id: 'p1', productId: 'p1', sku: 'A', name: 'A',
  unitPrice: 100, unitCost: 60, quantity: 1, discountValue: 0, unit: 'pcs', ...over,
});

describe('cartGrandTotal', () => {
  it('sums net of per-line amount discounts', () => {
    expect(cartGrandTotal([line({ quantity: 2 }), line({ productId: 'p2', discountValue: 20 })], DiscountType.amount))
      .toBe(200 + 80);
  });
  it('applies percentage discounts', () => {
    expect(cartGrandTotal([line({ discountValue: 10 })], DiscountType.percentage)).toBe(90);
  });
});

describe('changeFor', () => {
  it('is received minus total, floored at 0', () => {
    expect(changeFor(100, 150)).toBe(50);
    expect(changeFor(100, 100)).toBe(0);
    expect(changeFor(100, 80)).toBe(0);
  });
});

describe('cashTenders', () => {
  it('puts the whole total in the cash bucket', () => {
    expect(cashTenders(250)).toEqual({ [PaymentMethod.cash]: 250 });
  });
});

describe('lowStockLines', () => {
  it('flags lines whose qty exceeds on-hand', () => {
    const products = [{ id: 'p1', quantity: 1 }, { id: 'p2', quantity: 5 }] as Product[];
    const flagged = lowStockLines([line({ quantity: 3 }), line({ productId: 'p2', quantity: 2 })], products);
    expect([...flagged]).toEqual(['p1']);
  });
});
```

- [ ] **Step 3: Run both — verify they fail**

Run: `cd web_admin && npx vitest run src/domain/sales/`
Expected: FAIL (modules not found).

- [ ] **Step 4: Implement `saleNumber.ts`**

```ts
/** Local-time YYYYMMDD key for the daily sale counter (settings/sale_counters). */
export function counterKey(date: Date): string {
  const y = date.getFullYear();
  const m = `${date.getMonth() + 1}`.padStart(2, '0');
  const d = `${date.getDate()}`.padStart(2, '0');
  return `${y}${m}${d}`;
}

/** Human sale number: SALE-YYYYMMDD-NNN (sequence zero-padded to >= 3). */
export function formatSaleNumber(date: Date, seq: number): string {
  return `SALE-${counterKey(date)}-${`${seq}`.padStart(3, '0')}`;
}
```

- [ ] **Step 5: Implement `cart.ts`**

```ts
import { saleSubtotal, saleTotalDiscount, saleGrandTotal } from '@/domain/entities/Sale';
import type { Sale } from '@/domain/entities/Sale';
import type { SaleItem } from '@/domain/entities/SaleItem';
import type { Product } from '@/domain/entities/Product';
import { PaymentMethod } from '@/domain/enums/PaymentMethod';
import type { DiscountType } from '@/domain/enums/DiscountType';

/** A cart line is a SaleItem snapshot (id = product id until checkout assigns one). */
export type CartLine = SaleItem;

// Reuse the Sale money helpers by shaping a minimal Sale — they read only
// items/laborLines/discountType — so cart and sale math stay single-sourced.
function asSale(lines: CartLine[], discountType: DiscountType): Sale {
  return { items: lines, laborLines: [], discountType } as unknown as Sale;
}

export function cartSubtotal(lines: CartLine[], discountType: DiscountType): number {
  return saleSubtotal(asSale(lines, discountType));
}
export function cartDiscount(lines: CartLine[], discountType: DiscountType): number {
  return saleTotalDiscount(asSale(lines, discountType));
}
export function cartGrandTotal(lines: CartLine[], discountType: DiscountType): number {
  return saleGrandTotal(asSale(lines, discountType)); // labor = 0 this phase
}
export function changeFor(grandTotal: number, amountReceived: number): number {
  return Math.max(0, amountReceived - grandTotal);
}
export function cashTenders(grandTotal: number): Partial<Record<PaymentMethod, number>> {
  return { [PaymentMethod.cash]: grandTotal };
}
/** Product ids whose cart qty exceeds on-hand stock (for the low-stock warning). */
export function lowStockLines(lines: CartLine[], products: Product[]): Set<string> {
  const onHand = new Map(products.map((p) => [p.id, p.quantity]));
  const flagged = new Set<string>();
  for (const l of lines) {
    if (l.quantity > (onHand.get(l.productId) ?? 0)) flagged.add(l.productId);
  }
  return flagged;
}
```

- [ ] **Step 6: Run both — verify they pass**

Run: `cd web_admin && npx vitest run src/domain/sales/`
Expected: PASS.

- [ ] **Step 7: Commit**

```bash
git add web_admin/src/domain/sales/
git commit -m "feat(web): POS pure helpers — saleNumber + cart totals/change/low-stock"
```

---

## Task 2: Implement `FirestoreSaleRepository.create()` (atomic transaction)

**Files:**
- Modify: `web_admin/src/data/repositories/FirestoreSaleRepository.ts`

**Interfaces:**
- Consumes: `counterKey`/`formatSaleNumber` (Task 1), `FirestoreCollections`/`Subcollections`, `Sale`.
- Produces: a working `create(input: Omit<Sale,'id'|'createdAt'|'updatedAt'>, actorId): Promise<Sale>`.

- [ ] **Step 1: Extend the firestore imports**

In the `firebase/firestore` import list, add `increment`, `runTransaction`, `serverTimestamp`:
```ts
import {
  collection,
  doc,
  getDoc,
  getDocs,
  increment,
  limit as fbLimit,
  onSnapshot,
  orderBy,
  query,
  runTransaction,
  serverTimestamp,
  Timestamp,
  where,
  type Firestore,
} from 'firebase/firestore';
```
Add after the existing `saleItemConverter` import:
```ts
import { counterKey, formatSaleNumber } from '@/domain/sales/saleNumber';
```

- [ ] **Step 2: Replace the `create()` stub**

Replace:
```ts
  // Write methods land in phase 11.
  async create(): Promise<Sale> {
    throw new Error('SaleRepository.create not implemented yet (phase 11)');
  }
```
with:
```ts
  async create(
    input: Omit<Sale, 'id' | 'createdAt' | 'updatedAt'>,
    actorId: string,
  ): Promise<Sale> {
    if (input.items.length === 0) {
      throw new Error('Cannot complete a sale with an empty cart');
    }
    if (input.items.length > 200) {
      throw new Error(
        `This sale has ${input.items.length} lines — the max is 200. Split it into smaller sales.`,
      );
    }
    const now = new Date();
    const key = counterKey(now);
    const saleRef = doc(collection(this.db, FirestoreCollections.sales));
    const counterRef = doc(this.db, FirestoreCollections.settings, 'sale_counters');
    // Pre-allocate item ids so the tx is pure writes after the single counter read.
    const itemRefs = input.items.map(() =>
      doc(collection(this.db, FirestoreCollections.sales, saleRef.id, Subcollections.saleItems)),
    );

    await runTransaction(this.db, async (tx) => {
      // The only read — must precede every write.
      const counterSnap = await tx.get(counterRef);
      const seq =
        (counterSnap.exists() ? (counterSnap.data() as Record<string, number>)[key] ?? 0 : 0) + 1;
      const saleNumber = formatSaleNumber(now, seq);

      tx.set(saleRef, {
        saleNumber,
        discountType: input.discountType,
        paymentMethod: input.paymentMethod,
        tenders: input.tenders,
        amountReceived: input.amountReceived,
        changeGiven: input.changeGiven,
        status: input.status,
        cashierId: input.cashierId,
        cashierName: input.cashierName,
        laborLines: input.laborLines,
        mechanicId: input.mechanicId,
        mechanicName: input.mechanicName,
        draftId: input.draftId,
        notes: input.notes,
        voidedBy: null,
        voidedByName: null,
        voidReason: null,
        createdAt: serverTimestamp(),
        updatedAt: serverTimestamp(),
      });
      input.items.forEach((item, i) => {
        tx.set(itemRefs[i], {
          productId: item.productId,
          sku: item.sku,
          name: item.name,
          unitPrice: item.unitPrice,
          unitCost: item.unitCost,
          quantity: item.quantity,
          discountValue: item.discountValue,
          unit: item.unit,
        });
      });
      tx.set(counterRef, { [key]: seq }, { merge: true });
      // Stock decrement — the products update rule permits ONLY these 4 keys.
      for (const item of input.items) {
        tx.update(doc(this.db, FirestoreCollections.products, item.productId), {
          quantity: increment(-item.quantity),
          updatedAt: serverTimestamp(),
          updatedBy: actorId,
          updatedByName: input.cashierName,
        });
      }
    });

    const created = await this.getById(saleRef.id);
    if (!created) throw new Error('Failed to load the created sale');
    return created;
  }
```

- [ ] **Step 3: Typecheck + build**

Run: `cd web_admin && npm run typecheck && npm run build`
Expected: both pass. (`voidSale()` stays a stub — that's Phase «void».)

- [ ] **Step 4: Commit**

```bash
git add web_admin/src/data/repositories/FirestoreSaleRepository.ts
git commit -m "feat(web): atomic sale write — sales + items + counter + stock decrement"
```

---

## Task 3: Cart store (Zustand)

**Files:**
- Create: `web_admin/src/presentation/stores/cartStore.ts` + `cartStore.test.ts`

**Interfaces:**
- Consumes: `Product`, `CartLine` (Task 1), `DiscountType`.
- Produces: `useCartStore` with `{ lines, discountType, addLine, setQty, setLineDiscount, removeLine, setDiscountType, clear }`.

- [ ] **Step 1: Write the failing store tests**

`web_admin/src/presentation/stores/cartStore.test.ts`:
```ts
import { beforeEach, describe, expect, it } from 'vitest';
import { useCartStore } from './cartStore';
import { DiscountType } from '@/domain/enums/DiscountType';
import type { Product } from '@/domain/entities';

const product = (over: Partial<Product> = {}): Product =>
  ({ id: 'p1', sku: 'A', name: 'A', price: 100, cost: 60, unit: 'pcs', quantity: 10, ...over } as Product);

describe('cartStore', () => {
  beforeEach(() => useCartStore.getState().clear());

  it('adds a product as a line and merges quantity on re-add', () => {
    useCartStore.getState().addLine(product());
    useCartStore.getState().addLine(product());
    const { lines } = useCartStore.getState();
    expect(lines).toHaveLength(1);
    expect(lines[0].quantity).toBe(2);
    expect(lines[0].unitPrice).toBe(100);
    expect(lines[0].unitCost).toBe(60);
  });

  it('resets line discounts when the discount type changes', () => {
    useCartStore.getState().addLine(product());
    useCartStore.getState().setLineDiscount('p1', 15);
    expect(useCartStore.getState().lines[0].discountValue).toBe(15);
    useCartStore.getState().setDiscountType(DiscountType.percentage);
    expect(useCartStore.getState().discountType).toBe(DiscountType.percentage);
    expect(useCartStore.getState().lines[0].discountValue).toBe(0);
  });

  it('clamps quantity to a positive integer and removes lines', () => {
    useCartStore.getState().addLine(product());
    useCartStore.getState().setQty('p1', 0);
    expect(useCartStore.getState().lines[0].quantity).toBe(1);
    useCartStore.getState().removeLine('p1');
    expect(useCartStore.getState().lines).toHaveLength(0);
  });
});
```

- [ ] **Step 2: Run — verify it fails**

Run: `cd web_admin && npx vitest run src/presentation/stores/cartStore.test.ts`
Expected: FAIL (module not found).

- [ ] **Step 3: Implement `cartStore.ts`**

```ts
import { create } from 'zustand';
import type { Product } from '@/domain/entities';
import type { CartLine } from '@/domain/sales/cart';
import { DiscountType } from '@/domain/enums/DiscountType';

interface CartState {
  lines: CartLine[];
  discountType: DiscountType;
  addLine: (product: Product) => void;
  setQty: (productId: string, quantity: number) => void;
  setLineDiscount: (productId: string, discountValue: number) => void;
  removeLine: (productId: string) => void;
  setDiscountType: (discountType: DiscountType) => void;
  clear: () => void;
}

export const useCartStore = create<CartState>((set) => ({
  lines: [],
  discountType: DiscountType.amount,
  addLine: (product) =>
    set((s) => {
      if (s.lines.some((l) => l.productId === product.id)) {
        return {
          lines: s.lines.map((l) =>
            l.productId === product.id ? { ...l, quantity: l.quantity + 1 } : l,
          ),
        };
      }
      const line: CartLine = {
        id: product.id,
        productId: product.id,
        sku: product.sku,
        name: product.name,
        unitPrice: product.price,
        unitCost: product.cost,
        quantity: 1,
        discountValue: 0,
        unit: product.unit,
      };
      return { lines: [...s.lines, line] };
    }),
  setQty: (productId, quantity) =>
    set((s) => ({
      lines: s.lines.map((l) =>
        l.productId === productId ? { ...l, quantity: Math.max(1, Math.floor(quantity) || 1) } : l,
      ),
    })),
  setLineDiscount: (productId, discountValue) =>
    set((s) => ({
      lines: s.lines.map((l) =>
        l.productId === productId ? { ...l, discountValue: Math.max(0, discountValue) } : l,
      ),
    })),
  removeLine: (productId) => set((s) => ({ lines: s.lines.filter((l) => l.productId !== productId) })),
  setDiscountType: (discountType) =>
    set((s) => ({ discountType, lines: s.lines.map((l) => ({ ...l, discountValue: 0 })) })),
  clear: () => set({ lines: [], discountType: DiscountType.amount }),
}));
```

- [ ] **Step 4: Run — verify it passes**

Run: `cd web_admin && npx vitest run src/presentation/stores/cartStore.test.ts`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add web_admin/src/presentation/stores/cartStore.ts web_admin/src/presentation/stores/cartStore.test.ts
git commit -m "feat(web): POS cart store (Zustand) with discount-type reset"
```

---

## Task 4: `useCheckout` hook + `/pos` page + route

**Files:**
- Create: `web_admin/src/presentation/hooks/useCheckout.ts`
- Create: `web_admin/src/presentation/features/pos/PosPage.tsx`
- Modify: `web_admin/src/presentation/router/routes.tsx`

**Interfaces:**
- Consumes: `useSaleRepo`, `useAuthStore`, `useProducts`, `useCartStore`, the cart helpers, `formatMoney`, the enums.

- [ ] **Step 1: `useCheckout` hook**

`web_admin/src/presentation/hooks/useCheckout.ts`:
```ts
import { useMutation } from '@tanstack/react-query';
import { useSaleRepo } from '@/infrastructure/di/container';
import { useAuthStore } from '@/presentation/stores/authStore';
import type { Sale } from '@/domain/entities';
import { PaymentMethod } from '@/domain/enums/PaymentMethod';
import { SaleStatus } from '@/domain/enums/SaleStatus';
import type { DiscountType } from '@/domain/enums/DiscountType';
import { cartGrandTotal, cashTenders, type CartLine } from '@/domain/sales/cart';

export interface CheckoutInput {
  lines: CartLine[];
  discountType: DiscountType;
  amountReceived: number;
  changeGiven: number;
}

export function useCheckout() {
  const repo = useSaleRepo();
  const actor = useAuthStore((s) => s.user);
  return useMutation<Sale, Error, CheckoutInput>({
    mutationFn: async ({ lines, discountType, amountReceived, changeGiven }) => {
      if (!actor) throw new Error('Not signed in');
      const grandTotal = cartGrandTotal(lines, discountType);
      const cashierName = actor.displayName.trim() || actor.email;
      const saleInput: Omit<Sale, 'id' | 'createdAt' | 'updatedAt'> = {
        saleNumber: '', // generated inside the repo transaction
        items: lines,
        laborLines: [],
        mechanicId: null,
        mechanicName: null,
        tenders: cashTenders(grandTotal),
        discountType,
        paymentMethod: PaymentMethod.cash,
        amountReceived,
        changeGiven,
        status: SaleStatus.completed,
        cashierId: actor.id,
        cashierName,
        draftId: null,
        notes: null,
        voidedAt: null,
        voidedBy: null,
        voidedByName: null,
        voidReason: null,
      };
      return repo.create(saleInput, actor.id);
    },
  });
}
```

- [ ] **Step 2: `PosPage`**

`web_admin/src/presentation/features/pos/PosPage.tsx`:
```tsx
import { useEffect, useMemo, useState } from 'react';
import { TrashIcon } from '@heroicons/react/24/outline';
import { useProducts } from '@/presentation/hooks/useProducts';
import { useCheckout } from '@/presentation/hooks/useCheckout';
import { useCartStore } from '@/presentation/stores/cartStore';
import { cartSubtotal, cartDiscount, cartGrandTotal, changeFor, lowStockLines } from '@/domain/sales/cart';
import { DiscountType } from '@/domain/enums/DiscountType';
import { formatMoney } from '@/core/utils/money';
import { cn } from '@/core/utils/cn';

export function PosPage() {
  const { data: products } = useProducts();
  const lines = useCartStore((s) => s.lines);
  const discountType = useCartStore((s) => s.discountType);
  const addLine = useCartStore((s) => s.addLine);
  const setQty = useCartStore((s) => s.setQty);
  const setLineDiscount = useCartStore((s) => s.setLineDiscount);
  const removeLine = useCartStore((s) => s.removeLine);
  const setDiscountType = useCartStore((s) => s.setDiscountType);
  const clear = useCartStore((s) => s.clear);
  const checkout = useCheckout();

  const [search, setSearch] = useState('');
  const [amountReceived, setAmountReceived] = useState('');
  const [done, setDone] = useState<string | null>(null);

  useEffect(() => { document.title = 'POS'; }, []);

  const active = useMemo(() => (products ?? []).filter((p) => p.isActive), [products]);
  const results = useMemo(() => {
    const q = search.trim().toLowerCase();
    if (!q) return [];
    return active
      .filter((p) => p.name.toLowerCase().includes(q) || p.sku.toLowerCase().includes(q))
      .slice(0, 50);
  }, [active, search]);

  const isPct = discountType === DiscountType.percentage;
  const subtotal = cartSubtotal(lines, discountType);
  const discount = cartDiscount(lines, discountType);
  const grandTotal = cartGrandTotal(lines, discountType);
  const received = Number(amountReceived) || 0;
  const change = changeFor(grandTotal, received);
  const lowStock = useMemo(() => lowStockLines(lines, active), [lines, active]);
  const canComplete = lines.length > 0 && received >= grandTotal && !checkout.isPending;

  const onComplete = async () => {
    try {
      const sale = await checkout.mutateAsync({ lines, discountType, amountReceived: received, changeGiven: change });
      setDone(sale.saleNumber);
      setAmountReceived('');
      clear();
    } catch {
      // error shown via checkout.error
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
                  <span className="block text-[12px] text-light-text-hint">{p.sku} · {p.quantity} on hand</span>
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
                    <button type="button" onClick={() => removeLine(l.productId)} className="text-light-text-hint hover:text-error">
                      <TrashIcon className="h-4 w-4" />
                    </button>
                  </div>
                  <div className="flex items-center gap-tk-sm text-[12px] text-light-text-secondary">
                    <label className="flex items-center gap-tk-xs">
                      Qty
                      <input
                        type="number" min={1} value={l.quantity}
                        onChange={(e) => setQty(l.productId, Number(e.target.value))}
                        className="w-16 rounded-md border border-light-border px-tk-sm py-[4px]"
                      />
                    </label>
                    <label className="flex items-center gap-tk-xs">
                      {isPct ? '%' : '₱'} off
                      <input
                        type="number" min={0} step="0.01" value={l.discountValue}
                        onChange={(e) => setLineDiscount(l.productId, Number(e.target.value))}
                        className="w-20 rounded-md border border-light-border px-tk-sm py-[4px]"
                      />
                    </label>
                    <span className="ml-auto font-medium text-light-text">{formatMoney(l.unitPrice * l.quantity)}</span>
                  </div>
                  {lowStock.has(l.productId) ? (
                    <p className="text-[11px] text-warning-dark">⚠ exceeds on-hand stock</p>
                  ) : null}
                </li>
              ))}
            </ul>
          )}

          <dl className="space-y-tk-xs border-t border-light-hairline px-tk-md py-tk-sm text-bodySmall">
            <Row label="Subtotal" value={formatMoney(subtotal)} />
            <Row label="Discount" value={`− ${formatMoney(discount)}`} />
            <Row label="Total" value={formatMoney(grandTotal)} strong />
          </dl>
        </div>

        <div className="space-y-tk-sm rounded-lg border border-light-hairline bg-light-card p-tk-md">
          <label className="block space-y-tk-xs">
            <span className="text-bodySmall font-medium text-light-text">Cash received</span>
            <input
              type="number" min={0} step="0.01" value={amountReceived}
              onChange={(e) => setAmountReceived(e.target.value)}
              className="w-full rounded-md border border-light-border bg-light-card px-tk-md py-[10px] text-bodySmall"
            />
          </label>
          <Row label="Change" value={formatMoney(change)} />
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
```

- [ ] **Step 3: Wire the `/pos` route**

In `web_admin/src/presentation/router/routes.tsx`: add the import near the other feature-page imports:
```ts
import { PosPage } from '@/presentation/features/pos/PosPage';
```
Replace `{ path: RoutePaths.pos, element: placeholder('POS', 'phase 11') },` with:
```ts
{ path: RoutePaths.pos, element: <PosPage /> },
```

- [ ] **Step 4: Typecheck + tests + build**

Run: `cd web_admin && npm run typecheck && npm run test -- --run && npm run build`
Expected: tsc clean; all vitest pass (incl. Tasks 1+3); build OK. If `success-light`/`warning-dark` tokens don't exist, swap to existing ones (grep `success-light`/`warning-dark` in `src` / tailwind config; the inventory pages use `error-light`, `warning-light`, `success` — reuse whatever is defined).

- [ ] **Step 5: Manual verify (dev server — the smoke checklist)**

`npm run dev`, sign in: search a product → add → adjust qty + line discount → toggle discount type (line discounts reset) → enter cash ≥ total → **Complete sale** → success shows the `SALE-…` number; confirm in Firestore the `sales` doc + `items` subcollection + `settings/sale_counters` bump + the product `quantity` dropped; confirm the sale appears in `/reports`. Add a line exceeding stock → see the warning but still complete.

- [ ] **Step 6: Commit**

```bash
git add web_admin/src/presentation/hooks/useCheckout.ts web_admin/src/presentation/features/pos/PosPage.tsx web_admin/src/presentation/router/routes.tsx
git commit -m "feat(web): /pos cart + cash checkout page + useCheckout"
```

---

## Self-review notes (author)

- **Spec coverage:** §2 contract (sale number, doc shapes, stock-keys) → T1 + T2; §3 atomic write → T2; §4 helpers → T1; §5 cart store + page + hook → T3 + T4; §6 testing → T1/T3 unit + T4 build/manual; rules confirmed no-change (T2 writes exactly the 4 allowed product keys). Covered.
- **Type consistency:** `create(input: Omit<Sale,'id'|'createdAt'|'updatedAt'>, actorId)` matches the interface (verbatim) and the `useCheckout` call site builds exactly that shape. `CartLine = SaleItem` flows store → checkout → repo items. `cashTenders`/`cartGrandTotal`/`changeFor` shared by hook + page.
- **Reads-before-writes:** the transaction's only `tx.get` (counter) precedes all `tx.set`/`tx.update`; product updates are blind increments (no prior read needed).
- **Rules compliance:** the stock `tx.update` writes exactly `quantity,updatedAt,updatedBy,updatedByName` — matches the `hasOnly([...])` products rule, so non-admin checkouts won't be permission-denied.
- **No automated tx test** (web has no Firestore-mock) — the pure helpers + the store ARE unit-tested; the transaction is build- + manual-verified (T4 S5). Token-name caveat flagged in T4 S4.
