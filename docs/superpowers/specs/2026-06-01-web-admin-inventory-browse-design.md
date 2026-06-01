# Web Admin — Inventory (Slice 1: Browse + read-only detail) — Design

**Date:** 2026-06-01
**Status:** Approved (brainstorm complete)
**Effort:** Web inventory CRUD parity (phase 7), decomposed into slices — this spec is **Slice 1**.

## 1. Overview

The web admin (`web_admin/`, React) has no inventory pages — `/inventory`,
`/inventory/add`, `/inventory/edit/:id` all render `<PagePlaceholder>`. The
mobile app has a full inventory manager. This effort brings inventory to the web
at **full CRUD parity**, built in shippable slices.

**Slice 1 (this spec): browse + read-only detail.** A product list (search +
filters + counts) and a read-only product detail page. **No writes** — every
read it needs (`watchAll`, `getById`/`watchOne`) is already implemented in
`FirestoreProductRepository`, so this slice is pure presentation + routing. It
retires the Inventory placeholder with a useful monitoring view.

## 2. Decomposition (recorded for context; only Slice 1 is in scope here)

- **Slice 1 — Browse + read-only detail** (this spec).
- **Slice 2 — Edit + stock + deactivate.** Make the detail editable (zod form,
  core fields; `recordPriceChange` on cost/price change), and implement the
  `adjustStock` / `setStock` / `deactivate` repo stubs + Adjust-Stock dialog +
  Deactivate/Reactivate.
- **Slice 3 — Create new product (+ heavy extras).** `/inventory/add` full form:
  SKU auto-gen (web already has `domain/products/sku.ts`), category/unit
  dropdowns, supplier picker, image upload (`infrastructure/firebase/storage.ts`),
  multiple barcodes.

Each slice is its own spec → plan → implement and ships green/deployable.

## 3. Scope (Slice 1)

In:
- `/inventory` list page (counts, search, stock + category filters, table).
- `/inventory/:id` read-only detail page (all fields + audit + price-history link).
- Deep-link enhancement to the existing standalone `PriceHistoryPage`.

Out (later slices / non-goals):
- Any writes: create, edit, stock adjust, deactivate — **Slice 2/3**.
- Image upload, multiple-barcode editing — **Slice 3**.
- Removing the standalone `/inventory/price-history` page — **kept** (user
  decision); detail links to it.
- Server-side pagination/search — client-side over the live `watchAll` list is
  sufficient at current catalog size (mirrors `SuppliersListPage`).

## 4. `/inventory` list page

`features/inventory/InventoryListPage.tsx`. Mirrors `SuppliersListPage` (search +
table + filter state) and the dashboard's `InventoryStatus` (counts).

- **Data:** `useProducts()` (existing hook — live `watchAll`, newest by name).
  Loading/error via the established `LoadingView`/`ErrorView`.
- **Counts row:** three cards — In stock / Low stock / Out of stock — computed
  from `getStockStatus(product)` (already on the `Product` entity). Each card is
  clickable and sets the stock filter (active card highlighted). Mirrors mobile +
  dashboard.
- **Controls:**
  - Search input — matches `name` or `sku` (case-insensitive substring).
  - Stock filter — All / In stock / Low stock / Out of stock. **The count cards
    and this control share one `stock` state** (clicking a card selects that
    filter; clicking the active card again clears to All) — not two separate
    filters.
  - Category filter — dropdown of distinct categories present in the list, plus
    "All categories".
- **Table columns:** Name · SKU · Category · Stock (qty + In/Low/Out badge) ·
  Price · Cost. Status badge colour uses the existing status tokens
  (`success`/`warning`/`error`), consistent with the color discipline. Row click
  → `/inventory/:id`.
- **Cost is shown** with no toggle: the web admin is admin-only (`ProtectedRoute`)
  and admins hold `viewProductCost`.
- **Empty state:** `EmptyState` when the filtered list is empty.
- No "Add product" button in Slice 1 (Slice 3 adds it).

### 4.1 `filterProducts` (pure, unit-tested)

`domain/products/filterProducts.ts` — the list's filter logic, extracted so it is
testable in node env (relative imports per the web convention):

```ts
export interface ProductFilter {
  search: string;          // '' = no search
  stock: StockStatus | 'all';
  category: string | 'all';
}
export function filterProducts(products: Product[], f: ProductFilter): Product[]
```

Semantics: search matches `name`/`sku` (case-insensitive substring); `stock`
matches `getStockStatus(p)`; `category` matches `p.category`. `'all'` / `''`
disable that axis. AND across axes.

## 5. `/inventory/:id` read-only detail page

`features/inventory/InventoryDetailPage.tsx`. New route. The dynamic guard
`^/inventory/[^/]+$` → `viewInventory` **already exists** in `routeGuards.ts`, and
`/inventory/add` / `/inventory/price-history` are exact entries checked first, so
no guard change is needed — only route registration.

- **Data:** `getById(id)` via React Query (one-shot; a `useProduct(id)` hook).
  `watchOne` is an option but one-shot is fine for a read view. Not-found → an
  `EmptyState` ("Product not found").
- **Cards (read-only):**
  - **Header** — name, SKU, `imageUrl` thumbnail if present, active/inactive badge.
  - **Stock** — quantity, reorder level, In/Low/Out status.
  - **Pricing** — price, cost, margin (price − cost; %), via `formatMoney`.
  - **Details** — category, unit, supplier name, barcode, notes.
  - **Audit** — created/updated by (prefer denormalised `createdByName`/
    `updatedByName` per §21, fall back to UID) + timestamps (`en-PH` date format).
- **"View price history →"** link → `/inventory/price-history?product=<id>`.
- No edit/stock/deactivate controls (Slice 2).

## 6. Price-history deep-link

Enhance the existing `features/inventory/PriceHistoryPage.tsx`: read a
`?product=<id>` query param (`useSearchParams`). When present and it resolves to a
loaded product, pre-select it (show its history immediately); the search box stays
available to switch products. When absent, behaves exactly as today. The standalone
page and its nav item are unchanged.

## 7. Routing & guards

- `routes.tsx`: swap `RoutePaths.inventory` from `placeholder('Inventory', …)` to
  `<InventoryListPage />`; add `{ path: RoutePaths.productDetail, element:
  <InventoryDetailPage /> }` (`RoutePaths.productDetail = '/inventory/:id'`,
  already defined).
- `routeGuards.ts`: no change — `/inventory` (exact, `viewInventory`) and the
  `^/inventory/[^/]+$` dynamic rule (`viewInventory`) already cover both, and the
  exact `/inventory/add` & `/inventory/price-history` entries are matched first.
- Nav: the "Inventory" item already exists under Stock; it now reaches a real page.

## 8. Files

**Create:**
- `web_admin/src/presentation/features/inventory/InventoryListPage.tsx`
- `web_admin/src/presentation/features/inventory/InventoryDetailPage.tsx`
- `web_admin/src/domain/products/filterProducts.ts`
- `web_admin/src/domain/products/filterProducts.test.ts`
- `web_admin/src/presentation/hooks/useProduct.ts` (one-shot `getById` query)

**Modify:**
- `web_admin/src/presentation/router/routes.tsx` (wire list + add detail route)
- `web_admin/src/presentation/features/inventory/PriceHistoryPage.tsx` (`?product=`)

**No repository changes** (all reads already implemented).

## 9. Testing

- `filterProducts.test.ts` (vitest, node env): empty filter returns all; search by
  name and by SKU; each stock filter (all/in/low/out using boundary quantities vs
  reorder level); category filter; combined AND.
- Pages verified via `npx tsc --noEmit -p tsconfig.json` + `npm run build` + manual
  smoke, consistent with how Suppliers/Reports shipped (no jsdom component tests —
  the jsdom cold-start tax isn't worth it for presentation here).

## 10. Acceptance criteria

1. An admin opens "Inventory" → sees the live product list with In/Low/Out counts;
   search narrows by name/SKU; the stock filter and the count cards filter the
   table; the category dropdown filters; cost is visible.
2. Clicking a row opens `/inventory/:id` showing all product fields + audit, with a
   "View price history →" link that lands on **that product's** history (pre-selected).
3. The Inventory placeholder is gone; the standalone price-history page still works.
4. Gates green: `filterProducts` vitest passes; `tsc --noEmit -p tsconfig.json` and
   `npm run build` succeed; full vitest suite stays green.

## 11. Resolved decisions

- v1 ambition: **full CRUD parity**, decomposed into 3 slices; this is **Slice 1**.
- Price history: **keep the standalone page**, detail **links** to it (deep-linked
  by product). Not relocated/removed.
- List: **table** (not cards); **live `watchAll`** + **client-side** filtering;
  **cost always shown**; detail via **`getById`** (one-shot).
