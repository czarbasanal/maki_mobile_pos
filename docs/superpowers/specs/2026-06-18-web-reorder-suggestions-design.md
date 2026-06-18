# Reorder Suggestions (§22) — Web Admin (Design)

**Date:** 2026-06-18
**Surface:** Web admin (`web_admin/`, React) only. Mobile unchanged.
**Status:** Design — pending user review, then `writing-plans`.
**Roadmap:** §22 "Reorder decision engine — auto-suggest order quantities."

## 1. Problem & intent

The shop has no signal for *what to reorder and how much*. Today the inventory
list flags low stock by `reorderLevel`, but that's a static threshold blind to
how fast a product actually sells. §22 adds a **reorder suggestions** screen that
computes a suggested order quantity per product from **sales velocity** and
current stock, grouped by supplier and exportable.

### Decisions locked in brainstorming
- **Web admin only.** No mobile, no multi-branch (suggestions use global product
  movement). Sales-velocity rollup already exists on web (`topSellingProducts`).
- **Velocity-only model** for the suggested quantity (see §3): based purely on
  stock movement (sales over a window) and remaining stock. _(Amended 2026-06-18:
  the original design used a per-supplier lead-time term + a `Supplier.leadTimeDays`
  field; the user dropped lead time, so that field and the `defaultLeadDays` param
  were removed.)_
- **Output:** a read-only suggestions list, **editable qty per line**, with **CSV
  export**. No draft-receiving integration in v1.

## 2. Data

No schema change — suggestions read only existing `products` (stock, supplierName)
and `sales`. Grouping uses the product's denormalized `supplierName`.

### 2.1 Global parameters (defaults; adjustable on-screen, not persisted)
| Param | Default | Adjustable |
|-------|---------|-----------|
| `windowDays` (velocity window) | 30 | dropdown: 7 / 14 / 30 / 90 |
| `coverDays` (days of stock to keep on hand) | 14 | number input |

Persisting these (a settings doc) is out of scope; they reset to defaults on
load.

## 3. Core computation (pure domain function — TDD)

New module `src/domain/reorder/computeReorderSuggestions.ts`:

```
ReorderParams = { windowDays: number; coverDays: number }

ReorderSuggestion = {
  product: Product;
  supplierName: string | null;   // product.supplierName; 'No supplier' bucket when null
  velocityPerDay: number;        // unitsSold(window) / windowDays
  targetStock: number;           // ceil(velocityPerDay * coverDays)
  suggestedQty: number;          // max(0, targetStock - currentStock)
}

computeReorderSuggestions(
  products: Product[],
  unitsSoldByProduct: Map<string, number>,   // from the sales rollup over the window
  params: ReorderParams,
): ReorderSuggestion[]
```

Logic per **active** product:
1. `velocityPerDay = (unitsSoldByProduct.get(product.id) ?? 0) / windowDays`.
2. `targetStock = ceil(velocityPerDay * coverDays)`.
3. `suggestedQty = max(0, targetStock - product.quantity)`.
5. Keep only rows where `suggestedQty > 0`. Sort by supplier, then by
   `suggestedQty` desc.

**Sparse / dead sellers** (velocity ≈ 0) → `targetStock` 0 → `suggestedQty` 0 →
excluded. So the list only shows products with real recent demand running low.
Simple-average velocity (no EMA/seasonality — deferred).

**Velocity source:** reuse the existing per-product sales rollup
(`topSellingProducts` / the reports sales aggregation) over the window's sales to
build `unitsSoldByProduct`. The compute function takes the pre-aggregated map so
it stays pure and unit-testable (no Firestore).

## 4. UI — `ReorderSuggestionsPage`

Route `/inventory/reorder` (Stock area), admin-gated by `Permission.viewProductCost`
(cost/velocity are sensitive). Sidebar: add **"Reorder"** under the Stock section.

- **Controls row:** window dropdown (7/14/30/90d), cover-days input. Changing
  either re-computes (client-side).
- **Table grouped by supplier** (a subheader per supplier; "No supplier" last):
  columns — Product · SKU · Current · Velocity/day · **Suggested qty (editable
  number input)**.
- **Editable qty:** each row's suggested qty is an input the user can override;
  the override is what exports. Local state only.
- **CSV export** button → `supplier, sku, name, currentStock, velocityPerDay,
  suggestedQty` (using the edited qty), via the existing `downloadCsv`/`csv`
  util.
- **Empty state** when nothing needs reordering. **LoadingView** while products /
  sales load.

### Hooks / data flow
- `useProducts()` (realtime) — products (incl. denormalized `supplierName`).
- Sales over the window via the sale repo + an uncapped `unitsSoldByProduct`
  rollup (the existing `topSellingProducts` caps at a limit, so velocity uses a
  dedicated rollup).
- A small `useReorderSuggestions(params)` hook wires products + windowed sales and
  calls `computeReorderSuggestions`. (Editable-qty + CSV live in the page.)

## 5. Testing & gates
- **Unit-test `computeReorderSuggestions`** (pure): velocity math over window,
  `velocity × cover` target, no-supplier bucket, zero-velocity exclusion,
  `ceil`/`max(0,...)` rounding, inactive-skip, sort order.
- `unitsSoldByProduct` rollup unit-tested (voided-sale exclusion).
- Gates: `npm run typecheck` + `npm run test` (vitest) + `npm run build`.

## 6. Out of scope (deferred)
- Creating draft receivings from suggestions (the receiving drafts feature could
  consume this later).
- EMA / weighted velocity, seasonality, per-product safety stock.
- Persisting the global params (settings doc).
- Multi-branch (per-branch movement) — only relevant once multi-branch ships.
- Mobile.

## 7. Risks
- **Velocity needs sale line-items** over the window; the reports path already
  reads them, so reuse that repository/aggregation rather than re-querying.
- **No schema/rules change** — reads existing `products` + `sales` only.
- Large catalogs: the compute is O(products) client-side over an in-memory sales
  rollup — fine for this shop's scale.
