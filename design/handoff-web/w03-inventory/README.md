# MAKI POS Web Admin — Design Handoff w03: Inventory

**Purpose.** A self-contained bundle showing the **current** web-admin UI of the five Inventory
screens (plus their four dialogs) so you — or a design session — can *see* what exists today and
mark up what should change. Hand the marked-up version back and it gets implemented in React
(Vite + TypeScript + Tailwind) at `web_admin/`. This is the current-state reference only; no
redesign decisions are baked in here.

> ## ⚠️ Redesign constraint — read first
> **Redesign what is currently present in these screens. Nothing more, nothing less.**
> Do NOT remove any component: every section, table column, form field, button, banner, badge,
> filter, state (loading/empty/error/success/disabled/capped), dialog, and popover listed below
> must exist in the redesign. Do NOT add components: no new features, fields, actions, nav
> items, or data. **Single exception: charts/graphs MAY be added** if they visualize data
> already present on the screen. Role gating, copy, validation, and behavior are fixed —
> restyle freely, do not re-scope.

**What's in here**
- `current-ui.html` — open in any browser: a token-accurate reconstruction of all five Inventory
  screens plus the four dialogs, rendered inside the 240px AdminShell sidebar chrome, light theme,
  desktop (~1280px). Icons approximate heroicons; layout/color/type fidelity is the point.
- `README.md` (this file) — the design system, per-screen structure/copy/states/role rules, the
  modals inventory, and a **"What I want" template** to fill in.

**Surfaces.** React web admin (`web_admin/src/presentation/features/inventory/`):
- `InventoryListPage.tsx` — product list: 3 stock stat-filter cards, search/category/inactive bar, table
- `InventoryFormPage.tsx` — add (`/inventory/add`) **and** edit (`/inventory/edit/:id`) product; one component, `isEditing = !!id`
- `InventoryDetailPage.tsx` — read-only product detail + header actions + 4 cards
- `AdjustStockDialog.tsx` — adjust-stock modal (used by detail)
- `PriceHistoryPage.tsx` + `PriceHistoryView.tsx` + `Sparkline.tsx` — price/cost change log
- `ReorderSuggestionsPage.tsx` — velocity-based reorder suggestions + CSV

Shared chrome/components (restyled once, reused everywhere — see w01): `Sidebar`, `Dialog`,
`LoadingView`/`Spinner`, `ErrorView`, `EmptyState`, `CappedNotice`.

---

## Design system (tokens used by these screens)

Source of truth: `web_admin/src/core/theme/tokens.ts` → Tailwind via `tailwind.config.ts`. Only the
**light theme** is exercised on these screens.

### Color
| Token | Hex | Use here |
|---|---|---|
| `light-text` | `#0A0A0A` | primary text; also the **dark button fill** ("black" buttons) |
| `light-text-secondary` | `#666666` | secondary text, table headers, labels |
| `light-text-hint` | `#A0A0A0` | SKU, hints, section labels, timestamps, dots |
| `light-background` / `light-card` | `#FFFFFF` | page/card/input bg; button *text* on dark fills |
| `light-subtle` / `light-surface` | `#FAFAFA` | table header row, hover fills, chips, group header bars, segmented-active |
| `light-hairline` / `light-divider` | `#EAEAEA` | card borders, row dividers, table hairlines |
| `light-border` | `#E0E0E0` | input/select/outline-button borders |
| `primary-dark` | `#121C1D` | button hover; sparkline stroke (`text-primary-dark`) |
| success | `#4CAF50` / light `#E8F5E9` / dark `#2E7D32` | in-stock, price-up ▲, positive adjust preview |
| warning | `#FFC107` / light `#FFF8E1` / dark `#F57C00` | low-stock, capped banner, near-reorder adjust preview |
| error | `#F44336` / light `#FFEBEE` / dark `#C62828` | out-of-stock, delete, price-down ▼, validation |
| Raw Tailwind stock pills | `green/orange/red-50` bg + `-500` dot + `-700` text | list stock badges + count-card dots |

### Type — **Roboto** (body), **ui-monospace / Menlo** (SKU, barcodes, cost codes)
`headingMedium` 24/600 (page titles) · `bodyMedium` 16/400 (card titles at 600) · `bodySmall` 14/400
(the workhorse — rows, labels, buttons, inputs) · ad-hoc `text-[11px]` (section labels, stock pills,
count-card dots, inactive pill) · `text-[12px]` (validation errors, barcode chips) · `tabular-nums`
on all numeric table cells and count values.

### Spacing (`tk-*`) & radius
Spacing `tk-xs 4 · tk-sm 8 · tk-md 16 · tk-lg 24 · tk-xl 32`. Radius: `rounded-md` (6px) inputs /
buttons / segmented / chips-as-pills; `rounded-lg` (8px) cards / dialogs / tables; `rounded-full`
stock pills, count dots, inactive pill.

### Buttons (consistent across the bundle)
- **Primary (dark):** `bg-light-text text-light-background hover:bg-primary-dark` — Add product,
  Create/Save, Apply, Change SKU, crop Save.
- **Outline / secondary:** `border border-light-border hover:bg-light-subtle` — Show/Hide inactive,
  Adjust stock, Edit, Reactivate, Regenerate, barcode Add, image Upload/Change/Remove, Export CSV,
  Cancel, price-history link.
- **Destructive:** Delete on detail uses `border-error-light text-error-dark`; the Delete dialog's
  confirm uses `bg-error-dark text-white`.
- **Disabled:** `opacity-60` (or `opacity-50` for Export CSV).

### Cards & tables (standard pattern)
Card = `rounded-lg border border-light-hairline bg-light-card`. Table = that card wrapper +
`bg-light-subtle` header row + uppercase-ish `font-medium text-light-text-secondary` headers +
`divide-y divide-light-hairline` rows; numeric columns right-aligned `tabular-nums`.

### Segmented toggles
Shared style (Adjust-stock modes, Price-history metrics): `inline-flex rounded-md border p-[2px]`,
each option `rounded px-tk-md py-[4px]`, active = `bg-light-subtle font-semibold text-light-text`,
inactive = `text-light-text-secondary hover:text-light-text`.

---

## Access control model (applies to ALL five screens)

Gating is **entirely route-level** (`presentation/router/routeGuards.ts` + `ProtectedRoute.tsx`).
**None of the inventory page components do inline permission checks** — cost columns, Add/Edit/Delete
buttons all render unconditionally once you're on the route. Roles: **admin · staff · cashier**.

| Route | Screen | admin | staff | cashier |
|---|---|:--:|:--:|:--:|
| `/inventory` | Product list | ✓ | ✓ | ✓ |
| `/inventory/:id` | Product detail | ✓ | ✓ | ✓ |
| `/inventory/add` | New product | ✓ | — | — |
| `/inventory/edit/:id` | Edit product | ✓ | ✓ (`editProductLimited`) | — |
| `/inventory/price-history` | Price history | ✓ | — | — |
| `/inventory/reorder` | Reorder suggestions | ✓ | — | — |

Sidebar reflects this: **Reorder** and **Price History** appear in the *Stock* group only for admin;
staff sees Inventory + Receiving; cashier sees only Inventory. The web app is **admin-only at the
door** today (non-admins are bounced to `/access-denied` before per-route checks), but the RBAC
matrix above is what the sidebar + guards implement. **Note:** cost / margin / price-history / reorder
all expose cost data, and the components render it unconditionally — there is *no* per-widget
cost-hiding for cashiers in this web build (unlike mobile's cost-code pill).

---

## Screen 1 — Product list  (`/inventory` · `InventoryListPage.tsx`)

**Job:** browse products with stock status, price and cost; search/filter; jump to add or detail. All roles reach it.

**Layout, top → bottom:**
1. **Header row** — title **"Inventory"** (headingMedium) + subtitle *"Products, stock levels, and pricing."*; right-aligned **Add product** button (dark fill, `+` icon 14px) → `/inventory/add`.
2. **3 stat/count cards** (`CountCard`, grid 1→3 cols) — **In stock** (green dot), **Low stock** (orange dot), **Out of stock** (red dot). Each = colored dot (`h-2 w-2`) + label + big count. **Clickable = toggle that stock filter**; the active card gets a `border-light-text` (dark) border instead of hairline. Clicking an active card again clears back to "all".
3. **Filter bar** — search input with magnifier icon, placeholder *"Search by name or SKU…"* (searches name + SKU); category `<select>` ("All categories" + dynamic category names); **Show inactive / Hide inactive** toggle button (eye / eye-slash icon). Inactive-off is the default.
4. **Table** — columns **Name** (bold; appends muted *"(inactive)"* when inactive) · **SKU** (mono-ish secondary) · **Category** (— fallback) · **Stock** (pill badge `{qty} · {label}`, colored per status) · **Price** (right) · **Cost** (right). Rows are clickable → `/inventory/:id`; inactive rows render at `opacity-50`.

**Stock badge colors:** in-stock `bg-green-50 text-green-700` · low `bg-orange-50 text-orange-700` · out `bg-red-50 text-red-700`.

**States:** loading → `LoadingView` *"Loading inventory…"* · error → `ErrorView` *"Could not load inventory"* · empty → `EmptyState` *"No products found"* (description *"Try a different search."* when searching, else *"No products match these filters."*).

**Per-role:** list is identical for all three roles (no inline gating). Cashier still sees the Cost column and Add-product button in markup, but the sidebar hides admin-only stock items and the router blocks `/inventory/add`.

**Icons:** plus, magnifier, eye / eye-slash.

---

## Screen 2 — Product form  (`/inventory/add` + `/inventory/edit/:id` · `InventoryFormPage.tsx`)

**Job:** create or edit a product. One component; `isEditing = !!id`. react-hook-form + zod. Add is **admin-only**; Edit is **admin + staff**; cashier reaches neither.

**Layout, top → bottom:**
1. **Header** — back link **"Inventory"** (arrow-left) + title **"New product"** / **"Edit product"**.
2. **Banners (conditional):** mutation-error banner (error-tinted, shown only when there is *no* field-level SKU error); **`loadNotice`** warning banner (warning-tinted — e.g. *"Cost-code mapping is still loading — try again in a moment."* or *"Could not process that image — try a different file."*).
3. **Form — four `Section` cards**, each with an uppercase-hint title:
   - **Identity** — **Name** (blur auto-generates SKU while auto mode is on); **[Add only]** *"Auto-generate SKU from name"* checkbox; **SKU** field (read-only w/ subtle bg while locked) + **Regenerate** button (arrow-path, only when locked); **[Edit only]** hint *"Changing the SKU keeps past sales & receiving records on the old code and re-points linked variations."*; **Barcodes** = chip list (each chip = mono code + `×` remove, `aria-label="Remove …"`) + text input (Enter or **Add** commits; duplicate → *"Already added"*); **Image** = 64×64 preview or dashed *"No image"* box + **Upload/Change** file label + **Remove** button.
   - **Pricing** — **Cost**, **Price** (number, step 0.01, 2-col grid).
   - **Stock & classification** — **[Add only]** Initial quantity; **Reorder level**; **Unit** `<select>`; **Category** `<select>` ("(none)" + options); **Supplier** `<select>` ("No supplier" + options; inactive suppliers suffixed *"(inactive)"*).
   - **Notes** — textarea, 3 rows, resize-y.
4. **Footer actions** — **Cancel** (link to inventory) + **submit** button *"Create product"* / *"Save changes"* (dark fill; shows Spinner + *"Saving…"* and disables while busy).

**Validation (zod):** Name required (*"Name is required"*); SKU required, ≤50 chars, regex `[A-Za-z0-9-]+` (*"SKU is required"* / *"Max 50 characters"* / *"Use only letters, numbers, and hyphens"*); Cost/Price/Quantity/Reorder required numeric ≥0 (blank→error, *"Must be ≥ 0"*, integer fields *"Whole number"*); Unit required. Duplicate SKU / barcode surfaced from the mutation onto the field.

**Add vs Edit differences:** Add shows the auto-SKU checkbox + Initial quantity, no SKU hint, no SKU-change dialog. Edit hides Initial quantity (adjusted via the detail dialog), shows the SKU hint + the **Change SKU?** confirm dialog, and supports image replace/remove/keep + price-history reason detection.

**Per-role:** components render every field unconditionally — there is no in-form staff/cashier field disabling in this web build. Access differences are purely route-level (admin: add + edit; staff: edit only; cashier: neither).

**Modals:** **Change SKU?** and **Crop image** — see *Modals & overlays*.

**Icons:** arrow-left, arrow-path.

---

## Screen 3 — Product detail  (`/inventory/:id` · `InventoryDetailPage.tsx`)

**Job:** read-only product summary + actions. All roles reach it.

**Layout, top → bottom:**
1. **Back link** **"Back to inventory"** (arrow-left).
2. **Header** — optional 64×64 image + name (headingMedium) + SKU hint; right action cluster: **"Inactive"** pill (only when inactive) · **Adjust stock** button (adjustments icon) · **Edit** link (pencil) · **Delete** button (error-tinted outline, trash) **when active**, ELSE **Reactivate** button (arrow-path, disabled while pending). Reactivate error text shows below the header when present.
3. **4 cards** (`Card`/`Field`, 2-col grid):
   - **Stock** — Quantity (`{qty} {unit}`), Reorder level, Status (In/Low/Out stock).
   - **Pricing** — Price, Cost, **Margin** (`{money} ({pct}%)`).
   - **Details** — Category, Unit, Supplier, Barcodes (joined or —), Notes.
   - **Audit** — Created by / Created at, Updated by / Updated at (en-PH medium date + short time; — fallback).
4. **View price history** link (clock icon) → `/inventory/price-history?product=<id>`.

**States:** error → `ErrorView` *"Could not load product"* · loading → `LoadingView` *"Loading product…"* · not-found → back link + `EmptyState` *"Product not found"* / *"This product may have been removed."*

**Per-role:** all roles see the same page including cost + margin + the price-history link (no inline gating). The price-history link's *destination* is admin-only at the router; the link itself always renders.

**Modals:** **Adjust stock** and **Delete Product?** — see *Modals & overlays*.

**Icons:** adjustments-horizontal, arrow-left, arrow-path, clock, pencil-square, trash.

---

## Screen 4 — Price history  (`/inventory/price-history` · `PriceHistoryPage` + `PriceHistoryView` + `Sparkline`)

**Job:** search a product, view its cost & selling-price change timeline with sparklines. **Admin-only** route (also reachable via the detail page's deep link `?product=<id>`).

**`PriceHistoryPage` layout:**
1. **Header** — back link **"← Back to inventory"** (text arrow), title **"Price History"**, subtitle *"Search a product to see its cost & selling-price changes over time."*
2. **Search** `<input type=search>` (max-w-md) *"Search by name or SKU…"* with an **autocomplete dropdown** (up to 10 matches; each row = name + SKU, click selects). `?product=<id>` pre-selects once products load.
3. While products load → plain text *"Loading products…"*.
4. When a product is selected → **"← Back to search"** button, product name + SKU heading, then `<PriceHistoryView>`.

**`PriceHistoryView` layout:**
1. **Metric segmented toggle** — **All · Price · Cost**.
2. **Sparklines** (`text-primary-dark`) — Price and/or Cost section (uppercase-hint label + `Sparkline`), shown only when ≥2 entries; otherwise *"Not enough changes to chart"*.
3. **Table** — columns **Date** (en-PH) · **Price** and/or **Cost** (via `Delta`: value + ▲/▼ colored delta — ▲ success-dark up, ▼ error-dark down) · **Source** (derived from reason/note — Created / Manual edit / Receiving / Edit) · **By** (resolves user displayName, incl. deactivated, else the raw id).

**States:** *"Loading…"* · *"Could not load price history."* · *"No price changes yet."* (all plain text).

**`Sparkline.tsx`:** axis-less inline SVG, 320×44 viewBox, `preserveAspectRatio="none"`, `h-11 w-full`, stroke `currentColor` width 2; renders nothing under 2 points.

**Per-role:** admin-only at the router; staff/cashier never reach it (and the sidebar hides it for them).

**Icons:** none (text arrows + SVG sparkline only).

---

## Screen 5 — Reorder suggestions  (`/inventory/reorder` · `ReorderSuggestionsPage.tsx`)

**Job:** suggested order quantity from sales velocity × days of cover, grouped by supplier, with editable qty and CSV export. **Admin-only** route.

**Layout, top → bottom:**
1. **Header** — back link **"← Back to inventory"** (text arrow), title **"Reorder suggestions"**, subtitle *"Suggested order quantity from recent sales velocity × days of cover. Velocity uses complete days ending yesterday."*
2. **Controls row** (`Control`, uppercase-hint labels) — **Sales window** `<select>` (7 / 14 / 30 / 90 days; default 30) · **Days of cover** number input (min 0, default 14) · **Export CSV** button (right, download icon; disabled when no suggestions; downloads `reorder-YYYY-MM-DD.csv` with columns Supplier, SKU, Name, Current stock, Velocity/day, Order qty).
3. **`CappedNotice`** — warning banner shown when `capped`: *"Velocity is computed from the most recent {REORDER_SALES_CAP} sales — it may be understated for this window."*
4. **Supplier-grouped tables** ("No supplier" fallback) — each section = card with a `bg-light-subtle` supplier header bar + table: columns **Product** (name bold + SKU hint) · **Current** (right, tabular-nums) · **Velocity/day** (right, 2-dp) · **Order qty** = editable number input (`w-20`, min 0, clamps ≥0; local overrides keyed by product id, reset on recompute).

**States:** error → `ErrorView` *"Could not load reorder data"* · loading → `LoadingView` *"Crunching sales…"* (in an `h-32` box) · empty → `EmptyState` *"Nothing to reorder"* / *"No products are below their projected demand for this window."*

**Per-role:** admin-only at the router; staff/cashier never reach it (sidebar hides it).

**Icons:** arrow-down-tray (export).

---

## Modals & overlays

All use the shared `Dialog` (portal, `max-w-md`, `rounded-lg` panel, `shadow-xl`, dimmed `bg-black/30`
backdrop, header with title + optional `×` close, ESC + click-outside close **only when dismissable**,
body-scroll lock).

- **Change SKU?** *(form, edit-only — shown on submit when the SKU changed).* Body: old SKU → new SKU (mono, `→` separator); bullet list — *"Past sales and receiving records keep their original SKU."* + conditional *"{count} linked variation(s) will be re-pointed to the new SKU."*; buttons **Cancel** (outline) + **Change SKU** (dark, Spinner while saving). **Non-dismissable while submitting.**
- **Crop image** *(form — opens when a file is picked).* Body: 256-tall (`h-64`) crop area with a **react-easy-crop** square (aspect 1:1) cropper; a **Zoom** range slider (min 1, max 3, step 0.1); buttons **Cancel** (outline) + **Save** (dark, runs `getCroppedBlob`). Dismissable.
- **Adjust stock** *(detail · `AdjustStockDialog`).* Title **"Adjust stock"**. **Segmented mode toggle** Add / Remove / **Set to** (active pill `bg-light-subtle`); **Quantity** number input (autofocus, inline validation error); live **New quantity** preview line colored by result — **error-dark** ≤0, **warning-dark** ≤ reorder level, **success-dark** otherwise; *"—"* when no valid input; + unit; mutation-error banner; buttons **Cancel** (outline) + **Apply** (dark, Spinner while busy, disabled unless the preview is valid). **Non-dismissable while busy.**
- **Delete Product?** *(detail).* Body: *"Delete "{name}"? This product will be hidden from POS and inventory lists. Past sales and receivings that reference it remain intact."*; deactivate-error text when present; buttons **Cancel** (outline) + **Delete** (`bg-error-dark` white, Spinner while pending). **Non-dismissable while pending.** This is a **soft deactivate**, not a hard delete — hence the Reactivate affordance on the detail header.

---

## What I want  *(fill this in, then hand back)*

Leave anything blank you don't care about. Specifics beat vibes — name the screen + region + the change.

### Direction
- Overall: restyle in place (Vercel-flat like the current chrome), or a warmer/denser catalog feel? →
- Reference admin/catalog apps you like →

### Product list
- **Stock stat cards** — keep 3 dot-cards as toggle filters, or a segmented count strip / stacked bar chart of the stock split? →
- **Table** — density, which column is the hero (Name / Stock / Price)? Keep Cost visible in the list? →
- Stock badge — keep the `{qty} · label` pill, or split qty and status? →
- Search + category + inactive-toggle — keep inline bar, or a filter cluster? →

### Product form
- Keep the four stacked section cards (Identity / Pricing / Stock & classification / Notes), or regroup? →
- Field surfaces — outlined vs filled; section-header styling; 2-col grids? →
- Barcodes chips + Image uploader block — any layout change? →
- Pin the Create/Save action bar to the bottom, or keep inline at the end? →

### Product detail
- Header action cluster (Adjust stock / Edit / Delete-or-Reactivate) — keep as a button row, or a menu? →
- 4 info cards (Stock / Pricing / Details / Audit) — layout, hero number (quantity? margin?)? →
- Margin emphasis; price-history link placement →

### Price history
- Keep sparkline + delta table, or a richer line chart / timeline? →
- Row layout — Price & Cost columns vs stacked; delta emphasis; Source badge styling →
- Search + autocomplete — keep, or a product picker? →

### Reorder
- Controls row (window / cover / export) — layout →
- Supplier-grouped tables + editable Order qty — keep per-supplier cards, or one table with a supplier column? →
- CappedNotice + empty/loading copy — keep as-is? →

### Constraints / must-keep
- **Role gating stays route-level** (admin: add + price-history + reorder; admin+staff: edit; all: list + detail). Components render cost/margin unconditionally — do not add per-widget cost hiding →
- All four dialogs + their exact copy: **Change SKU?**, **Crop image**, **Adjust stock**, **Delete Product?** →
- All states per screen: loading / error / empty / **capped** (reorder) / disabled-Export / non-dismissable-while-busy dialogs →
- Validation copy + the auto-SKU / Regenerate / barcode-dedupe behavior →
- CSV export (`reorder-YYYY-MM-DD.csv`, 6 columns) and the adjust-stock preview color logic →
- Delete = **soft deactivate** (Reactivate path must stay) →

---

*Bundles: w01-shell-login-dashboard · w02-pos-drafts · **w03-inventory (this)** · w04-receiving ·
w05-suppliers · w06-reports · w07-users · w08-settings · w09-logs — one bundle at a time, per
`design/handoff-web/ROADMAP.md`.*
