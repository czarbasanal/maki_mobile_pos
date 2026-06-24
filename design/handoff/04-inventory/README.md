# MAKI POS — Design Handoff 04: Inventory

**Purpose.** A self-contained bundle showing the **current** UI of the three Inventory screens so you (or a
design session) can *see* what exists, then mark up what you want changed. Hand the marked-up version back and
I'll implement it in Flutter.

**Note — this is a migration bundle (like 01/02), not a refinement (like 03).** These screens already use
`AppColors` tokens and are dark-aware, but they are **not on the redesigned surface language yet**: icons are
still **Cupertino** (not Lucide), product rows use Material-default `Card` shadows while the summary stats use
flat hairline `Container`s (inconsistent elevation), there are **no `AppCard` soft-shadow surfaces**, and no
hero-number treatment. So this bundle brings Inventory **up** to the new language — the same pass done for
POS/Checkout (bundle 02) and Sale Detail (bundle 03).

**What's in here**
- `current-ui.html` — open in any browser: a token-accurate reconstruction of all three screens (Inventory list,
  Product form, Price history) in light theme. *(Icons render in Lucide — the migration target — even though the
  live screens still ship Cupertino glyphs.)*
- `README.md` (this file) — the design system, per-screen structure/copy/states/role rules, and a
  **"What I want" template** to fill in.

**Surfaces.** Flutter mobile app:
- `lib/presentation/mobile/screens/inventory/inventory_screen.dart` — list + summary + search/filter
- `lib/presentation/mobile/screens/inventory/product_form_screen.dart` — add / edit product (~14 fields)
- `lib/presentation/mobile/screens/inventory/price_history_screen.dart` — admin price/cost history

Shared tiles: `ProductListTile`, `CostCodePill`, `CostDisplayToggle`, `ProductImageUploader`,
`EmptyStateView`/`LoadingView`/`ErrorStateView`.

---

## Design system (tokens in `lib/core/theme/`)

### Color (`app_colors.dart`)
| Token | Hex | Use here |
|---|---|---|
| slate (primary) | `#283E46` | price pill, primary buttons, selected chips/filters (gold in dark) |
| info | `#2196F3` | "Total" stat |
| success | `#4CAF50` (text `#2E7D32` light / `#8FE39A` dark) | In-stock stat/badge, price-up arrow, margin badge |
| warning | `#FFC107` (dark `#F57C00`) | Low-stock stat/badge, reorder-level |
| error | `#F44336` | Out-of-stock stat/badge, delete, price-down arrow |
| Light canvas / card | `#F6F5F3` / `#FFFFFF` | screen bg / surfaces |
| Dark canvas / card | `#0C1415` / `#18262A` (1px border `#243234`) | screen bg / surfaces |
| Field fill / input border | `#FAFAFA` / `#E2E2E2` | text fields, dropdowns |
| Text: primary / muted | `#16201F` / `#8A9296` | values / labels, SKU, dates |
| Hairline | `#ECECEC` light / `#243234` dark | stat-card borders, row dividers, cost/category chips |

### Type — **Figtree**, **Roboto Mono** for SKU / barcode / cost code
Stat value `16/600` · product name `13/600` (h 1.25) · SKU/labels `12` muted · price pill `12/600` · stock-badge
qty `18/600` + unit `10` · field value `14` · field label `12` muted · section/segment `13`.

### Spacing & radius (`app_spacing.dart`)
Spacing `xs 4 · sm 8 · md 16 · lg 24 · xl 32`. Radius `sm 10 · md 14 · field 16 · lg 18 · xl 24 · pill 999`.

### Elevation (`app_shadows.dart`) & surfaces — **the migration target**
Neutral cards should become **`AppCard`** (light soft shadow `0 2px 8px rgba(17,28,29,.06)`; dark = 1px hairline
border). **Today they aren't:** product rows are Material `Card` (default grey elevation shadow), summary stats
are flat hairline `Container`s — inconsistent. A pinned bottom action bar should use `AppShadows.pinnedFooter`.

### Icons → migrate **Cupertino → Lucide** (`lucide_icons`)
Current → target mapping: `back`→`chevron-left` · `eye`/`eye_slash`→`eye`/`eye-off` (cost toggle) ·
`arrow_up_arrow_down`→`arrow-up-down` (sort) · `more` (3-dot)→`more-vertical` · `add`→`plus` ·
`cloud_download`→`download` (export) · `cube_box`→`package`/`box` · `checkmark_circle`→`check-circle` ·
`exclamationmark_triangle`→`alert-triangle` · `exclamationmark_circle`→`alert-circle` ·
`square_grid_2x2`→`layout-grid` (category) · `search`→`search` · `xmark`→`x` ·
`line_horizontal_3_decrease`→`sliders-horizontal` · `qrcode`→`qr-code` (SKU) · `tag`→`tag` (price) ·
`AppIcons.peso`→`philippine-peso` (cost) · `number`→`hash` (qty) · `barcode_viewfinder`→`scan-barcode` ·
`briefcase`→`briefcase` (supplier) · `lock`→`lock` (cost code) · `list_bullet`→`list` (notes) ·
`clock`→`clock` (price history) · `trash`→`trash-2` · `tray_arrow_down`→`save` · `info_circle`→`info` ·
`arrow_up`/`arrow_down`→`arrow-up`/`arrow-down` (price deltas).

---

## Screen 1 — Inventory list  (`inventory_screen.dart`)

**Job:** browse/search/filter the product catalog; jump to add/edit; admin sees costs + export.

**App bar:** title **"Inventory"**; leading **back**. Actions: **cost toggle** (`eye`/`eye-off`, *admin only*;
green when costs shown — toggling on requires a password and auto-hides after 5 min) · **sort** (`arrow-up-down`
→ menu: **Name · SKU · Quantity · Price · Recently Updated**, selected shows ↑/↓) · **overflow** (3-dot → **Add
Product** *(if permitted)* · **Export CSV** *(admin)*).

**Body, top → bottom:**
1. **Summary stats** — 4 tappable cards: **Total** (`package`, info/blue) · **In Stock** (`check-circle`,
   green) · **Low** (`alert-triangle`, amber) · **Out** (`alert-circle`, red). Each = icon + count + label;
   tapping In/Low/Out toggles that `StockFilter`; selected card gets a 1.5px colored border. *(Current: flat
   hairline `Container`s — no shadow.)*
2. **Search field** — hint **"Search by name, SKU, or barcode..."**, `search` prefix, clear (`x`) suffix when
   non-empty. Searches name + SKU + all barcodes.
3. **Filter chips** (horizontal scroll) — `FilterChip`s **All · In Stock · Low Stock · Out of Stock** + a
   **Category** chip (`layout-grid`, popup of active categories + "All Categories").
4. **Active-filters row** *(when any filter ≠ default)* — `sliders-horizontal` + **"Filters active"** +
   **"Clear all"**.
5. **Product list** — `ProductListTile` rows (currently Material `Card`, margin 16×4, radius lg):
   - **Leading 40×40** — product image, else a stock-tinted fallback icon.
   - **Name** (`13/600`, 2-line ellipsis); **SKU** (mono, muted) + **• category chip**.
   - **Price row** — slate **price pill** `₱250.00`; then *if costs shown*: **cost pill** "Cost: ₱180.00" +
     **margin badge** "28%" (green). *If costs hidden / staff*: **cost-code pill** (`lock` + mono code) instead.
   - **Trailing stock badge** — outlined in stock color: qty (`18/600`) + unit (e.g. "pcs").
   - **Stock status:** out (red `alert-circle`) · low (amber `alert-triangle`) · in (green `check-circle`).
6. **Bottom action bar** *(if `addProduct` permission)* — filled **"Add Product"** (`plus`).

**States:** loading (`LoadingView`) · error ("Error: …" + **Retry**) · empty-no-products ("No Products Yet" /
"Add your first product to get started", `package`) · empty-with-filters ("No products match filters" / "Try
adjusting your search or filters", **Clear Filters**) · pull-to-refresh.
**Role rules:** `addProduct` perm → Add affordances; **admin** → cost toggle + Export CSV + long-press-to-delete
(dialog: *'Delete "{name}"? This product will be hidden from POS and inventory lists. Past sales and receivings
that reference it remain intact.'*).

---

## Screen 2 — Product form  (`product_form_screen.dart`)

**Job:** add or edit a product. Title **"Add Product"** (create) / **"Edit Product"** (edit). Heavily
role-gated; long form in a single scroll, primary action at the bottom.

**App bar:** back · *(edit + admin)* **cost toggle** · *(edit + admin)* **delete** (`trash-2`, red, tooltip
"Delete").

**Body, top → bottom:**
1. **Role banner** *(edit only)* — staff: *"You can edit product details except price and cost fields."* ·
   cashier: *"You can edit the product name and image."* (info-blue tint).
2. **Image uploader** (`ProductImageUploader`) — add/replace/remove product image.
3. **SKU** *(req)* — `qr-code`, mono. Create has an **"Auto-generate SKU"** switch (subtitle *"Built from
   category + random suffix"* / *"Type the SKU manually"*) + **Regenerate** (`arrow-2-circlepath`). Edit (admin):
   helper *"Changing the SKU keeps past sales & receiving history intact and keeps the old code scannable."* →
   confirm dialog **"Change SKU?"** with bullets. Validation: *"SKU is required"* / *"Use only letters, numbers,
   and hyphens (max 50)"*.
4. **Product Name** *(req)* — `box`. *"Name is required"*.
5. **Selling Price (₱)** *(req)* — `tag`. Admin always; staff create-only (disabled on edit, helper *"Only admin
   can change price"*); cashier never. *"Price is required"* / *"Enter a valid price"*.
6. **Cost (₱)** *(req, admin)* — `philippine-peso`. Shown on create; on edit only when cost toggle is on.
7. **Cost Code** *(req, staff-create-only)* — `lock`, uppercase. *"Enter the product cost code"* / *"Invalid cost
   code"*.
8. **Initial Quantity** *(req)* — `hash`. Disabled for cashier.
9. **Reorder Level** — `alert-triangle`, helper *"Alert when stock falls below this level"*.
10. **Unit** — dropdown (`ruler`/`straighten`), admin-managed list, default "pcs".
11. **Barcodes** — chip list of codes (deletable) + add field (hint *"e.g. 4806504801108"*, `scan-barcode` +
    add). Dup within product → *"Already added"*; cross-product dup caught on save.
12. **Category** — dropdown (`layout-grid`), active list + "(none)".
13. **Supplier** *(admin)* — dropdown (`briefcase`), "No supplier" default.
14. **Notes** — `list`, 3 lines.
15. **Audit info** *(edit)* — Created / Created by / Last updated / Updated by.
16. **View price history** *(admin, edit, costs shown)* — outlined (`clock`).
17. **Submit** — filled **"Add Product"** / **"Update Product"** (`save`/`tray_arrow_down`), spinner while saving.

**States:** form loading · saving (button spinner, actions disabled) · delete dialog (**"Delete Product?"**) ·
SKU-change dialog · success snackbars (*"Product created/updated successfully"*) · *"Image upload failed —
product saved without image."*.
**Role rules (admin / staff / cashier):** create → yes / yes(via cost code) / no · edit price → all / create-only
/ no · edit cost → admin only · edit SKU → admin only · supplier → admin only · qty/reorder/unit/category/notes →
not cashier · name + image → all · delete → admin only. *(Disabled fields currently render at `Opacity(0.38)`.)*

---

## Screen 3 — Price history  (`price_history_screen.dart`)

**Job:** admin-only read-only log of price/cost changes for one product (newest-first, last ~50).

**App bar:** title **"Price History"**; leading **back**. No actions.

**Body, top → bottom:**
1. **Segmented filter** — `SegmentedButton`: **All · Price · Cost**.
2. **Sparklines** (`fl_chart`, 44px, no axes, primary color) — **Price** and/or **Cost** trend (oldest→newest);
   under 2 points shows *"Not enough changes to chart"*.
3. **History rows** (hairline-divided) — per change: **Price ₱X** + delta (`arrow-up` green / `arrow-down` red +
   `₱amount`); **Cost ₱Y** + delta; then a metadata line: **date** (`MMM d, y • h:mm a`) **• who** • **source
   badge** (Created / Manual edit / Receiving / Receiving (RCV-…) / Edit).

**States:** loading (spinner) · error (*"Could not load price history"*) · empty (*"No price changes yet."*).
**Role rules:** admin-only (gated upstream; reached only from the admin price-history link in the form).

---

## What I want  *(fill this in, then hand back)*

Leave anything blank you don't care about. Specifics beat vibes — name the screen + region + the change.

### Direction
- Overall: bring Inventory fully onto the new language (Lucide + `AppCard` soft surfaces), or rethink the layout? →
- Reference apps / catalogs you like the look of →

### Inventory list
- **Summary stats** — keep 4 flat cards, or make them a hero strip / segmented counts? Should they stay tappable filters? →
- **Product row** — what's the hero (name vs price vs stock)? Density (current ~3 lines)? Keep image thumbnail? →
- Price/cost/margin treatment — pills vs plain text; how prominent should margin be? →
- Stock badge — outlined number vs colored pill vs progress-to-reorder? →
- Search + filters — keep chips + category popup, or a filter sheet? Sort UI (menu vs sheet)? →
- Surface: product rows → `AppCard` soft shadow (matches POS)? Summary cards same? →

### Product form
- Long single scroll vs grouped sections/cards (e.g. "Identity · Pricing · Stock · Classification")? →
- Field surfaces — outlined fields vs filled; section headers like sale-detail? →
- Disabled (role-locked) fields — keep `Opacity(0.38)`, or a cleaner locked treatment + reason? →
- Pin the submit button to the bottom (like sale-detail's void), or keep inline? →
- Image uploader / barcodes / audit card — any layout changes? →

### Price history
- Keep sparkline + row list, or a richer chart / timeline? →
- Row layout — Price & Cost side-by-side vs stacked; delta emphasis; source-badge styling →
- Surface — wrap rows in an `AppCard`, or keep flat hairline rows? →

### Constraints / must-keep
- All role-gating (admin/staff/cashier price·cost·SKU·delete·export; `addProduct` perm) must stay →
- Cost visibility = password + 5-min auto-hide; cost-code pill for non-cost viewers →
- SKU-change + delete confirmation dialogs and their copy →
- Barcode multi-code + dedupe; CSV export; pull-to-refresh →
- Dark-theme parity →

---

*Bundles: 01-login-dashboard · 02-pos-checkout · 03-sale-detail · 04-inventory (this). Queued next (per
`ROADMAP.md`): Receiving · Reports · Void Requests · Expenses · Drafts · Settings · Suppliers · Users · Logs —
one bundle at a time.*
