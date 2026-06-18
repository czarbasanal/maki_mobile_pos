# Reorder Suggestions (§22) — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A web-admin "Reorder suggestions" screen that suggests an order quantity per product from sales velocity × (per-supplier lead time + cover), grouped by supplier, with editable qty and CSV export.

**Architecture:** A pure domain core (`unitsSoldByProduct` + `computeReorderSuggestions`) computes suggestions from products + a sales rollup + suppliers + tunable params. A hook wires realtime products/suppliers + a windowed sales query into it; the page renders a grouped, editable table with CSV export. A new `Supplier.leadTimeDays` field feeds per-supplier lead time.

**Tech Stack:** React 18 + TypeScript + Vite, TanStack Query, react-hook-form + zod, Firestore, date-fns, Tailwind, Vitest.

## Global Constraints

- **Web admin only** (run everything from `web_admin/`). No mobile, no `firestore.rules` change (`suppliers` create/update already permitted; `leadTimeDays` is additive).
- **Import convention:** modules under `src/domain/**` (imported by Vitest) use **relative** imports, not `@/`. Presentation/data code may use `@/`.
- **Velocity = simple average** over the window; **zero-velocity products are excluded**. No EMA/seasonality.
- **Params defaults:** `windowDays=30`, `coverDays=14`, `defaultLeadDays=7` (cover folds in safety). Adjustable on-screen, not persisted.
- Gates per task: `npm run typecheck` + `npm run test` + (UI) `npm run build`.

---

## Task 1: `Supplier.leadTimeDays` field (entity → converter → repo → form)

**Files:**
- Modify: `web_admin/src/domain/entities/Supplier.ts`
- Modify: `web_admin/src/domain/repositories/SupplierRepository.ts` (the `SupplierCreateInput` type)
- Modify: `web_admin/src/data/converters/supplierConverter.ts`
- Create: `web_admin/src/data/converters/supplierConverter.test.ts`
- Modify: `web_admin/src/data/repositories/FirestoreSupplierRepository.ts:71-92` (create) and `:111-135` (update field list)
- Modify: `web_admin/src/presentation/features/suppliers/SupplierFormPage.tsx`

**Interfaces:**
- Produces: `Supplier.leadTimeDays: number | null`, persisted via supplier create/update and read by the converter.

- [ ] **Step 1: Add the field to the entity**

In `Supplier.ts`, add to the `Supplier` interface (after `email`):
```ts
  /** Typical days from order to delivery for this supplier; null = unknown.
   *  Used by the reorder engine (falls back to a default when null). */
  leadTimeDays: number | null;
```

- [ ] **Step 2: Write the failing converter test**

```ts
// web_admin/src/data/converters/supplierConverter.test.ts
import { describe, expect, it } from 'vitest';
import { supplierConverter } from './supplierConverter';

function snap(id: string, data: Record<string, unknown>) {
  return { id, data: () => data } as never;
}
const opts = {} as never;

describe('supplierConverter.fromFirestore', () => {
  it('reads leadTimeDays as a number', () => {
    const s = supplierConverter.fromFirestore(
      snap('sup-1', {
        name: 'Acme', transactionType: 'cash', createdAt: new Date('2026-06-01T00:00:00Z'),
        leadTimeDays: 5,
      }),
      opts,
    );
    expect(s.leadTimeDays).toBe(5);
  });

  it('defaults a missing leadTimeDays to null', () => {
    const s = supplierConverter.fromFirestore(
      snap('sup-2', {
        name: 'Beta', transactionType: 'cash', createdAt: new Date('2026-06-01T00:00:00Z'),
      }),
      opts,
    );
    expect(s.leadTimeDays).toBeNull();
  });
});
```

- [ ] **Step 3: Run it — verify it fails**

Run: `cd web_admin && npx vitest run src/data/converters/supplierConverter.test.ts`
Expected: FAIL — `leadTimeDays` is `undefined` (not yet read) / type error.

- [ ] **Step 4: Read/write the field in the converter**

In `supplierConverter.ts` `toFirestore`, add after `email: s.email,`:
```ts
      leadTimeDays: s.leadTimeDays,
```
In `fromFirestore`, add after `email: d.email ?? null,`:
```ts
      leadTimeDays: d.leadTimeDays != null ? Number(d.leadTimeDays) : null,
```

- [ ] **Step 5: Run it — verify it passes**

Run: `cd web_admin && npx vitest run src/data/converters/supplierConverter.test.ts`
Expected: PASS (2 tests).

- [ ] **Step 6: Thread it through the create input + repo writes**

In `SupplierRepository.ts`, add to the `SupplierCreateInput` interface:
```ts
  leadTimeDays?: number | null;
```
In `FirestoreSupplierRepository.ts` `create()`, add to the `addDoc(col, {…})` object (after `notes: input.notes ?? null,`):
```ts
      leadTimeDays: input.leadTimeDays ?? null,
```
In `update()`, add `'leadTimeDays'` to BOTH the `Updatable` union and the `fields` array (so an updated value is written via the existing `patch[f] = v ?? null` loop):
```ts
      | 'notes'
      | 'leadTimeDays';
```
```ts
      'notes',
      'leadTimeDays',
```

- [ ] **Step 7: Add the form field**

In `SupplierFormPage.tsx`:
- zod `schema`: add `leadTimeDays: z.string().trim().optional().or(z.literal('')),`
- `defaultValues`: add `leadTimeDays: '',`
- the load mapping (where `target` fields seed the form, alongside `contactNumber: target.contactNumber ?? ''`): add
  `leadTimeDays: target.leadTimeDays != null ? String(target.leadTimeDays) : '',`
- `onSubmit` `payload`: add `leadTimeDays: values.leadTimeDays?.trim() ? Number(values.leadTimeDays) : null,`
- Add a numeric `FormField` near the contact fields:
```tsx
<FormField label="Lead time (days)" error={errors.leadTimeDays?.message}
  input={<input type="number" min={0} className={inputCls(!!errors.leadTimeDays)} {...register('leadTimeDays')} />} />
```
(Match the existing `FormField`/`inputCls` usage in this file; `min={0}`.)

- [ ] **Step 8: Typecheck + build**

Run: `cd web_admin && npm run typecheck && npm run build`
Expected: both pass.

- [ ] **Step 9: Commit**

```bash
git add web_admin/src/domain/entities/Supplier.ts web_admin/src/domain/repositories/SupplierRepository.ts web_admin/src/data/converters/supplierConverter.ts web_admin/src/data/converters/supplierConverter.test.ts web_admin/src/data/repositories/FirestoreSupplierRepository.ts web_admin/src/presentation/features/suppliers/SupplierFormPage.tsx
git commit -m "feat(web): add Supplier.leadTimeDays (entity, converter, repo, form)"
```

---

## Task 2: `unitsSoldByProduct` velocity rollup (pure, TDD)

**Files:**
- Create: `web_admin/src/domain/reorder/unitsSoldByProduct.ts`
- Test: `web_admin/src/domain/reorder/unitsSoldByProduct.test.ts`

**Interfaces:**
- Consumes: `Sale`, `saleIsVoided` (`../entities`).
- Produces: `unitsSoldByProduct(sales: Sale[]): Map<string, number>` (productId → total units, excluding voided sales).

- [ ] **Step 1: Write the failing test**

```ts
// web_admin/src/domain/reorder/unitsSoldByProduct.test.ts
import { describe, expect, it } from 'vitest';
import { unitsSoldByProduct } from './unitsSoldByProduct';
import { DiscountType, PaymentMethod, SaleStatus } from '../enums';
import type { Sale } from '../entities';

function sale(over: Partial<Sale> = {}): Sale {
  return {
    id: 's', saleNumber: 'S', items: [], laborLines: [], mechanicId: null, mechanicName: null,
    discountType: DiscountType.amount, paymentMethod: PaymentMethod.cash, tenders: {},
    amountReceived: 0, changeGiven: 0, status: SaleStatus.completed, cashierId: 'c1',
    cashierName: 'Cashier', createdAt: new Date('2026-06-01T10:00:00Z'), updatedAt: null,
    draftId: null, notes: null, voidedAt: null, voidedBy: null, voidedByName: null,
    voidReason: null, ...over,
  };
}
function item(productId: string, qty: number) {
  return { id: `${productId}-${qty}`, productId, sku: productId, name: productId,
    unitPrice: 10, unitCost: 5, quantity: qty, discountValue: 0, unit: 'pcs' };
}

describe('unitsSoldByProduct', () => {
  it('sums quantity per product across sales', () => {
    const m = unitsSoldByProduct([
      sale({ items: [item('p1', 3), item('p2', 1)] }),
      sale({ items: [item('p1', 2)] }),
    ]);
    expect(m.get('p1')).toBe(5);
    expect(m.get('p2')).toBe(1);
  });

  it('excludes voided sales', () => {
    const m = unitsSoldByProduct([
      sale({ items: [item('p1', 4)] }),
      sale({ status: SaleStatus.voided, items: [item('p1', 99)] }),
    ]);
    expect(m.get('p1')).toBe(4);
  });

  it('returns an empty map for no sales', () => {
    expect(unitsSoldByProduct([]).size).toBe(0);
  });
});
```

- [ ] **Step 2: Run it — verify it fails**

Run: `cd web_admin && npx vitest run src/domain/reorder/unitsSoldByProduct.test.ts`
Expected: FAIL — module not found.

- [ ] **Step 3: Implement**

```ts
// web_admin/src/domain/reorder/unitsSoldByProduct.ts
import { saleIsVoided, type Sale } from '../entities';

/** Total units sold per productId across the given (non-voided) sales. */
export function unitsSoldByProduct(sales: Sale[]): Map<string, number> {
  const m = new Map<string, number>();
  for (const sale of sales) {
    if (saleIsVoided(sale)) continue;
    for (const it of sale.items) {
      m.set(it.productId, (m.get(it.productId) ?? 0) + it.quantity);
    }
  }
  return m;
}
```

- [ ] **Step 4: Run it — verify it passes**

Run: `cd web_admin && npx vitest run src/domain/reorder/unitsSoldByProduct.test.ts`
Expected: PASS (3 tests).

- [ ] **Step 5: Commit**

```bash
git add web_admin/src/domain/reorder/unitsSoldByProduct.ts web_admin/src/domain/reorder/unitsSoldByProduct.test.ts
git commit -m "feat(web): unitsSoldByProduct velocity rollup"
```

---

## Task 3: `computeReorderSuggestions` core (pure, TDD)

**Files:**
- Create: `web_admin/src/domain/reorder/computeReorderSuggestions.ts`
- Test: `web_admin/src/domain/reorder/computeReorderSuggestions.test.ts`

**Interfaces:**
- Consumes: `Product`, `Supplier` (`../entities`).
- Produces:
  - `interface ReorderParams { windowDays: number; coverDays: number; defaultLeadDays: number }`
  - `interface ReorderSuggestion { product: Product; supplierName: string | null; velocityPerDay: number; leadDays: number; targetStock: number; suggestedQty: number }`
  - `computeReorderSuggestions(products: Product[], unitsSold: Map<string, number>, suppliers: Supplier[], params: ReorderParams): ReorderSuggestion[]`

- [ ] **Step 1: Write the failing test**

```ts
// web_admin/src/domain/reorder/computeReorderSuggestions.test.ts
import { describe, expect, it } from 'vitest';
import { computeReorderSuggestions, type ReorderParams } from './computeReorderSuggestions';
import type { Product, Supplier } from '../entities';

function product(over: Partial<Product> = {}): Product {
  return {
    id: 'p1', sku: 'BANGUS', name: 'Bangus', costCode: 'AB', cost: 100, price: 150,
    quantity: 0, reorderLevel: 2, unit: 'kg', supplierId: 'sup-1', supplierName: 'Acme',
    isActive: true, createdAt: new Date(), updatedAt: null, createdBy: null, updatedBy: null,
    createdByName: null, updatedByName: null, searchKeywords: [], baseSku: null,
    variationNumber: null, barcode: null, category: null, imageUrl: null, notes: null, ...over,
  };
}
function supplier(over: Partial<Supplier> = {}): Supplier {
  return {
    id: 'sup-1', name: 'Acme', address: null, contactPerson: null, contactNumber: null,
    alternativeNumber: null, email: null, transactionType: 'cash' as Supplier['transactionType'],
    isActive: true, notes: null, leadTimeDays: null, createdAt: new Date(), updatedAt: null,
    createdBy: null, updatedBy: null, productCount: 0, totalInventoryValue: 0, ...over,
  };
}
const params: ReorderParams = { windowDays: 30, coverDays: 14, defaultLeadDays: 7 };

describe('computeReorderSuggestions', () => {
  it('suggests velocity × (lead + cover) − stock, using supplier lead time', () => {
    // 30 units / 30 days = 1/day. lead 6 + cover 14 = 20 days → target 20, stock 5 → suggest 15.
    const out = computeReorderSuggestions(
      [product({ id: 'p1', quantity: 5, supplierId: 'sup-1' })],
      new Map([['p1', 30]]),
      [supplier({ id: 'sup-1', leadTimeDays: 6 })],
      params,
    );
    expect(out).toHaveLength(1);
    expect(out[0]).toMatchObject({ leadDays: 6, targetStock: 20, suggestedQty: 15, velocityPerDay: 1 });
  });

  it('uses defaultLeadDays when the supplier has no lead time', () => {
    // 1/day, lead 7 + cover 14 = 21, stock 0 → 21.
    const out = computeReorderSuggestions(
      [product({ id: 'p1', quantity: 0 })],
      new Map([['p1', 30]]),
      [supplier({ id: 'sup-1', leadTimeDays: null })],
      params,
    );
    expect(out[0]).toMatchObject({ leadDays: 7, suggestedQty: 21 });
  });

  it('rounds the target up (ceil)', () => {
    // 10 units / 30 = 0.333/day × 21 = 7.0 → ceil 7; stock 0 → 7.
    const out = computeReorderSuggestions(
      [product({ id: 'p1', quantity: 0, supplierId: null, supplierName: null })],
      new Map([['p1', 10]]),
      [],
      params,
    );
    expect(out[0]).toMatchObject({ targetStock: 7, suggestedQty: 7, supplierName: null });
  });

  it('excludes zero-velocity products and already-stocked products', () => {
    const out = computeReorderSuggestions(
      [
        product({ id: 'dead', quantity: 0 }),              // no sales → excluded
        product({ id: 'full', quantity: 999 }),            // overstocked → suggest 0 → excluded
      ],
      new Map([['full', 30]]),
      [supplier()],
      params,
    );
    expect(out).toHaveLength(0);
  });

  it('skips inactive products and sorts by supplier then qty desc', () => {
    const out = computeReorderSuggestions(
      [
        product({ id: 'p1', quantity: 0, supplierId: 'b', supplierName: 'Beta' }),
        product({ id: 'p2', quantity: 0, supplierId: 'a', supplierName: 'Acme' }),
        product({ id: 'gone', quantity: 0, isActive: false }),
      ],
      new Map([['p1', 30], ['p2', 60], ['gone', 60]]),
      [supplier({ id: 'a', name: 'Acme' }), supplier({ id: 'b', name: 'Beta' })],
      params,
    );
    expect(out.map((s) => s.product.id)).toEqual(['p2', 'p1']); // Acme before Beta; gone skipped
  });
});
```

- [ ] **Step 2: Run it — verify it fails**

Run: `cd web_admin && npx vitest run src/domain/reorder/computeReorderSuggestions.test.ts`
Expected: FAIL — module not found.

- [ ] **Step 3: Implement**

```ts
// web_admin/src/domain/reorder/computeReorderSuggestions.ts
import type { Product, Supplier } from '../entities';

export interface ReorderParams {
  windowDays: number;
  coverDays: number;
  defaultLeadDays: number;
}

export interface ReorderSuggestion {
  product: Product;
  supplierName: string | null;
  velocityPerDay: number;
  leadDays: number;
  targetStock: number;
  suggestedQty: number;
}

/**
 * Suggests an order quantity per active product:
 *   velocity = unitsSold(window) / windowDays
 *   target   = ceil(velocity × (leadDays + coverDays))
 *   suggest  = max(0, target − currentStock)
 * Lead time comes from the product's supplier, falling back to defaultLeadDays.
 * Products with no recent sales (velocity 0) or enough stock are excluded.
 * Sorted by supplier name (no-supplier last), then suggested qty desc.
 */
export function computeReorderSuggestions(
  products: Product[],
  unitsSold: Map<string, number>,
  suppliers: Supplier[],
  params: ReorderParams,
): ReorderSuggestion[] {
  const supplierById = new Map(suppliers.map((s) => [s.id, s]));
  const out: ReorderSuggestion[] = [];

  for (const product of products) {
    if (!product.isActive) continue;
    const velocityPerDay = (unitsSold.get(product.id) ?? 0) / params.windowDays;
    const supplier = product.supplierId ? supplierById.get(product.supplierId) : undefined;
    const leadDays = supplier?.leadTimeDays ?? params.defaultLeadDays;
    const targetStock = Math.ceil(velocityPerDay * (leadDays + params.coverDays));
    const suggestedQty = Math.max(0, targetStock - product.quantity);
    if (suggestedQty <= 0) continue;
    out.push({
      product,
      supplierName: supplier?.name ?? product.supplierName ?? null,
      velocityPerDay,
      leadDays,
      targetStock,
      suggestedQty,
    });
  }

  return out.sort((a, b) => {
    const sa = a.supplierName ?? '~~~'; // nulls sort last
    const sb = b.supplierName ?? '~~~';
    if (sa !== sb) return sa < sb ? -1 : 1;
    return b.suggestedQty - a.suggestedQty;
  });
}
```

- [ ] **Step 4: Run it — verify it passes**

Run: `cd web_admin && npx vitest run src/domain/reorder/computeReorderSuggestions.test.ts`
Expected: PASS (5 tests).

- [ ] **Step 5: Commit**

```bash
git add web_admin/src/domain/reorder/computeReorderSuggestions.ts web_admin/src/domain/reorder/computeReorderSuggestions.test.ts
git commit -m "feat(web): computeReorderSuggestions core"
```

---

## Task 4: generic `toCsv` util (pure, TDD)

**Files:**
- Modify: `web_admin/src/core/utils/csv.ts`
- Modify: `web_admin/src/core/utils/csv.test.ts`

**Interfaces:**
- Produces: `toCsv(headers: string[], rows: (string | number)[][]): string` — RFC-4180-ish, escapes `" , \n`.

- [ ] **Step 1: Write the failing test**

Append to `web_admin/src/core/utils/csv.test.ts`:
```ts
import { toCsv } from './csv';

describe('toCsv', () => {
  it('joins headers + rows and escapes commas, quotes, newlines', () => {
    const out = toCsv(['name', 'qty'], [['Bangus, 1kg', 3], ['He said "hi"', 1]]);
    expect(out).toBe('name,qty\n"Bangus, 1kg",3\n"He said ""hi""",1');
  });
});
```
(If `csv.test.ts` already imports from `./csv`, add `toCsv` to that import instead of a second import line.)

- [ ] **Step 2: Run it — verify it fails**

Run: `cd web_admin && npx vitest run src/core/utils/csv.test.ts`
Expected: FAIL — `toCsv` is not exported.

- [ ] **Step 3: Implement**

Append to `web_admin/src/core/utils/csv.ts`:
```ts
/** Builds a CSV string from headers + rows, escaping `" , \n` per RFC 4180. */
export function toCsv(headers: string[], rows: (string | number)[][]): string {
  const esc = (v: string | number) => {
    const s = String(v);
    return /[",\n]/.test(s) ? `"${s.replace(/"/g, '""')}"` : s;
  };
  return [headers, ...rows].map((row) => row.map(esc).join(',')).join('\n');
}
```

- [ ] **Step 4: Run it — verify it passes**

Run: `cd web_admin && npx vitest run src/core/utils/csv.test.ts`
Expected: PASS (new test green, existing csv tests still green).

- [ ] **Step 5: Commit**

```bash
git add web_admin/src/core/utils/csv.ts web_admin/src/core/utils/csv.test.ts
git commit -m "feat(web): generic toCsv helper"
```

---

## Task 5: `useReorderSuggestions` hook + `ReorderSuggestionsPage` + nav/route

**Files:**
- Create: `web_admin/src/presentation/hooks/useReorderSuggestions.ts`
- Create: `web_admin/src/presentation/features/inventory/ReorderSuggestionsPage.tsx`
- Modify: `web_admin/src/presentation/router/routePaths.ts`
- Modify: `web_admin/src/presentation/router/routes.tsx`
- Modify: `web_admin/src/presentation/router/routeGuards.ts`
- Modify: `web_admin/src/presentation/components/common/Sidebar.tsx`

**Interfaces:**
- Consumes: `computeReorderSuggestions`/`ReorderParams`/`ReorderSuggestion` (Task 3), `unitsSoldByProduct` (Task 2), `toCsv` (Task 4), `useProducts`, `useSuppliers`, `useSaleRepo`, `downloadCsv`, `formatMoney`.

- [ ] **Step 1: Write the hook**

```ts
// web_admin/src/presentation/hooks/useReorderSuggestions.ts
import { useMemo } from 'react';
import { useQuery } from '@tanstack/react-query';
import { endOfDay, startOfDay, subDays } from 'date-fns';
import { useProducts } from './useProducts';
import { useSuppliers } from './useSuppliers';
import { useSaleRepo } from '@/infrastructure/di/container';
import { unitsSoldByProduct } from '@/domain/reorder/unitsSoldByProduct';
import {
  computeReorderSuggestions,
  type ReorderParams,
  type ReorderSuggestion,
} from '@/domain/reorder/computeReorderSuggestions';

const SALES_CAP = 2000;

export function useReorderSuggestions(params: ReorderParams, now: Date) {
  const saleRepo = useSaleRepo();
  const { data: products, isLoading: lp } = useProducts();
  const { data: suppliers, isLoading: ls } = useSuppliers();

  const range = useMemo(
    () => ({
      start: startOfDay(subDays(now, params.windowDays - 1)),
      end: endOfDay(now),
    }),
    [now, params.windowDays],
  );

  const salesQ = useQuery({
    queryKey: ['reorder', 'sales', range.start.getTime(), range.end.getTime()],
    queryFn: () => saleRepo.list({ start: range.start, end: range.end, limit: SALES_CAP }),
  });

  const suggestions = useMemo<ReorderSuggestion[]>(() => {
    if (!products || !suppliers || !salesQ.data) return [];
    return computeReorderSuggestions(products, unitsSoldByProduct(salesQ.data), suppliers, params);
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [products, suppliers, salesQ.data, params.windowDays, params.coverDays, params.defaultLeadDays]);

  return {
    suggestions,
    isLoading: lp || ls || salesQ.isLoading,
    error: (salesQ.error as Error) ?? null,
    capped: (salesQ.data?.length ?? 0) >= SALES_CAP,
  };
}
```

- [ ] **Step 2: Write the page**

```tsx
// web_admin/src/presentation/features/inventory/ReorderSuggestionsPage.tsx
import { useEffect, useMemo, useState } from 'react';
import { Link } from 'react-router-dom';
import { ArrowDownTrayIcon } from '@heroicons/react/24/outline';
import { useReorderSuggestions } from '@/presentation/hooks/useReorderSuggestions';
import type { ReorderParams } from '@/domain/reorder/computeReorderSuggestions';
import { toCsv, downloadCsv } from '@/core/utils/csv';
import { LoadingView } from '@/presentation/components/common/LoadingView';
import { ErrorView } from '@/presentation/components/common/ErrorView';
import { EmptyState } from '@/presentation/components/common/EmptyState';
import { RoutePaths } from '@/presentation/router/routePaths';

const WINDOWS = [7, 14, 30, 90];

export function ReorderSuggestionsPage() {
  const [now] = useState(() => new Date());
  const [windowDays, setWindowDays] = useState(30);
  const [coverDays, setCoverDays] = useState(14);
  const [defaultLeadDays, setDefaultLeadDays] = useState(7);
  const params: ReorderParams = { windowDays, coverDays, defaultLeadDays };
  const { suggestions, isLoading, error } = useReorderSuggestions(params, now);

  // Editable qty overrides, keyed by product id.
  const [overrides, setOverrides] = useState<Record<string, number>>({});
  useEffect(() => { setOverrides({}); }, [suggestions]); // reset edits when recomputed

  useEffect(() => { document.title = 'Reorder · MAKI POS Admin'; }, []);

  const finalQty = (productId: string, suggested: number) =>
    overrides[productId] ?? suggested;

  // Group by supplier name, preserving the sorted order.
  const groups = useMemo(() => {
    const m = new Map<string, typeof suggestions>();
    for (const s of suggestions) {
      const key = s.supplierName ?? 'No supplier';
      const arr = m.get(key) ?? [];
      arr.push(s);
      m.set(key, arr);
    }
    return [...m.entries()];
  }, [suggestions]);

  function exportCsv() {
    const rows = suggestions.map((s) => [
      s.supplierName ?? 'No supplier',
      s.product.sku,
      s.product.name,
      s.product.quantity,
      s.velocityPerDay.toFixed(2),
      finalQty(s.product.id, s.suggestedQty),
    ]);
    const csv = toCsv(
      ['Supplier', 'SKU', 'Name', 'Current stock', 'Velocity/day', 'Order qty'],
      rows,
    );
    downloadCsv(`reorder-${now.toISOString().slice(0, 10)}.csv`, csv);
  }

  return (
    <div className="space-y-tk-lg px-tk-xl py-tk-lg">
      <header className="space-y-tk-xs">
        <Link to={RoutePaths.inventory} className="text-bodySmall text-light-text-secondary hover:underline">
          ← Back to inventory
        </Link>
        <h1 className="text-headingMedium font-semibold tracking-tight text-light-text">Reorder suggestions</h1>
        <p className="text-bodySmall text-light-text-secondary">
          Suggested order quantity from recent sales velocity × (supplier lead time + cover days).
        </p>
      </header>

      <div className="flex flex-wrap items-end gap-tk-md">
        <Control label="Sales window">
          <select value={windowDays} onChange={(e) => setWindowDays(Number(e.target.value))} className={ctl}>
            {WINDOWS.map((w) => <option key={w} value={w}>{w} days</option>)}
          </select>
        </Control>
        <Control label="Days of cover">
          <input type="number" min={0} value={coverDays} onChange={(e) => setCoverDays(Number(e.target.value) || 0)} className={ctl} />
        </Control>
        <Control label="Default lead (days)">
          <input type="number" min={0} value={defaultLeadDays} onChange={(e) => setDefaultLeadDays(Number(e.target.value) || 0)} className={ctl} />
        </Control>
        <button type="button" onClick={exportCsv} disabled={suggestions.length === 0}
          className="ml-auto inline-flex items-center gap-tk-xs rounded-md border border-light-border px-tk-md py-[8px] text-bodySmall text-light-text hover:bg-light-subtle disabled:opacity-50">
          <ArrowDownTrayIcon className="h-4 w-4" /> Export CSV
        </button>
      </div>

      {error ? (
        <ErrorView title="Could not load reorder data" message={error.message} />
      ) : isLoading ? (
        <div className="h-32"><LoadingView label="Crunching sales…" /></div>
      ) : suggestions.length === 0 ? (
        <EmptyState title="Nothing to reorder" description="No products are below their projected demand for this window." />
      ) : (
        <div className="space-y-tk-lg">
          {groups.map(([supplierName, rows]) => (
            <section key={supplierName} className="overflow-hidden rounded-lg border border-light-hairline bg-light-card">
              <h2 className="border-b border-light-hairline bg-light-subtle px-tk-md py-tk-sm text-bodySmall font-semibold text-light-text">
                {supplierName}
              </h2>
              <table className="w-full text-bodySmall">
                <thead className="border-b border-light-hairline text-light-text-secondary">
                  <tr>
                    <th className="px-tk-md py-tk-sm text-left font-medium">Product</th>
                    <th className="px-tk-md py-tk-sm text-right font-medium">Current</th>
                    <th className="px-tk-md py-tk-sm text-right font-medium">Velocity/day</th>
                    <th className="px-tk-md py-tk-sm text-right font-medium">Lead</th>
                    <th className="px-tk-md py-tk-sm text-right font-medium">Order qty</th>
                  </tr>
                </thead>
                <tbody className="divide-y divide-light-hairline">
                  {rows.map((s) => (
                    <tr key={s.product.id}>
                      <td className="px-tk-md py-tk-sm">
                        <span className="font-medium text-light-text">{s.product.name}</span>
                        <span className="ml-tk-sm text-light-text-hint">{s.product.sku}</span>
                      </td>
                      <td className="px-tk-md py-tk-sm text-right tabular-nums">{s.product.quantity}</td>
                      <td className="px-tk-md py-tk-sm text-right tabular-nums">{s.velocityPerDay.toFixed(2)}</td>
                      <td className="px-tk-md py-tk-sm text-right tabular-nums">{s.leadDays}d</td>
                      <td className="px-tk-md py-tk-sm text-right">
                        <input type="number" min={0}
                          value={finalQty(s.product.id, s.suggestedQty)}
                          onChange={(e) => setOverrides((o) => ({ ...o, [s.product.id]: Math.max(0, Number(e.target.value) || 0) }))}
                          className="w-20 rounded-md border border-light-border bg-light-card px-tk-sm py-[4px] text-right tabular-nums" />
                      </td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </section>
          ))}
        </div>
      )}
    </div>
  );
}

const ctl = 'rounded-md border border-light-border bg-light-card px-tk-md py-[6px] text-bodySmall text-light-text';
function Control({ label, children }: { label: string; children: React.ReactNode }) {
  return (
    <label className="block">
      <span className="mb-1 block text-[11px] font-medium uppercase tracking-wider text-light-text-hint">{label}</span>
      {children}
    </label>
  );
}
```

- [ ] **Step 3: Wire route + path + guard + nav**

In `routePaths.ts`, add under the inventory block:
```ts
  reorder: '/inventory/reorder',
```
In `routes.tsx`, import and register (place BEFORE `productDetail` so the static path wins over `/inventory/:id`):
```tsx
import { ReorderSuggestionsPage } from '@/presentation/features/inventory/ReorderSuggestionsPage';
```
```tsx
{ path: RoutePaths.reorder, element: <ReorderSuggestionsPage /> },
```
In `routeGuards.ts` `protectedRoutes`, add:
```ts
[RoutePaths.reorder, Permission.viewProductCost],
```
In `Sidebar.tsx`, add to the **Stock** section `items` (import `ClipboardDocumentListIcon` from `@heroicons/react/24/outline`):
```ts
{ label: 'Reorder', path: RoutePaths.reorder, icon: ClipboardDocumentListIcon },
```

- [ ] **Step 4: Typecheck + build + full tests**

Run: `cd web_admin && npm run typecheck && npm run test && npm run build`
Expected: typecheck clean; all vitest pass; build succeeds.

- [ ] **Step 5: Manual verify (dev server)**

`npm run dev`, sign in, open **/inventory/reorder** (also via the **Reorder** nav). Confirm: a product that has sold recently and is low shows a suggested qty = roughly `velocity × (lead+cover) − stock`; changing the window/cover recomputes; editing a qty and **Export CSV** downloads the edited numbers grouped by supplier; set a supplier's **Lead time** in Suppliers and confirm that product's Lead column reflects it.

- [ ] **Step 6: Commit**

```bash
git add web_admin/src/presentation/hooks/useReorderSuggestions.ts web_admin/src/presentation/features/inventory/ReorderSuggestionsPage.tsx web_admin/src/presentation/router/routePaths.ts web_admin/src/presentation/router/routes.tsx web_admin/src/presentation/router/routeGuards.ts web_admin/src/presentation/components/common/Sidebar.tsx
git commit -m "feat(web): reorder suggestions page + hook + nav"
```

---

## Self-review notes (author)

- **Spec coverage:** §2.1 leadTimeDays → Task 1; §2.2 params → Task 5 controls; §3 compute → Tasks 2+3 (velocity rollup split out, uncapped, since `topSellingProducts` caps at `limit`); §4 UI/CSV/nav → Tasks 4+5; §5 testing → Tasks 1–4 + Task 5 gates. Covered.
- **Type consistency:** `ReorderParams`/`ReorderSuggestion` defined in Task 3, consumed by Task 5; `unitsSoldByProduct` (Task 2) → Task 5 hook; `toCsv` (Task 4) → Task 5 page; `Supplier.leadTimeDays` (Task 1) read by Task 3's compute.
- **Velocity divisor** is `windowDays` (not the count of days with sales) — simple average per the spec.
- **Confirm at implementation:** exact location of `SupplierCreateInput` (grep if not in `SupplierRepository.ts`); the `SupplierFormPage` load-mapping line to mirror; that `csv.test.ts` already has a top-level `describe` import to extend.
