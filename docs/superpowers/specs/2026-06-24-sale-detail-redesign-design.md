# Sale-Detail Screen Redesign (Bundle 03 — start) — Design

**Date:** 2026-06-24
**Surface:** Flutter mobile app — `lib/presentation/mobile/screens/sales/sale_detail_screen.dart`
**Predecessor:** [Bundle 02 — POS Sale-Flow Redesign](2026-06-21-pos-sale-flow-redesign-design.md) (`568d284`)
**Builds on:** `feat/pos-redesign-fidelity-pass` — the shared `AppCard` (bundle 02) and the new
`SummaryRow` primitive (commit `d2612b3`).

## Overview

Bundle 02 brought the **sale flow** (POS, Checkout, Scanner, Success dialog) onto the elevated
theme but explicitly left the **post-sale record** — the Sale Detail screen — untouched. This is
the first screen of that follow-on work: bring `sale_detail_screen.dart` onto the same system
(`AppCard`, `SummaryRow`, design tokens) so the screen a cashier sees *after* a sale matches the
screen they used *during* it.

Like bundle 02 this is **almost entirely a visual restyle** — no providers, repositories, Firestore
writes, or `firestore.rules` are touched. The one behavior change is the labor-row label format.

A side benefit: the screen is currently built from raw `Container`s with **hardcoded Material
colors** (`Colors.grey[50]`, `red[50]`, `amber[50]`, `green[700]`, `grey[600]`), so it renders
**broken (light-grey) in dark mode**. Moving to `AppCard` + `AppColors` fixes that.

## Scope

In scope (light + dark): **`sale_detail_screen.dart` only.**

Out of scope (unchanged):
- `receipt_widget.dart` — intentionally monochrome/dashed print artifact (out of scope in bundle
  02 too; its own docstring says it "benefits from looking that way").
- `checkout_success_dialog.dart` — already redesigned in bundle 02 (CHANGE DUE hero, filled check).
- `void_sale_dialog.dart`, `request_void_dialog.dart`, `void_requests_screen.dart` — separate widgets.
- Any other screen. No app-wide sweep.

## Design tokens

**Do not invent new tokens** — reuse bundle 02's (see the predecessor spec): `AppColors`
(`success`/`successText()`/`successFill()`, `error`, `warning`, surfaces, hairlines), `AppShadows`
(via `AppCard`), `AppRadius` (`md 14`, `field 16`, `lg 18`, `hero 22`, `xl 24`), `AppSpacing`,
Figtree/`monospace` type. No raw color or radius literals.

## Component design

### Neutral cards → `AppCard`
Replace the raw `Container` + hardcoded grey in:
- `_buildItemsList` → `AppCard` (clipped; keep hairline-divided item/labor rows, but borders use
  `AppColors.lightHairline`/`darkHairline`, not `Colors.grey[200]`).
- `_buildPaymentCard` → `AppCard`.
- `_buildDetailsCard` → `AppCard`.

`AppCard` derives `isDark` itself and supplies the soft-shadow (light) / hairline-border (dark)
surface; callers never re-derive brightness.

### Tinted cards → theme-aware tinted `Container` (NOT `AppCard`)
`AppCard` has no color override, so tints follow the bundle-02 Change-box pattern — a `Container`
with a `withValues`-alpha fill + matching border, brightness-aware:
- `_buildVoidedBanner`, `_buildVoidInfoCard` → `AppColors.error` tint + border; icon/text use
  `AppColors.error` (replaces `Colors.red[*]`).
- `_buildNotesCard` → `AppColors.warning` tint + border; label uses `AppColors.warning`
  (replaces `Colors.amber[*]`).

### Payment breakdown → `SummaryRow`
Replace `_buildPaymentRow` **and** `_tenderRows` with the shared `SummaryRow`:
- Subtotal, Received, tender rows → `SummaryRow(label, value)`.
- Total → `SummaryRow(..., isTotal: true)` (26/700 primary hero).
- Discount, Change → `SummaryRow(..., valueColor: AppColors.successText(isDark))` (caller formats
  the `-`/`₱` string; `SummaryRow` does not).

Deletes the bespoke `_buildPaymentRow` and its hardcoded `Colors.green[700]`/font-size logic.

### Section headers → uppercase style
`_buildSectionHeader` adopts the bundle-02 section-label look: `UPPERCASE`, 11/600,
`letterSpacing 0.8`, `onSurfaceVariant` (replaces `titleMedium` bold `grey[700]`).

### Sale header
`_buildSaleHeader` keeps the large total as the block's hero but becomes theme-aware: date →
`onSurfaceVariant` (not `grey[600]`); the status badge uses `AppColors.success`/`AppColors.error`
(not `Colors.green`/`Colors.red`); voided total uses muted + strikethrough. Rendered on an
`AppCard` (radius `hero`/`xl`).

### Detail rows & void buttons
`_buildDetailRow` keeps its icon+label+value structure but theme-aware (`grey[600]` →
`onSurfaceVariant`). Void/Request-Void buttons use `AppColors.error` instead of `Colors.red`.

### Labor label (the one behavior change)
Payment card's labor row label: `Labor (N services)` → **`Labor · {mechanicName}`** (or `Labor`
when no mechanic), matching checkout/cart. The separate "Mechanic" row in the Details card stays
(it is the metadata home — a different card, not the adjacent redundancy bundle 02 removed).

### Icons (Cupertino → Lucide)
For visual parity with the redesigned sale flow, migrate this screen's `CupertinoIcons` to the
bundle-02 Lucide equivalents (person→`user`, wrench→`wrench`, creditcard→`creditCard`, bag→
`shoppingBag`, clock→`clock`, doc/notes→`fileText`/`stickyNote`, xmark→`x`/`xCircle`, etc.) and
drop the now-unused `cupertino.dart` import. *(Decided: included in this pass — Q1.)*

## Testing & verification

Follows the **bundle-02 minimal-testing decision** — colors/shadows/radii are not meaningfully
unit-testable; rely on manual on-device verification, keep the suite green.

- **TDD the one behavior change:** update `test/presentation/widgets/sale_detail_screen_labor_test.dart`
  to expect `Labor · {mechanic}` first (RED), then implement (GREEN).
- **Keep the existing suite green:** update any icon matchers broken by the Lucide swap; no new
  golden/dark-mode tests.
- **Gate each increment:** `flutter test` + `flutter analyze` must pass before moving on.
- **Visual/dark-mode verification is manual on the emulator** by driving to a sale's detail view
  (light + dark): cards lift correctly, payment breakdown + Total hero, tinted void/notes cards,
  `Labor · {mechanic}` label.

## Sequencing

Each step its own commit; `flutter test` + `flutter analyze` green between steps. Continue on
`feat/pos-redesign-fidelity-pass`; no deploy.

1. Payment breakdown → `SummaryRow` + `_buildPaymentCard` → `AppCard`; `Labor · {mechanic}` (TDD
   the label test first).
2. Items + Details cards → `AppCard`; `_buildDetailRow`/section headers theme-aware + uppercase.
3. Tinted cards (Voided banner, Void info, Notes) + sale header + void buttons → `AppColors`.
4. Lucide icon migration + drop `cupertino.dart`; fix icon matchers.

## Must-keep (regression guard)

- Void role-gating: `voidSale` (direct) vs `requestVoidSale` (request) vs none; pending-request state.
- Voided-sale rendering: banner, strikethrough total, void-info card.
- Multi-tender breakdown (`effectiveTenders`), Salmon downpayment labels.
- Cost-code encoding on item rows; draft-origin row.
- Dark-theme parity (this pass should *fix* it, not regress it).
- Receipt sheet still opens via the existing `ReceiptWidget`.
