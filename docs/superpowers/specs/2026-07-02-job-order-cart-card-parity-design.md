# Job Orders — POS cart-card parity + Save-Job-Order polish

**Date:** 2026-07-02 · **Status:** approved · **Surface:** mobile Flutter app
**Branch context:** builds on `feature/job-orders-redesign` (uncommitted visual redesign).

## Problem

1. The job order editor's parts list uses bespoke cards (qty badge + 26px stepper) while the POS cart uses the richer `CartItemTile`. The user wants one card language: the POS card, everywhere parts are edited.
2. The POS footer "Save Job Order" button label wraps/cuts off on narrow screens.
3. The Save-as-Job-Order modal has no mechanic option, and its model picker always starts empty even when the cart already has a model.
4. The POS Labor & Service section has a mechanic picker but no motorcycle-model picker; the model can only be set in the save modal.

Out of scope (explicitly reverted by the user): stripping labor/mechanic from POS, any standard-vs-serviced routing change. POS flow stays as-is.

## Design

### 1. Card parity in the job order editor (`draft_edit_screen.dart`)

Replace `_buildDraftItem` + `_stepperButton` with the POS `CartItemTile` per part:

- `item:` the draft item; `discountType: draft.discountType`.
- `onQuantityChanged: (qty) → _persist(draft.updateItemQuantity(item.id, qty))` (absolute qty; entity helper exists at `draft_entity.dart:214`). Minus disables at qty 1 (POS parity; removal is ✕/swipe).
- `onRemove` / swipe-to-delete `→ _persist(draft.removeItem(item.id))`.
- `onDiscountTap` → the POS `DiscountInputDialog` with the same construction as `pos_screen._showDiscountDialog` (itemName, currentDiscount, discountType, maxAmount = grossAmount, hasOtherDiscounts across the draft's other items):
  - `onApply(value) → _persist(draft.updateItem(item.copyWith(discountValue: value)))` (`updateItem` exists at `draft_entity.dart:196`).
  - `onTypeChanged(type)` mirrors cart semantics: set `draft.discountType` and reset every item's `discountValue` to 0 (match `CartNotifier.setDiscountType` behavior — verify and mirror exactly).
- The editor summary's existing green Discount row and entity money math already handle per-item discounts; discounts ride into the sale at bill-out unchanged.

Accepted deltas vs the redesign mock: POS card replaces the qty-badge card; job orders gain per-item discounts.

### 2. POS footer button fit (`pos_screen.dart`)

Wrap the "Save Job Order" label so it renders on one line, scaling down if needed (`FittedBox(fit: BoxFit.scaleDown)` around the label or equivalent). No copy change. Same guard for "Checkout" is unnecessary (short label).

### 3. Save-as-Job-Order modal (`pos_screen._showSaveDraftDialog`)

- Add `MechanicPicker(nonePlaceholder: '— Optional —')` below the model picker, **prefilled from the cart's mechanic** (`cart.mechanicId`).
- Prefill the model picker from `cart.motorcycleModel` (today `pickedModel` starts null).
- On Save: write both back to the cart (`setMotorcycleModel`, and the cart's existing mechanic setter) before `toDraft`, so the ticket carries them. No other modal changes.

### 4. Model picker in POS Labor & Service (`pos_screen` labor expansion)

Add `MotorcycleModelPicker` beside the existing `MechanicPicker` in the Labor & Service `ExpansionTile`, wired to cart state: `selectedModel: cart.motorcycleModel`, `onChanged → cartNotifier.setMotorcycleModel(...)`. Cart state is the single source of truth — section and modal read/write the same fields. A direct checkout (no ticket) carries the model into the sale exactly as today.

## Testing

TDD per change:
- Rewrite `draft_edit_screen_items_test` against `CartItemTile` (qty pill text, +/− behavior incl. disabled-at-1, remove via ✕).
- New: discount applied via the dialog persists on the ticket (working copy) and renders the summary Discount row.
- Save modal: widget test that the mechanic picker appears and prefills from cart mechanic; model prefills from cart model.
- Labor section: model picker present and writes cart state.
- Full `flutter test` + `flutter analyze`; `/code-review`; device pixel-smoke remains the user's gate.

## Non-goals

- No provider/repo/schema/rules changes; no POS labor removal; no routing changes; no web admin changes.
