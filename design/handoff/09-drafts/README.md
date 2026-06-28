# Bundle 09 — Drafts

Mobile Flutter restyle. **This folder is the *current* state, for hand-off to Claude Design.**
`reference_current-ui.html` is a token-accurate reconstruction of what ships today (open it in a browser).
Mark up / redesign on top of it and drop the redesigned hand-off file back here.

## Scope (2 screens + shared widgets, 5 states/surfaces)

| # | Surface | Source |
|---|---------|--------|
| 1 | **Saved Drafts** list (`/drafts`) | `lib/presentation/mobile/screens/drafts/drafts_list_screen.dart` + `widgets/drafts/draft_list_tile.dart` |
| 2 | **Empty** state | same (`EmptyStateView`) |
| 3 | **Detail** bottom sheet (tap a row) | `widgets/drafts/draft_detail_sheet.dart` (`DraggableScrollableSheet`) |
| 4 | **Draft editor** (`/drafts/:id`) | `lib/presentation/mobile/screens/drafts/draft_edit_screen.dart` (items, labor/mechanic, summary, Edit-in-POS / Checkout) |
| 5 | **Delete / Replace-cart** confirm dialogs | both screens (`AlertDialog`) |

Reached from the POS screen (Saved Drafts) and an active-drafts badge. Shared widgets reused: `MechanicPicker`
(already Lucide), `SummaryRow`, `EmptyStateView`, `LoadingView`/`LoadingOverlay`.

## Current state — what's not migrated

The list rows (`DraftListTile`) and the detail sheet (`DraftDetailSheet`) are **already on soft-shadow Material
`Card`s** with theme-aware hairlines / muted fills — visually close to the target — but the editor's item rows are
**raw Material `Card`s**, and **nothing uses `AppCard`**. **Every icon is still Cupertino**
(`doc_text`, `cart_badge_plus`, `trash`, `wrench`, `clock`, `pencil`, `xmark`, `refresh`, `tag`, `person`, `calendar`,
`cube_box`…). The single already-migrated piece is the shared `MechanicPicker` dropdown (Lucide `wrench`). Drafts have
**no status**, so there is **no status color semantics** to add — color is limited to the slate primary (total, qty
badge, service-job badge, Load) and success-green (discount / labor). This bundle = Cupertino→Lucide + Material
`Card`→`AppCard` + dark parity, keeping the neutral discipline.

## States & rules to preserve (don't design these away)

- **List row** (`DraftListTile`) = one draft: leading doc glyph, `{name}` + `{updatedAt ?? createdAt}` (`MMM d, h:mm a`),
  right-aligned `{grandTotal}` (slate) + `{n} item(s)`; a **items-preview box** (muted fill) showing up to 3 items
  (`{name} ×{qty} {grossAmount}`) with a **"Service job"** outlined badge when `laborLines` is non-empty and a
  `+N more item(s)` overflow line; footer `By {createdByName}` + **trash** (permission-gated) + **Load** filled button.
  Newest first.
- **Load is destructive (consume-on-load):** loading a draft into the cart **immediately deletes it** from the
  collection (re-saving creates a new entry; the active-drafts badge decrements via stream). If the cart is **non-empty**,
  prompt **Replace Cart?** ("current cart has N item(s)… will replace them") before loading.
- **Delete permission:** trash is shown only when the user is **admin OR the draft's creator** (mirrors
  `firestore.rules`). Confirm dialog shows an item-count + total preview box and "This action cannot be undone"; the
  Delete action is `error`-colored. Success/error snackbars on completion.
- **Detail sheet** (`DraggableScrollableSheet`, 0.7 initial): doc glyph + `{name}` + long date
  (`EEEE, MMMM d, y • h:mm a`) + close; sections **Items (n)** (qty badge, `{sku} • {unitPrice} / {unit}`, per-item
  discount with strike-through gross + green net), **Summary** (Subtotal, Discount, per-labor-line + Labor subtotal,
  Total), **Information** (Created by, Mechanic if set, Created, Last updated, Items `n (m products)`), optional
  **Notes**; pinned footer = icon-only **Delete** (error-outlined) + **Load into Cart** (filled).
- **Draft editor** (`/drafts/:id`): app bar `{name}` + trash; info header (Created / Updated rows, optional notes);
  scrollable **item rows** (outlined qty badge `{qty}x`, name, `SKU: {sku}`, `{unitPrice} each`, right `grossAmount`);
  **Labor & Service** band — `MechanicPicker` dropdown + **Add Labor** + tappable labor lines (`{description}` /
  `{fee}` / remove ✕); **summary** (Subtotal, Discount if >0, Labor if any, Total `(n items)`) + **Edit in POS**
  (outlined) and **Checkout** (filled, 2× width). Both bottom actions are **disabled when `items` is empty** and both
  **consume the draft** (load into cart + delete) before navigating.
- **Labor/mechanic editing** persists through the **full `updateDraft`** path (never `updateDraftItems`, which writes
  only `items` and would drop labor). Labor line dialog requires a **non-empty description** and a **fee > 0**.
- **Totals math:** `grandTotal = subtotal − totalDiscount + laborSubtotal`; discount renders green and signed
  (`-₱…`); discount type (percentage / amount) drives per-item `{value}% off` vs `{value} off`.
- **Empty state:** envelope icon + "No Saved Drafts" + "Drafts you save from the POS screen will appear here." +
  **Go to POS** CTA. Loading = `LoadingView`; error = `ErrorStateView` with retry.
- Currency grouped `₱1,234.00` via the app formatter; SKUs in mono.

## Target language

Global theme tokens at `design/handoff/maki-theme/` + the patterns shipped in bundles 01–08: soft-shadow `AppCard`
rows (replace the Material `Card`s in the editor; align the already-`Card`-based list/sheet to `AppCard`), Lucide icons
(`file-text` doc, `wrench`, `cart`/`shopping-cart`, `trash-2`, `square-pen` for edit/pencil, `clock`, `x`,
`refresh-cw`, `plus`, `user`, `calendar`, `box`), neutral-by-default discipline — color only for the slate primary
affordances and success-green discount/labor — with **dark parity** (reuse `AppColors` + their `*OnDark` variants and
`darkHairline`/`darkSurfaceMuted`). No new status colors (drafts have no state). App bar stays flat on canvas. The
detail sheet's item/summary breakdown should visually match the redesigned **Sale Detail** (bundle 03).
