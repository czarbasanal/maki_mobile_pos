# MAKI POS Web Admin — Design Handoff w06: Reports & Sale detail

**Purpose.** A self-contained bundle showing the **current** web-admin UI of the Reports feature
(hub, four sub-reports, sale detail, and the printable receipt) so you (or a design session) can
*see* what exists today, then mark up what you want changed. Hand the marked-up version back and
I'll implement it in React (Vite + TypeScript + Tailwind, `web_admin/`). This is a **restyle**
bundle — every screen already ships and uses the shared token system; the goal is to bring the
Reports surface onto the redesigned language without changing scope.

> ## ⚠️ Redesign constraint — read first
> **Redesign what is currently present in these screens. Nothing more, nothing less.**
> Do NOT remove any component: every section, table column, form field, button, banner, badge,
> filter, state (loading/empty/error/success/disabled/capped), dialog, and popover listed below
> must exist in the redesign. Do NOT add components: no new features, fields, actions, nav
> items, or data. **Single exception: charts/graphs MAY be added** if they visualize data
> already present on the screen. Role gating, copy, validation, and behavior are fixed —
> restyle freely, do not re-scope.

**What's in here**
- `current-ui.html` — open in any browser: a token-accurate reconstruction of all six Reports
  screens plus the printable receipt and the void-sale dialog, in light theme at desktop width,
  each rendered inside the 240px sidebar chrome. States (capped banner, empty, loading, error,
  not-found) are drawn as side-by-side variant cards.
- `README.md` (this file) — the design system, per-screen structure/copy/states/role rules, the
  modals section, and a **"What I want" template** to fill in.

**Surfaces.** React web admin (`web_admin/src/presentation/features/reports/`):
- `ReportsHubPage.tsx` — hub, 4 link cards
- `SalesReportPage.tsx` — sales report (+ local `TopProducts`, `Panel`)
- `SalesTable.tsx` — sales list table (+ local `Th`)
- `ProfitReportPage.tsx` — profit report (admin only)
- `LaborReportPage.tsx` — labor report
- `PriceChangeReportPage.tsx` — price-changes report (admin only)
- `SaleDetailPage.tsx` — sale detail + void dialog (+ local `Row`)
- `Receipt.tsx` — printable 320px receipt (+ local `Divider`, `Line`)

Shared components these screens reuse (restyle once, reuse everywhere):
`SummaryCard` (`features/dashboard/SummaryCard.tsx`), `DateRangePicker`, `CappedNotice`,
`EmptyState`, `ErrorView`, `LoadingView`/`Spinner`, `Dialog`
(all in `presentation/components/common/`). Chrome (Sidebar/AdminShell/OfflineBanner) is in **w01**.

Routing: routes at `presentation/router/routes.tsx` (lines 87–92); role gating at
`presentation/router/routeGuards.ts`. Money via `formatMoney` (`core/utils/money`); dates via
`Intl.DateTimeFormat('en-PH')`. Report data via `presentation/hooks/useReportData.ts`
(`repo.list({start,end,limit:2000})`; `SALES_FETCH_CAP = 2000`; `capped = sales.length >= 2000`).

---

## Design system (tokens used by these screens)

Full token reference lives in the **w01** bundle; below are the ones these screens actually use.

### Color
| Token | Hex | Use here |
|---|---|---|
| `light-text` | `#0A0A0A` | primary text; also the **dark button fill** and the **emphasized SummaryCard** background |
| `light-text-secondary` | `#666666` | subtitles, table headers, `dt` labels, muted totals |
| `light-text-hint` | `#A0A0A0` | timestamps, SKU in tables, "unchanged" deltas, struck-through voided values |
| `light-background` / `light-card` | `#FFFFFF` | page bg / cards, panels, dialog |
| `light-subtle` | `#FAFAFA` | table header row, labor-line rows, hover fill |
| `light-hairline` | `#EAEAEA` | card borders, row dividers, section separators |
| `light-border` | `#E0E0E0` | input & outlined-button borders |
| `primary-dark` | `#121C1D` | button hover, account avatar |
| success (`-dark`) | `#4CAF50` / `#2E7D32` | **price/cost decrease** delta (green) |
| warning (`-light`/`-dark`) | `#FFF8E1` / `#F57C00` | **CappedNotice** banner |
| error (base/`-light`/`-dark`) | `#F44336` / `#FFEBEE` / `#C62828` | Void pill, Voided pill, Void-sale button, **price/cost increase** delta (red), error text |
| info | `#2196F3` | (SummaryCard tone option; not emphasized here) |

### Type scale
`headingMedium` 24/600 (page h1, SummaryCard value) · `bodyLarge` 18/400 · `bodyMedium` 16/600
(panel/section h2, card titles) · `bodySmall` 14/400 (body, tables, buttons, inputs) ·
`badge` 11/600. Ad-hoc: `text-[10px]` (Void pill), `[11px]` (Voided pill / receipt footer),
`[12px]` (receipt qty·hint), `[14px]` (receipt store name). Font: **Roboto**;
**ui-monospace/Menlo** for the receipt and SKU cells. All numerics use `tabular-nums`.

### Spacing (`tk-*`) & radii
Spacing `xs 4 · sm 8 · md 16 · lg 24 · xl 32`. Radii: `rounded-md` (6px) inputs/buttons/pills-area,
`rounded-lg` (8px) cards/panels/dialog, `rounded-full` pills. No custom shadows (weight lives in
type + hairlines); Dialog uses `shadow-xl`.

### Button styles
- **Outlined** (default): `border-light-border bg-light-card`, hover `bg-light-subtle` — Download CSV, CSV, Print receipt, Cancel.
- **Outlined destructive**: `border-error-light text-error-dark`, hover `bg-error-light/30` — Void sale trigger.
- **Solid destructive**: `bg-error text-white`, hover `bg-error-dark`, `disabled:opacity-60` — dialog confirm Void sale.
- **Disabled**: `disabled:opacity-50` (CSV buttons when 0 rows).

### Card / table patterns (two distinct kinds — keep both)
- **Card table** (SalesTable, Sale-detail items): rounded hairline card, header row `bg-light-subtle`,
  left-aligned `text-light-text-secondary` headers, `divide-y` rows, hover `bg-light-subtle`,
  right-aligned tabular numerics.
- **Inline panel table** (Top products, Labor-by-mechanic, Price changes): plain `<table>` inside a
  bordered panel — no header fill, `text-light-text-secondary` headers, `divide-y` rows.
- **SummaryCard**: bordered tile, title + value; **emphasized** variant inverts to
  `bg-light-text text-light-background` (black tile, white text) for the hero metric.
- **Panel** (Sales report): `rounded-lg border-hairline bg-card p-tk-lg` with a `bodyMedium` h2.

---

## Screen 1 — Reports hub (`/reports`)

**Job:** landing hub; a grid of links to the four sub-reports. (Not a sales list — that lives on
`/reports/sales`.)

**Layout top→bottom:**
1. **Header** — h1 "Reports"; subtitle "Sales and profit over any date range."
2. **Card grid** — 1 col, `sm:` 2 cols. Each card is a `<Link>`: outlined heroicon (h-6), title,
   description; hover darkens the border (`hover:border-light-text`).
   - **Sales report** → `/reports/sales` — `ChartBarIcon` — "Sales, payment breakdown, top products, and a downloadable sales list."
   - **Profit report** → `/reports/profit` — `ArrowTrendingUpIcon` — "Cost of goods, gross profit, margin, and top products by profit."
   - **Labor report** → `/reports/labor` — `WrenchIcon` — "Service revenue and a per-mechanic breakdown of labor."
   - **Price changes** → `/reports/price-changes` — `TagIcon` — "Price/cost changes across products over a date range."

**States:** static only — no loading/empty/error.
**Per-role:** hub is reachable by **all roles** (`viewSalesReports`). All four cards always render;
two of them target **admin-only** routes (Profit, Price changes) — a staff/cashier who follows those
links is bounced to `/access-denied` by the router (the card is not hidden). No in-page role branching.

---

## Screen 2 — Sales report (`/reports/sales`)

**Job:** sales totals, payment split, top products, and the downloadable sales list for a date range.
Default range preset **Last 7 days**.

**Layout top→bottom:**
1. **Header** — back-link "← Reports" (`ArrowLeftIcon` h-3.5); h1 "Sales report"; subtitle "Sales and
   payment breakdown for the selected range."; **DateRangePicker** right-aligned.
2. **CappedNotice** (shared) — warning strip, shown only when `capped`: "Showing the most recent
   2,000 sales — narrow the date range for exact totals."
3. **Summary cards** — grid 1/2/4 of `SummaryCard`: **Gross Sales** (*emphasized* — black tile),
   **Net**, **Avg order**, **Sales count**.
4. **Two panels** — grid 1/3:
   - *By payment method* (`<dl>`): rows **Cash · Gcash · Maya · Salmon** (capitalized), then a
     hairline-separated **Service / Labor** row (`summary.laborRevenue`).
   - *Top products* (`lg:col-span-2`): inline table, cols **Product | Qty | Revenue | Profit**
     (numerics right). Empty → "No products sold in this range."
5. **Sales section** — header "Sales ({count})" + **Download CSV** button (`ChartBarIcon` h-4;
   filename `sales-YYYYMMDD-YYYYMMDD.csv`; disabled + `opacity-50` when 0 rows). Then **SalesTable**.

**SalesTable columns:** **When** (en-PH short date + 12h time) · **Sale #** (Link to
`/reports/sale/:id`, bold tabular) · **Items** (`saleTotalItemCount`) · **Mechanic**
(`mechanicName ?? '—'`) · **Payment** (`paymentMethodDisplayName`) · **Total** (right).
Voided rows: Sale # and Total get `line-through text-light-text-hint`, plus a red **Void** pill
(`bg-error-light text-error-dark`, 10px uppercase) beside the sale number.

**States:** error → `ErrorView(title="Could not load sales")` · loading → `LoadingView("Loading sales…")`
in an h-32 box · empty table → `EmptyState(title="No sales in this range", description="Adjust the
date range above.")` · capped → CappedNotice banner.
**Per-role:** all roles (`viewSalesReports`). No in-page role branching; the whole content (incl.
Gross/Net) shows to any role that reaches the route. ⚠️ **`viewDailySalesOnly`** (held by cashier &
staff on mobile) is **not consumed anywhere on web** — a cashier/staff would see the full range
picker and all-time totals. Flagged as a gap for design/behavior review, not a current UI element.

**Icons:** `ChartBarIcon` (CSV), `ArrowLeftIcon` (back).

---

## Screen 3 — Profit report (`/reports/profit`) — admin only

**Job:** COGS, gross profit, margin, labor profit, and top products by profit. Default **Last 7 days**.
`topProducts` re-sorted by `totalProfit` desc.

**Layout top→bottom:**
1. **Header** — back-link, h1 "Profit report", subtitle "Cost of goods, gross profit, and margin for
   the selected range.", **DateRangePicker**.
2. **Summary cards** — grid 1/2/4: **Gross Sales**, **Total COGS** (`summary.totalCost`),
   **Gross Profit** (*emphasized*), **Margin** (`profitMargin.toFixed(1)%`).
3. **Second row** — grid 1/2: single card **Service / Labor profit** (`summary.laborProfit`).
4. **Top products by profit** — bordered card; inline table cols **Product | Qty | Revenue | Cost |
   Profit** (numerics right). Empty → "No products sold in this range."

**States:** error → `ErrorView(title="Could not load profit")` · loading → `LoadingView("Loading…")`
h-32. **No CSV export, no capped notice on this page.**
**Per-role:** **admin only** (`viewProfitReports`) — non-admins bounced at the router. No in-page branching.

**Icons:** `ArrowLeftIcon` (back).

---

## Screen 4 — Labor report (`/reports/labor`)

**Job:** service revenue and per-mechanic labor breakdown. Default **Last 7 days**.
`summarizeLabor(sales)`.

**Layout top→bottom:**
1. **Header** — back-link, h1 "Labor report", subtitle "Service revenue and per-mechanic breakdown for
   the selected range.", **DateRangePicker**.
2. **Summary cards** — grid 1/2/4: **Total Labor** (*emphasized*), **Service Sales** (count).
3. **Labor by mechanic** — bordered card; inline table cols **Mechanic | Jobs | Labor** (numerics
   right). Row key = `mechanicId ?? '__unassigned__'` (unassigned labor rolls into one row). Empty →
   "No labor recorded in this range."

**States:** error → `ErrorView(title="Could not load labor")` · loading → `LoadingView("Loading…")`
h-32. No CSV, no capped notice.
**Per-role:** **all roles** (`viewSalesReports`). No in-page branching.

**Icons:** `ArrowLeftIcon` (back).

---

## Screen 5 — Price changes (`/reports/price-changes`) — admin only

**Job:** cross-product price/cost change log over a range. **Default preset `thisMonth`** (differs
from the other reports' `last7`). Data: `usePriceChangeReport(range)` joined with `useProducts()`
for name/SKU.

**Layout top→bottom:**
1. **Header** — back-link, h1 "Price changes", subtitle "Price/cost changes across products for the
   selected range." Right group: **DateRangePicker** + **CSV** button (`ArrowDownTrayIcon` h-3.5;
   disabled + `opacity-50` when 0 rows; filename `price-changes-YYYY-MM-DD-YYYY-MM-DD.csv`; headers:
   Date, Product, SKU, New Price, Price Delta, New Cost, Cost Delta, Reason, Changed By — deltas
   prefixed `+`/`-`, blank when no prior).
2. **Card** — bordered; inline table cols **Product | SKU | New Price | Δ | New Cost | Δ | Reason |
   When**. Delta cells colored: **increase → `text-error-dark` (red)**, **decrease →
   `text-success-dark` (green)**, zero/no-prior → hint; the value only shows when
   `hasPrior && delta !== 0` (otherwise blank). When = `changedAt.toLocaleDateString()`.

**States:** error → `ErrorView(title="Could not load price changes")` · loading →
`LoadingView("Loading…")` h-32 · empty → "No price changes in this range." No capped notice.
**Per-role:** **admin only** (`viewProductCost`).

**Icons:** `ArrowLeftIcon` (back), `ArrowDownTrayIcon` (CSV).

---

## Screen 6 — Sale detail (`/reports/sale/:id`)

**Job:** one sale's full breakdown, with Print-receipt and (admin) Void actions. Data via
React-Query `['sales', id]` → `repo.getById`.

**Layout top→bottom** (main wrapper is `print:hidden`):
1. **Header** — back-link "← Back to sales"; h1 = `sale.saleNumber`; if voided a red **Voided** pill
   (`bg-error-light text-error-dark`, 11px uppercase). Sub-line: date · `cashierName` · optional
   "Mechanic: …".
2. **Action buttons** — **Print receipt** (outlined, `window.print()`); **Void sale** (outlined red)
   rendered only when `canVoidSale(sale)` = not already voided AND `status === 'completed'`. Click
   resets the reason, calls `voidSale.reset()`, opens the dialog.
3. **Items table** card — header `bg-light-subtle`; cols **Item** (name + gray SKU) **| Qty | Unit |
   Net** (`saleItemNet`). Labor lines appended as `bg-light-subtle` rows, colSpan 3, "🔧 {description
   || 'Service'}", fee in the last column.
4. **Totals panel** — right-aligned `max-w-sm` card (local `Row`, capitalized labels): **Gross Sales**
   (`salePartsSubtotal`), **Discount** (`-…`), **Labor** (`saleLaborSubtotal`), hairline divider,
   **Total** (bold); then a divider + tender breakdown — each `realTenderMethods` with amount > 0
   (`paymentMethodDisplayName`, muted), **Amount received**, **Change** (muted).

**States:** loading → `LoadingView("Loading sale…")` · error → `ErrorView(title="Could not load
sale")` · not-found → `EmptyState(title="Sale not found", description="It may have been removed.",
action=Link "Back to sales")`.
**Per-role:** page reachable by **all roles** (`viewSalesReports`). The **Void sale** button is the
one in-page conditional — gated by `canVoidSale` (status-based). Voiding itself needs the `voidSale`
permission (**admin only**, and password-protected via `passwordProtectedPermissions`), **but the web
void UI does not re-check the permission or prompt for a password** — flagged as a gap; keep the
button appearing only on completed, non-voided sales.

**Icons:** emoji **🔧** on labor rows.

### Printable Receipt (`Receipt.tsx`)
Hosted in `<div id="print-receipt" class="hidden print:block">` at page bottom; only appears when
printing. **Print scoping** (`index.css` `@media print`): `body * { visibility:hidden }`, then
`#print-receipt` and its descendants visible and pinned top-left at `width:100%` — so only the
receipt prints, all chrome (sidebar/detail body) hidden.

- Container: `max-w-[320px]`, `font-mono`, 12px. Centered header: store name **"MAKI Mobile POS"**
  (14px bold), sale number, formatted datetime (en-PH medium/short), "Cashier: …", optional
  "Mechanic: …".
- If voided: centered bold **"*** VOIDED ***"** + " (voidReason)" when present.
- Dashed `Divider`. Item lines: name + tiny gray "{qty}×{unitPrice}", right = `saleItemNet`. Labor
  lines: "🔧 {description||'Service'}" + fee.
- Divider. `Line` rows: **Subtotal** (`salePartsSubtotal`), **Discount** (`-…`), **Labor**, **TOTAL**
  (bold). Divider. Tender lines (each real method > 0), **Amount received**, **Change**. Footer
  centered "Thank you!".

---

## Modals & overlays

### Void-sale reason dialog (shared `Dialog`)
Opened from the Sale-detail **Void sale** button. Body portal, `bg-black/30` overlay,
`role="dialog"`, `aria-modal`; panel `max-w-md rounded-lg border-hairline bg-card shadow-xl`.
- **Title** "Void sale"; X close (`XMarkIcon`) shown only when dismissable.
- **`dismissable = !voidSale.isPending`** — while the mutation is in-flight the X is hidden and
  ESC/overlay-click are blocked.
- **Body warning:** "Voiding restores the sold stock and removes this sale from reports. This can't be
  undone."
- **Field (with reasons):** a **Reason `<select>`** — placeholder "Select a reason…", options from
  `useActiveCategories(CategoryKind.voidReason)`.
- **Field (no active reasons):** message "No void reasons configured." + Link **"Add them in Manage
  lists"** → `/settings/lists`. (No select shown.)
- **Error:** `voidSale.error.message` in `text-error-dark` above the buttons.
- **Buttons:** **Cancel** (outlined, disabled while pending) · **Void sale** (solid `bg-error` white;
  disabled unless a reason is chosen and not pending; label toggles to **"Voiding…"** while pending).
  On success the dialog closes; `useVoidSale` invalidates `['sales', id]` and `['reports']`.

---

## What I want *(fill this in, then hand back)*

Leave anything blank you don't care about. Specifics beat vibes — name the screen + region + change.

### Direction
- Overall: bring Reports onto the new web language (same pass as w01/w02), or rethink layout? →
- Reference dashboards / report apps you like →
- **Charts (the one allowed addition):** sales-over-time line on Sales report? tender-split donut from
  the By-payment-method panel? profit-vs-COGS bars? labor-by-mechanic bars? price-delta sparkline? →

### Reports hub
- Keep 4 link cards (2-col grid), or a denser list / tabbed sub-nav? Icon treatment? →

### Sales report
- Summary-cards row — keep 4 tiles with an emphasized Gross Sales, or a hero-number strip? →
- By-payment-method panel + Top-products panel — keep the 1/3 split, or stack / merge? →
- Sales table — density, Void-pill + strike-through voided treatment, sticky header? →
- CappedNotice banner styling; Download CSV button placement →

### Profit report
- 4 cards + separate Service/Labor-profit card + top-products table — layout / emphasis? →
- Margin presentation (plain %, gauge, badge)? →

### Labor report
- 2 cards + by-mechanic table — keep, or add a mechanic bar chart? Unassigned-row treatment →

### Price changes
- Delta coloring (red-up / green-down) — keep, add arrows/badges? Table density; CSV button →

### Sale detail + receipt
- Header (sale #, Voided pill, date/cashier/mechanic line) + action buttons — layout? →
- Items table + labor 🔧 rows — keep inline labor rows or a separate labor section? →
- Totals panel (right `max-w-sm`) + tender breakdown — placement / emphasis? →
- Printable receipt — keep the 320px mono thermal look and the *** VOIDED *** variant? →

### Constraints / must-keep
- **Role gating (router-level):** hub / sales / labor / sale-detail = all roles; **profit &
  price-changes = admin only**. Keep all four hub cards visible regardless of role. →
- **Void button** appears only on completed, non-voided sales (`canVoidSale`); voiding is admin +
  password-protected but the web UI doesn't re-check — keep behavior as-is unless you decide to add
  the gate. Flag `viewDailySalesOnly` (cashier/staff) is not consumed on web today. →
- **All states:** capped (Sales only), empty (per screen copy), loading, error, sale-not-found. →
- **Void-sale dialog** — warning copy, reason select, no-reasons → Manage-lists link, Cancel + red
  Void sale, "Voiding…" lock + non-dismissable while pending. →
- **CSV exports** — Sales (`sales-…csv`) and Price changes (`price-changes-…csv`), disabled at 0 rows;
  exact headers preserved. →
- **Print behavior** — `window.print()` prints only the receipt (`@media print` scoping); keep the
  hidden `#print-receipt` host. →
- Default range presets: `last7` everywhere **except Price changes = `thisMonth`**. →
- Money `formatMoney` (₱ en-PH), dates en-PH, `tabular-nums`. →

---

*Bundles: w01-shell-login-dashboard · w02-pos-drafts · w03-inventory · w04-receiving ·
w05-suppliers · **w06-reports (this)** · w07-users · w08-settings · w09-logs. One bundle at a time,
per `design/handoff-web/ROADMAP.md`.*
