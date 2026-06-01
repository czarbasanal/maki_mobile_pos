# Dedicated Price-History Views (Roadmap §23) — Design

**Date:** 2026-06-01
**Status:** Approved (brainstorm complete)
**Roadmap item:** §23 — Dedicated cost & selling-price history views per product

## 1. Overview

§7 already records every cost and selling-price change in the
`products/{id}/price_history` subcollection and surfaces them together as an
inline **Price History card** on the mobile product-detail screen. This work adds
a **dedicated full-screen view** per product — a trend sparkline plus a detailed
table — on **both** the Flutter mobile app and the React web admin.

This is a **read-only reporting** feature. No new writes, no schema changes to
`price_history`.

## 2. Goals

- A dedicated per-product price-history view that shows more than the inline card:
  a trend sparkline + a full table with date, old → new, change source, and actor.
- Combined cost + selling-price in one view, with a filter (All / Price / Cost).
- Parity between mobile and web (same content, columns, filter semantics).

## 3. Non-goals (v1)

- **No staff-facing view.** Price history stays admin-only (see §6).
- **No full interactive chart** (axes/tooltips). A compact sparkline only.
- **No date-range filtering.** Price history is sparse; show all (existing
  `limit: 50`). The only filter is metric (All / Price / Cost).
- **No new `price_history` fields, writes, or Firestore indexes.**
- **No web inventory browse/edit.** The web view ships with a *minimal* host
  page only (see §7); the broader web inventory-browse work is separate (queued).
- **No multi-branch awareness.** If multi-branch ships later, cost history becomes
  per-branch — out of scope here.

## 4. Existing data model (unchanged)

Each `price_history` entry is a **snapshot of both** price and cost at a point in
time. Domain entity `PriceHistoryEntry` (and `PriceHistoryModel`):

| field       | type       | notes                                              |
|-------------|------------|----------------------------------------------------|
| `id`        | String     | doc id                                             |
| `price`     | double     | selling price at this point                        |
| `cost`      | double     | cost at this point                                 |
| `changedAt` | DateTime   | server timestamp                                   |
| `changedBy` | String     | actor UID                                          |
| `reason`    | String?    | one of `PriceChangeReason.*` (see below)           |
| `note`      | String?    | free text; for receiving entries, the `RCV-…` id   |

`PriceChangeReason` constants: `initial`, `priceUpdate`, `costUpdate`,
`receiving`, `promotion`, `supplierChange`, `marketAdjustment`, `correction`.

Read path:
- **Mobile:** `ProductRepository.getPriceHistory(productId, limit: 50)` → newest
  first, exposed via `priceHistoryProvider(productId)`.
- **Web:** *does not exist yet* — only sales/receiving/product converters are
  implemented in React. A new read path is part of Phase 2 (§7).

## 5. Shared behavior contract (identical on both surfaces)

One screen, combined cost + price, with:

### 5.1 Metric filter
A segmented filter: **All · Price changes · Cost changes**. Semantics, derived
client-side from the newest-first list (compute deltas against the chronologically
prior entry):

- **All** — every entry; table shows both price and cost columns.
- **Price changes** — only entries where `price` moved vs. the prior entry.
- **Cost changes** — only entries where `cost` moved vs. the prior entry.

### 5.2 Sparkline
Compact trend line(s) of the filtered metric over time (chronological):
- **All** → two small **stacked, separately-scaled** sparklines (price on top,
  cost below), each labelled. (Separate scales, not one shared axis — price and
  cost differ in magnitude, so a shared axis would flatten the smaller series.)
- **Price changes** → price sparkline only. **Cost changes** → cost sparkline only.
- Needs **≥2 points** to draw; with <2 points the sparkline is hidden and a quiet
  caption ("Not enough changes to chart") is shown instead.
- No axes, no tooltips. Mobile uses `fl_chart` (already a dependency, currently
  unused). Web uses an inline SVG sparkline (no new dependency).

### 5.3 Table
Newest-first. Columns: **Date · Old → New · Δ (▲/▼ badge) · Source · Who**.
- For **All**, the row shows both price and cost (matching the inline card's
  two-line layout); for a single-metric filter, the row focuses on that metric.
- **Old → New** is computed from the prior entry; the first (oldest) entry shows
  just the value (no prior to diff).
- Δ badge colour follows the existing convention (▲/▼); colour is reserved for
  this status semantic per the project's color discipline.

### 5.4 Source label (derived from `reason`)
- `initial` → **Created**
- `priceUpdate` / `costUpdate` → **Manual edit**
- `receiving` → **Receiving** (append the `RCV-…` id from `note` when present)
- `promotion` / `supplierChange` / `marketAdjustment` / `correction` → the reason,
  title-cased, shown as-is
- `null` / unknown → **Edit**

### 5.5 Actor ("Who")
Prefer a denormalised actor name when available; otherwise resolve by UID (the
§21 fallback — mobile uses `userByIdProvider`; web resolves via its user lookup).

## 6. Gating

The inline card is gated entirely behind `inventoryState.showCost` →
**admin-only, both metrics visible**. The dedicated view **inherits the same admin
gate** in v1:

- **Mobile:** reached only from the inline card, which only renders when
  `showCost` is true. Route additionally guarded so a deep link can't bypass it.
- **Web:** the host page + view are admin-gated (`ProtectedRoute`, admin-only),
  consistent with the existing web admin gating.

A staff-facing **price-only** view is a reasonable future follow-up but is
explicitly out of v1.

## 7. Decomposition & sequencing

One design doc, **two implementation phases** (each its own plan → implement):

### Phase 1 — Mobile (build first)
Lowest risk: data path and host card already exist.

- New `PriceHistoryScreen(productId)` full-screen widget.
- New nested route off product detail, e.g. `/inventory/product/:id/price-history`
  (exact base confirmed during planning to match `app_routes.dart`), guarded so
  it requires the same admin/cost visibility as the card.
- Entry point: a **"View all →"** trailing link added to the existing
  `_PriceHistoryCard` header (mirrors the Recent Transactions / Top Selling
  pattern). The inline card stays as the at-a-glance preview.
- Reuses `priceHistoryProvider(productId)`.
- **Pure, widget-free helpers** extracted to `lib/core/utils/price_history_view.dart`
  (or similar): `deriveSource(reason, note)`, `filterByMetric(entries, metric)`
  (returns rows annotated with prior-entry deltas), and sparkline point-mapping.
  These are unit-tested without Firestore or widgets.
- Sparkline rendered with `fl_chart`.

### Phase 2 — Web (build second)
Mirrors Phase 1 for parity. Ships with a **minimal host page** since web has no
product-detail/inventory-browse page yet:

- A lightweight **product search → product page** in `web_admin/` whose primary
  content is the price-history view. Self-contained; does not depend on the
  queued web inventory-browse work.
- A new **web read path** for `products/{id}/price_history`: a
  `priceHistoryConverter` + a `getPriceHistory` method on the product (or a new
  price-history) repository, wired through the DI container, exposed via a hook.
- The **same derivation helpers ported to TypeScript** in
  `web_admin/src/domain/products/priceHistory.ts` using **relative imports** (per
  the web convention — `@/` is not resolved by vitest for unit-tested modules).
- Table + inline-SVG sparkline (no new dependency).
- Admin-gated route via `ProtectedRoute`.

## 8. Testing

### Mobile (Phase 1)
- Unit tests (no Firestore/widgets) for `deriveSource`, `filterByMetric`
  (All/Price/Cost incl. the oldest-entry no-prior case and zero-delta exclusion),
  and sparkline point-mapping (incl. the <2-points hidden case).
- Widget test for `PriceHistoryScreen`: empty, single-entry (sparkline hidden),
  and multi-entry states; filter switching.
- `flutter analyze` clean.

### Web (Phase 2)
- vitest (node env) for the ported helpers and the new `priceHistoryConverter`.
- Component test (jsdom) for the table + filter switching.
- `tsc --noEmit -p tsconfig.json` + `npm run build` green.

## 9. Acceptance criteria

1. **Mobile:** an admin on product detail (cost visible) sees a "View all →" link
   on the Price History card that opens a full-screen view with a sparkline + a
   detailed table; the metric filter switches between All / Price / Cost; source
   and actor render per §5.4–5.5; a product with <2 changes hides the sparkline
   with a caption; a product with no history shows an empty state. A non-admin
   cannot reach the screen (card hidden + route guarded).
2. **Web:** an admin can search a product, open its price-history page, and see the
   same content/columns/filter as mobile, reading the same `price_history` data
   written by mobile and web receiving.
3. All gates green: mobile `flutter test` + `flutter analyze`; web vitest +
   `tsc --noEmit -p tsconfig.json` + `npm run build`.

## 10. Resolved decisions

- **Surface:** both (mobile first, web second).
- **Layout:** combined cost + price on one screen with an All/Price/Cost filter.
- **Chart:** sparkline + table (no full interactive chart; no new web dependency).
- **Gating:** admin-only in v1; no staff price-only view.
- **Web entry:** bundle a minimal host (product search → product page); do not wait
  on the queued web inventory-browse work.

## 11. Out-of-scope follow-ups (recorded, not built)

- Staff-facing price-only history view.
- Full interactive chart (axes, tooltips, pinch-zoom).
- Web inventory browse/edit + receiving history/detail (separate queued work).
- Per-branch cost history once multi-branch ships.
