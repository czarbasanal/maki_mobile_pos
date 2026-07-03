# Handoff: Job Orders — MAKI POS (visual redesign)

> ## ⛔ TWO HARD RULES — read `CLAUDE.md` in this bundle before you build
> 1. **Follow the mocks faithfully.** Recreate `MAKI POS Job Orders.dc.html` pixel-for-pixel in the
>    existing Flutter codebase — exact tokens, **both light and dark**, Lucide icons, neutral-by-default
>    color discipline. Do not improvise, re-color, re-flow, or substitute components/icons/copy.
> 2. **Ask before wiring anything.** These files specify **appearance only**. For any behavior, data,
>    provider, navigation, permission, or money-math that isn't literally drawn, **stop and ask the
>    human.** Do not guess or silently scaffold. Preserve all existing business logic; change the
>    presentation layer only.

> **Status (2026-07-03): this redesign has been IMPLEMENTED and merged** (commits `37fb818`,
> `d768129`, badge fix `1ab4597`). `current-implementation.md` now documents the shipped
> post-redesign UI and is the source of truth for behavior/wiring; `reference_current-ui.html`
> was regenerated 2026-07-03 and previews the shipped post-redesign UI (light mode).

---

## Overview

**Job Orders are motorcycle-service tickets.** The feature repurposes the existing **Drafts** feature:
internally everything is still named `draft`/`Draft` (entity, repository, providers, routes, Firestore
collection `drafts`), while all user-facing copy says **"Job Order."** An open ticket carries **parts,
labor lines, an assigned mechanic, and a motorcycle model**, and is eventually **"billed out"** into a
Sale (non-destructively — the ticket survives an abandoned checkout).

This bundle is the **approved visual redesign** of every Job Order surface, migrated onto the MAKI POS
"elevated" theme. Implementation target is the existing Flutter app.

## About the design files

The `.dc.html` files are **design references written in HTML** — prototypes of intended look and layout.
**Do not ship the HTML.** Recreate each screen in the Flutter codebase using its established widgets
(`AppCard`, `AppDialog`, `EmptyStateView`, `ListSkeleton`, `app_colors` / `app_text_styles` /
`app_shadows`, the shared `ProductSearchField`, `MechanicPicker`, `MotorcycleModelPicker`, etc.). Where a
Flutter equivalent already exists, reuse it — don't fork a parallel styling system.

Open `MAKI POS Job Orders.dc.html` in a browser (it loads `support.js`, included here) to see the
target. Pan the board: light theme on top, dark below.

## Fidelity

**High-fidelity (hifi).** Final colors, type, spacing, radii, elevation, and copy. Recreate the UI
exactly; only translate HTML/CSS constructs into their Flutter equivalents.

## What changed vs the pre-redesign UI (historical — `reference_current-ui.html` now shows the shipped UI)

- **Cupertino glyphs → Lucide** everywhere (uniform stroke width **1.75**).
- **Material `Card` item rows → soft-shadow `AppCard`s** (light) / 1px-border surfaces (dark).
- **POS toolbar badge re-iconed:** `shopping-cart` → **`clipboard-list`**, meaning "open job-order
  count." This fixes the read where the badge looked like a stuck cart count. **← wiring to confirm (see
  below).**
- **Motorcycle model surfaced:** a model chip on each list card and a model line in the editor header
  (the model is the bill-out gate).
- **Neutral-by-default color discipline:** job orders have no status, so no invented status colors.
- **Full light + dark parity** (slate leads light, **gold leads dark**).
- **Floating "New Job Order" FAB removed** at the designer's request. The empty state keeps its centered
  "New Job Order" button. **Resolved:** the populated list's create entry point shipped as a `plus`
  app-bar action (`drafts_list_screen.dart:30-34`).

---

## Screens / views

All frames are a 390-wide phone mock (mock-only chrome: 42px frame radius, status bar, `9:41`). Ignore
the frame; build the screen body. Every screen ships in **both** themes.

### 1 · POS entry point (context only)
- **Purpose:** shows where Job Orders is reached from POS; not a Job Orders screen itself.
- **Layout:** elevated white/`#121C1D` app-bar band with a bottom footer bar.
- **Components:** app-bar — back chevron, title "Point of Sale", right cluster = **`clipboard-list` icon
  with a badge** (`3`) + destructive `trash-2` (clear cart). Footer — outlined **"Save Job Order"**
  (`clipboard-plus`) + filled **"Checkout"** (`arrow-right`). An amber note calls out the badge fix.
- **Badge:** slate `#283E46` (light) / gold `#E8B84C` (dark) pill, 2px canvas ring, white/ink text.
  *(Shipped deviation: the user chose a **red pill with white count** in both themes —
  `job_order_badge_button.dart`.)*

### 2 · Job Orders list — `drafts_list_screen.dart` (`/drafts`)
- **Purpose:** browse open tickets, open one, delete (creator/admin).
- **Layout:** app-bar (back · "Job Orders" · `refresh-cw`) over a scrolling column of ticket cards,
  16px side padding, 12px gap.
- **Ticket card (`AppCard`, radius 18):**
  - Header row: 40px neutral glyph tile (`clipboard-list`), title (customer/plate, 15/600, ellipsized),
    relative date (12, secondary); right column = **grand total** (15/700, primary color) + item count.
  - Recessed preview box (radius 14): a **"Service job"** chip (`wrench`, primary outline) when labor
    exists, then a neutral **model chip** (`bike`), then up to 3 part rows (`name  ×qty  gross`), then
    "+N more items" (italic).
  - Footer: "By {name}" (secondary) · optional destructive `trash-2` (creator/admin only) · filled
    **"Open"** pill (`arrow-right`).
- **Data shown:** Juan / ABC-123 (₱1,430.00, 4 items) · Maria / Click 125i (₱4,120.00, 5 items) ·
  Walk-in / XRM 125 (₱360.00, 1 item, parts-only, no service chip). Sample data — replace with real.

### 3 · Empty state — `EmptyStateView`
- 86px soft square with `clipboard-list` (40, muted), **"No job orders yet"** (17/600), subtitle
  "Tap New Job Order to open a ticket for a bike being serviced." (max 250), filled **"New Job Order"**
  button (`plus`). No FAB.

### 4 · New Job Order dialog — `new_job_order_dialog.dart` (`AppDialog`)
- **Purpose:** create a ticket.
- **Header:** primary-tint chip (`clipboard-list`) + "New Job Order".
- **Fields (floating-label, radius 14):**
  - **Customer / plate** — text, required. Shown active (primary border + caret; **no focus glow**).
    Hint "e.g. Juan / ABC-123"; becomes `draft.name`.
  - **Motorcycle model** — picker (`bike`, `chevron-down`). Optional at create, **required at bill-out.**
  - **Mechanic** — picker (`wrench`), optional ("— Optional —").
- **Actions:** text "Cancel" + filled "Create".

### 5 · Job order editor — `draft_edit_screen.dart` (`/drafts/:id`)
- **Purpose:** work the ticket — parts, labor, mechanic; then bill out.
- **App-bar:** back · ticket name (ellipsized) · destructive `trash-2`.
- **Info header (band, bottom hairline):** **model line** (`bike`, 13.5/600, primary — it's the bill-out
  gate), then "Created …" (`clock`) and "Updated …" (`square-pen`), 12.5 secondary.
- **Parts section:** header `package` "Parts" + primary text button **"Add parts"** (`plus`). Each part
  is an `AppCard` (radius 16): primary-outline **qty badge** ("2x", 40px), name (14.5/600), **SKU** (11
  Roboto Mono), "₱320.00 each" (12); right = **line total** (14.5/700) over a compact stepper
  **[− · + · ×]** (26px outline icon buttons).
- **Labor & Service band:** header `wrench` "Labor & Service" + **"Add Labor"**. A **Mechanic** picker
  field, then labor rows (`AppCard`, `wrench` · description · fee · `x`).
- **Summary (pinned footer):** Subtotal · "Labor (N services)" · **Total (N items)** over a total
  hairline · full-width filled **"Bill out"** (`shopping-cart`). (Discount row is green when present.)
- **Sample math:** parts ₱1,080.00 + labor ₱350.00 = **₱1,430.00**, 4 items, 2 services.

### 6 · Add-parts bottom sheet — reuses POS `ProductSearchField`
- Sheet has a **fixed height with a scrollable results panel** so results always have room. Grab handle,
  "Add parts" title, search field (`search` + placeholder "Search name, SKU, or scan barcode" +
  `scan-barcode`), then result rows (thumbnail · name · **SKU · N in stock** in mono · price · filled
  **`plus` add** button). Right-aligned "Done" pinned at the bottom. Sheet **stays open** so several
  parts accumulate; "Done" dismisses.

### 7 · Delete confirmation — `draft_dialogs.dart` (destructive `AppDialog`)
- Red-tint chip (`trash-2`), **"Delete job order?"**, body `Delete "{name}"?`, recessed box with item
  count + "Total {grandTotal}", red **"This action cannot be undone."** (`triangle-alert`), text "Cancel"
  + filled-red "Delete".

### 8 · Reports — `job_order_reports_screen.dart` (`/reports/job-orders`, admin only)
- App-bar (back · "Job Orders" · `download` CSV). Date bar = **"This month"** preset pill + range pill.
- **Segmented control Models / Mechanics** — selected segment uses a **primary tint** (not green; green
  is reserved for discounts).
- Rows (`AppCard`): 38px `bike` glyph · model name · "N jobs" · revenue (15/700, primary). Sample:
  Nmax 7 · Click 125i 5 · XRM 125 3 · Mio i 125 2.

---

## Interactions & behavior — CONFIRM WIRING BEFORE IMPLEMENTING (Rule 2)

Recreate the visuals now; **ask the human to confirm each of these** before hooking up logic. Details of
the *current* wiring are in `current-implementation.md` — reuse it, don't reinvent.

- **List data / refresh:** what stream feeds the list, loading (`ListSkeleton`) / error (`ErrorStateView`
  + retry) / empty states, pull-to-refresh invalidation.
- **Create entry point:** the FAB was removed — decide/confirm how a new job order is started from the
  populated list (see "What changed").
- **New Job Order → editor:** create then immediately push the editor.
- **Editor persistence:** every edit persists immediately via the full `updateDraft` path (must not drop
  labor). Confirm.
- **Add-parts / barcode:** search + `productByBarcodeProvider` scan; sheet stays open.
- **Bill out:** guard that a **motorcycle model is set**; "Register in use" confirm if the cart is
  non-empty; load into cart, keep the ticket, navigate to `/checkout`; conversion is marked only when the
  sale is written.
- **POS badge:** bind the `clipboard-list` badge to the **live open-job-order count** (the
  `activeDrafts` stream length), **not** a cached one-shot count (this was the known stale-count bug).
  **Resolved:** shipped as a derived stream count in `1ab4597` (`draft_provider.dart:67-69`).
- **Delete:** restricted to creator/admin.
- **Reports:** admin-only route; derived from **completed (billed-out) sales**; CSV export; date-range
  presets; Models vs Mechanics.
- **Money math:** reuse the existing `DraftEntity` computations (`subtotal`, `laborSubtotal`,
  `grandTotal`, …). Labor is never discounted.

## State management

See `current-implementation.md` (§ "State management (Riverpod)") for the exact providers
(`activeDraftsProvider`, `draftByIdProvider`, `draftOperationsProvider`, cart `loadFromDraft`/`toSale`,
report providers, pickers) and the **known stale-badge bug + fix**. **Do not change provider wiring
without asking.**

## Design tokens

**Color — light / dark**
| Token | Light | Dark |
|---|---|---|
| App canvas | `#F6F5F3` | `#0C1415` |
| Card surface | `#FFFFFF` | `#18262A` (+1px border `#243234`) |
| Recessed / preview / field | `#FAFAFA` (border `#ECECEC`) | `#0C1415` (border `#2C3C3E`) |
| Primary (leads) | slate `#283E46` | gold `#E8B84C` |
| On-primary | `#FFFFFF` | `#121C1D` |
| Text | `#16201F` | `#ECEFEF` |
| Text secondary | `#8A9296` | `#93A0A3` |
| Hint / tertiary | `#9AA0A3` | `#6C797C` |
| Hairline / divider | `#ECECEC` · `#F0F0F0` | `#243234` |
| Total hairline | `#E5E3DE` | `#243234` |
| Destructive | `#F44336` | `#FF6B5E` |
| Discount (reserved) | `#2E7D32` | `#4CAF50` |
| Amber note | bg `#FBF3DE` / border `rgba(183,131,26,.32)` / text `#7A6320` | bg `rgba(232,184,76,.10)` / border `rgba(232,184,76,.28)` / text `#D8B15A` |

**Elevation** — Light: card `0 2px 8px rgba(17,28,29,.06)`; app-bar `0 2px 10px rgba(17,28,29,.05)`;
footer `0 -4px 16px rgba(17,28,29,.06)`; primary button `0 8px 20px -6px rgba(40,62,70,.5)`; dialog
`0 26px 60px -18px rgba(17,28,29,.42), 0 6px 16px rgba(17,28,29,.07)`; sheet `0 -10px 36px
rgba(17,28,29,.22)`. **Dark:** surfaces use the 1px `#243234` border instead of a shadow; primary button
`0 8px 20px -6px rgba(232,184,76,.45)`; dialog `0 26px 70px -18px rgba(0,0,0,.78)`; sheet `0 -10px 40px
rgba(0,0,0,.6)`.

**Radius** — card 18 · inner card / list row 16 · recessed & fields & mini buttons 14 · qty badge 10–11 ·
chips 8 · dialog 24 · sheet top 24 · primary buttons / FAB 16 · "Open" pill 14 · app-bar icon circles 999.

**Type** — **Figtree** 400/500/600/700/800 (UI); **Roboto Mono** 500/600 (SKUs, IDs, codes). App-bar
title 18/600 · section label 13/600 · card title 15/600 · card meta 12 · total 15/700 · item name
14.5/600 · SKU 11 mono · "each" 12 · line total 14.5/700 · dialog title 18/600 · field label 11.5 ·
field value 15 · button 14.5–15/600 · summary total 18/700 · report value 15/700.

**Currency** — grouped, two decimals, ₱ prefix: `₱1,430.00`.

## Assets

- **Icons — Lucide** (stroke 1.75; heavier only on tiny/emphasis glyphs). Used: `chevron-left`,
  `clipboard-list`, `clipboard-plus`, `trash-2`, `shopping-cart`, `arrow-right`, `refresh-cw`, `plus`,
  `minus`, `x`, `wrench`, `bike`, `package`, `clock`, `square-pen`, `search`, `scan-barcode`,
  `calendar-days`, `calendar`, `chevron-down`, `download`, `triangle-alert`, `badge-check` (+ status-bar
  `signal-high` / `wifi` / `battery-full`). Map to the codebase's Lucide equivalents.
- **Fonts — Google Fonts:** Figtree, Roboto Mono. Use the app's bundled equivalents.
- No raster assets; product thumbnails are placeholders — use the app's real product images.

## Files in this bundle

- **`MAKI POS Job Orders.dc.html`** — the approved redesign (light + dark). Open in a browser to view.
- **`support.js`** — runtime required by the `.dc.html`.
- **`reference_current-ui.html`** — as-built preview of the **shipped post-redesign UI** (regenerated
  2026-07-03; light mode, self-contained, 9 panels). The pre-redesign version it replaced lives in git
  history (`a58fafd`) for before/after comparison.
- **`current-implementation.md`** — real Dart file paths, routes, Riverpod providers, data model,
  permissions. Rewritten 2026-07-03 against the shipped post-redesign UI (`16280ad`); the stale-badge
  bug it used to describe is fixed. Your map to the code to change.
- **`CLAUDE.md`** — the two hard rules, verbatim.
