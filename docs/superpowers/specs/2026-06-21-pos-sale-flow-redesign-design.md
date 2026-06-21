# POS Sale-Flow Redesign (Bundle 02) — Design

**Date:** 2026-06-21
**Surface:** Flutter mobile app (`lib/presentation/mobile/screens/pos/…`)
**Source of truth:** `~/Downloads/design_handoff_pos_checkout/` (`MAKI POS Checkout.dc.html`, `README.md`, `screenshots/`)
**Predecessor:** Bundle 01 — Login + Dashboard global-theme redesign (`f54e85e`, local main, not yet pushed/deployed)

## Overview

Bundle 02 brings the **sale flow** — Point of Sale, Checkout, Barcode Scanner, and the
post-sale Success dialog — into the elevated global theme established on Login + Dashboard.
Flat hairline cards become **soft-shadow surfaces**, **Total** and **Change** become the hero
numbers, **Lucide** icons replace Cupertino, payment methods become **pill chips**, and each
screen keeps **one pinned primary action** for one-handed use. Light and dark are both in scope.

This is **almost entirely a visual restyle.** The structure, totals math, all five payment
methods (incl. Mixed/Salmon split math), role-gating, drafts, and the product-search dropdown
already exist and work. What changes is the skin: surfaces, icons, spacing, radii, shadows, and
a few hero promotions. No providers, repositories, Firestore writes, or `firestore.rules` are
touched.

## Scope

In scope (full handoff bundle, light + dark):

1. **POS** — `lib/presentation/mobile/screens/pos/pos_screen.dart`
   - incl. the **product-search dropdown** (`widgets/pos/product_search_field.dart`, restyle only — behavior preserved)
   - `widgets/pos/cart_item_tile.dart`, `cart_summary.dart`, `labor_line_tile.dart`, `mechanic_picker.dart`
2. **Checkout** — `screens/pos/checkout_screen.dart` + `widgets/pos/payment_section.dart`
3. **Barcode Scanner** — `screens/pos/barcode_scanner_screen.dart`
4. **Success dialog** — `widgets/pos/checkout_success_dialog.dart`

Out of scope: web admin POS; any non-sale-flow screen; app-wide icon migration (sale-flow files
only); `receipt_widget.dart`, `void_sale_dialog.dart`, `request_void_dialog.dart` (not in the
handoff — left as-is); the print stub stays a stub.

## Decisions

- **Shared `AppCard` primitive** for the soft-shadow surface (chosen over inlining per-widget).
- **Minimal testing:** keep the existing suite green, update the Cupertino→Lucide icon matchers,
  rely on **manual on-device verification** for the visual result. No new behavior or golden tests.
  (Rationale: colors/shadows/radii are not meaningfully unit-testable; the underlying behavior is
  already covered by existing provider/widget tests.)
- **Icon migration is sale-flow-scoped** — only the files listed above move off Cupertino.
- **Branch + local-merge, no deploy.** UI-only; follows bundle 01 (merge to local `main`, leave
  push/deploy and APK install to the user — see [[project_mobile_release]]).

## Design tokens

Identical to bundle 01 — **do not invent new tokens.** They already exist and match the handoff:

- Colors: `lib/core/theme/app_colors.dart` — `brandSlate #283E46` (light primary), `primaryAccent
  #E8B84C` (dark/gold), `lightCanvas #F6F5F3` / `darkCanvas #0C1415`, `lightCard #FFFFFF` /
  `darkCard #18262A`, `lightHairline #ECECEC` / `darkHairline #243234`, `success #4CAF50` /
  `successLight #E8F5E9` / `successDark #2E7D32`, `gcashPayment #007DFE`, `warning`, `error`.
- Shadows: `lib/core/theme/app_shadows.dart` — `card()`, `hero()`, `pinnedHeader()`,
  `primaryButton` / `primaryButtonGold`, `focusRing()`. Each takes `dark:` and returns the
  light/dark variant (dark cards use `[]` + a 1px border instead of a shadow).
- Radii: `lib/core/theme/app_spacing.dart` `AppRadius` — `md 14`, `field 16`, `lg 18`, `hero 22`,
  `xl 24`, `pill 999`. Spacing `AppSpacing` xs/sm/md/lg/xl.
- Type: Figtree (primary), Roboto Mono (`fontFamily: 'monospace'`) for sale #, SKU, cost code.

### Confirm-button green shadow (new)

The handoff specifies a green glow under the Confirm Payment button:
`0 8px 20px -6px rgba(76,175,80,.5)` (light) / `.45` (dark). Add a `confirmButton({bool dark})`
entry to `AppShadows` mirroring the existing `primaryButton` shape, so it lives with the other
button shadows rather than being inlined.

## Shared primitive: `AppCard`

New widget, `lib/presentation/shared/widgets/common/app_card.dart` (exported from
`common_widgets.dart`).

**Contract:**
- Light: `color: lightCard`, `boxShadow: AppShadows.card()`, no border.
- Dark: `color: darkCard`, 1px `darkHairline` border, no shadow.
- Params: `child`, `padding` (default none), `radius` (default `AppRadius.lg` = 18; callers pass
  `AppRadius.xl`/`hero` for dialogs/hero blocks), optional `onTap`, optional `clipBehavior`
  (for the dropdown's list), optional `margin`.
- Derives `isDark` from `Theme.of(context).brightness` internally — callers never re-derive it.

Replaces every Material `Card` and every hand-rolled soft-shadow `Container` in the sale-flow
widgets. The app-bar bottom-shadow surface is **not** `AppCard` — app bars reuse
`AppShadows.pinnedHeader()` directly (see below), matching the dashboard.

## App-bar treatment (POS + Checkout)

Match the dashboard's pinned-surface look: `AppBar(backgroundColor: <surface>, elevation: 0,
scrolledUnderElevation: 0, surfaceTintColor: Colors.transparent)` where surface =
`lightBackground` / `darkBackground`, with the soft bottom shadow supplied by wrapping the bar
in a `PreferredSize` whose container carries `AppShadows.pinnedHeader(dark:)`. Title 18/600.
Scaffold background = `lightCanvas` / `darkCanvas`.

## Screen specs

References below are abbreviated from the handoff README; the `.dc.html` prototype and
`screenshots/` are the visual source of truth for exact placement.

### 1 — POS (`pos_screen.dart`)

Phone = flex column: app bar → scrolling body (canvas bg, padding 14, gap 10) → **pinned action
bar**. Tablet ≥800px keeps the existing 3:2 search-left / cart-right split.

- **App bar:** back `chevronLeft`; title "Point of Sale"; **Drafts** (`inbox` + count badge,
  slate/gold); **Clear Cart** (`trash2`, muted, only when cart non-empty → confirm dialog).
- **Search:** elevated white pill (`AppCard`-style, radius 16, ~50px) — `search` prefix,
  placeholder "Search products or scan barcode…", clear `x` suffix once typing, and a **filled
  34px rounded-square scan button** (slate/gold) with `scanLine` opening the scanner.
- **Cart item card** (`CartItemTile` in an `AppCard`, radius 18): row1 name (14/600, ≤2 lines) +
  `x` remove; row2 `SKU · ₱unit/unit` (muted) + **cost-code pill** (mono); row3 quantity stepper
  (`minus`/`plus`, 40px, `−` disabled at qty 1) · discount chip (off = hairline + `tag` +
  "Discount"; on = success-tint + success text + `tag` + "10%") · line total (17/700, right;
  strikethrough gross over green net when discounted). Swipe-to-delete (red `trash2`) preserved.
- **Labor & Service** (`ExpansionTile`): `wrench` + title + subtitle ("Optional — add mechanic
  labor" / "N service · ₱subtotal") + `chevronDown`; expanded = `MechanicPicker` dropdown →
  `LaborLineTile` rows (`wrench`, desc, fee, `pencil` edit, swipe-delete) → "Add labor line"
  outlined (`plus`, dialog).
- **Cart summary** (`AppCard`): Subtotal (with item count), Discount (green −₱), Labor, divider,
  **Total** hero (26/700, slate/gold).
- **Pinned action bar:** elevated surface with **top** shadow — "Proceed to Checkout" (filled
  slate/gold, `arrowRight`, 50px) over "Save as Draft" (outlined, `save`, 46px).
- **Empty cart:** centered Lucide cart icon + "Cart is empty" + muted hint.
- **Role rules preserved:** discount → `applyDiscount`; save-draft → `saveDraft`; entry →
  `accessPos`; labor open to all.

### Product-search dropdown (`product_search_field.dart`) — restyle only

Keep all behavior: 300ms debounce, `localProductSearchProvider`, ≤10 rows, stock color
(out/low/in), out-of-stock disabled, tap → `onProductSelected`, dismiss on blur, barcode-on-
submit, scan button. Restyle the overlay as an `AppCard` (soft shadow light / border dark, radius
18, clipped). Product rows adopt the new look (name 14/600, `SKU · ₱price` muted, stock trailing);
swap `CupertinoIcons.search`/`xmark`/`qrcode_viewfinder`/`exclamationmark_circle` and
`Icons.search_off` for Lucide equivalents. The wide-layout results list in `pos_screen.dart`
(`_buildProductSearchResults`) gets the same row restyle.

### 2 — Checkout (`checkout_screen.dart` + `payment_section.dart`)

Flex column, pinned Confirm. App bar: back `chevronLeft` (disabled while processing); title
"Checkout". Uppercase section labels (11/600, ls .8, muted) already implemented — keep.

- **ORDER ITEMS** (`AppCard`, hairline-divided rows): product row = `×N` outlined qty pill
  (slate/gold) + name + SKU (+ green "10% off") + ₱net right; labor row = bordered `wrench` badge
  + desc + ₱fee right.
- **PAYMENT SUMMARY** (`AppCard`): Parts subtotal · Discount (green −₱) · Labor · Mechanic ·
  divider · **Total** hero (26/700 slate/gold).
- **PAYMENT METHOD** (`payment_section.dart`): horizontal **scrollable pill chips** with Lucide
  icons — Cash `banknote`, GCash `smartphone`, Maya `wallet`, Mixed `layers`, Salmon `fish`.
  Selected = filled slate/gold; others = card surface + hairline + muted icon. Right-edge fade
  hints scroll. (Replaces the current `ChoiceChip` `Wrap`.) Method-specific inputs:
  - **Cash/GCash/Maya:** Amount Received field (elevated, ₱ prefix, **"Exact"** `checkCheck`
    button fills total) + quick chips ₱100/200/500/1000. Cash also shows the **Change** box —
    **filled success-tint bg** (`successLight` / `rgba(76,175,80,.18)`) + big green value; tender <
    total → "Amount Short", error-red. (Current code uses a bordered box; promote to filled tint.)
  - **Mixed:** segmented GCash/Maya + digital-amount field, then "Cash portion: ₱…".
  - **Salmon:** segmented Cash/GCash/Maya + Downpayment field, then "Salmon balance: ₱…".
- **Error banner:** error-bordered, `alertTriangle` + message.
- **Pinned Confirm:** "Confirm Payment · ₱{total}" — full-width **filled success-green, 52px**,
  `checkCircle2`, **green glow shadow** (`AppShadows.confirmButton`), spinner while processing,
  disabled until tender valid. Role: `processSale`.

### 3 — Barcode Scanner (`barcode_scanner_screen.dart`)

Single-shot: detect → haptic → pop value (preserved).

- **Chrome:** transparent app bar, white foreground; translucent circular buttons
  (`rgba(255,255,255,.12)`): close `x`, title "Scan Barcode", torch `flashlight`, flip
  `switchCamera`.
- **Stage:** live camera under a dimming overlay; centered **≈248px viewfinder** with **gold
  corner brackets** (3px `#E8B84C`, radius ~20) + a gold scan line. Instruction = **blurred dark
  pill**: `scanLine` (gold) + "Hold a barcode inside the box".
- **States preserved:** permission denied / unsupported / hardware error / scanning, with the
  existing copy.

### 4 — Success dialog (`checkout_success_dialog.dart`)

Modal over a dimmed scrim; existing scale+fade+haptic entrance preserved. Card radius 24
(`AppCard` with `AppRadius.xl`).

- **Success check:** circled, **filled success-tint** bg (`successLight` / `rgba(76,175,80,.18)`)
  + `check` (2.5 stroke) green. (Current = outlined ring; switch to filled tint.)
- **"Payment Successful!"** (20/700).
- **Sale number** pill — mono on a quiet chip (already implemented).
- **CHANGE DUE hero** — new: success-tint block (radius 18) with label + **₱ value at 40/700
  green** — the dialog's hero number. (Currently Change is one row in a combined amount card;
  promote it out.)
- **Amount card** (quiet fill): Total, Received.
- **Buttons:** Receipt (outlined, `receipt` → existing `ReceiptWidget` sheet) + Done (filled
  green → back to POS). Optional **Warnings** card (amber) above the buttons when present.

## Icon migration (Cupertino → Lucide, sale-flow only)

Apply the handoff mapping (stroke 1.75). Key swaps: `back`→`chevronLeft`, search→`search`,
scan→`scanLine`, drafts→`inbox`, clear/trash→`trash2`, remove/close→`x`, qty→`minus`/`plus`,
discount→`tag`, labor/mechanic→`wrench`, edit→`pencil`, add→`plus`, save-draft→`save`,
proceed→`arrowRight`, expand→`chevronDown`, cash→`banknote`, gcash→`smartphone`, maya→`wallet`,
mixed→`layers`, salmon→`fish`, exact→`checkCheck`, confirm/success→`checkCircle2`/`check`,
receipt→`receipt`, torch→`flashlight`, flip→`switchCamera`, error→`alertTriangle`,
no-results→`searchX`. Remove now-unused `package:flutter/cupertino.dart` imports.

## Testing & verification

- **Keep the existing suite green:** `cart_item_tile_test.dart`, `checkout_labor_test.dart`,
  `pos_labor_section_test.dart`, plus the cart/tenders provider tests.
- **Update icon matchers** broken by the migration — known: `cart_item_tile_test.dart:65`
  (`find.byIcon(CupertinoIcons.add)` → `LucideIcons.plus`). Sweep for any others after each edit.
- **No new behavior/golden tests** (per the minimal-testing decision).
- **Gate each increment:** `flutter test` + `flutter analyze` must pass before moving on.
- **Visual verification is manual/on-device** by the user (the agent can build but not install —
  see [[project_mobile_release]]). Verify both light and dark, the dropdown, all five payment
  methods, the scanner overlay, and the success dialog.

## Sequencing

Each step is its own commit; `flutter test` + `flutter analyze` green between steps.

1. `AppShadows.confirmButton` + shared **`AppCard`** primitive (+ export).
2. **POS:** `pos_screen.dart`, `product_search_field.dart` (dropdown), `cart_item_tile.dart`,
   `cart_summary.dart`, `labor_line_tile.dart`, `mechanic_picker.dart` — restyle + Lucide; fix
   icon matchers.
3. **Checkout:** `checkout_screen.dart` + `payment_section.dart` — restyle + Lucide pill chips +
   filled Change box + green confirm.
4. **Success dialog:** `checkout_success_dialog.dart` — filled check + CHANGE DUE hero.
5. **Scanner:** `barcode_scanner_screen.dart` — brackets, blurred pill, translucent controls.

Branch off `main`. On completion: merge to local `main`, leave push/deploy + APK install to the
user.

## Must-keep (regression guard)

- Role-gating: `applyDiscount`, `saveDraft`, `processSale`, `accessPos`.
- All five payment methods **and** the Mixed/Salmon split math.
- Dark-theme parity on every screen.
- One-handed reach: primary action pinned at the bottom.
- Tablet ≥800px POS split (search-left / cart-right).
- Product-search dropdown behavior (debounce, out-of-stock disable, tap-to-add, barcode-on-submit).
- Scanner single-shot detect → haptic → pop.
