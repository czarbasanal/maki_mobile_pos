# Handoff: Purchase Orders / "Reorder" — MAKI POS (visual redesign)

> ## ⛔ TWO HARD RULES — read `CLAUDE.md` in this bundle before you build
> 1. **Follow the mocks faithfully.** Recreate `MAKI POS Purchase Orders.dc.html` pixel-for-pixel in
>    the existing Flutter codebase — exact tokens, **both light and dark**, Lucide icons. POs have a
>    real status enum, so the four-status color language (draft neutral · ordered amber · received
>    green · cancelled red) is **legitimate semantic color** — but promote the literals to
>    `AppColors` tokens (see Design tokens). Do not improvise, re-color, re-flow, or substitute
>    components/icons/copy.
> 2. **Ask before wiring anything.** These files specify **appearance only**. For any behavior, data,
>    provider, navigation, permission, or money-math that isn't literally drawn, **stop and ask the
>    human.** Do not guess or silently scaffold. Preserve all existing business logic — lifecycle,
>    suggestion math, receiving integration, CSV — change the presentation layer only.

---

## Overview

**Reorder turns stock movement into purchase orders.** A velocity engine
(`velocity = unitsSold(window)/windowDays`, `target = ceil(velocity × coverDays)`,
`suggested = max(0, target − stock)`) drafts what to buy; out-of-stock / low-stock items are offered
as **unchecked** top-ups; anything else can be search-added; Save creates **one draft PO per
supplier**. A PO walks `draft ⇄ ordered → received / cancelled`, ships a **costs-free CSV** to the
supplier, and **Receive** spawns a linked Bulk Receiving draft whose completion atomically closes the
PO. Data lives in Firestore `purchase_orders`.

This bundle is the **approved visual redesign** (2026-07-03) of every Purchase Orders surface,
migrated onto the MAKI POS "elevated" theme. The feature shipped functional-first on Material
defaults; this pass addresses every item in `current-implementation.md` § "Redesign starting points."
Implementation target is the existing Flutter app.

## About the design files

The `.dc.html` file is a **design reference written in HTML** — a prototype of intended look and
layout. **Do not ship the HTML.** Recreate each screen in the Flutter codebase using its established
widgets (`AppCard`, `AppDialog`, `EmptyStateView`, the POS stepper pills, the Job Orders add-parts
sheet pattern / `ProductSearchField`, `app_colors` / `app_text_styles` / `app_shadows`). Where a
Flutter equivalent already exists, reuse it — don't fork a parallel styling system.

Open `MAKI POS Purchase Orders.dc.html` in a browser (it loads `support.js`, included here) to see
the target. Pan the board: light theme on top, dark below.

## Fidelity

**High-fidelity (hifi).** Final colors, type, spacing, radii, elevation, and copy. Recreate the UI
exactly; only translate HTML/CSS constructs into their Flutter equivalents.

## Naming decision (friction point 14)

- Screens say **"Purchase Orders"** (list app bar) / **"New Purchase Order"** (create).
- The **detail app-bar title is the PO reference** in Roboto Mono (`PO-20260703-001`) — the strongest
  identifier; no static "Purchase Order" title.
- The dashboard quick-action pill **keeps "Reorder"** — it names the *action*, not the screen.
- The save button says what it does: **"Create 3 purchase orders"** (live count of supplier groups),
  with the caption "One PO per supplier" — no more "Save drafts" + after-the-fact snackbar surprise.

## What changed vs the current UI (`reference_current-ui.html`)

Mapped to the numbered friction points in `current-implementation.md`:

1. **Flush AppCards → padded cards** (13–14px) with 40px glyph tiles on list cards and detail header.
2. **ChoiceChip triple-duty split:** window presets 30d/60d/90d = **segmented control**; By status /
   By supplier = **segmented control** (the app's mode-toggle pattern); the list status filter =
   restyled pill chips (selected = solid primary fill).
3. **Params density fixed:** one params card = window segmented + a **cover-days stepper** (− 30 +),
   with a plain-language caption. **Applies immediately as changed** — no submit-only trap. ← wiring
   to confirm (see below).
4. **Bare Rows → AppCard rows:** suggestion rows get a 22px rounded checkbox + name + mono SKU +
   caption + **26px stepper pill**; unchecked top-up rows render **dimmed (~60%)**. Detail item rows
   get the Job Orders **qty-badge** (`10x`, primary outline) + stepper **[− · + · ×]** while draft,
   or a neutral qty badge + static "4 pc" when locked.
5. **Wrap action bar → pinned footer**, one primary per status: draft = outlined **Share CSV** +
   filled **Mark ordered** (`send`); ordered = outlined **Back to draft** / **Share CSV** row over a
   full-width filled **"Receive delivery"** (`package-check`). Staged draft edits swap the footer to
   **Save changes / Discard** (same slot, same shape).
6. **Status colors tokenized** — same four-status language, literals promoted to tokens (table below).
7. **Add-product sheet re-patterned** on the Job Orders add-parts sheet: grab handle, "Add products"
   title + "N added this session", `ProductSearchField` with barcode scan, result rows (thumb · name ·
   mono `SKU · N in stock` · add button, already-added rows show an "Added" chip), pinned **Done**.
   **Stays open to accumulate.** ← behavior change, confirm wiring.
8. **Costs stay off the cards — explicit decision:** the CSV to the supplier is cost-free by design,
   so cards/detail show `N items · M pcs`, never ₱. (List search/supplier filter was **not** added —
   raise separately if wanted.)
9. **Machine dates → friendly:** `Jul 3, 9:41 AM` everywhere (list meta, created/ordered lines).
10. **FAB retired:** create moves to an app-bar `plus` on the list (matches Job Orders).
11. **Cap warning → amber-note pattern** ("Movement data may be incomplete — the sales cap was
    reached for this window.").
12. **Empty states tiled:** 86px soft square, `clipboard-list`, "No purchase orders yet", subtitle
    "Suggestions come from your stock movement. Start one to draft what to buy.", filled
    **"New purchase order"** CTA.
13. **Nav-menu icon:** use Lucide `clipboard-list` for `/reorder` (drop `Icons.shopping_cart_checkout`).
14. **Naming unified** (see above).
15. **List error state:** render `ErrorStateView` **with retry** (invalidate `purchaseOrdersProvider`),
    like the drafts/receiving lists.

---

## Screens / views

All frames are a 390-wide phone mock (mock-only chrome: 42px frame radius, status bar, `9:41`).
Ignore the frame; build the screen body. Every screen ships in **both** themes.

### 1 · Purchase Orders list — `purchase_orders_screen.dart` (`/reorder`)
- **App-bar:** back chevron · **"Purchase Orders"** · **`plus`** (→ `/reorder/new`). No FAB.
- **Filter chips** (34px pills, 8px gap): All · Draft · Ordered · Received · Cancelled. Selected =
  solid primary fill (slate/gold) with on-primary text; unselected = card surface + hairline border.
- **PO card (`AppCard`, radius 18, padding 13):**
  - Header row: 40px neutral glyph tile (`clipboard-list`) · **supplier name** (15/600, "No supplier"
    fallback) over the **PO ref** (11 Roboto Mono, secondary) · **status pill** right.
  - Meta row (12, secondary): `4 items · 14 pcs · by Czar` … right-aligned friendly date.
- **Status pill:** 4px/10px padding, radius 999, 12px glyph + 12/600 label — `pencil-line` Draft ·
  `send` Ordered · `package-check` Received · `ban` Cancelled (colors in Design tokens).

### 2 · Empty state — `EmptyStateView(tiled: true)`
- 86px soft square (`clipboard-list` 40, muted), **"No purchase orders yet"** (17/600), subtitle
  (max ~260px), filled **"New purchase order"** button (`plus`).

### 3 · New Purchase Order — `new_purchase_order_screen.dart` (`/reorder/new`)
- **App-bar:** back · "New Purchase Order" · **`search`** (opens the add-products sheet).
- **Params card (`AppCard`, radius 16):** 3-cell segmented **30d / 60d / 90d** + cover-days stepper
  (30px − / + buttons around `30` over a tiny `COVER` label). Caption below: *"Suggesting **30 days
  of stock** from the last **60 days** of sales — applies as you change it."*
- **View toggle:** full-width 2-cell segmented **By status** (`layers`) / **By supplier** (`truck`);
  selected cell = primary tint. Grouping only — selection & quantities carry over.
- **Cap note (conditional):** amber note pattern with `triangle-alert`.
- **Sections:** header = 16px icon + 13/600 label + right count — `trending-up` Recommended ·
  `package-x` Out of stock · `package-minus` Low stock · `circle-plus` Added. (Supplier view: same
  rows grouped by supplier name, alphabetical, "No supplier" last.)
- **Suggestion row (`AppCard`, radius 16, padding 10/12):** 22px checkbox (radius 7; checked = solid
  primary + white/ink check; unchecked = 1.5px border, row content + stepper dimmed to ~60%) ·
  name (14.5/600) + **SKU** (11 mono) + caption (12, secondary) · stepper (26px [−] qty [+], minus
  disabled at 1). Captions by bucket: `Stock 4 · 0.4/day` (recommended) · `Stock 0 · reorder at 5`
  (out/low) · `Stock 7 · added manually` (added).
- **Footer (pinned):** summary line `4 items checked · 15 pcs` ↔ `One PO per supplier`, then
  full-width filled **"Create 3 purchase orders"** (`clipboard-plus`, 52px). Disabled when nothing
  is checked.

### 4 · Add-products sheet — Job Orders add-parts pattern
- Grab handle · **"Add products"** + "N added this session" · search field (`search` · text · caret ·
  `scan-barcode`) · scrollable results (40px thumb placeholder · name · mono `SKU · N in stock` ·
  30px filled `plus`; already-added rows show a tinted **"Added"** chip instead) · pinned right
  **Done**. **Stays open**; adds accumulate into the Added section, checked.

### 5 · Detail — draft — `purchase_order_detail_screen.dart` (`/reorder/:id`)
- **App-bar:** back · **PO ref in Roboto Mono** (15/600) · `ellipsis-vertical` overflow (Cancel —
  draft/ordered; Delete — admin only).
- **Header card (`AppCard`, radius 18, padding 14):** 40px `truck` tile · supplier (15/600) + PO ref
  (11 mono) · status pill; hairline; then meta lines (12.5, secondary): `clock` "Created Jul 3,
  9:41 AM · by Czar", plus `send` "Ordered …" / `package-check` "Received …" when set.
- **Items:** section header `package` "Items" + right `3 items · 16 pcs`. Row = qty badge (40px,
  1.4px primary outline, "10x") · name + mono SKU · stepper **[− · + · ×]** (26px). Removing the
  last item stays blocked ("Last item — delete the purchase order instead").
- **Footer (pinned):** outlined **Share CSV** (`share-2`) + filled **Mark ordered** (`send`).
  With staged edits: **Save changes** (filled) + **Discard** (outlined) in the same slot.

### 6 · Detail — ordered
- Header card adds the "Ordered Jul 3, 2:10 PM" line; pill = Ordered (amber).
- Items locked: neutral qty badge (tint fill, secondary text) + static `4 pc` right.
- **Footer:** outlined **Back to draft** (`undo-2`) / **Share CSV** row, then full-width filled
  **"Receive delivery"** (`package-check`, 52px). Received-with-receiving adds "View receiving"
  (outlined) in the secondary row; cancelled collapses the footer.

### 7 · Cancel confirmation — `showAppConfirmDialog`
- Destructive `AppDialog`: red-tint chip (`ban`), **"Cancel this purchase order?"**, body
  "`PO-20260703-002` (mono) will be marked cancelled.", red warning `triangle-alert` **"Its
  in-progress receiving draft will be cancelled too."** (only when a receiving draft is linked;
  otherwise the default "This action cannot be undone."), actions: text **"Keep"** + filled-red
  **"Cancel order"**. Delete confirm mirrors this with `trash-2` / "Delete this purchase order?" /
  "will be permanently removed." / **"Delete"**.

---

## Interactions & behavior — CONFIRM WIRING BEFORE IMPLEMENTING (Rule 2)

Recreate the visuals now; **ask the human to confirm each of these** before hooking up logic.
Details of the *current* wiring are in `current-implementation.md` — reuse it, don't reinvent.

- **Cover-days stepper applies immediately:** the mock removes the submit-only `TextField`. Confirm
  recompute-on-change (debounced?) against `reorderSuggestionsProvider((windowDays, coverDays))` —
  the family key is a value-equal record, so param changes re-fetch. Confirm the 1–365 clamp stays.
- **"Create N purchase orders" live count:** button label = number of supplier groups among checked
  lines (no-supplier lines form their own group). Confirm it reuses the exact `_save` grouping.
- **Add-products sheet stays open** (was: closes per pick). Confirm accumulate behavior + barcode
  scan via the existing `productByBarcodeProvider` path, mirroring the Job Orders `_AddPartsSheet`.
- **App-bar `plus` replaces the FAB** → `push('/reorder/new')`; empty-state CTA does the same.
- **List retry:** `ErrorStateView(onRetry: invalidate purchaseOrdersProvider)`.
- **Filter chips** stay client-side over the streamed list.
- **Detail overflow menu** unchanged: Cancel (`canCancel`), Delete (admin-only, any status).
- **Receive** keeps the idempotent `startReceiving` flow (existing linked draft → navigate to it);
  completion marks the PO received atomically. Don't touch.
- **Cancel / revert / delete cleanup invariant** (linked receiving draft cancelled + `receivingId`
  cleared in the same batch) is business logic — presentation change only.
- **Nav-menu metadata:** swap `Icons.shopping_cart_checkout` → Lucide `clipboard-list` (route_guards
  nav item). Icon-only change; confirm nothing else reads that metadata.
- **Permissions** unchanged: everything behind `Permission.accessReceiving`; Delete admin-only.
- **Costs:** never shown on these screens; CSV stays `SKU, Name, Qty, Unit` — no costs.

## State management

See `current-implementation.md` § "State management (Riverpod)" for the exact providers
(`purchaseOrdersProvider`, `purchaseOrderProvider(id)`, `reorderSuggestionsProvider(params)`,
`ReorderResult`, the 10k `reorderSalesCap`). **Do not change provider wiring without asking.**

## Design tokens

**Status pill — promote these to `AppColors` tokens (friction point 6).** Suggested names shown;
match the codebase's naming convention.

| Status | Icon | Text light / dark | Tint light / dark | Suggested tokens |
|---|---|---|---|---|
| Draft | `pencil-line` | `#6A7378` / `#93A0A3` | `rgba(0,0,0,.08)` / `rgba(255,255,255,.12)` | `poDraftFg/Bg` |
| Ordered | `send` | `#C8881A` / `#F5B547` | `rgba(245,124,0,.12)` / `rgba(245,181,71,.14)` | `poOrderedFg/Bg` |
| Received | `package-check` | `#2E7D32` / `#8FE39A` | `#E8F5E9` / `rgba(76,175,80,.16)` | `poReceivedFg/Bg` |
| Cancelled | `ban` | `#F44336` / `#FF6B5E` | `rgba(244,67,54,.10)` / `rgba(255,107,94,.14)` | `poCancelledFg/Bg` |

**Color — light / dark** (same base palette as the Job Orders bundle)
| Token | Light | Dark |
|---|---|---|
| App canvas | `#F6F5F3` | `#0C1415` |
| Card surface | `#FFFFFF` | `#18262A` (+1px border `#243234`) |
| Recessed / field | `#FAFAFA` (border `#E2E2E2`) | `#0C1415` (border `#2C3C3E`) |
| Primary (leads) | slate `#283E46` | gold `#E8B84C` |
| On-primary | `#FFFFFF` | `#121C1D` |
| Text | `#16201F` | `#ECEFEF` |
| Text secondary | `#8A9296` | `#93A0A3` |
| Hint / tertiary | `#9AA0A3` | `#6C797C` |
| Hairline / divider | `#ECECEC` · `#F0F0F0` | `#243234` · `#223032` |
| Checkbox border (off) | `#C9CFD2` | `#3A4A4D` |
| Destructive | `#F44336` (dark dialog keeps `#F44336` fill, fg `#FF6B5E`) | `#FF6B5E` |
| Amber note | bg `#FBF3DE` / border `rgba(183,131,26,.32)` / text `#7A6320`, icon `#9A7B1F` | bg `rgba(232,184,76,.10)` / border `rgba(232,184,76,.28)` / text `#D8B15A`, icon `#E8B84C` |

**Elevation** — Light: card `0 2px 8px rgba(17,28,29,.06)`; footer `0 -4px 16px rgba(17,28,29,.06)`;
primary button `0 8px 20px -6px rgba(40,62,70,.5)`; dialog `0 26px 60px -18px rgba(17,28,29,.42),
0 6px 16px rgba(17,28,29,.07)`; sheet `0 -10px 36px rgba(17,28,29,.22)`. **Dark:** surfaces use the
1px `#243234` border instead of a shadow; footer `0 -4px 16px rgba(0,0,0,.4)`; primary button
`0 8px 20px -6px rgba(232,184,76,.45)`; dialog `0 26px 70px -18px rgba(0,0,0,.78)`.

**Radius** — card 18 · row card / params 16 · segmented & fields & note 12–14 · qty badge 10–11 ·
checkbox 7 · stepper buttons 8–9 · status pill & filter chips 999 · dialog 24 · sheet top 24 ·
buttons 16.

**Type** — **Figtree** 400/500/600/700 (UI); **Roboto Mono** 500/600 (SKUs, **PO references**,
codes — including the detail app-bar title). List title 18/600 · detail app-bar ref 15/600 mono ·
card title 15/600 · PO ref 11 mono · meta 12 · section label 13/600 · row name 14.5/600 · SKU 11
mono · caption 12 · qty 14.5/700 · pill 12/600 · segmented 13–13.5 · footer summary 12.5 · buttons
14–15/600 · dialog title 18/600.

**Currency** — not rendered on these screens (deliberate). If ever added: `₱1,430.00`.

## Assets

- **Icons — Lucide** (stroke 1.75; 2+ only on tiny/emphasis glyphs). Used: `chevron-left`, `plus`,
  `minus`, `x`, `check`, `search`, `scan-barcode`, `clipboard-list`, `clipboard-plus`, `truck`,
  `layers`, `trending-up`, `package`, `package-x`, `package-minus`, `package-check`, `circle-plus`,
  `pencil-line`, `send`, `ban`, `undo-2`, `share-2`, `clock`, `ellipsis-vertical`, `triangle-alert`
  (+ status-bar `signal-high` / `wifi` / `battery-full`). Map to the codebase's Lucide equivalents.
- **Fonts — Google Fonts:** Figtree, Roboto Mono. Use the app's bundled equivalents.
- No raster assets; product thumbnails are placeholders — use the app's real product images.

## Files in this bundle

- **`MAKI POS Purchase Orders.dc.html`** — the approved redesign (light + dark). Open in a browser.
- **`support.js`** — runtime required by the `.dc.html`.
- **`reference_current-ui.html`** — the as-shipped (pre-redesign) UI, for before/after only. Do not
  rebuild.
- **`current-implementation.md`** — real Dart file paths, routes, Riverpod providers, lifecycle,
  data model, CSV format, permissions, and the 15 redesign starting points. Your map to the code.
- **`CLAUDE.md`** — the two hard rules, verbatim.
