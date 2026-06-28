# Bundle 11 — Suppliers

Mobile Flutter restyle. **This folder is the *current* state, for hand-off to Claude Design.**
`reference_current-ui.html` is a token-accurate reconstruction of what ships today (open it in a browser).
Mark up / redesign on top of it and drop the redesigned hand-off file back here.

## Scope (2 screens, 5 states/surfaces)

| # | Surface | Source |
|---|---------|--------|
| 1 | **Suppliers list** (active) | `lib/presentation/mobile/screens/suppliers/suppliers_screen.dart` |
| 2 | **Show-inactive** toggle on (strikethrough rows) | same (`_showInactive` + `_SupplierListTile`) |
| 3 | **Empty / no-results** state | same (`EmptyStateView`) |
| 4 | **Add / Edit Supplier** form | `lib/presentation/mobile/screens/suppliers/supplier_form_screen.dart` |
| 5 | **Validation** errors (name required, bad phone/email) | same (`Validators` + `Form`) |

Shared widgets: `EmptyStateView`, `LoadingView`, `ErrorStateView`, `AppDropdown` (from
`presentation/shared/widgets/common/`). Entity: `SupplierEntity`; payment terms enum: `TransactionType`.

## Current state — what's not migrated

Raw Material throughout. The **list** is a `ListView.builder` of Material `Card` + `ListTile` rows (leading
`briefcase`, title = name, subtitle = `contactPerson` + `transactionType.displayName`, trailing chevron), a search
`TextField` pinned in the app-bar's `PreferredSize` bottom, an **eye / eye-slash** show-inactive app-bar toggle, and
a bottom `FilledButton.icon` "Add Supplier" (`bottomNavigationBar`). Inactive rows are **struck-through + muted**.
The **form** is a `SingleChildScrollView` `Form` of `TextFormField`s + an `AppDropdown` for payment terms with a
full-width submit. **All icons are Cupertino** (`back`, `eye`/`eye_slash`, `search`, `briefcase`, `person`, `phone`,
`device_phone_portrait`, `envelope`, `location`, `creditcard`, `list_bullet`, `add`, `chevron_right`). **No `AppCard`,
no Lucide, no status color.** This bundle = Cupertino→Lucide + Material `Card`/`ListTile`→soft-shadow `AppCard`,
neutral discipline, dark parity. **Note:** there is **no delete / deactivate UI and no confirmation dialog** in these
two screens (a `deactivateSupplier` method exists on `supplierOperationsProvider` but is not wired in here) — don't
invent one.

## States & rules to preserve (don't design these away)

- **List row** = one supplier: leading `briefcase` glyph, **title** = `name`, **subtitle** = `contactPerson`
  (when present) then `transactionType.displayName` (`Cash` / `30 / 45 / 60 / 90 Days` / `N/A`), **trailing chevron**.
  Tap → edit form at `${suppliers}/edit/{id}`.
- **Inactive suppliers**: rendered **struck-through + muted** (not hidden when the toggle is on).
- **Show-inactive toggle** — app-bar `eye` / `eye_slash` icon button; when **off**, inactive suppliers are filtered
  out of the list entirely.
- **Search** — `TextField` in the app-bar bottom; case-insensitive match against **name OR contactPerson**.
- **Empty state** — `EmptyStateView` with a people icon: "No suppliers yet / Add your first supplier" (no data) vs
  "No suppliers found / Try a different search" (active search).
- **Add Supplier** — bottom full-width `FilledButton.icon` → `supplierAdd` route.
- **Form fields** (in order): **Supplier Name \*** (required, words-capitalized), **Contact Person**,
  **Contact Number** (phone-validated), **Alternative Number**, **Email** (email-validated only when non-empty),
  **Address** (multiline ×2), **Payment Terms \*** (`AppDropdown<TransactionType>`, required), **Notes**
  (multiline ×3). Title is "Add Supplier" / "Edit Supplier"; submit reads "Add Supplier" / "Update Supplier".
- **Validation** — Name required; Payment Terms required (has default `Cash`); phone validated via
  `Validators.phoneNumber`; email validated via `Validators.email` (skipped when blank). Blank optional fields save
  as `null`.
- **Save** — spinner in the submit button while `_isSaving`; **success snackbar** ("Supplier added" / "Supplier
  updated") then `go(suppliers)`; **error snackbar** on failure. Edit screen shows a centered
  `CircularProgressIndicator` while loading the existing supplier.
- Loading list = `LoadingView`; list error = `ErrorStateView` with retry (invalidates `suppliersProvider`).

## Target language

Global theme tokens at `design/handoff/maki-theme/` + the patterns shipped in bundles 01–07: soft-shadow `AppCard`
rows, Lucide icons (`briefcase`, `user`, `phone`, `smartphone`, `mail`, `map-pin`, `credit-card`, `list`, `search`,
`eye`/`eye-off`, `plus`, `chevron-right`/`-left`/`-down`), theme-aware neutral colors with **dark parity** (canvas
`#0C1415`, card `#18262A`, gold primary), and **neutral-by-default discipline** — suppliers carry no status, so keep
it all neutral; the only differentiation is the **muted + strikethrough** treatment for inactive rows. App bar stays
flat on canvas; the search field and form fields adopt the elevated field styling (radius `16`, hairline border).
