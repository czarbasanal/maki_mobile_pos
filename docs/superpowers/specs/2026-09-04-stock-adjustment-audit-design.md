# Stock Adjustment Audit Flow — Design

**Date:** 2026-09-04
**Status:** Approved design, pending implementation plan
**Handoff:** `design/maki-pos-stock-adjustment-modal/` (Stock Adjustment
Modal - Implementation Guide.md is the UI authority; this spec is the
engineering mapping onto Firestore + both surfaces)

## Purpose

Every stock adjustment becomes an attributable, append-only record — who
changed the count, from what to what, why — instead of a bare quantity
overwrite with (at best) an activity-log line. Driven by the same physical
count reconciliation the tags sweep serves.

## Decisions (client-confirmed 2026-09-04)

- Reasons are a CONFIGURABLE managed list seeded with the handoff's
  presets; each reason carries its own `requiresNote` flag.
- "Set to" (absolute overwrite) is ADMIN ONLY; Add/Remove stay staff+admin
  (cashiers cannot adjust — unchanged from today).
- No approval threshold yet — record-only. Revisit if records show abuse.
- Deactivated products cannot be adjusted (reactivate first).

## Data model

### `products/{id}/stock_adjustments/{adjustmentId}` (append-only)

```
{
  mode: 'add' | 'remove' | 'set',
  quantity: int,            // as typed; always positive
  delta: int,               // signed; after - before
  before: int,
  after: int,               // >= 0
  reasonId: string,
  reasonName: string,       // snapshot — renames never rewrite history
  note: string | null,
  createdAt: serverTimestamp,
  createdBy: uid,
  createdByName: string | null
}
```

Mode + typed quantity are stored, not just the result: a "set to 40" and
a "remove 38" landing on the same number are different business events
(handoff §4 rule 1). Docs are never updated or deleted — an erroneous
adjustment is superseded by another adjustment.

### `adjustment_reasons/{reasonId}`

```
{ name, requiresNote: bool, isActive: bool,
  createdAt, updatedAt, createdBy, updatedBy }
```

Seed defaults (auto-seed when the list is empty at first dialog open, plus
a "Seed defaults" action in the editor, mirroring expense/unit seeding):

| name | requiresNote |
|---|---|
| Delivery | no |
| Count correction | yes |
| Damaged | yes |
| Lost | yes |
| Returned | no |
| Transfer | no |

## Transaction semantics (the "server" layer)

One Firestore transaction per Apply, in a shared repo method on each
surface (`adjustStockAudited` / `adjustStock` replacement):

1. Read the product doc.
2. Abort `product-inactive` if `isActive == false`.
3. Abort `stale-on-hand` (carrying the current quantity) if
   `product.quantity != expectedOnHand` — the figure the modal displayed.
4. Compute `after` (`add`: +qty, `remove`: −qty, `set`: qty); abort
   `negative-result` if `after < 0` (client blocks this at the input; the
   transaction is the rule, the UI the courtesy).
5. Write product `{quantity: after, updatedAt, updatedBy, updatedByName}`
   and create the adjustment doc — atomically.

Stale handling in UI: reopen with the fresh on-hand, keep the typed
quantity/reason/note, and say someone else moved the stock. Double-tap
safety: the transaction plus the existing button-lock pattern — a second
Apply sees a changed base and goes stale. No idempotency-key field
(deviation from the handoff's REST contract, which assumed a server).

"On-hand is the sum of movements" (handoff §4) is adopted for ADJUSTMENTS
only: sales, receiving and POs keep their own existing records; this spec
does not migrate them into movement docs. Each stock-moving flow remains
reconcilable through its own collection.

Every adjustment also writes the standard Activity Logs entry (mode,
delta, reason, note — web finally records the note) — the log line is the
cross-product feed, the subcollection the per-product truth.

## Firestore rules

`products/{id}/stock_adjustments/{adjId}`:

- create: `isStaffOrAdmin() && isActiveUser()`, AND
  `request.resource.data.mode != 'set' || isAdmin()`, AND parent product
  `get(...).data.isActive == true`, AND structural checks:
  `after == before + delta`, `after >= 0`,
  `createdBy == request.auth.uid`.
- read: `isStaffOrAdmin() && isActiveUser()`.
- update, delete: `false` — append-only is server-enforced.

`adjustment_reasons`: the shared-list template (any active user reads and
creates/renames; staff/admin flip `isActive` and delete) with
`requiresNote` added beside `isActive` in the staff/admin-guarded diff
keys — a cashier cannot loosen the note policy.

The product doc's own quantity-only update branch stays permissive (sale
deduction needs it); the audit artifact is the gated record, and the
adjust dialogs are already hidden from cashiers client-side.

Rules deploy is production-affecting → show diff, get explicit OK.

## Web UI (handoff-faithful)

`AdjustStockDialog` rebuilt per the guide: shared `Modal` (sm/452px) over
the product modal; preview strip (`ON HAND → NEW QUANTITY`, 19px mono,
signed delta chip, `—` until a quantity is typed, `--neg` when negative);
mode as three equal chips (Set to hidden for staff), "Set to" relabels the
field to "Counted quantity"; −/+ steppers around a digits-only mono field
with the product's unit as static text; reason chips from
`useActiveAdjustmentReasons()`, required; note textarea — required when
the picked reason's `requiresNote` is true, signaled by the amber border +
label losing "(optional)" BEFORE submit; footer `Recorded against <name> ·
today`, Cancel + amber `Apply adjustment` at .45 opacity until valid;
Enter applies when valid; Escape peels one layer (existing escapeLayers);
scrim click closes; autofocus+select the quantity; full state reset on
every open. On apply: both modals close, toast `Stock adjusted` with
`+12 → 90 pcs`. On stale: reopen with fresh figure, inputs kept, explicit
copy. Negative blocked at the input with the guide's inline sentence.

New "Adjustment Reasons" settings page (Mechanics/Tags pattern — bespoke
for the `requiresNote` toggle), route `/settings/adjustment-reasons`,
gated `editLists`; the 3-file route wiring gotcha applies.

## Mobile UI (parity, app idiom)

`StockAdjustmentDialog` rebuilt with the same semantics: preview strip,
mode chips (Set to admin-only), stepper, required reason chips from
`activeAdjustmentReasonsProvider`, conditional note, stale-retry flow,
transactional write, activity log. New "Adjustment Reasons" editor screen
tile in Settings → Lists (`/settings/adjustment-reasons`, editLists;
manageCategories gates deactivate/delete/requiresNote).

Old APKs (≤ +33) keep the old dialog and write NO movement records until
updated — transition caveat, acceptable.

## Out of scope (handoff §5 + client calls)

Multi-SKU stocktake sessions · damage photos · Transfer destinations ·
approval thresholds · a per-product adjustment-history screen (records
exist from day one; the view is a later cheap add) · migrating
sales/receiving into movement records.

## Testing (TDD)

- Pure helpers both surfaces: `resolveAdjustment(mode, qty, onHand)` →
  {delta, after} + validity (negative block, note-required logic).
- Rules tests: append-only (update/delete fail even for admin), staff can
  add/remove but NOT set, admin can set, cashier cannot create, inactive
  product blocks create, structural after==before+delta check,
  adjustment_reasons template incl. requiresNote guard.
- Web Vitest: dialog validity gating, note-required cue, stale-reopen
  keeps inputs, apply writes through the transaction method, reasons page
  CRUD.
- Mobile: dialog widget tests (mode gating by role, reason requirement,
  preview math), transaction method via recording fake, editor screen.
- Gates: full `flutter analyze`/`test`, `npm run typecheck`/`test`/
  `build`, rules suite.

## Rollout

1. Rules (additive) — user-confirmed deploy.
2. Web — hosting deploy.
3. Mobile — rides APK +34.
