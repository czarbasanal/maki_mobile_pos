# Shared-list permissions: cashier add/edit, staff full manage

Date: 2026-07-24
Surface: Flutter mobile app + firestore.rules. Web admin untouched.

## Problem

Mechanics, product/expense categories, units, void reasons, and motorcycle
models are all gated by the single admin-only `Permission.manageCategories`.
Cashiers and staff cannot maintain these lists, so routine additions (a new
mechanic, a new category or unit) bottleneck on the admin.

## Decisions (confirmed with user)

- **Cashier**: add + edit entries on all these lists. No deactivate/reactivate.
- **Staff**: full manage — add + edit + deactivate/reactivate (same as admin
  on these lists).
- **Scope = everything in the hub**: product categories, expense categories,
  units, void reasons, mechanics, motorcycle models.
- **POS mechanic dropdown gains inline "➕ Add mechanic…"** (pick-or-add,
  mirroring the motorcycle-model picker).
- No editor hard-deletes today ("delete" = deactivate toggle); that stays true.
- firestore.rules change is production-affecting: **deploy only on explicit
  user go-ahead**.

## Design

### 1. Permission model (`lib/core/constants/role_permissions.dart`)

- New `Permission.editLists` — "add and edit shared list entries (categories,
  units, void reasons, mechanics, motorcycle models)". Granted to **cashier,
  staff, admin**.
- Existing `Permission.manageCategories` now means "full list manage,
  including deactivate/reactivate". Granted to **staff + admin** (was
  admin-only). Admin set unchanged otherwise.

### 2. Route guards (`lib/config/router/route_guards.dart`)

`/settings/categories`, `/settings/categories/<kind>` (dynamic),
`/settings/mechanics`, `/settings/motorcycle-models` re-gate from
`manageCategories` → `editLists`.

### 3. Settings screen (`settings_screen.dart`)

The three tiles (Manage Lists, Mechanics, Motorcycle Models) move out of the
`isAdmin` block into a block shown when the user has `editLists`. Admin-only
tiles (users, logs, etc.) stay where they are.

### 4. Editors

`category_editor_screen.dart`, `mechanic_editor_screen.dart`,
`motorcycle_model_editor_screen.dart`:

- Add (FAB) and edit stay available to everyone who can reach the screen.
- The deactivate/reactivate affordance on each row (via
  `settings_crud_row.dart`) renders only when the user has
  `manageCategories`.
- "Seed defaults" (expense/unit/voidReason kinds) is an add operation —
  available with `editLists`.

### 5. POS mechanic picker (`widgets/pos/mechanic_picker.dart`)

Add a "➕ Add mechanic…" sentinel entry mirroring
`motorcycle_model_picker.dart`: selecting it opens a name dialog, creates (or
reuses, case-insensitively, matching the model picker's resolve-or-create
pattern) the mechanic, and auto-selects it. Available wherever the picker is
used (POS, draft edit, job-order dialogs).

### 6. firestore.rules

For `product_categories`, `expense_categories`, `units`, `void_reasons`,
`mechanics`, and `motorcycle_models` (names confirmed in
`firestore_collections.dart`), replace admin-only write with:

- `create`: any `isValidUser() && isActiveUser()`.
- `update`: any active valid user, **except** an update whose
  `affectedKeys()` includes `isActive` requires staff or admin.
- `delete`: admin only (unchanged; nothing in-app hard-deletes).

The motorcycle-models inline-create carve-out (`createdBy == auth.uid`)
is subsumed by the new create rule; keep the `createdBy` stamp requirement
on create for that collection as today.

**Deploy is a separate, user-confirmed step.** Old APKs keep working (rules
only loosen).

### 7. Web admin

Untouched. It is an admin-only app with its own permission copy; its gating
continues to require its own `manageCategories`, held only by admin there.

## Not changing

- No hard-delete paths added anywhere.
- Sale/labor/draft flows, all other rules blocks, indexes, schemas.
- Web admin code.

## Testing (TDD; tests mirror lib/)

- `role_permissions_test.dart`: cashier/staff/admin hold `editLists`;
  staff+admin hold `manageCategories`; cashier does not.
- Route-guard tests: cashier can now access the four routes (existing
  "cashier-cannot" assertions in
  `route_guards_mechanics_test.dart` / `route_guards_motorcycle_models_test.dart`
  flip to "can"); a signed-out/unknown route check still denies.
- Settings screen test: cashier sees the three tiles; (existing admin
  assertions unchanged).
- Editor widget tests: with a cashier user the deactivate toggle is absent
  and add/edit affordances present; with staff the toggle is present.
- Mechanic picker test: inline add entry appears, dialog creates and
  selects; reuse path (existing name, case-insensitive) does not duplicate.
- Emulator rules tests (`tools/firestore-rules-test`): new describe blocks
  for the six collections — cashier create ok, cashier name-edit ok, cashier
  `isActive` flip denied, staff `isActive` flip ok, non-admin delete denied.
