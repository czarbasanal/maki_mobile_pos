# Bundle 12 — Users

Mobile Flutter restyle. **This folder is the *current* state, for hand-off to Claude Design.**
`reference_current-ui.html` is a token-accurate reconstruction of what ships today (open it in a browser).
Mark up / redesign on top of it and drop the redesigned hand-off file back here.

## Scope (2 screens + shared widget, 5 states/surfaces)

| # | Surface | Source |
|---|---------|--------|
| 1 | **User Management** list (admin only) | `lib/presentation/mobile/screens/users/users_screen.dart` |
| 2 | **Active filters + empty** state | same (`EmptyStateView`) |
| 3 | **Create User** form (role picker + password) | `lib/presentation/mobile/screens/users/user_form_screen.dart` |
| 4 | **Edit User** form (email locked, no password, Reset link) | same |
| 5 | **Deactivate / Reactivate** confirm dialog | `users_screen.dart` (`AlertDialog`) |

Shared widget: **user row card** — `lib/presentation/mobile/widgets/users/user_list_tile.dart`.
Entity `UserEntity`; enum `UserRole` (`cashier` < `staff` < `admin`). **Whole bundle is admin-only**
(non-admins hit an "Access denied" Scaffold).

## Current state — what's not migrated

Raw Material. The list is a `Column` of tinted summary boxes + a `ListView` of Material `Card`s
(`UserListTile`), each with a `CircleAvatar`, a pill **role badge**, a blue **You** tag, and a
`PopupMenuButton` overflow. The form is a `TextFormField` stack with a big role-tinted `CircleAvatar`,
a custom radio-style **role picker** (3 `InkWell` cards), and create-only obscured password fields.
**No `AppCard`, no Lucide, Cupertino icons throughout.** Role colors are **hard-coded Material swatches**
(`Colors.purple` / `Colors.green` / `Colors.orange`) duplicated in `user_list_tile.dart` **and**
`user_form_screen.dart` — not theme tokens. Status/role tags use `Colors.red[100]` / `Colors.blue[100]`
inline. This bundle = Cupertino→Lucide + Material `Card`→soft-shadow `AppCard` + lift role/status colors
into theme-aware tokens with dark parity.

## States & rules to preserve (don't design these away)

- **Admin-only.** Non-admin users get an "Access denied. Admin privileges required." screen — keep it.
- **Summary cards** (Total / Admins / Staff / Cashiers) count **active** users only; tapping Admins / Staff /
  Cashiers sets the role filter. Total is not tappable.
- **Filters:** app-bar **role filter** (`PopupMenuButton`, All Roles + the three roles) and a **show/hide
  inactive** toggle (eye / eye-slash). When either is active, a chip row appears with removable chips
  (`Admin ×`, `Showing inactive ×`) + a **Clear all** text button.
- **Sort:** active users first, then alphabetical by display name. Hidden-when-`!_showInactive`.
- **User row** = role-tinted avatar (role icon) + display name + email + **role badge** (icon + label, role
  color) + "Since {MMM d, y}". A blue **You** tag on the current user. Deactivated users render at **0.6
  opacity**, with **strikethrough** name and a red **Inactive** tag.
- **Role badges + semantics** — `admin` / `staff` / `cashier`, color-coded **admin = purple**, **staff = green**,
  **cashier = orange** (verify: these are the live swatches; cashier is orange, not green). Re-express as
  theme-aware role tokens with dark parity, keeping the three distinct hues.
- **Overflow / self-edit guards:** the 3-dot overflow (Deactivate / Reactivate) is **hidden for the current
  user's own row** — that row shows a chevron instead (no self-deactivate from the list). Tapping a row always
  opens the edit form.
- **Deactivate / Reactivate** = `AlertDialog` confirm ("{name} will no longer be able to log in." / "...able to
  log in again."), red **Deactivate** vs green **Reactivate** button, then a **warning** (deactivated) /
  **success** (reactivated) snackbar.
- **Form — create vs edit:**
  - Role-tinted avatar + role `displayName` label at top, recolors live with the picked role.
  - **Email** is editable on create, **locked (disabled)** when editing.
  - **Role picker** = three full-width cards (icon tile + name + description + check-circle when selected);
    descriptions are fixed per role (Cashier "POS operations only", Staff "POS, inventory, and receiving (no
    cost visibility)", Admin "Full access ... including user management").
  - **Password** + **Confirm Password** fields appear **only on create**, both obscured with eye-toggle suffix;
    confirm validates against password.
  - Editing shows a **Reset Password** text link (sends a reset email) instead of password fields.
  - Inline **error box** (red) for use-case failures + success snackbar on save.
- **Business guards** (last-admin, self-demote, self-deactivate) are enforced in the use-case / notifier layer
  and surfaced via the inline error box / snackbars — preserve the surfacing, don't move the logic.
- Dates `MMM d, y` ("Since Feb 14, 2026").

## Target language

Global theme tokens at `design/handoff/maki-theme/` + the patterns shipped in bundles 01–07: soft-shadow
`AppCard` rows, Lucide icons (`shield-half` admin / `tag` staff / `shopping-cart` cashier; `user-plus` add;
`more-vertical` overflow; `sliders-horizontal` filter; `eye` / `eye-off` toggle; `key-round` reset), and
**theme-aware role/status colors** lifted out of the hard-coded Material swatches into `AppColors`-style tokens
with `*OnDark` dark-parity variants (keep the three role hues distinct, plus success/active green + error red for
active/inactive). Neutral-by-default discipline: color only for the role badge, the You / Inactive tags, and the
deactivate action. App bar stays flat on canvas; the role picker becomes `AppCard`-style selectable rows.
