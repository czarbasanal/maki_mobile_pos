# Price-Change Report (Reports)

Date: 2026-07-01
Scope: Flutter mobile app + React web admin (parity).

## Context / current state

Price/cost changes are recorded as a **per-product subcollection**
`products/{productId}/price_history/{historyId}` whenever a product's price or
cost changes (create, edit, receiving-with-different-cost → variation). Entry
fields: `price, cost, changedAt, changedBy, reason?, note?` — there is NO
`productId` on the entry (it is implicit in the path).

- Rules: `price_history` is **admin-only** (`allow read/write: if isAdmin() &&
  isActiveUser()`), nested under `products`.
- Reads today are **per product only**: `ProductRepository.getPriceHistory({
  productId })` (mobile) and the web `usePriceHistory` hook. Both drive a
  per-product drill-down view (mobile `price_history_screen.dart`, web
  `PriceHistoryPage.tsx`) reached from inventory. Shared delta/display logic:
  `lib/core/utils/price_history_view.dart` (mobile) and
  `web_admin/src/domain/products/priceHistory.ts` (`buildPriceHistoryRows`).
- There is **no cross-product query** and no `collectionGroup` usage anywhere.
- The reports hub exists on both surfaces (mobile `ReportsHubScreen`, web
  `ReportsHubPage`) with a shared preset date filter (`DateRangePicker` +
  `dateRangeForPreset`) and CSV export (`saveReportCsv` /
  `buildXxxReportCsv`). The per-product price-history route is guarded on
  `Permission.viewProductCost` ("it exposes cost", admin-only).
- `fake_cloud_firestore 4.1.1` supports `collectionGroup`, so the query is
  unit-testable.

## Goals

A new **admin-only** report in the reports hub (both surfaces): a **change log
of price/cost changes across all products** over a selected date range, with
▲/▼ deltas, reason, who, and when — plus CSV export, matching the other reports.

## Non-goals

- No change to how price history is recorded or stored (keep the subcollection).
- No new metrics beyond the change log; no editing.
- Not shown to non-admins (price_history is admin-only).

## Design

### 1. Data query — cross-product (collection group)

New abstract + impl method on `ProductRepository`:

```
Future<List<PriceChangeEntry>> getPriceChangesInRange({
  required DateTime startDate,
  required DateTime endDate,
  int limit = 500,
});
```

Impl (Firestore):
`_firestore.collectionGroup('price_history')
  .where('changedAt', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate))
  .where('changedAt', isLessThanOrEqualTo: Timestamp.fromDate(endDate))
  .orderBy('changedAt', descending: true).limit(limit).get()`.
For each doc, `productId = doc.reference.parent.parent!.id`.

New domain type `PriceChangeEntry` (`lib/domain/repositories/product_repository.dart`
alongside the existing `PriceHistoryEntry`, or its own file):
`{ String id; String productId; double price; double cost; DateTime changedAt;
String changedBy; String? reason; String? note; }`.

A capped `limit` (500) bounds a pathological range; the UI notes when the cap is
hit (rare).

### 2. Deltas — pure, cross-product

`lib/core/utils/price_change_report.dart`:

```
class PriceChangeRow { final PriceChangeEntry entry; final double priceDelta;
  final double costDelta; final bool hasPrior; }

List<PriceChangeRow> priceChangeRowsInRange(List<PriceChangeEntry> entries);
```

Groups `entries` by `productId`, orders each group chronologically, computes
`priceDelta`/`costDelta` against the prior **in-range** entry for that product
(oldest-per-product ⇒ `hasPrior=false`, deltas 0), then returns all rows sorted
**newest-first** by `changedAt`. Mirrors the existing per-product
`buildPriceHistoryRows` delta semantics. Deltas are within-range only (a delta
vs a change that happened before the range is intentionally not computed).

### 3. Mobile — screen, hub card, route

- New `lib/presentation/mobile/screens/reports/price_change_report_screen.dart`
  (`PriceChangeReportScreen`, admin-only).
- Provider `priceChangeReportProvider` (family over `DateRangeParams`) →
  `repo.getPriceChangesInRange(...)` → `priceChangeRowsInRange(...)`.
- UI: shared `DateRangePicker` + presets, **default preset `thisMonth`** (price
  changes are infrequent). Rows: product **name + SKU** (joined from the cached
  `allProductsProvider` / products list; deleted product ⇒ show id), new price &
  cost, ▲/▼ price & cost deltas, `reason` (e.g. "Receiving"), `changedBy`
  (resolved to a name where possible, else the id), and `changedAt`. Loading
  skeleton / error / empty states like the other reports.
- **Export CSV** app-bar action via the shared `saveReportCsv`, using
  `buildPriceChangeReportCsv(rows, productLabelById)` (see §5). Filename
  `price-changes_<start>_to_<end>.csv`.
- Reports hub: add a 4th card **"Price Changes"** shown when
  `RolePermissions.hasPermission(user.role, Permission.viewProductCost)` (same
  gate as the existing price-history view; sits with the admin-only Profit
  card).
- Route: `RouteNames.priceChangeReport` / `RoutePaths.priceChangeReport =
  '/reports/price-changes'`; `app_routes.dart` child under `/reports`;
  `route_guards.dart` maps `/reports/price-changes → Permission.viewProductCost`.

### 4. Web — page, hub card, route (parity)

- Web `ProductRepository` gains `listPriceChangesInRange(start, end, limit)`
  using `collectionGroup(db, 'price_history')` + the same range query;
  `PriceChangeEntry` carries `productId` (from `snap.ref.parent.parent.id`).
- Domain helper `web_admin/src/domain/products/priceChangeReport.ts` with
  `priceChangeRowsInRange(entries)` (mirrors §2; can reuse the per-entry delta
  logic from `priceHistory.ts`).
- Hook `usePriceChangeReport(range)` → runs the repo query via TanStack Query,
  joins product names (from the products cache/hook), returns rows +
  loading/error.
- Page `web_admin/src/presentation/features/reports/PriceChangeReportPage.tsx`:
  `DateRangePicker` + rows table (Product, SKU, New Price, Δ, New Cost, Δ,
  Reason, By, When) + CSV download (existing web CSV pattern).
- Hub card in `ReportsHubPage.tsx` (admin-gated) + the **route trio**:
  `routePaths.ts` (`priceChangeReport: '/reports/price-changes'`), `routes.tsx`
  (element), `routeGuards.ts` (`[RoutePaths.priceChangeReport,
  Permission.viewProductCost]`).

### 5. CSV builder

`lib/core/utils/report_csv.dart` gains:

```
String buildPriceChangeReportCsv(
  List<PriceChangeRow> rows,
  Map<String, String> productLabelById, // productId -> "Name (SKU)"
);
```

Header: `Date, Product, SKU, New Price, Price Δ, New Cost, Cost Δ, Reason,
Changed By`. One row per change, newest-first; money to 2 dp; deltas signed
(`+`/`-`); missing product ⇒ the id. (No TOTAL row — a change log has no
meaningful column totals.) Web mirrors these columns in its own builder.

### 6. Firestore rules + index (deploy — user-gated)

- **Rule** (`firestore.rules`, additive, admin-only): enable collection-group
  reads of `price_history`:
  `match /{path=**}/price_history/{historyId} { allow read: if isAdmin() &&
  isActiveUser(); }`. The existing nested `products/{id}/price_history/{id}`
  rule stays (writes + per-product reads).
- **Index** (`firestore.indexes.json`, `fieldOverrides`): a collection-group
  single-field index on `price_history.changedAt` (ASC + DESC), so the
  range+orderBy collection-group query is served:
  ```
  "fieldOverrides": [{
    "collectionGroup": "price_history",
    "fieldPath": "changedAt",
    "indexes": [
      { "queryScope": "COLLECTION_GROUP", "order": "ASCENDING" },
      { "queryScope": "COLLECTION_GROUP", "order": "DESCENDING" }
    ]
  }]
  ```
- Both are **production-affecting deploys** (`firebase deploy --only
  firestore:rules` / `firestore:indexes`). Code is written + tested first; the
  exact diffs are handed to the user and deployed only on explicit go-ahead. The
  report is non-functional against production until both are deployed (Firestore
  returns a permission-denied / failed-precondition otherwise) — surfaced as the
  report's error state.

## Data flow

Report screen → date range → `getPriceChangesInRange` (collection-group query) →
`List<PriceChangeEntry>` (with productId) → `priceChangeRowsInRange` (group +
deltas, newest-first) → join product name/SKU from the cached products list →
render rows / build CSV.

## Components / files

New (mobile): `price_change_report_screen.dart`,
`lib/core/utils/price_change_report.dart`, `PriceChangeEntry` type + repo
method, `priceChangeReportProvider`, `buildPriceChangeReportCsv`.
Modified (mobile): `product_repository.dart` (+impl), `report_csv.dart`,
`reports_hub_screen.dart`, `route_names.dart`, `app_routes.dart`,
`route_guards.dart`.
New (web): `priceChangeReport.ts`, `usePriceChangeReport.ts`,
`PriceChangeReportPage.tsx`, repo `listPriceChangesInRange`.
Modified (web): `ProductRepository` (+Firestore impl), `ReportsHubPage.tsx`,
`routePaths.ts`, `routes.tsx`, `routeGuards.ts`.
Config: `firestore.rules`, `firestore.indexes.json`.

## Testing (TDD)

- Repo query (mobile + web): fake-Firestore round-trip — seed `price_history`
  under two products with changes inside/outside the range; assert the query
  returns only in-range entries, newest-first, each with the correct
  `productId`.
- `priceChangeRowsInRange`: grouping, per-product deltas, oldest-per-product has
  no delta, overall newest-first ordering.
- `buildPriceChangeReportCsv`: header, rows, signed deltas, missing-product
  fallback.
- Mobile widget test: `PriceChangeReportScreen` renders rows from an overridden
  provider; hub shows the "Price Changes" card for admin, hides it for a
  cashier.
- Web: domain helper + page test.
- Rules/index are validated manually on deploy (Firestore is the only real
  authority); code paths above are covered with the fake.

## Open items

- Default preset is `thisMonth` (vs Today) for this report — confirmed with the
  user during design.
- `changedBy` is a user id; resolve to a display name where the users list is
  available, else show the id.
