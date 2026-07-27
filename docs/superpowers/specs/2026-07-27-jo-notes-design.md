# Job Order Notes — optional notes on save + editable on JO edit screens (mobile + web)

**Date:** 2026-07-27 · **Status:** approved (user Q&A) · **Surfaces:** Flutter mobile + web admin

## Context

The `notes` field already exists on the Draft schema and flows end-to-end on
mobile — `CartState.notes`, `toDraft()`/`toSale()` persist it, `loadFromDraft`
restores it, and `draft_edit_screen` displays it read-only — but **no UI ever
sets it** (`setNotes` on the cart has zero callers). On web, `Draft.notes`
exists in the entity/converter, but `useSaveDraft` hard-codes `notes: null`,
`createCartStore()` has no notes, `buildSaleInput` hard-codes `notes: null`
onto every sale, and nothing displays notes. The web-batch-11 final review
flagged the missing dialog notes as a ratified spec deviation; the user now
wants it built, plus editing.

## Goal

1. Optional notes can be entered when saving the cart as a Job Order (both
   surfaces), prefilled from the cart so resume → re-save keeps them.
2. Notes are **editable** on the JO edit screens (both surfaces) — upgrade
   from mobile's current read-only display.
3. Notes ride into the sale at bill-out on web, matching what mobile's
   `toSale()` already does.

Empty/whitespace input normalizes to `null` (never empty string) everywhere.

## Design — mobile (input UI only; pipeline already works)

- **`save_job_order_dialog.dart`:** add optional multiline "Notes" field.
  `SaveJobOrderInput` gains `notes`; new `initialNotes` param prefills it.
  Trimmed-empty → null.
- **`pos_screen.dart`:** pass `initialNotes` from cart state; on confirm call
  `cartProvider.notifier.setNotes(input.notes)` **before** `_saveDraft(...)`
  (synchronous state update; `toDraft()` reads it).
- **`draft_edit_screen.dart`:** replace the read-only notes `Text` with an
  editable notes field following the screen's `_persist` pattern. To avoid a
  Firestore write per keystroke, persist on focus loss / editing-complete,
  via `copyWith(notes: …)` — using the entity's clear-flag pattern
  (`clearNotes`, added if the entity's `copyWith` lacks it — mirrors
  `clearMotorcycleModel`/`clearMechanic`) when emptied. Field visible even
  when notes are currently null (it's now an input, not a display).
- Bill-out carry-through: already works (`toSale()` uses `state.notes`).

## Design — web (mirror mobile's pipeline)

- **`createCartStore()`:** add `notes: string | null` + `setNotes(notes)`;
  `loadDraft` restores `draft.notes`; `clear()` resets to null. This gives
  BOTH `cartStore` (POS) and `draftEditStore` (JO edit) notes for free.
- **PosPage Save-as-JO dialog:** optional textarea, prefilled from
  `cartStore.notes`; on confirm `setNotes(trimmed || null)` and pass `notes`
  in the save input.
- **`useSaveDraft`:** `SaveDraftInput` gains `notes: string | null`; the
  create branch writes `input.notes` (drops the hard-coded null); the update
  branch now includes `notes` in the patch (so JO-edit note changes persist).
- **`JobOrderEditPage`:** notes textarea bound to `draftEditStore`
  notes/`setNotes` (hydrated by `loadDraft`), included in the existing
  `save.mutateAsync({...})` payload. Label "Notes", optional.
- **Checkout carry-through:** `CheckoutInput` gains `notes`;
  `buildSaleInput` uses `input.notes ?? null` (drops the hard-coded null);
  the checkout call site passes the cart store's notes. JO-resumed carts
  therefore bill out with the JO's notes on the sale — mobile parity.

## Not in scope

- Displaying notes on sale receipts / sale detail pages (neither surface
  does today; unchanged).
- Notes on the JO **list** rows (both surfaces show them only in edit/save
  contexts).
- Firestore rules / indexes: none needed — mobile has written `drafts.notes`
  since the schema's inception; sales `notes` is an existing field.
- Activity-log changes: none (JO save/delete logs already carry the JO
  number; notes aren't logged).

## Testing (TDD both surfaces)

- **Mobile:** dialog returns trimmed notes / null on empty; pos flow calls
  `setNotes` before save (widget test on the dialog + existing save-flow
  test extension); draft-edit notes field persists via full `updateDraft`
  path incl. clear-to-null.
- **Web:** store factory (loadDraft restores / clear resets / setNotes);
  save hook passes notes on create AND update; `buildSaleInput` carries
  notes; PosPage dialog prefills + passes notes; JobOrderEditPage textarea
  hydrates from draft and saves changes.

## Risks

- Mobile draft-edit persist-on-blur must not double-write with the screen's
  existing sync/`_persist` machinery — reuse `_persist` exactly like the
  model/mechanic edits do.
- Web `createCartStore` is shared by two stores — notes must be included in
  `clear()` so a cancelled JO edit doesn't leak notes into the next edit
  (the page already calls `clear()` on unmount).
