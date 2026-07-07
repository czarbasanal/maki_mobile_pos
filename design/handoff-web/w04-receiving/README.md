# MAKI POS Web Admin — Design Handoff w04: Receiving

**Purpose.** A self-contained bundle showing the **current** web-admin UI of the five Receiving
screens so you (or a design session) can *see* what exists today, then mark up what you want
changed. Hand the marked-up version back and I'll implement it in React (Vite + Tailwind at
`web_admin/`). This is the light-theme, desktop web admin — a different surface from the Flutter
mobile app, though it mirrors the same tokens.

> ## ⚠️ Redesign constraint — read first
> **Redesign what is currently present in these screens. Nothing more, nothing less.**
> Do NOT remove any component: every section, table column, form field, button, banner, badge,
> filter, state (loading/empty/error/success/disabled/capped), dialog, and popover listed below
> must exist in the redesign. Do NOT add components: no new features, fields, actions, nav
> items, or data. **Single exception: charts/graphs MAY be added** if they visualize data
> already present on the screen. Role gating, copy, validation, and behavior are fixed —
> restyle freely, do not re-scope.

**What's in here**
- `current-ui.html` — open in any browser: a token-accurate reconstruction of all five Receiving
  screens (Dashboard, Entry, Bulk CSV, History, Detail) plus the three inline overlays, rendered
  inside the 240px admin sidebar at 1280px. Light theme.
- `README.md` (this file) — the design system, per-screen structure/copy/states/role rules, an
  overlays section, and a **"What I want" template** to fill in.

**Surfaces** (React web admin, all under `web_admin/src/presentation/features/receiving/`):
- `ReceivingDashboardPage.tsx` — monthly overview + drafts + recent list
- `ReceivingEntryPage.tsx` (+ `useReceivingEntry.ts`) — manual receiving / resume draft
- `BulkReceivingPage.tsx` (+ `useBulkReceiving.ts`) — CSV upload, preview, batch receive
- `ReceivingHistoryPage.tsx` — date-ranged history list
- `ReceivingDetailPage.tsx` — read-only receiving record
- Local components: `ReceivingStatusBadge.tsx`, `ReceivingPreviewTable.tsx`
- Shared chrome: `presentation/components/common/{Sidebar,LoadingView,EmptyState,ErrorView,DateRangePicker}.tsx`

---

## Design system (tokens in `web_admin/src/core/theme/tokens.ts` → Tailwind)

### Color
| Token | Hex | Use here |
|---|---|---|
| text | `#0A0A0A` | primary text, bulk "Receive" button fill |
| primary-dark | `#121C1D` | primary button fill (New Receiving / Add / Receive) |
| card / background | `#FFFFFF` | cards, tables, page bg |
| subtle | `#FAFAFA` | table header row, row hover, inline panel/dropdown fills |
| hairline | `#EAEAEA` | card borders, row dividers |
| border | `#E0E0E0` | input borders, outlined buttons |
| secondary | `#666666` | supplier/date cells, subtitles, "match" pill text |
| hint | `#A0A0A0` | SKU hints, "No items yet.", auto row numbers |
| success | `#4CAF50` / `#E8F5E9` / `#2E7D32` | `completed` status badge, "New" preview pill |
| warning | `#FFC107` / `#FFF8E1` / `#F57C00` | `draft` badge, "Variation" pill, cost-differs warning text |
| error | `#F44336` / `#FFEBEE` / `#C62828` | error banner, "Error" pill, error-row tint, remove-icon hover |
| info | `#2196F3` / `#E3F2FD` / `#1565C0` | "New" / "New variation" line pills |
| cancelled tone | subtle / secondary | `cancelled` status badge |

### Type scale (px / weight)
headingMedium 24/600 (H1) · bodyLarge 18/400 · headingSmall 20/600 (stat value) ·
bodyMedium 16/600 (H2 section titles) · bodySmall 14/400 (body + most table text) ·
labelSmall 12/500 · badge 11/600 (status badges, pills) · ad-hoc `text-[11px]` / `[10px]`
(field labels, "New" pills) · **mono** (`ui-monospace, Menlo`) for the reference number.

### Spacing (`tk-*`) & radii
Spacing `xs 4 · sm 8 · md 16 · lg 24 · xl 32 · xxl 48`. Radii: `rounded-md` **6px**
(inputs, buttons, banners, dropdown, pills-are-full), `rounded-lg` **8px** (cards, tables,
panels), `rounded-full` (status badges + pills).

### Buttons
- **Primary** — `bg-primary-dark text-white hover:opacity-90` (New Receiving, Add, Add new product, Receive).
- **Bulk Receive CTA** — uniquely `bg-light-text (#0A0A0A) text-light-card font-semibold`.
- **Outlined / secondary** — `border border-light-border hover:bg-light-subtle` (Import CSV, Choose CSV, Save draft, + New product, Receive another file).
- **Text links** — `hover:underline` (back link, View all →, Resume, Cancel).

### Card / table pattern
Every table = `rounded-lg border border-light-hairline bg-light-card` wrapper, header row
`bg-light-subtle text-light-text-secondary` with uppercase-free 12px medium headers,
`divide-light-hairline` rows, numeric cells `tabular-nums` + right-aligned. Stat tiles and
totals cards use the same hairline-bordered 8px card. No shadows on cards (dropdown uses
`shadow-lg`). Money via `formatMoney` (en-PH `₱1,234.00`); dates via
`Intl.DateTimeFormat('en-PH', {dateStyle:'medium', timeStyle:'short'})`.

### Icons (heroicons 24/outline, 16px)
`ArrowUpTrayIcon` (Import CSV / Choose CSV) · `TrashIcon` (remove line) · `TruckIcon` (sidebar nav).

### Role model (applies to ALL five screens)
- **admin** and **staff** — identical; both hold all four permissions (`accessReceiving`,
  `receiveStock`, `bulkReceive`, `viewReceivingHistory`). No in-page role branching exists.
- **cashier** — blocked entirely: the Receiving nav item is filtered out of the sidebar and
  every `/receiving*` route is denied by the route guard.

There are **no overlay dialogs anywhere in Receiving** — the product picker, new-product form,
and picked-item editor are all inline (dropdown / expanding panel / bar). No confirm/discard
dialogs and no unsaved-changes guard.

---

## Screen 1 — Receiving dashboard (`/receiving`)

**Job:** monthly receiving overview + open drafts + recent receivings; entry points to create.

**Layout top → bottom:**
1. **Header** — H1 "Receiving" + subtitle "Record incoming stock from suppliers, and track what
   you've received." Right actions: **+ New Receiving** (primary-dark) → `/receiving/new`;
   **Import CSV** (outlined, `ArrowUpTrayIcon`) → `/receiving/bulk`.
2. **Stat cards** (3-col grid): "Completed this month" (count) · "Open drafts" (count) ·
   "Received this month" (`formatMoney` total).
3. **Drafts section** *(only if ≥1 draft)* — H2 "Drafts"; borderless-header table, per row:
   referenceNumber (bold) · supplierName or "—" · `{totalQuantity} items` (right) · **Resume**
   link → `/receiving/new/{id}`. Row hover `light-subtle`.
4. **Recent receivings** — H2 + **View all →** link → `/receiving/history`. Table columns:
   **Reference · Date · Supplier · Items (r) · Total (r) · Status**. Rows clickable →
   `/receiving/{id}`; Date = `completedAt ?? createdAt`; Status = `ReceivingStatusBadge`.

**States:** loading → `LoadingView` "Loading receiving…" (h-32 box); recent empty → `EmptyState`
"No receivings yet this month" / "Use New Receiving to record stock, or Import CSV for a batch.";
drafts absent → section hidden. No error state (hook has none).

**Per-role:** admin = staff (full). cashier can't reach this route (nav item hidden).

---

## Screen 2 — Receiving entry (`/receiving/new`, `/receiving/new/:id`)

**Job:** create a new receiving or resume a draft; add existing/new products; save draft or Receive.

**Layout top → bottom:**
1. **Header** — back link "← Back to receiving"; H1 "New receiving" (or "Resume receiving" when
   `:id`); **monospace reference number** (pre-reserved; shows "…" until reserved).
2. **Error banner** *(conditional)* — `border-error bg-error-light text-error-dark` box (e.g.
   "Add at least one item before receiving.", plus mutation errors).
3. **Supplier select** (max-w-sm) — label "Supplier"; options "No supplier" + supplier list.
4. **Add items card** — H2 "Add items" + toggle **+ New product** (outlined; toggles the
   new-product panel and clears any picked item). Two mutually-exclusive modes inside:
   - **Search mode** (default) — input "Search a product by name or SKU…"; live results
     dropdown (≤8 matches): each row = name + SKU hint + right-aligned `formatMoney(cost)`.
   - **New-product panel** — 2/3-col grid on subtle bg. Fields: **Name · SKU** (with **auto**
     checkbox → shows "(auto)", disabled while auto) · **Category** (product categories, "—"
     default) · **Unit** (unit categories) · **Cost · Price · Quantity · Reorder level** (all
     number). Button **Add new product** (primary-dark). Field labels: uppercase 11px hint.
   - **Picked-item bar** (when a search result is chosen) — name + SKU hint; **Qty** (default 1);
     **Unit cost** (defaults to product cost); conditional warning `text-warning-dark`
     "Cost differs → a {baseSku|sku}-N variation will be created" when cost ≠ product cost;
     **Add** (primary-dark) + **Cancel** (text link).
5. **Items table** — columns **Item · Qty (r) · Unit cost (r) · Line total (r) · (remove)**.
   Item cell: name + SKU hint + optional **New** pill (info tint) for pending-new-product lines.
   Remove = `TrashIcon` (hover `text-error`, aria-label "Remove"). Empty → "No items yet."
   (hint, colSpan 5).
6. **Footer bar** — left totals "Total {qty} items · {formatMoney(cost)}". Right: **Save draft**
   (outlined; navigates back to `/receiving`); **Receive** (primary-dark; disabled when busy or
   0 lines; label "Receiving…" while pending → on success navigates `/receiving/{id}`).

**States:** inline error banner (validation + mutation); busy disables both buttons and swaps
the Receive label; resuming hydrates supplier/lines/reference once. No modals.

**Per-role:** admin = staff (full). cashier can't reach this route.

---

## Screen 3 — Bulk receiving / CSV (`/receiving/bulk`)

**Job:** upload a CSV, preview the classification, batch-receive.

**Layout top → bottom:**
1. **Header** — back link; H1 "Bulk receiving"; help paragraph naming expected columns
   "(sku, name, category, unit, cost, price, quantity, reorder_level)" and behavior (existing
   SKU adds stock; different cost → variation; new / "GENERATE" → created).
2. **Controls row** — Supplier select ("No supplier" + list); **Choose CSV** (outlined,
   `ArrowUpTrayIcon`, disabled while refs load, opens hidden `<input type=file accept=.csv>`);
   selected filename text; "Loading…" hint while refs load.
3. **Preview** *(parsed, no result yet)* — summary line "{total} rows · {new} new · {match} match
   · {mismatch} variation [· {errors} error]"; **Receive {n} item(s)** button (bulk CTA
   `bg-light-text`, disabled when 0 actionable or receiving; label "Receiving…"); then the
   **`ReceivingPreviewTable`**.
4. **Result panel** *(after receive)* — card: bold "Received — {referenceNumber}"; summary
   "{received} line items · {newProducts} new · {variations} variations · {failed} failed";
   failed-rows list ("Row {n}: {message}", error-dark); **Receive another file** button (resets).

**`ReceivingPreviewTable` columns:** **# · SKU · Name · Cost (r) · Price (r) · Qty (r) · Status.**
SKU shows "— (auto)" for auto-generate rows. Name cell shows name + first error (error-dark) or
warning (hint). Error rows get `bg-error-light/30` tint. Status pill: match → subtle/secondary,
mismatch → "Variation" warning, new → "New" success, error → "Error" error.

**States:** loading refs → `LoadingView` "Loading products & suppliers…" (h-24); `parseError` →
`ErrorView` "Receiving error"; `headerError` → `ErrorView` "Wrong columns"; top-level `loadError`
→ `ErrorView` "Could not load reference data" (replaces the whole body). No confirm/discard dialogs.

**Per-role:** admin = staff (full). cashier can't reach this route.

---

## Screen 4 — Receiving history (`/receiving/history`)

**Job:** date-ranged list of past receivings (default preset "Last 7 days").

**Layout:** Header (back link, H1 "Receiving history", subtitle "Stock received from suppliers in
the selected range.") with **`DateRangePicker`** on the right (preset dropdown Today / Yesterday /
Last 7 / Last 30 / This Month / Custom; custom reveals two native date inputs). Body: table
identical to the dashboard's recent list — **Reference · Date · Supplier · Items (r) · Total (r) ·
Status**; rows clickable → `/receiving/{id}`.

**States:** error → `ErrorView` "Could not load receivings"; loading → `LoadingView` "Loading
receivings…" (h-32); empty → `EmptyState` "No receivings in this range" / "Try a wider date
range, or record stock from the Receiving dashboard." No modals/menus.

**Per-role:** admin = staff (full). cashier can't reach this route.

---

## Screen 5 — Receiving detail (`/receiving/:id`)

**Job:** read-only view of one receiving record.

**Layout:** Header (back link; H1 = referenceNumber + `ReceivingStatusBadge`; subtitle
"{supplierName | 'No supplier'} · {completedAt ?? createdAt} · {createdByName}"). Items table
columns **Item · Qty (r) · Unit cost (r) · Line total (r)**; Item cell = name + SKU hint +
optional **New variation** pill (info tint) when `isNewVariation`. Totals card (right, max-w-sm):
"Total items" (quantity) and bordered "Total cost" (`formatMoney`).

**States:** loading → `LoadingView` "Loading receiving…"; error → `ErrorView` "Could not load
receiving"; not found → `EmptyState` "Receiving not found" / "It may have been removed." with a
"Back to receiving" action link. **No actions** — no cancel/void/edit UI exists here.

**Per-role:** admin = staff (full). cashier can't reach this route.

---

## Inline overlays *(there are NO modal dialogs in Receiving)*

All three "overlays" live inside the Entry page's Add-items card and are rendered in the HTML as
labeled detail frames, not as backdrop dialogs:
- **A · Search-results dropdown** — absolutely-positioned list under the search input, ≤8 matches,
  each row name + SKU hint + right cost; click selects.
- **B · New-product inline panel** — expanding grid of fields (Name, SKU + auto, Category, Unit,
  Cost, Price, Quantity, Reorder level) + "Add new product"; toggled by "+ New product".
- **C · Picked-item editor bar** — name + Qty + Unit cost + cost-differs variation warning + Add
  / Cancel.

No pending/lock/backdrop behavior — these are plain inline regions. State the "no dialogs" fact
explicitly to any implementer.

---

## What I want *(fill this in, then hand back)*

Leave anything blank you don't care about. Specifics beat vibes — name the screen + region + change.

### Direction
- Overall: refine the current Vercel-flat receiving screens, or rethink the layout? →
- Reference apps / dashboards you like the look of →

### Dashboard
- Stat cards — keep 3 flat tiles, or a hero strip? Add a small trend chart of monthly received? →
- Drafts vs Recent — two separate tables, or merge with a filter? →
- Recent table — hero column (Reference vs Total vs Status)? Row density? →

### Entry
- Add-items card — keep search-dropdown + inline new-product panel + picked bar all inline, or split? →
- New-product form — grid vs stacked; which fields grouped? →
- Cost-differs variation warning — inline text vs a clearer callout? →
- Items table + footer totals — pin the footer action bar, or keep inline? →

### Bulk (CSV)
- Help copy + controls row — keep, or a drop-zone? →
- Preview summary + `ReceivingPreviewTable` — status pills vs row tint emphasis? →
- Result panel + failed-rows list — layout? →

### History
- DateRangePicker placement; table = same as dashboard recent — keep identical or differentiate? →

### Detail
- Items table + totals card + status badge — layout; totals card position? →

### Constraints / must-keep
- Role gating: admin = staff (all four receiving perms); **cashier blocked entirely** (no nav item, guarded routes) →
- **No overlay dialogs** — product picker (dropdown), new-product form (inline panel), picked-item bar (inline) stay inline; no confirm/discard dialogs, no unsaved-changes guard →
- All table columns per screen (Reference/Date/Supplier/Items/Total/Status; entry & detail item tables; preview #/SKU/Name/Cost/Price/Qty/Status) →
- All states: loading / empty / error / result / cost-differs warning / error-row tint / "No items yet." →
- Status badges (completed/draft/cancelled) + pills (New / New variation / Match / Variation / New / Error / auto) and their tones →
- Reference number stays monospace; money `formatMoney` en-PH `₱`; dates en-PH medium+short →
- Bulk "Receive" keeps its distinct `bg-light-text` fill; primary actions stay primary-dark →
- Copy, validation ("Add at least one item before receiving."), and navigation behavior are fixed →

---

*Bundles: w01-shell-login-dashboard · w02-pos-drafts · w03-inventory · **w04-receiving (this)** ·
w05-suppliers · w06-reports · w07-users · w08-settings · w09-logs — one bundle at a time, per
`design/handoff-web/ROADMAP.md`.*
