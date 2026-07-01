# Mobile Reports: Hub + Shared Date Filter + CSV Export

Date: 2026-07-01
Scope: Flutter mobile app only (the web admin already has a reports hub,
preset date picker, and CSV download).

## Context / current state

Mobile reporting today:

- `/reports` → `SalesListScreen` (a transaction history list) is the landing.
  It has an app-bar chart button to `/reports/sales`.
- `/reports/sales` → `SalesReportScreen` (analytics: summary card, top
  products, payment breakdown). It already uses the shared `DateRangePicker`
  widget (preset dropdown + custom range) and forces "Today" for daily-only
  roles. It also carries stopgap "More Reports" tiles (Profit/Labor) that were
  added before this hub existed.
- `/reports/profit` → `ProfitReportScreen` and `/reports/labor` →
  `LaborReportScreen` each use a simpler `showDateRangePicker` (custom range
  only — no presets) and have no CSV export.

Reusable pieces that already exist:

- `DateRangePreset` enum (`lib/presentation/mobile/widgets/reports/date_range_picker.dart`)
  already has `today, yesterday, thisWeek, lastWeek, thisMonth, lastMonth,
  thisQuarter, thisYear, custom` — a superset of the requested seven.
- The `DateRangePicker` widget renders the preset dropdown and opens a custom
  range picker when `custom` is chosen.
- The preset → date-range computation is INLINE in
  `SalesReportScreen._handlePresetChange` (a switch over the enum) — not shared.
- CSV export precedent: `inventory_screen._handleExport` builds a CSV via
  `buildInventoryCsv` (the `csv` package) and saves it with
  `FilePicker.platform.saveFile(fileName:, bytes:)` (handles Android/iOS +
  desktop). `csv: ^6.0.0` and `file_picker` are already dependencies. There is
  no `share_plus`; the save-file dialog is the established mechanism.

## Goals

1. Navigating to reports first shows a hub with **Sales**, **Profit**, **Labor**.
2. A consistent preset date filter across all three reports: **Today,
   Yesterday, This Week, This Month, This Quarter, This Year, Custom** (Custom
   opens the existing date-range picker).
3. An **Export as CSV** action on all three reports.

## Non-goals

- No web changes (web already has these).
- No new reports or new metrics; export/filter operate on existing data.
- No new packages (reuse `csv` + `file_picker`).

## Design

### 1. Reports hub

New `ReportsHubScreen` at `/reports` (replaces `SalesListScreen` as the index):
three tap cards — Sales, Profit, Labor — styled like the existing settings/hub
cards. Profit is shown only to roles with `viewProfitReports` (admin), matching
today's gating. Mirrors the web `ReportsHubPage`.

- Cards navigate to `/reports/sales`, `/reports/profit`, `/reports/labor`.
- The **Sales** card opens the analytics screen (`SalesReportScreen`), per the
  decision that "Sales" = analytics.
- The transaction history list (`SalesListScreen`) moves to a new route
  `/reports/history` (name `salesHistory`, guard `viewSalesReports`) and is
  reached via a "View transactions" link added to `SalesReportScreen`.
- Remove the stopgap "More Reports" Profit/Labor tiles from
  `SalesReportScreen` (the hub is now the entry point). Keep its End-of-Day
  tile.
- The dashboard's Reports quick action already navigates to `/reports`, so it
  now lands on the hub with no change. **However**, audit other callers that
  expected the transaction *list* at `/reports` (e.g. the dashboard "Recent
  Transactions → View All", any `RoutePaths.reports`/sales-list navigation) and
  re-point those to `/reports/history`.

### 2. Shared date filter

- Extract the preset → range logic into
  `lib/core/utils/report_date_range.dart`:
  `DateTimeRange dateRangeForPreset(DateRangePreset preset, DateTime now)`.
  It covers every non-custom enum case (today, yesterday, thisWeek, lastWeek,
  thisMonth, lastMonth, thisQuarter, thisYear). Callers never pass `custom`
  because the `DateRangePicker` routes a custom selection to
  `onCustomRangeSelected` (its own date-range picker), not `onPresetChanged`;
  for defensiveness `dateRangeForPreset` returns Today when handed `custom`.
- `SalesReportScreen` is refactored to call `dateRangeForPreset` instead of its
  inline switch (behavior unchanged).
- `ProfitReportScreen` and `LaborReportScreen` replace their custom-only
  `showDateRangePicker` with the shared `DateRangePicker` widget: they gain a
  `_selectedPreset` (default `today`), `_startDate`/`_endDate` state, and
  `onPresetChanged` / `onCustomRangeSelected` handlers that use
  `dateRangeForPreset`.
- Default preset across all three: **Today** (consistent with a POS's daily
  rhythm; Profit/Labor change from their previous 30-day default).
- Daily-only roles (cashier/staff, `RolePermissions.isDailyReportsOnly`) stay
  locked to Today with the existing warning banner — applied to **Labor** as
  well as Sales. Profit is admin-only via its route guard, so no daily-only
  case there.
- The picker's extra `lastWeek`/`lastMonth` presets are left in place (Sales
  already shows them; they are a harmless superset of the requested seven).

### 3. Export as CSV

- Extract the save-file mechanism from `inventory_screen._handleExport` into a
  shared `lib/core/utils/report_export.dart`:
  `Future<void> saveReportCsv(BuildContext context, String csv, String fileName)`
  — UTF-8 encodes, calls `FilePicker.platform.saveFile`, writes bytes on
  desktop, and shows the success / cancelled / failed snackbars. Inventory
  export is refactored to use it (no behavior change).
- Pure, tested CSV builders in `lib/core/utils/report_csv.dart` (LF eol, `csv`
  package `ListToCsvConverter`), each ending with a totals row:
  - `buildSalesReportCsv(List<SaleEntity> sales)` — header + one row per
    completed (non-voided) sale: sale #, date/time, cashier, parts subtotal,
    discount, grand total, payment method. Totals row sums money columns.
  - `buildProfitReportCsv(List<ProductSalesData> products)` — header + one row
    per product (ranked by profit): name, SKU, qty sold, revenue, cost, profit,
    margin %. Totals row sums qty/revenue/cost/profit.
  - `buildLaborReportCsv(LaborReportData report)` — header + one row per
    mechanic: mechanic, jobs, labor total. Totals row = report totals.
- Each report screen gets an **Export** app-bar action (download icon). It
  builds the CSV from the currently-loaded data and calls `saveReportCsv` with a
  range-encoded filename, e.g. `sales_2026-07-01_to_2026-07-01.csv`,
  `profit_…`, `labor_…`.
- Data source for the Sales CSV: the transaction list from
  `salesByDateRangeProvider(params)` (the analytics screen shows a summary, so
  the export reads the list provider for the same range). Profit and Labor read
  the same providers their screens already use
  (`topSellingProductsProvider`, `laborReportProvider`). Export is disabled /
  no-ops with a "nothing to export" snackbar when the range has no data.

## Data flow

Report screens fetch via existing providers → screen renders → Export action
reads the already-loaded (or same-param) provider data, hands it to the pure
CSV builder, and passes the string to `saveReportCsv`. No new repositories or
Firestore reads beyond the providers the screens already use.

## Components / files

New:
- `lib/presentation/mobile/screens/reports/reports_hub_screen.dart`
- `lib/core/utils/report_date_range.dart`
- `lib/core/utils/report_csv.dart`
- `lib/core/utils/report_export.dart`

Modified:
- `lib/presentation/mobile/screens/reports/sales_report_screen.dart` (use
  `dateRangeForPreset`; drop More-Reports tiles; add "View transactions" link
  + Export action)
- `lib/presentation/mobile/screens/reports/profit_report_screen.dart` (shared
  DateRangePicker + presets + Export)
- `lib/presentation/mobile/screens/reports/labor_report_screen.dart` (shared
  DateRangePicker + presets + daily-only + Export)
- `lib/presentation/mobile/screens/inventory/inventory_screen.dart` (use shared
  `saveReportCsv`)
- `lib/config/router/route_names.dart`, `app_routes.dart`, `route_guards.dart`
  (hub at `/reports`; `salesHistory` at `/reports/history`)
- Dashboard / any nav that pointed at the transaction list → `/reports/history`

## Testing (TDD)

- `report_date_range_test.dart` — each preset maps to the correct
  `DateTimeRange` (fixed `now`); quarter/year boundaries.
- `report_csv_test.dart` — the three builders: header + rows + totals; voided
  sales excluded from the sales CSV; comma/quote escaping.
- `reports_hub_screen_test.dart` — renders three cards; Profit hidden for a
  non-admin role, shown for admin.
- Existing report screen tests updated for the new picker wiring.
- `saveReportCsv` (FilePicker platform channel) is not unit-tested directly;
  its logic is covered by keeping the CSV building pure and reusing the proven
  inventory-export save path.

## Open items

- Whether to hide the picker's `lastWeek`/`lastMonth` presets (default: keep).
