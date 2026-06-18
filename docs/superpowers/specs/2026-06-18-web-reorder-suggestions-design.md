# Reorder Suggestions (§22) — Web Admin (Design)

**Date:** 2026-06-18
**Surface:** Web admin (`web_admin/`, React) only. Mobile unchanged.
**Status:** Design — pending user review, then `writing-plans`.
**Roadmap:** §22 "Reorder decision engine — auto-suggest order quantities."

## 1. Problem & intent

The shop has no signal for *what to reorder and how much*. Today the inventory
list flags low stock by `reorderLevel`, but that's a static threshold blind to
how fast a product actually sells. §22 adds a **reorder suggestions** screen that
computes a suggested order quantity per product from **sales velocity**, current
stock, and **per-supplier lead time**, grouped by supplier and exportable.

### Decisions locked in brainstorming
- **Web admin only.** No mobile, no multi-branch (suggestions use global product
  movement). Sales-velocity rollup already exists on web (`topSellingProducts`).
- **Lead-time model** for the suggested quantity (see §3), with a new
  **per-supplier lead time** field.
- **Output:** a read-only suggestions list, **editable qty per line**, with **CSV
  export**. No draft-receiving integration in v1.
- **Safety stock is folded into a single "days of cover" knob** (not a separate
  field).

## 2. Data

### 2.1 New field: `Supplier.leadTimeDays`
- `leadTimeDays: number | null` on the `Supplier` entity (mirrors the Dart side
  shape; web-written). Added to `supplierConverter` (read: `?? null`; write).
- Added to the supplier add/edit form (`SupplierFormPage`) as an optional number
  input ("Lead time (days)"), default empty → `null`.
- **Additive** to the shared `suppliers` collection: mobile ignores the field; a
  missing value reads as `null`. **No `firestore.rules` change** (suppliers
  create/update already permitted for admin/staff).

### 2.2 Global parameters (defaults; adjustable on-screen, not persisted)
| Param | Default | Adjustable |
|-------|---------|-----------|
| `windowDays` (velocity window) | 30 | dropdown: 7 / 14 / 30 / 90 |
| `coverDays` (days of cover after arrival, incl. safety) | 14 | number input |
| `defaultLeadDays` (used when a product's supplier has no lead time / no supplier) | 7 | number input |

Persisting these (a settings doc) is out of scope; they reset to defaults on
load.

## 3. Core computation (pure domain function — TDD)

New module `src/domain/reorder/computeReorderSuggestions.ts`:

```
ReorderParams = { windowDays: number; coverDays: number; defaultLeadDays: number }

ReorderSuggestion = {
  product: Product;
  supplierName: string | null;   // 'No supplier' bucket when null
  velocityPerDay: number;        // unitsSold(window) / windowDays
  leadDays: number;              // supplier.leadTimeDays ?? defaultLeadDays
  targetStock: number;           // ceil(velocityPerDay * (leadDays + coverDays))
  suggestedQty: number;          // max(0, targetStock - currentStock)
}

computeReorderSuggestions(
  products: Product[],
  unitsSoldByProduct: Map<string, number>,   // from the sales rollup over the window
  suppliers: Supplier[],
  params: ReorderParams,
): ReorderSuggestion[]
```

Logic per **active** product:
1. `velocityPerDay = (unitsSoldByProduct.get(product.id) ?? 0) / windowDays`.
2. `leadDays = supplierById(product.supplierId)?.leadTimeDays ?? defaultLeadDays`.
3. `targetStock = ceil(velocityPerDay * (leadDays + coverDays))`.
4. `suggestedQty = max(0, targetStock - product.quantity)`.
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

- **Controls row:** window dropdown (7/14/30/90d), cover-days input, default-lead
  input. Changing any re-computes (client-side).
- **Table grouped by supplier** (a subheader per supplier; "No supplier" last):
  columns — Product · SKU · Current · Velocity/day · Lead (days) · **Suggested
  qty (editable number input)**.
- **Editable qty:** each row's suggested qty is an input the user can override;
  the override is what exports. Local state only.
- **CSV export** button → `supplier, sku, name, currentStock, velocityPerDay,
  suggestedQty` (using the edited qty), via the existing `downloadCsv`/`csv`
  util.
- **Empty state** when nothing needs reordering. **LoadingView** while products /
  sales load.

### Hooks / data flow
- `useProducts()` (realtime) — products.
- Sales over the window via the existing sales repo/report hook + the
  `topSellingProducts`-style rollup → `unitsSoldByProduct`.
- `useSuppliers()` — for lead times + names.
- A small `useReorderSuggestions(params)` hook wires the three together and calls
  `computeReorderSuggestions`. (Editable-qty + CSV live in the page.)

## 5. Testing & gates
- **Unit-test `computeReorderSuggestions`** (pure): velocity math over window,
  lead/cover target, supplier lead-time vs default, no-supplier bucket, zero-
  velocity exclusion, `ceil`/`max(0,...)` rounding, sort order.
- Existing `topSellingProducts` tests cover the velocity rollup.
- Converter: add a `supplierConverter` case for `leadTimeDays` read/write.
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
- **`Supplier.leadTimeDays`** touches the shared `suppliers` collection — additive
  and web-written only; confirm the field name matches if/when the mobile side
  adds it.
- Large catalogs: the compute is O(products) client-side over an in-memory sales
  rollup — fine for this shop's scale.
