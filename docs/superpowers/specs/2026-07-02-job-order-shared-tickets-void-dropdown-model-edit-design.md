# Job orders as shared tickets, void-reason dropdown for requests, editable motorcycle model

Date: 2026-07-02
Status: Approved design (user AFK — recommended option chosen; rules deploy still gated on user confirmation)

## Problems

1. **Cashier bill-out of a job order fails.** Job Orders repurposed the personal
   `drafts` collection but kept its owner-or-admin write rule (both in
   `firestore.rules` and `UpdateDraftUseCase`). When a cashier bills out a JO
   created by staff/admin, the sale itself commits, but
   `markDraftAsConverted` is rejected with permission-denied — the ticket stays
   open, checkout surfaces a failure/warning, and the JO can be billed again.
   The same wall silently blocks every cross-user JO edit (parts, labor,
   mechanic) even though the JO edit screen offers those actions to everyone.
2. **Request Void uses a free-text reason** while the admin Void Sale dialog
   uses the admin-managed void-reasons dropdown (+ "Other" detail). The user
   wants the same dropdown UX for cashier/staff void requests.
3. **Motorcycle model is set-once.** The JO edit screen displays it read-only;
   there is no way to change the model being serviced after creation.

## Decision 1 — Job orders are shared shop tickets

Any active valid user (cashier/staff/admin) may **update** any job order.
**Delete** stays creator-or-admin. **Create** unchanged (creator = auth uid).

Changes:
- `firestore.rules` `/drafts/{draftId}`: split the combined
  `update, delete` rule — `update` for any `isValidUser() && isActiveUser()`;
  `delete` keeps the owner-or-admin condition.
  ⚠️ Production-affecting; **do not deploy without user confirmation**. The
  bug is only fixed in production once these rules deploy.
- `UpdateDraftUseCase`: drop the owner-or-admin guard (keep
  `Permission.editDraft` assert and the not-found check).
- `DeleteDraftUseCase`: untouched (owner-or-admin stays).
- `markDraftAsConverted` needs no code change — it already writes the right
  fields; the rules were the blocker.

## Decision 2 — Shared void-reason field

Extract the reason dropdown + conditional "Other" free-text detail from
`VoidSaleDialog` into a reusable `VoidReasonField` widget
(`lib/presentation/mobile/widgets/pos/void_reason_field.dart`), reading
`activeCategoriesProvider(CategoryKind.voidReason)` exactly as today:
- dropdown of unique active reason names; empty-list / loading / error states
  preserved;
- picking the seeded `Other` entry reveals a detail `TextFormField`
  (required, min 5 chars);
- validators included so parents just wrap in a `Form`.

`VoidSaleDialog` refactors onto it (behavior unchanged). `RequestVoidDialog`
replaces its free-text field with it; the submitted `reason` string becomes
the picked name, or the detail text when "Other" (same resolution as admin
void). Request flow (no password; admin approves) unchanged.

## Decision 3 — Editable motorcycle model on the JO edit screen

Replace the read-only model row in the ticket header with the existing
`MotorcycleModelPicker` (pick-or-add, same widget as the New/Save JO dialogs),
persisted through the screen's optimistic `_persist` path like the mechanic
picker. Supporting change: add `clearMotorcycleModel` flag to
`DraftEntity.copyWith` (picker's "— None —" must actually clear the field;
`copyWith(motorcycleModel: null)` is a no-op today). Clearing the model simply
re-arms the existing bill-out gate ("Set the motorcycle model to bill out").

## Testing

- `update_draft_usecase_test`: non-owner staff/cashier update now succeeds;
  inactive/no-permission still fails; delete tests untouched.
- Entity test for `clearMotorcycleModel`.
- Widget test for `VoidReasonField` (renders reasons, validates empty pick,
  "Other" reveals detail + min-length validation).
- `flutter analyze` + full `flutter test`.

## Out of scope

- Making draft conversion atomic with the sale transaction (web-style) — the
  existing best-effort + warning path is acceptable once rules allow the write.
- Any web-admin change (its drafts flow is admin-only and unaffected).
