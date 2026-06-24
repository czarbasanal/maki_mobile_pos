# MAKI POS — Design Handoff 05: Receiving

**Purpose.** A self-contained bundle showing the **current** UI of the five Receiving surfaces so you (or a design
session) can *see* what exists, then mark up what you want changed. Hand the marked-up version back and I'll
implement it in Flutter.

**Note — migration bundle (mixed, like 04 but deeper).** These screens are **not on the redesigned language**:
icons are **Cupertino**, surfaces are Material `Card`s / flat bordered `Container`s (no `AppCard`), and status uses
**hardcoded** `Colors.green/orange/blue/grey` (no dark parity) instead of theme tokens. The batch-import flow is
*partly* on-system (semantic `AppColors` chips). Currency already renders grouped (`₱1,234.00`) from the app-wide
formatter. This bundle brings everything **up** to the new language — Lucide icons, soft-shadow `AppCard`
surfaces, and theme-aware status colors with dark parity — the same pass done for POS/Checkout/Sale-Detail (02/03)
and Inventory (04).

**What's in here**
- `current-ui.html` — open in any browser: token-accurate reconstruction of 5 surfaces (Receiving landing, Bulk
  receiving, Batch-import preview, Drafts list, History list) in light theme. *(Icons render in Lucide — the
  target — though the live screens ship Cupertino.)*
- `README.md` (this file) — design system, per-screen structure/copy/states/role rules, the Cupertino→Lucide map,
  and a **"What I want"** template to fill in.

**Surfaces.** Flutter mobile app:
- `screens/receiving/receiving_screen.dart` — landing hub (summary cards + this-week list)
- `screens/receiving/bulk_receiving_screen.dart` — the main receive-stock form (807 lines; edit + read-only)
- `screens/receiving/batch_import_screen.dart` — CSV import flow (idle → parse → preview → done)
- `screens/receiving/receiving_drafts_screen.dart` — drafts list
- `screens/receiving/receiving_history_screen.dart` — completed history (month-grouped)
- Widgets: `receiving_item_row.dart`, `receiving_summary_cards_row.dart`, `csv_import_dialog.dart`,
  `import_preview.dart`. Shared: `EmptyStateView`/`LoadingView`/`ErrorStateView`, `AppDropdown`.

---

## Design system (tokens in `lib/core/theme/`)

### Color (`app_colors.dart`) — and the migration the bundle performs
| Role | Light | Dark | Today |
|---|---|---|---|
| slate (primary) | `#283E46` | gold `#E8B84C` | primary buttons, totals, links |
| Completed / success | `#4CAF50` (text `#2E7D32`/`#8FE39A`, fill `#E8F5E9`/`.18`) | icon `#5FC86A`, text `#8FE39A` | **hardcoded `Colors.green[50/700]`** → migrate to `AppColors.success*` |
| Draft / warning | `#F57C00` (icon `#FFC107`) | `#F5B547` | **hardcoded `Colors.orange[50/700]`** → `AppColors.warning*` |
| Total / info | `#2196F3` | `#5AA9F0` | **hardcoded `Colors.blue`** → `AppColors.info` |
| Cancelled / muted | `#8A9296` | `#93A0A3` | **hardcoded `Colors.grey[200/700]`** → muted tokens |
| New-variant badge | info tint | info tint dark | **hardcoded `Colors.blue[100/700]`** → `AppColors.info` tint |
| Cost-diff up / down | `#C62828` / `#2E7D32` | `#FF6B5E` / `#8FE39A` | already `AppColors.errorDark/successDark` (keep, add dark) |
| Canvas / card | `#F6F5F3` / `#FFFFFF` (soft shadow) | `#0C1415` / `#18262A` (1px `#243234`) | Material `Card` → `AppCard` |
| Field fill / border | `#FAFAFA` / `#E2E2E2` | `#0C1415` / `#2C3C3E` | `OutlineInputBorder` |
| Text: primary / muted | `#16201F` / `#8A9296` | `#ECEFEF` / `#93A0A3` | grey[600/700] → muted |

### Type — **Figtree**, **Roboto Mono** for reference numbers / SKU
ref # `13/600` mono · stat value `24/700` · section header `16/600` · month header `13/600` uppercase muted ·
item name `13/600` · price line `12` · total `14/700` · summary total `22/700` · badge `11/600`.

### Spacing & radius · elevation
Spacing `xs 4 · sm 8 · md 16 · lg 24`. Radius `sm 10 · md 14 · field 16 · lg 18 · pill 999`.
Neutral surfaces → **`AppCard`** (light soft shadow `AppShadows.card`; dark `#18262A` + 1px `#243234`). Pinned
bottom bars (New Receiving, Complete Receiving) → footer `Container` with `AppShadows.pinnedFooter` + primary
button (`AppShadows.primaryButton`). Stat/summary cards → `AppCard` (like Inventory's `18/700` stats).

### Icons → migrate **Cupertino → Lucide** (`lucide_icons`)
`back`→`chevron-left` · `cloud_upload`→`upload-cloud` · `add`→`plus` · `cube_box`→`package` ·
`checkmark_circle`→`check-circle` · `square_pencil`→`square-pen` · `xmark`→`x` · `minus_circle`→`minus-circle` ·
`plus_circle`→`plus-circle` · `trash`→`trash-2` · `arrow_up`/`arrow_down`→`arrow-up`/`arrow-down` ·
`arrow_up_right`/`arrow_down_right`→`arrow-up-right`/`arrow-down-right` · `pencil`→`square-pen` ·
`briefcase`→`briefcase` · `tray_arrow_down`→`save` · `search`→`search` · `arrow_right_circle`→`arrow-right-circle` ·
`check_mark_circled`→`check-circle` · `exclamationmark_triangle`→`alert-triangle` ·
`exclamationmark_circle`→`alert-circle` · `folder_open`→`folder-open` · `calendar`→`calendar` ·
`arrow_right`→`arrow-right`. Material empty-state `Icons.add_shopping_cart`→`LucideIcons.shoppingCart`/`packagePlus`.

---

## Screen 1 — Receiving landing (`receiving_screen.dart`)
**App bar:** back · title **"Receiving"** · action **batch import** (`upload-cloud`, tooltip "Batch import (CSV)").
**Body:** **summary cards row** (`ReceivingSummaryCardsRow`: Drafts (orange `square-pen`) · Completed (green
`check-circle`) · **Total Received** *(admin)*, compact `₱45.6K`; tap Drafts→drafts, Completed→history) →
**"Recent Receivings"** header + **"View all"** → this-week list of `Card` rows: status-circle leading,
**reference number** (mono), `date · time · supplier`, trailing **status badge** (Completed/Draft/Cancelled) +
**"N items"** + **₱total** *(admin)*; tap → bulk receiving for that record.
**Pinned:** **"New Receiving"** (`plus`).
**States:** empty ("Nothing yet this week" / 'Tap "View all" to see earlier records', `cube_box`) · loading · error.
**Roles:** admin → per-row ₱total + Total-Received card.

## Screen 2 — Bulk receiving (`bulk_receiving_screen.dart`)
**App bar:** back · title **"Receive Stock"** / **"Receiving Details"** (read-only) + **ref #** subtitle ·
*(edit)* **Import CSV** (`upload-cloud`) · **Save Draft** (`save`, disabled when empty).
**Body:** *(read-only)* success banner "Completed on {date}. Read-only." → **Supplier** dropdown
("Supplier (optional)", `briefcase`, "No supplier" default) → *(edit)* grey **Add Product** panel: search
autocomplete ("Search product by name or SKU", results = name + `SKU · Stock: N` + ₱cost admin) → on select:
**Quantity** (+ unit suffix) + **Unit Cost** *(admin, ₱ prefix)* + **Add**; **cost-diff warning** ("Cost
increased/decreased by X% — A new SKU variation will be created") → **items list** (`ReceivingItemRow`).
**Item row:** name · SKU (+ **"New Variant"** badge) · `Cost ₱… · Sells ₱… · unit` (+ cost-diff badge admin) ·
qty **stepper** (`minus-circle`/field/`plus-circle`; read-only = `×N`) · **line total** *(admin)* + `N unit` ·
**x** remove (or **`square-pen`** "Adjust stock" when read-only). Swipe-left = delete (red, `trash-2`).
**Pinned summary:** "N products / M total units" + **Total Cost ₱…** *(admin)* + **"Complete Receiving"**
(spinner while processing) → confirm dialog **"Complete Receiving?"** (lists cost-different lines for admin) →
"Post Receiving".
**States:** empty ("No items added yet" / "Search and add products above") · saving · validation ("Please enter a
valid quantity") · "Draft saved" / "Stock received successfully!".
**Roles:** admin → unit cost, cost in search, line totals, total-cost summary, cost-diff badges/warnings, price-change dialog.

## Screen 3 — Batch import (`batch_import_screen.dart` + `csv_import_dialog.dart` + `import_preview.dart`)
**App bar:** back · **"Batch Import"**.
**Idle:** expandable **"CSV format"** help card (column spec, GENERATE rule, variation rule) → **Supplier**
dropdown ("Supplier (applies to all rows)") → **"Pick CSV file"** (`upload-cloud`).
**Parsing/Importing:** centered spinner ("Parsing CSV…" / "Importing…").
**Preview** (`ImportPreview`, shared with the in-form `CsvImportDialog`): **summary chips** — Match (success) ·
Cost variation (warning) · New product (info) · Errors (error) — already semantic; **error list** (red bordered
"Skipped rows:") ; **classified row tiles**: name · `SKU • qty unit • cost X` + right **badge** (Match/Variation/New);
permission banner if file has new products and user lacks `addProduct`; bottom **Cancel** + **"Import N row(s)"**
(`arrow-right-circle`, disabled when blocked/empty).
**Done:** `check-circle` + "Import completed" + "Reference: …" + "Back to receiving" / "Import another".
**Errored:** `alert-triangle` + message + "Try again".
**Roles:** new-product rows require `Permission.addProduct` (else banner + disabled import).

## Screen 4 — Drafts list (`receiving_drafts_screen.dart`)
**App bar:** back · **"Draft Receivings"**. **List:** `Card` rows — orange `square-pen` leading, **ref #**,
`N item(s) • M units` + date, trailing **"Resume"**; tap or Resume → bulk receiving.
**States:** empty ("No Drafts" / "In-progress receivings appear here") · loading · error.

## Screen 5 — Receiving history (`receiving_history_screen.dart`)
**App bar:** back · **"Receiving History"**. **List:** `CustomScrollView` grouped by month (**"MMMM y"** header +
count) → `Card` rows: green `check-circle` leading, **ref #**, date + supplier, trailing **"N items"** + **₱total**
*(admin)*; tap → bulk receiving (read-only).
**States:** empty ("No Receiving History" / "Completed receivings will appear here") · loading · error.
**Roles:** admin → per-row ₱total.

---

## What I want  *(fill this in, then hand back)*

Leave anything blank you don't care about. Specifics beat vibes — name the screen + region + the change.

### Direction
- Bring Receiving fully onto the new language (Lucide + `AppCard` + theme-aware status), or rethink any layout? →
- Reference apps / receiving/PO screens you like →

### Landing
- **Summary cards** — keep 3 (Drafts/Completed/Total), and the compact `₱45.6K` total? Same hero/`AppCard` style as Inventory stats? Tappable? →
- **Recent list rows** — what's the hero (ref# vs total vs status)? Keep status badge + item count + ₱total? Density? →
- Status colors: completed=success / draft=warning / cancelled=muted — agree, or different? →

### Bulk receiving
- **Add-product panel** — keep the grey inline panel (search → qty/cost → Add), or a bottom sheet / scan-first flow? →
- **Item rows** — `AppCard`; qty stepper style; New-Variant + cost-diff badge treatment; keep swipe-to-delete? →
- **Pinned summary + Complete** — layout of products/units/total; button treatment (matches Inventory/Sale-Detail pinned)? →
- Read-only completed view — banner + per-line "Adjust stock" pencil — any change? →

### Batch import
- Keep the chips + classified-row preview (it's already semantic)? Any restyle of the help card / idle step? →
- Surfaces: bordered cards → `AppCard`? Done/Errored screens treatment? →

### Drafts / History
- Row layout (ref# / counts / date / Resume) · month-header style · empty states →

### Constraints / must-keep
- All role-gating (admin: unit cost, line/total costs, cost-diff, price-change dialog; `addProduct` for CSV new products) →
- Read-only mode for completed receivings; SKU-variation-on-cost-change behavior + its warnings/dialog copy →
- CSV format rules + GENERATE + variation logic; draft save/resume; supplier optional →
- Currency stays grouped (`₱1,234.00`); dates `MMM d, y • h:mm a`, month `MMMM y` →
- Dark-theme parity →

---

*Bundles: 01-login-dashboard · 02-pos-checkout · 03-sale-detail · 04-inventory · 05-receiving (this). Queued next
(per `ROADMAP.md`): Reports · Void Requests · Expenses · Drafts · Settings · Suppliers · Users · Logs —
one bundle at a time.*
