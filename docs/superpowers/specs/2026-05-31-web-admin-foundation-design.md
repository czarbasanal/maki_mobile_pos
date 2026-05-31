# Web Admin Foundation — Design

> **Status:** approved design (brainstormed 2026-05-31). First of three specs for the web admin
> effort (Foundation → Sales monitoring + Reports → Bulk product import).

## Context

The web admin's goals are to **monitor sales, generate reports, and bulk-import products**. The repo
currently has **two** web-admin codebases:

1. **Flutter web** (`lib/presentation/web/`, served at `/`) — admin-only router + a `WebShell`/sidebar
   and a single read-only dashboard screen. Branched in `lib/main.dart` via
   `kIsWeb ? MAKIPOSWebApp() : MAKIPOSMobileApp()`.
2. **React/TypeScript app** (`web_admin/`, Vite + React 18 + Tailwind + React Query + Firebase,
   served at `/admin`) — the more built-out admin (dashboard, suppliers, users, settings); reports
   and bulk import are "phase" placeholders.

**Decision:** consolidate on the **React app** and **remove the Flutter web** layer. The React app
becomes the sole web surface, served at root `/`.

**Why this spec exists (the blocker):** the React app's sales data model **predates the POS labor
feature and full payment methods**. `web_admin/src/domain/entities/Sale.ts` + `saleConverter.ts`:
- drop `laborLines` / `mechanicId` / `mechanicName` (labor revenue & profit silently vanish);
- `PaymentMethod` only has `cash | gcash` (missing `maya`, `salmon`, `mixed`) and there is no
  `tenders` map, so split / maya / salmon sales are mis-bucketed;
- money helpers (`saleGrandTotal`, `saleTotalProfit`) are parts-only with no labor track.

Any sales-monitoring or report built on the current model would report **wrong numbers**. Aligning
the data model is therefore a prerequisite for Specs 2 and 3, and is the core of this Foundation.

## Goals

1. Remove the Flutter web layer; the Flutter project becomes mobile-only.
2. Serve the React app at root `/`; repoint Firebase hosting; drop the `/admin` basename + rewrite.
3. Align the React `Sale` / `SaleItem` types + Firestore converter to the current schema the Flutter
   app writes (inline labor lines, mechanic, `cash/gcash/maya/salmon/mixed` + `tenders`).
4. Provide a single shared `summarizeSales()` util that mirrors the Dart `getSalesSummary` math
   (parts-only top-line + parallel labor track), unit-tested for parity, and fix the existing
   DashboardPage to use it.

## Non-goals (handled by later specs)

- New sales-monitoring / report screens, filters, CSV/PDF export → **Spec 2**.
- Bulk product import UI + product creation → **Spec 3**.
- Any change to the Flutter mobile app beyond deleting its web layer.
- Firestore security-rule changes (reads are already permitted for valid users).

---

## Part A — Consolidation: remove Flutter web, React → root

### A1. Delete the Flutter web layer
- `lib/presentation/web/**` (web_shell, web_sidebar, web_top_bar, web_page, web dashboard screen).
- `lib/app_web.dart`, `lib/config/router/web_router.dart`.
- In `lib/main.dart`, drop the `kIsWeb ? MAKIPOSWebApp() : MAKIPOSMobileApp()` branch → always
  `MAKIPOSMobileApp()`. Remove the now-unused `app_web.dart` / `webRouterProvider` imports.
- Remove the Flutter `web/` platform folder so no stale Flutter web build is produced (consistent
  with the project already dropping ios/macos/linux/windows platform folders).
- Remove any web-only references left dangling (e.g. `webRouterProvider` in the router barrel,
  `web_dashboard_screen` imports). `flutter analyze` must be clean afterward.

### A2. React app to root
- `web_admin/vite.config.ts`: `base: '/admin/'` → `base: '/'`; `build.outDir: '../build/web/admin'`
  → `'dist'` (Vite default, **per the approved hosting decision**).
- `web_admin/src/presentation/router/routes.tsx`: `createBrowserRouter(routes, { basename: '/admin' })`
  → drop the basename (root). Route paths in `RoutePaths` are relative, so no per-route change.
- Verify all internal navigation uses `RoutePaths` (the explore confirmed sidebar + pages do), so
  links resolve at the new root with no edits.

### A3. Firebase hosting
- `firebase.json` `hosting.public`: `build/web` → `web_admin/dist`.
- Remove the `{"source": "/admin/**", "destination": "/admin/index.html"}` rewrite.
- Keep the SPA fallback `{"source": "**", "destination": "/index.html"}`.
- (Other hosting fields — storage rules, flutter platform config — unchanged.)

---

## Part B — Align the Sale data model

Target: the React `Sale` reads everything the Dart `SaleModel.toMap` writes. Confirmed Firestore
shapes (from `lib/data/models/sale_model.dart`, `lib/core/enums/`):

| Firestore field | Shape | Notes |
|---|---|---|
| `laborLines` | array of `{ id, description, fee }` | **inline on the sale doc** (NOT a subcollection); absent on legacy docs |
| `mechanicId`, `mechanicName` | `string?` | null when no mechanic |
| `paymentMethod` | string | one of `cash` `gcash` `maya` `salmon` `mixed` |
| `tenders` | `{ [methodValue]: number }` | present **only when non-empty**; e.g. a mixed sale → `{ cash: 900, gcash: 600 }` |
| `status` | string | `completed` \| `voided` |
| `discountType` | string | `amount` \| `percentage` |
| items | subcollection `sales/{id}/items` | already loaded by `FirestoreSaleRepository` |

### B1. Types (`web_admin/src/domain/entities/`)
- New `LaborLine.ts`: `interface LaborLine { id: string; description: string; fee: number }`.
- `PaymentMethod.ts`: add `maya`, `salmon`, `mixed`. Add an `isDigital`/real-bucket helper as needed.
- `Sale.ts`: add `laborLines: LaborLine[]`, `mechanicId: string | null`,
  `mechanicName: string | null`, `tenders: Partial<Record<PaymentMethod, number>>`.

### B2. Converter (`saleConverter.ts`)
- Parse `laborLines` from `data.laborLines` (default `[]`); coerce `fee` via `Number(...)`.
- Parse `mechanicId` / `mechanicName` (default `null`).
- Parse `tenders` from `data.tenders` (a `{methodValue: number}` map → `Partial<Record<...>>`),
  default `{}`; ignore unknown keys.
- `paymentMethodFromString` handles the new values; unknown → `cash` (matches Dart default).

### B3. Money helpers (`Sale.ts`, pure functions — labor-aware contract, identical to Dart)
```
partsSubtotal(sale)  = Σ items (unitPrice * qty)
partsRevenue(sale)   = partsSubtotal − totalDiscount        // discount applies to parts only
laborSubtotal(sale)  = Σ laborLines.fee                      // never discounted
laborRevenue(sale)   = laborSubtotal
grandTotal(sale)     = partsRevenue + laborRevenue
totalCost(sale)      = Σ items (unitCost * qty)              // labor has zero cost
partsProfit(sale)    = partsRevenue − totalCost
laborProfit(sale)    = laborRevenue
totalProfit(sale)    = partsProfit + laborProfit
effectiveTenders(sale) = tenders (if non-empty) else { [paymentMethod]: grandTotal }
```
Keep existing helper names where they exist (`saleGrandTotal`, `saleTotalProfit`) but redefine them
to the labor-aware formulas so existing callers (DashboardPage) pick up correct numbers; add the new
parts/labor helpers alongside.

---

## Part C — Shared `summarizeSales()` util + DashboardPage

### C1. `summarizeSales(sales: Sale[]): SalesSummary`
Location: `web_admin/src/domain/sales/summarizeSales.ts` (new). Mirrors Dart
`SaleRepositoryImpl.getSalesSummary` exactly:
- Consider **completed** sales only for money (voided excluded; counted separately).
- **Parts-only top-line:** `grossAmount += partsSubtotal`, `totalDiscounts += totalDiscount`,
  `netAmount += partsRevenue`, `totalCost += totalCost`, `totalProfit = netAmount − totalCost`.
- **Labor track:** `laborRevenue += laborRevenue`; `laborProfit = laborRevenue` (zero cost).
- **`byPaymentMethod`:** seed real buckets only (`cash`, `gcash`, `maya`, `salmon` — never `mixed`),
  then sum each sale's `effectiveTenders` (labor-inclusive — the drawer holds labor cash).
- Derived: `averageSaleAmount = netAmount / completedCount`,
  `profitMargin = totalProfit / netAmount * 100`.

`SalesSummary` TS shape mirrors the Dart fields: `totalSalesCount`, `voidedSalesCount`,
`grossAmount`, `totalDiscounts`, `netAmount`, `totalCost`, `totalProfit`, `laborRevenue`,
`laborProfit`, `byPaymentMethod`.

### C2. DashboardPage
Replace its inline `summarize()` with `summarizeSales()`. The dashboard then shows correct
labor-inclusive revenue, parts-only profit, and (where it displays payment breakdown) maya/salmon.
No layout change required in this spec.

---

## Testing

**React (vitest + testing-library):**
- `saleConverter` tests: a doc with `laborLines` + `mechanicId` + a `tenders` map (incl. maya/salmon)
  round-trips into the `Sale`; a legacy doc with none of those defaults to `[]` / `null` / `{}`.
- `summarizeSales` parity tests against the same fixtures the Dart tests use:
  - parts-only sale → labor track is 0, top-line equals parts.
  - parts + labor sale → top-line stays parts-only, `laborRevenue`/`laborProfit` reflect labor,
    `grandTotal = partsRevenue + laborRevenue`.
  - reconciliation identity: `Σ byPaymentMethod == netAmount + laborRevenue`.
  - a mixed-tender sale → buckets split correctly, `mixed` never appears as a bucket.
- `npm run typecheck` + `npm run test` clean.

**Flutter:** `flutter test` still green and `flutter analyze` clean after the web-layer removal (the
mobile suite is unaffected; only dead web code is deleted).

## Rollout / deploy

1. Land Part A + B + C behind the normal branch/PR flow; run `flutter test` + `web_admin` vitest.
2. `cd web_admin && npm run build` → produces `web_admin/dist`.
3. `firebase deploy --only hosting` and verify: `/` loads the React admin (admin-gated), and a sale
   carrying labor + a maya/salmon (or mixed) tender reports correct revenue/profit and payment
   buckets on the dashboard.

## Risks & mitigations

- **Hosting cutover removes the Flutter web admin.** Low risk: the Flutter web was already admin-only
  (`web_router` redirects non-admins to access-denied), so it only served the admin dashboard the
  React app replaces. Mitigate by deploying React to a preview channel first if desired.
- **Converter silently dropping a field again.** Mitigated by the converter round-trip tests and the
  reconciliation-identity test, which fail loudly if labor/tenders are dropped.
- **Dart ↔ TS math drift.** Mitigated by porting the exact formulas and pinning them with parity
  tests; this util is the single source of truth Spec 2 reuses.

## Out of scope → next specs

- **Spec 2 — Sales monitoring + Reports:** live sales monitor, date-range sales/profit/top-selling
  reports, CSV export — all consuming `summarizeSales()` and the aligned `Sale`.
- **Spec 3 — Bulk product import:** CSV upload → validate/preview → batch-create products.
