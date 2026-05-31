# Web Admin — Sales Monitoring + Reports — Design

> **Status:** approved design (brainstormed 2026-05-31). Spec 2 of the web-admin effort
> (Foundation ✓ → **Sales monitoring + Reports** → Bulk product import).

## Context

The React admin (`web_admin/`, served at root `/`, admin-only) shipped its Foundation: the `Sale`
data model is aligned to the labor-era schema and `summarizeSales()` produces a parts-only top-line
with a parallel labor track. The reports section is still four placeholder routes
(`/reports`, `/reports/sales`, `/reports/profit`, `/reports/sale/:id` — all "phase 12"), and the only
sales view is the dashboard's today snapshot.

This spec builds the **Reports** section: monitor individual sales over a date range and generate
sales/profit/top-selling reports with CSV export — the "monitor sales" + "generate reports" goals.

## Goals

1. A date-range **Sales report** (`/reports/sales`): summary + payment breakdown + a browsable sales
   list + top-selling products + CSV export.
2. A date-range **Profit report** (`/reports/profit`): COGS / gross profit / margin + top products by
   profit (admin).
3. A **Sale detail** page (`/reports/sale/:id`): full line items, labor, discounts, totals, payment.
4. A **Reports hub** (`/reports`): links to the two reports.

## Non-goals (out of scope)

- **Charts / trend graphs** — no charting dependency is added in this spec (numbers + tables, like
  the mobile reports).
- **Live-updating report pages** — reports are date-range snapshots; the dashboard already streams
  today's sales.
- Per-cashier breakdown, scheduled/emailed reports, PDF export, server-side report aggregation.
- Bulk product import → **Spec 3**.

## Architecture

**Client-side aggregation**, consistent with the dashboard: fetch the sales in a date range via
`SaleRepository.list({start,end})`, then aggregate with `summarizeSales()` and a new
`topSellingProducts()` domain function. No backend report endpoints exist or are added. Pages are
thin; the data + aggregation live in shared, independently-testable units.

### Shared building blocks (new)

| Unit | File | Responsibility |
|---|---|---|
| `DateRange` + presets | `src/domain/reports/dateRange.ts` | `type DateRange = { start: Date; end: Date }`; `type RangePreset = 'today'\|'yesterday'\|'last7'\|'last30'\|'thisMonth'\|'custom'`; `resolvePreset(preset): DateRange` (uses `date-fns` `startOfDay`/`endOfDay`/`subDays`/`startOfMonth`). Pure, unit-tested. |
| `topSellingProducts` | `src/domain/sales/topSellingProducts.ts` | `topSellingProducts(sales: Sale[], limit = 10): ProductSalesData[]` — over COMPLETED sales only, group line items by `productId`, sum `quantitySold`/`totalRevenue` (item net of discount, via `saleItemNet`)/`totalCost` (`saleItemTotalCost`); `totalProfit = totalRevenue - totalCost`; sort by `totalRevenue` desc, slice `limit`. `ProductSalesData = { productId, sku, name, quantitySold, totalRevenue, totalCost, totalProfit }` (mirrors the Dart `ProductSalesData`). Unit-tested. |
| `salesToCsv` + `downloadCsv` | `src/core/utils/csv.ts` | `salesToCsv(sales: Sale[]): string` — header + one row per sale: `saleNumber, date(ISO), itemsCount, paymentMethod, grossSales, discount, labor, total, cashierName, mechanicName`, with quoting/escaping for commas/quotes. `downloadCsv(filename, content)` — Blob (`text/csv`) + anchor click + `URL.revokeObjectURL`. Unit-test `salesToCsv` (rows + escaping). |
| `DateRangePicker` | `src/presentation/components/common/DateRangePicker.tsx` | Preset `<select>` + two `<input type="date">` shown when `custom`. Controlled: `value: { preset, range }`, `onChange`. Uses the existing input styling. |
| `useReportData(range)` | `src/presentation/hooks/useReportData.ts` | React-Query `useQuery` keyed `['reports','sales', range.start, range.end]`; calls `useSaleRepo().list({ start, end })`; returns `{ sales, summary: summarizeSales(sales), topProducts: topSellingProducts(sales), isLoading, error }`. |
| `SalesTable` | `src/presentation/features/reports/SalesTable.tsx` | Manual HTML `<table>` (existing pattern): columns time · sale# · items · mechanic · payment · total, voided rows greyed + "VOID" pill; each row links (`<Link to={/reports/sale/${id}}>`). |

### Data-layer change

`src/data/repositories/FirestoreSaleRepository.ts` `list()` currently builds constraints but never
applies a size cap. Add: when `filters.limit` is set, append Firestore `limit(filters.limit)` to the
query. `useReportData` passes `limit: 2000` and, if the result length equals the cap, surfaces a
"showing the most recent 2000 sales — narrow the range" notice. (At auto-shop volume this never
triggers; it's a guardrail against a huge range fetching unbounded item subcollections.)

### Pages

- **`/reports` (hub)** — `ReportsHubPage`: replaces the placeholder; page header + two `Link` cards
  ("Sales report", "Profit report") using the existing card styling. (Both are admin-visible since
  the app is admin-only; still rendered behind their route guards.)

- **`/reports/sales` (Sales report)** — `SalesReportPage`: `DateRangePicker` (default `last7`) →
  `useReportData(range)` → summary cards (Gross Sales `summary.grossAmount`, Net `summary.netAmount`,
  Avg order `summary.averageSaleAmount`, Sales count `summary.totalSalesCount`) + a payment-method
  breakdown panel (`summary.byPaymentMethod` for cash/gcash/maya/salmon + a Service/Labor line for
  `summary.laborRevenue`) + `SalesTable` (the list) + a "Download CSV" button (`salesToCsv(sales)` →
  `downloadCsv('sales-<start>-<end>.csv', …)`) + a top-selling products table (qty · revenue ·
  profit). `LoadingView`/`ErrorView`/`EmptyState` for states.

- **`/reports/profit` (Profit report)** — `ProfitReportPage`: `DateRangePicker` → `useReportData` →
  profit cards (Gross Sales, Total COGS `summary.totalCost`, Gross Profit `summary.totalProfit`,
  Margin `summary.profitMargin`%, Service/Labor profit `summary.laborProfit`) + a "top products by
  profit" table (reuse `topProducts`, re-sorted by `totalProfit` desc).

- **`/reports/sale/:id` (Sale detail)** — `SaleDetailPage`: `useQuery(['sales', id], () => repo.getById(id))`;
  renders header (sale#, date, cashier, mechanic if present, VOID banner if voided) + line-items table
  (sku · name · qty · unit price · discount · line net via `saleItemNet`) + labor section (description ·
  fee per `LaborLine`) + totals (Gross Sales `salePartsSubtotal`, Discount `saleTotalDiscount`, Labor
  `saleLaborSubtotal`, **Total** `saleGrandTotal`) + payment (`saleEffectiveTenders` breakdown,
  amount received, change). `EmptyState` when not found.

### Routing & nav

Routes already exist in `src/presentation/router/routes.tsx` + `routePaths.ts`; the sidebar "Reports"
entry already points at `/reports`. This spec only swaps the four placeholder elements for the real
pages. Guards in `routeGuards.ts` already map `salesReport→viewSalesReports`,
`profitReport→viewProfitReports`, and `/reports/sale/*→viewSalesReports`; no guard changes needed.

## Error handling

- Query errors → `ErrorView` with the message; empty ranges → `EmptyState` ("No sales in this range").
- Sale-detail not found / bad id → `EmptyState` with a back link to `/reports/sales`.
- CSV with zero sales → button disabled.
- The 2000-cap notice (above) when a range is too large.

## Testing (vitest, `--environment=node` for pure-logic; jsdom for component render)

- `topSellingProducts`: grouping by product, qty/revenue/cost/profit sums, void exclusion, sort + limit.
- `salesToCsv`: header + row shape, comma/quote escaping, money formatting, empty input.
- `resolvePreset`: each preset yields the correct `{start,end}` for a fixed "now" (pass `now` in to
  keep it deterministic — do NOT call `new Date()` inside).
- Light render tests (jsdom) for `SalesReportPage`/`SaleDetailPage` with an overridden repo in the DI
  container returning canned sales, asserting key figures + a row renders. (Reuse the Foundation's
  jsdom note: component tests pay the jsdom cost; logic tests use node env.)
- `npx tsc --noEmit -p tsconfig.json` clean; `npm run build` succeeds.

## Rollout

Standard branch → implement (TDD per task) → `npm run build` → `firebase deploy --only hosting`.
No data migration, no rules change, no new dependency.

## Open questions

None — date-range UX (presets + custom native inputs), separate pages, per-sale CSV rows, and
no-charts were all confirmed during brainstorming.
