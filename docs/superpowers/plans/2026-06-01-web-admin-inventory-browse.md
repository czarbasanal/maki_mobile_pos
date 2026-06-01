# Web Inventory — Slice 1 (Browse + read-only detail) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans (inline) or superpowers:subagent-driven-development to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax.

**Goal:** Add a web-admin inventory **list** (`/inventory`) and **read-only product detail** (`/inventory/:id`), retiring the Inventory placeholder, plus a `?product=` deep-link on the existing price-history page.

**Architecture:** Pure presentation + routing over reads that already exist (`watchAll` via `useProducts`, `getById` via a new `useProduct` hook). List filtering is a pure, unit-tested helper; pages mirror `SuppliersListPage` and the dashboard `InventoryStatus`. No repository changes.

**Tech Stack:** React, TypeScript, React Router v6, TanStack Query, Tailwind (project tokens), Vitest. Spec: `docs/superpowers/specs/2026-06-01-web-admin-inventory-browse-design.md`. Run all commands from `web_admin/`.

**Toolchain notes:** typecheck with `npx tsc --noEmit -p tsconfig.json` (the `npm run typecheck` script is broken). Run logic suites with `--environment=node`. Unit-tested modules use **relative imports** (not `@/`). Presentation files may use `@/`.

---

## Context already verified

- `getStockStatus(p)` + `StockStatus` ({inStock, lowStock, outOfStock}) live on `src/domain/entities/Product.ts`, re-exported by `@/domain/entities`.
- `useProducts()` (`src/presentation/hooks/useProducts.ts`) returns `SubscriptionState<Product[]>` = `{ data, isLoading, error }` (live `watchAll`).
- `useProductRepo()` DI hook + `FirestoreProductRepository.getById(id)` exist.
- Shared components: `LoadingView` (`label`), `ErrorView` (`title`,`message`), `EmptyState` (`title`,`description`) under `src/presentation/components/common/`.
- `formatMoney(n)` (`@/core/utils/money`), `cn(...)` (`@/core/utils/cn`).
- `RoutePaths.inventory = '/inventory'`, `RoutePaths.productDetail = '/inventory/:id'`, `RoutePaths.priceHistory = '/inventory/price-history'` all exist in `routePaths.ts`.
- Guards: `/inventory` (exact → `viewInventory`) and `^/inventory/[^/]+$` (dynamic → `viewInventory`) already in `routeGuards.ts`; `/inventory/add` & `/inventory/price-history` are exact entries matched first. **No guard change needed.**
- `PriceHistoryPage.tsx` already uses `useProducts()` + local `selected` state.

## File Structure

**Create:**
- `web_admin/src/domain/products/filterProducts.ts` — pure list filter (`filterProducts`).
- `web_admin/src/domain/products/filterProducts.test.ts` — vitest.
- `web_admin/src/presentation/hooks/useProduct.ts` — one-shot `getById` query.
- `web_admin/src/presentation/features/inventory/InventoryListPage.tsx`
- `web_admin/src/presentation/features/inventory/InventoryDetailPage.tsx`

**Modify:**
- `web_admin/src/presentation/router/routes.tsx` (wire list + add detail route)
- `web_admin/src/presentation/features/inventory/PriceHistoryPage.tsx` (`?product=` pre-select)

---

## Task 1: `filterProducts` pure helper

**Files:**
- Create: `web_admin/src/domain/products/filterProducts.ts`
- Test: `web_admin/src/domain/products/filterProducts.test.ts`

- [ ] **Step 1: Write the failing test**

Create `web_admin/src/domain/products/filterProducts.test.ts`:

```ts
import { describe, expect, it } from 'vitest';
import { filterProducts, type ProductFilter } from './filterProducts';
import { StockStatus, type Product } from '../entities/Product';

function p(over: Partial<Product>): Product {
  return {
    id: 'id', sku: 'SKU', name: 'Name', costCode: '', cost: 0, price: 0,
    quantity: 0, reorderLevel: 0, unit: 'pcs', supplierId: null, supplierName: null,
    isActive: true, createdAt: new Date(0), updatedAt: null, createdBy: null,
    updatedBy: null, createdByName: null, updatedByName: null, searchKeywords: [],
    baseSku: null, variationNumber: null, barcode: null, category: null,
    imageUrl: null, notes: null, ...over,
  };
}

const ALL: ProductFilter = { search: '', stock: 'all', category: 'all' };

const products: Product[] = [
  p({ id: 'a', name: 'Coca Cola', sku: 'COKE-1', quantity: 50, reorderLevel: 10, category: 'Drinks' }), // inStock
  p({ id: 'b', name: 'Pepsi', sku: 'PEP-1', quantity: 5, reorderLevel: 10, category: 'Drinks' }),        // lowStock
  p({ id: 'c', name: 'Chips', sku: 'CHIP-1', quantity: 0, reorderLevel: 5, category: 'Snacks' }),        // outOfStock
];

describe('filterProducts', () => {
  it('returns all with the empty filter', () => {
    expect(filterProducts(products, ALL).map((x) => x.id)).toEqual(['a', 'b', 'c']);
  });
  it('searches name and sku (case-insensitive)', () => {
    expect(filterProducts(products, { ...ALL, search: 'cola' }).map((x) => x.id)).toEqual(['a']);
    expect(filterProducts(products, { ...ALL, search: 'pep-1' }).map((x) => x.id)).toEqual(['b']);
  });
  it('filters by stock status', () => {
    expect(filterProducts(products, { ...ALL, stock: StockStatus.inStock }).map((x) => x.id)).toEqual(['a']);
    expect(filterProducts(products, { ...ALL, stock: StockStatus.lowStock }).map((x) => x.id)).toEqual(['b']);
    expect(filterProducts(products, { ...ALL, stock: StockStatus.outOfStock }).map((x) => x.id)).toEqual(['c']);
  });
  it('filters by category', () => {
    expect(filterProducts(products, { ...ALL, category: 'Snacks' }).map((x) => x.id)).toEqual(['c']);
  });
  it('ANDs the axes together', () => {
    expect(
      filterProducts(products, { ...ALL, search: 'p', stock: StockStatus.lowStock, category: 'Drinks' }).map((x) => x.id),
    ).toEqual(['b']);
  });
});
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd web_admin && npx vitest run --environment=node src/domain/products/filterProducts.test.ts`
Expected: FAIL — cannot resolve `./filterProducts`.

- [ ] **Step 3: Write the implementation**

Create `web_admin/src/domain/products/filterProducts.ts`:

```ts
// Pure list-filter for the inventory page. Unit-tested in node env, so it uses
// RELATIVE imports (vitest doesn't resolve @/).
import { getStockStatus } from '../entities/Product';
import type { Product, StockStatus } from '../entities/Product';

export interface ProductFilter {
  search: string; // '' disables search
  stock: StockStatus | 'all';
  category: string | 'all';
}

/** Filters by name/SKU substring (case-insensitive), stock status, and
 *  category. 'all' / '' disable that axis; axes are ANDed. */
export function filterProducts(products: Product[], f: ProductFilter): Product[] {
  const q = f.search.trim().toLowerCase();
  return products.filter((p) => {
    if (q && !(p.name.toLowerCase().includes(q) || p.sku.toLowerCase().includes(q))) {
      return false;
    }
    if (f.stock !== 'all' && getStockStatus(p) !== f.stock) return false;
    if (f.category !== 'all' && (p.category ?? '') !== f.category) return false;
    return true;
  });
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd web_admin && npx vitest run --environment=node src/domain/products/filterProducts.test.ts`
Expected: PASS (5 tests).

- [ ] **Step 5: Commit**

```bash
git add web_admin/src/domain/products/filterProducts.ts web_admin/src/domain/products/filterProducts.test.ts
git commit -m "feat(web-admin): filterProducts pure helper (search/stock/category)"
```

---

## Task 2: `useProduct` hook

**Files:**
- Create: `web_admin/src/presentation/hooks/useProduct.ts`

- [ ] **Step 1: Write the hook**

Create `web_admin/src/presentation/hooks/useProduct.ts`:

```ts
import { useQuery } from '@tanstack/react-query';
import { useProductRepo } from '@/infrastructure/di/container';
import type { Product } from '@/domain/entities';

/** One-shot read of a single product by id. Disabled until an id is supplied. */
export function useProduct(id: string | undefined) {
  const repo = useProductRepo();
  return useQuery<Product | null>({
    queryKey: ['product', id],
    queryFn: () => repo.getById(id as string),
    enabled: !!id,
  });
}
```

- [ ] **Step 2: Typecheck**

Run: `cd web_admin && npx tsc --noEmit -p tsconfig.json`
Expected: clean.

- [ ] **Step 3: Commit**

```bash
git add web_admin/src/presentation/hooks/useProduct.ts
git commit -m "feat(web-admin): useProduct query hook"
```

---

## Task 3: Inventory list page

**Files:**
- Create: `web_admin/src/presentation/features/inventory/InventoryListPage.tsx`

- [ ] **Step 1: Write the page**

Create `web_admin/src/presentation/features/inventory/InventoryListPage.tsx`:

```tsx
import { useEffect, useMemo, useState, type ReactNode } from 'react';
import { useNavigate } from 'react-router-dom';
import { MagnifyingGlassIcon } from '@heroicons/react/24/outline';
import { useProducts } from '@/presentation/hooks/useProducts';
import { getStockStatus, StockStatus } from '@/domain/entities';
import { filterProducts, type ProductFilter } from '@/domain/products/filterProducts';
import { LoadingView } from '@/presentation/components/common/LoadingView';
import { ErrorView } from '@/presentation/components/common/ErrorView';
import { EmptyState } from '@/presentation/components/common/EmptyState';
import { formatMoney } from '@/core/utils/money';
import { cn } from '@/core/utils/cn';

const STOCK_LABEL: Record<StockStatus, string> = {
  [StockStatus.inStock]: 'In stock',
  [StockStatus.lowStock]: 'Low stock',
  [StockStatus.outOfStock]: 'Out of stock',
};
const STOCK_BADGE: Record<StockStatus, string> = {
  [StockStatus.inStock]: 'bg-green-50 text-green-700',
  [StockStatus.lowStock]: 'bg-orange-50 text-orange-700',
  [StockStatus.outOfStock]: 'bg-red-50 text-red-700',
};

export function InventoryListPage() {
  useEffect(() => {
    document.title = 'Inventory · MAKI POS Admin';
  }, []);
  const navigate = useNavigate();
  const { data: products, isLoading, error } = useProducts();

  const [search, setSearch] = useState('');
  const [stock, setStock] = useState<ProductFilter['stock']>('all');
  const [category, setCategory] = useState<ProductFilter['category']>('all');

  const active = useMemo(() => (products ?? []).filter((p) => p.isActive), [products]);

  const counts = useMemo(() => {
    let inStock = 0;
    let lowStock = 0;
    let outOfStock = 0;
    for (const p of active) {
      const s = getStockStatus(p);
      if (s === StockStatus.inStock) inStock += 1;
      else if (s === StockStatus.lowStock) lowStock += 1;
      else outOfStock += 1;
    }
    return { inStock, lowStock, outOfStock };
  }, [active]);

  const categories = useMemo(() => {
    const set = new Set<string>();
    for (const p of active) if (p.category) set.add(p.category);
    return [...set].sort();
  }, [active]);

  const filtered = useMemo(
    () => filterProducts(active, { search, stock, category }),
    [active, search, stock, category],
  );

  if (error) return <ErrorView title="Could not load inventory" message={error.message} />;

  const toggleStock = (s: StockStatus) => setStock((cur) => (cur === s ? 'all' : s));

  return (
    <div className="space-y-tk-xl px-tk-xl py-tk-lg">
      <header>
        <h1 className="text-headingMedium font-semibold tracking-tight text-light-text">Inventory</h1>
        <p className="mt-tk-xs text-bodySmall text-light-text-secondary">
          Products, stock levels, and pricing.
        </p>
      </header>

      <div className="grid grid-cols-1 gap-tk-md sm:grid-cols-3">
        <CountCard label="In stock" value={counts.inStock} active={stock === StockStatus.inStock} tone="green" onClick={() => toggleStock(StockStatus.inStock)} />
        <CountCard label="Low stock" value={counts.lowStock} active={stock === StockStatus.lowStock} tone="orange" onClick={() => toggleStock(StockStatus.lowStock)} />
        <CountCard label="Out of stock" value={counts.outOfStock} active={stock === StockStatus.outOfStock} tone="red" onClick={() => toggleStock(StockStatus.outOfStock)} />
      </div>

      <div className="flex flex-wrap items-center gap-tk-sm">
        <div className="relative max-w-md flex-1">
          <MagnifyingGlassIcon className="pointer-events-none absolute left-3 top-1/2 h-4 w-4 -translate-y-1/2 text-light-text-hint" />
          <input
            type="text"
            placeholder="Search by name or SKU…"
            value={search}
            onChange={(e) => setSearch(e.target.value)}
            className="w-full rounded-md border border-light-border bg-light-card py-tk-sm pl-9 pr-tk-md text-bodySmall text-light-text outline-none focus:border-light-text"
          />
        </div>
        <select
          value={category}
          onChange={(e) => setCategory(e.target.value)}
          className="rounded-md border border-light-border bg-light-card px-tk-sm py-tk-sm text-bodySmall text-light-text"
        >
          <option value="all">All categories</option>
          {categories.map((c) => (
            <option key={c} value={c}>
              {c}
            </option>
          ))}
        </select>
      </div>

      {isLoading || !products ? (
        <LoadingView label="Loading inventory…" />
      ) : filtered.length === 0 ? (
        <EmptyState
          title="No products found"
          description={search ? 'Try a different search.' : 'No products match these filters.'}
        />
      ) : (
        <div className="overflow-hidden rounded-lg border border-light-hairline bg-light-card">
          <table className="w-full text-bodySmall">
            <thead className="border-b border-light-hairline bg-light-subtle text-light-text-secondary">
              <tr>
                <Th>Name</Th>
                <Th>SKU</Th>
                <Th>Category</Th>
                <Th>Stock</Th>
                <Th className="text-right">Price</Th>
                <Th className="text-right">Cost</Th>
              </tr>
            </thead>
            <tbody className="divide-y divide-light-hairline">
              {filtered.map((p) => {
                const s = getStockStatus(p);
                return (
                  <tr
                    key={p.id}
                    onClick={() => navigate(`/inventory/${p.id}`)}
                    className="cursor-pointer hover:bg-light-subtle"
                  >
                    <Td className="font-medium text-light-text">{p.name}</Td>
                    <Td className="text-light-text-secondary">{p.sku}</Td>
                    <Td className="text-light-text-secondary">{p.category ?? '—'}</Td>
                    <Td>
                      <span className={cn('inline-flex items-center rounded-full px-2 py-[2px] text-[11px] font-medium', STOCK_BADGE[s])}>
                        {p.quantity} · {STOCK_LABEL[s]}
                      </span>
                    </Td>
                    <Td className="text-right text-light-text">{formatMoney(p.price)}</Td>
                    <Td className="text-right text-light-text">{formatMoney(p.cost)}</Td>
                  </tr>
                );
              })}
            </tbody>
          </table>
        </div>
      )}
    </div>
  );
}

function CountCard({
  label,
  value,
  active,
  tone,
  onClick,
}: {
  label: string;
  value: number;
  active: boolean;
  tone: 'green' | 'orange' | 'red';
  onClick: () => void;
}) {
  const dot = { green: 'bg-green-500', orange: 'bg-orange-500', red: 'bg-red-500' }[tone];
  return (
    <button
      type="button"
      onClick={onClick}
      className={cn(
        'flex items-center justify-between rounded-lg border bg-light-card px-tk-lg py-tk-md text-left transition-colors hover:border-light-text',
        active ? 'border-light-text' : 'border-light-hairline',
      )}
    >
      <span className="flex items-center gap-tk-sm">
        <span className={cn('h-2 w-2 rounded-full', dot)} />
        <span className="text-bodySmall text-light-text-secondary">{label}</span>
      </span>
      <span className="text-headingMedium font-semibold text-light-text">{value}</span>
    </button>
  );
}

function Th({ children, className }: { children: ReactNode; className?: string }) {
  return <th className={cn('px-tk-md py-tk-sm text-left font-medium', className)}>{children}</th>;
}
function Td({ children, className }: { children: ReactNode; className?: string }) {
  return <td className={cn('px-tk-md py-tk-sm', className)}>{children}</td>;
}
```

- [ ] **Step 2: Typecheck**

Run: `cd web_admin && npx tsc --noEmit -p tsconfig.json`
Expected: clean.

- [ ] **Step 3: Commit**

```bash
git add web_admin/src/presentation/features/inventory/InventoryListPage.tsx
git commit -m "feat(web-admin): inventory list page (counts, search, filters, table)"
```

---

## Task 4: Inventory detail page

**Files:**
- Create: `web_admin/src/presentation/features/inventory/InventoryDetailPage.tsx`

- [ ] **Step 1: Write the page**

Create `web_admin/src/presentation/features/inventory/InventoryDetailPage.tsx`:

```tsx
import { useEffect, type ReactNode } from 'react';
import { Link, useParams } from 'react-router-dom';
import { ArrowLeftIcon, ClockIcon } from '@heroicons/react/24/outline';
import { useProduct } from '@/presentation/hooks/useProduct';
import { getStockStatus, StockStatus } from '@/domain/entities';
import { LoadingView } from '@/presentation/components/common/LoadingView';
import { ErrorView } from '@/presentation/components/common/ErrorView';
import { EmptyState } from '@/presentation/components/common/EmptyState';
import { RoutePaths } from '@/presentation/router/routePaths';
import { formatMoney } from '@/core/utils/money';

const STOCK_LABEL: Record<StockStatus, string> = {
  [StockStatus.inStock]: 'In stock',
  [StockStatus.lowStock]: 'Low stock',
  [StockStatus.outOfStock]: 'Out of stock',
};

function fmtDate(d: Date | null): string {
  if (!d) return '—';
  return d.toLocaleString('en-PH', { dateStyle: 'medium', timeStyle: 'short' });
}

export function InventoryDetailPage() {
  const { id } = useParams<{ id: string }>();
  const { data: product, isLoading, error } = useProduct(id);

  useEffect(() => {
    document.title = product ? `${product.name} · Inventory` : 'Inventory';
  }, [product]);

  if (error) return <ErrorView title="Could not load product" message={error.message} />;
  if (isLoading) return <LoadingView label="Loading product…" />;
  if (!product) {
    return (
      <div className="space-y-tk-lg px-tk-xl py-tk-lg">
        <BackLink />
        <EmptyState title="Product not found" description="This product may have been removed." />
      </div>
    );
  }

  const s = getStockStatus(product);
  const margin = product.price - product.cost;
  const marginPct = product.price > 0 ? (margin / product.price) * 100 : 0;

  return (
    <div className="space-y-tk-lg px-tk-xl py-tk-lg">
      <BackLink />
      <header className="flex items-start justify-between gap-tk-md">
        <div className="flex items-center gap-tk-md">
          {product.imageUrl ? (
            <img src={product.imageUrl} alt="" className="h-16 w-16 rounded-md object-cover" />
          ) : null}
          <div>
            <h1 className="text-headingMedium font-semibold tracking-tight text-light-text">{product.name}</h1>
            <p className="mt-tk-xs text-bodySmall text-light-text-hint">{product.sku}</p>
          </div>
        </div>
        {!product.isActive ? (
          <span className="rounded-full bg-light-subtle px-tk-sm py-[2px] text-[11px] font-medium text-light-text-secondary">
            Inactive
          </span>
        ) : null}
      </header>

      <div className="grid grid-cols-1 gap-tk-lg sm:grid-cols-2">
        <Card title="Stock">
          <Field label="Quantity" value={`${product.quantity} ${product.unit}`} />
          <Field label="Reorder level" value={String(product.reorderLevel)} />
          <Field label="Status" value={STOCK_LABEL[s]} />
        </Card>
        <Card title="Pricing">
          <Field label="Price" value={formatMoney(product.price)} />
          <Field label="Cost" value={formatMoney(product.cost)} />
          <Field label="Margin" value={`${formatMoney(margin)} (${marginPct.toFixed(1)}%)`} />
        </Card>
        <Card title="Details">
          <Field label="Category" value={product.category ?? '—'} />
          <Field label="Unit" value={product.unit} />
          <Field label="Supplier" value={product.supplierName ?? '—'} />
          <Field label="Barcode" value={product.barcode ?? '—'} />
          <Field label="Notes" value={product.notes ?? '—'} />
        </Card>
        <Card title="Audit">
          <Field label="Created by" value={product.createdByName ?? product.createdBy ?? '—'} />
          <Field label="Created at" value={fmtDate(product.createdAt)} />
          <Field label="Updated by" value={product.updatedByName ?? product.updatedBy ?? '—'} />
          <Field label="Updated at" value={fmtDate(product.updatedAt)} />
        </Card>
      </div>

      <Link
        to={`${RoutePaths.priceHistory}?product=${product.id}`}
        className="inline-flex items-center gap-tk-xs rounded-md border border-light-border px-tk-md py-tk-sm text-bodySmall text-light-text hover:bg-light-subtle"
      >
        <ClockIcon className="h-4 w-4" />
        View price history
      </Link>
    </div>
  );
}

function BackLink() {
  return (
    <Link
      to={RoutePaths.inventory}
      className="inline-flex items-center gap-tk-xs text-bodySmall text-light-text-secondary hover:text-light-text"
    >
      <ArrowLeftIcon className="h-4 w-4" /> Back to inventory
    </Link>
  );
}

function Card({ title, children }: { title: string; children: ReactNode }) {
  return (
    <div className="rounded-lg border border-light-hairline bg-light-card p-tk-lg">
      <h2 className="mb-tk-md text-bodyMedium font-semibold text-light-text">{title}</h2>
      <dl className="space-y-tk-sm">{children}</dl>
    </div>
  );
}
function Field({ label, value }: { label: string; value: string }) {
  return (
    <div className="flex justify-between gap-tk-md">
      <dt className="text-bodySmall text-light-text-hint">{label}</dt>
      <dd className="text-right text-bodySmall text-light-text">{value}</dd>
    </div>
  );
}
```

- [ ] **Step 2: Typecheck**

Run: `cd web_admin && npx tsc --noEmit -p tsconfig.json`
Expected: clean.

- [ ] **Step 3: Commit**

```bash
git add web_admin/src/presentation/features/inventory/InventoryDetailPage.tsx
git commit -m "feat(web-admin): read-only product detail page"
```

---

## Task 5: Wire the routes

**Files:**
- Modify: `web_admin/src/presentation/router/routes.tsx`

- [ ] **Step 1: Add the imports**

In `web_admin/src/presentation/router/routes.tsx`, after the
`import { PriceHistoryPage } …` line, add:

```tsx
import { InventoryListPage } from '@/presentation/features/inventory/InventoryListPage';
import { InventoryDetailPage } from '@/presentation/features/inventory/InventoryDetailPage';
```

- [ ] **Step 2: Wire the list route**

Replace:

```tsx
        { path: RoutePaths.inventory, element: placeholder('Inventory', 'phase 7') },
```

with:

```tsx
        { path: RoutePaths.inventory, element: <InventoryListPage /> },
```

- [ ] **Step 3: Add the detail route**

Immediately after the `RoutePaths.productEdit` line, add:

```tsx
        { path: RoutePaths.productDetail, element: <InventoryDetailPage /> },
```

(React Router v6 ranks the static `/inventory/add`, `/inventory/edit/:id`, and
`/inventory/price-history` above the dynamic `/inventory/:id`, so array order is
not significant here.)

- [ ] **Step 4: Typecheck + build**

Run: `cd web_admin && npx tsc --noEmit -p tsconfig.json && npm run build`
Expected: tsc clean; build succeeds.

- [ ] **Step 5: Commit**

```bash
git add web_admin/src/presentation/router/routes.tsx
git commit -m "feat(web-admin): wire /inventory list + /inventory/:id detail routes"
```

---

## Task 6: Price-history `?product=` deep-link

**Files:**
- Modify: `web_admin/src/presentation/features/inventory/PriceHistoryPage.tsx`

- [ ] **Step 1: Import useSearchParams**

In `PriceHistoryPage.tsx`, change the react-router import to add `useSearchParams`.
The file currently imports nothing from `react-router-dom` (it doesn't navigate),
so add this import near the other imports:

```tsx
import { useSearchParams } from 'react-router-dom';
```

- [ ] **Step 2: Pre-select the product from the query param**

Inside `PriceHistoryPage`, after the existing
`const [selected, setSelected] = useState<Product | null>(null);` line, add:

```tsx
  const [searchParams] = useSearchParams();
  const productIdParam = searchParams.get('product');

  // Deep-link: when arriving via /inventory/price-history?product=<id>, pre-select
  // that product once the list has loaded. Manual search still works afterwards.
  useEffect(() => {
    if (!productIdParam || selected || !products) return;
    const match = products.find((p) => p.id === productIdParam);
    if (match) {
      setSelected(match);
      setQueryText(match.name);
    }
  }, [productIdParam, products, selected]);
```

If `useEffect` is not already imported in this file, add it to the existing
`react` import (the file already imports `useEffect` for `document.title`, so no
change is usually needed — verify the import line includes `useEffect`).

- [ ] **Step 3: Typecheck + build**

Run: `cd web_admin && npx tsc --noEmit -p tsconfig.json && npm run build`
Expected: tsc clean; build succeeds.

- [ ] **Step 4: Commit**

```bash
git add web_admin/src/presentation/features/inventory/PriceHistoryPage.tsx
git commit -m "feat(web-admin): price-history deep-link via ?product= query param"
```

---

## Task 7: Final gates

- [ ] **Step 1: Typecheck**

Run: `cd web_admin && npx tsc --noEmit -p tsconfig.json`
Expected: clean.

- [ ] **Step 2: Unit tests**

Run: `cd web_admin && npx vitest run --environment=node`
Expected: all suites pass (existing 65 + the new `filterProducts` suite).

- [ ] **Step 3: Build**

Run: `cd web_admin && npm run build`
Expected: succeeds.

- [ ] **Step 4: Manual smoke (optional, /run or preview)**

As an admin: open "Inventory" → list shows counts + products; search/stock/category
filters narrow the table; click a row → detail shows all fields; "View price
history" lands on that product (pre-selected). Confirm the Inventory placeholder
is gone.

---

## Self-Review notes (author)

- **Spec coverage:** §4 list → Task 3 (+ Task 1 filter). §4.1 `filterProducts` → Task 1. §5 detail → Task 4 (+ Task 2 `useProduct`). §6 deep-link → Task 6. §7 routing → Task 5 (no guard change, per spec). §9 testing → Task 1 + full-suite runs in 5/6/7.
- **Out of scope (Slices 2/3):** edit, stock adjust, deactivate, create, image upload, multi-barcode editing.
- **Type consistency:** `ProductFilter{search,stock,category}`, `filterProducts`, `useProduct(id)`, `StockStatus`/`getStockStatus`, `StOCK_LABEL`/`STOCK_BADGE` maps are used identically across helper, pages, and tests.
- **Assumption:** Tailwind tokens `border-light-border`, `bg-light-card`, `bg-light-subtle`, `text-light-*`, `bg-{green,orange,red}-{50,500,700}` exist (used by SuppliersListPage / tones.ts). If a token is missing, tsc passes but the build's Tailwind scan just omits it — verify visually in the smoke test.
