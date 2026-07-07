# MAKI POS Web Admin — Design Handoff w07: Users

**Purpose.** A self-contained bundle showing the **current** web-admin UI of the two Users screens
(Users list + User form) plus their row popover and confirm dialog, so you (or a design session) can
*see* what exists today and mark up what you want changed. Hand the marked-up version back and I'll
implement it in React (Vite + Tailwind) inside the existing `AdminShell` chrome.

> ## ⚠️ Redesign constraint — read first
> **Redesign what is currently present in these screens. Nothing more, nothing less.**
> Do NOT remove any component: every section, table column, form field, button, banner, badge,
> filter, state (loading/empty/error/success/disabled/capped), dialog, and popover listed below
> must exist in the redesign. Do NOT add components: no new features, fields, actions, nav
> items, or data. **Single exception: charts/graphs MAY be added** if they visualize data
> already present on the screen. Role gating, copy, validation, and behavior are fixed —
> restyle freely, do not re-scope.

**What's in here**
- `current-ui.html` — open in any browser: a token-accurate reconstruction of both Users screens in
  light theme, rendered at ~1280px including the 240px sidebar (Users nav item active), plus a
  **Modals & overlays** section for the row popover and the deactivate/reactivate confirm dialog.
- `README.md` (this file) — the design system, per-screen structure/copy/states/role rules, and a
  **"What I want" template** to fill in.

**Surfaces.** React web admin (`web_admin/`):
- `src/presentation/features/users/UsersListPage.tsx` — Users list: header, summary tiles, role
  filter + show-inactive toggle, table, row menu, deactivate/reactivate dialog. (Local components:
  `SummaryTile`, `UsersTable`, `UserRow`, `RowMenu`, `Th`.)
- `src/presentation/features/users/UserFormPage.tsx` — combined Add / Edit form (avatar banner, email
  + display name, role picker, password / reset section). (Local components: `Field`, `inputCls`.)
- `src/presentation/features/users/RoleBadge.tsx` — tonal role pill (admin/staff/cashier).

Shared components used: `LoadingView` / `Spinner`, `ErrorView`, `EmptyState`, `Dialog`
(`src/presentation/components/common/*`), tonal palette `src/core/theme/tones.ts`.

**Whole feature is admin-only.** `ProtectedRoute` redirects any signed-in user whose `role !== 'admin'`
to `/access-denied` before the per-route check, so a staff/cashier never renders `/users`,
`/users/add`, or `/users/edit/:id` on the web. In-page rules for admins: you can't deactivate your own
row (no ellipsis menu on the self row) and you can't change your own role (other role cards locked in
edit-self mode).

---

## Design system (tokens used by these screens)

Full token source: `web_admin/src/core/theme/tokens.ts` → Tailwind via `tailwind.config.ts`.
Font: **Roboto** (`@fontsource/roboto` 300/400/500/700); mono `ui-monospace, Menlo`.

### Color

| Token | Hex | Use here |
|---|---|---|
| `light-background` | `#FFFFFF` | page / sidebar bg; text on dark buttons |
| `light-card` | `#FFFFFF` | cards, table, dialog, inputs |
| `light-subtle` / `light-surface` | `#FAFAFA` | table header row, hover fills, active tile bg, "You"/filter pills |
| `light-hairline` / `light-divider` | `#EAEAEA` | card borders, table dividers, row-menu border |
| `light-border` | `#E0E0E0` | input & outlined-button borders |
| `light-text` | `#0A0A0A` | primary text; also the dark **button fill** + active-tile/selected-card border |
| `light-text-secondary` | `#666666` | secondary text, subtitles, email, inactive status label |
| `light-text-hint` | `#A0A0A0` | field hints, self-role-locked note |
| `primary-dark` | `#121C1D` | avatar bg (white initials); dark-button hover |
| success base/light/dark | `#4CAF50` / `#E8F5E9` / `#2E7D32` | reset-sent banner; Active status text (dot `#16a34a`) |
| error base/light/dark | `#F44336` / `#FFEBEE` / `#C62828` | mutation-error banner/text; Deactivate confirm button; Deactivate menu item |

Role tones (`tones.ts` `toneBadgeClasses`, standard Tailwind scale = tinted bg + saturated text):
- **admin → violet** `bg-violet-50 text-violet-600` (`#F5F3FF` / `#7C3AED`)
- **staff → green** `bg-green-50 text-green-600` (`#F0FDF4` / `#16A34A`)
- **cashier → blue** `bg-blue-50 text-blue-600` (`#EFF6FF` / `#2563EB`)

Inactive status dot = `#A3A3A3`. Inactive table rows render at `opacity-60`.

### Type scale (px / weight)
headingMedium 24/600 (h1) · headingSmall 20/600 (tile values) · bodyMedium 16/400-500-600 (names,
row titles) · bodySmall 14/400 (subtitles, body, buttons) · badge / `text-[11px]` 600 uppercase (role
pill, table headers) · `text-[12px]` (email, last-sign-in, hints, field errors) · `text-[10px]`
uppercase ("You" pill). Numerics use `tabular-nums`.

### Spacing / radius / shadow
tk scale: `tk-xs 4 · tk-sm 8 · tk-md 16 · tk-lg 24 · tk-xl 32`. Page shell =
`space-y-tk-xl px-tk-xl py-tk-lg`. Radii: `rounded-md` (6px) inputs/buttons/menu, `rounded-lg` (8px)
cards/tiles/dialog, `rounded-full` avatars/pills/status-dot. Shadows: none on cards; `shadow-lg` on
the row popover, `shadow-xl` on the Dialog.

### Buttons
- **Dark (primary):** `bg-light-text text-light-background hover:bg-primary-dark`, `rounded-md`,
  bodySmall semibold. (Add user, Create user / Save changes, Reactivate confirm.)
- **Destructive:** `bg-error text-white hover:bg-error-dark` (Deactivate confirm).
- **Outlined:** `border border-light-border … hover:bg-light-subtle` (Show/Hide inactive, Send reset
  email).
- **Ghost:** `hover:bg-light-subtle`, no border (Cancel, Edit link, ellipsis, eye toggles).
- Disabled = `opacity-60` (+ `cursor-not-allowed` on submit / locked role cards). Pending buttons show
  an inline `Spinner`.

### Card / table pattern
Card = `rounded-lg border border-light-hairline bg-light-card`. Table wrapped in that card
(`overflow-hidden`); header row `bg-light-subtle` with uppercase `text-[11px]` headers; body rows
`divide-y divide-light-hairline`; Actions column right-aligned.

---

## Screen 1 — Users list (`/users`) · admin-only

**Job.** Manage admin/staff/cashier accounts: at-a-glance counts, filter by role, show/hide
deactivated users, and per-row edit / deactivate / reactivate.

**Layout, top → bottom**
1. **Header** — h1 **"Users"** + subtitle "Add, edit, and manage admin users and staff accounts."
   Right: **Add user** button (dark fill, `PlusIcon` 14px) → `/users/add`.
2. **Summary tiles** — grid `grid-cols-2 sm:grid-cols-4`. Four clickable filter tiles (`SummaryTile`):
   **Total active**, **Admins**, **Staff**, **Cashiers**. Value = headingSmall tabular-nums (counts
   over active users only). Clicking a tile sets the role filter; the active tile gets
   `border-light-text bg-light-subtle` (Total active = the "no filter" state). Others =
   `border-light-hairline bg-light-card hover:bg-light-subtle`.
3. **Filter row** — when a role filter is active, a removable pill (`bg-light-subtle` rounded-full,
   role name + "×") clears it. Then a **Show inactive / Hide inactive** toggle button (outlined) with
   `EyeIcon` / `EyeSlashIcon`.
4. **Content** — the users table (below), or a state (loading / empty / error).

**Table columns** (`UsersTable` → `UserRow`; header cells `Th`, uppercase 11px):

| Column | Content |
|---|---|
| **User** | 9×9 `rounded-full bg-primary-dark` avatar with white initial; display name (bodyMedium medium) + **"You"** pill (`bg-light-subtle`, 10px uppercase) on the self row; email (`text-[12px]` secondary). Name falls back to "—". |
| **Role** | `RoleBadge` — rounded-full 11px semibold uppercase, tone-tinted: admin=violet, staff=green, cashier=blue. |
| **Last sign-in** | `en-PH` medium date + short time, or **"—"** when never signed in. |
| **Status** | dot + label — **Active** = `text-success-dark`, dot `#16a34a`; **Inactive** = secondary text, dot `#a3a3a3`. |
| **Actions** (right) | **Edit** link (`PencilIcon`) → `/users/edit/:id`; and, **only when not the self row**, an `EllipsisHorizontalIcon` "More actions" button that toggles the `RowMenu` popover. |

Inactive rows render the whole `<tr>` at `opacity-60`.

**UI states**
- **Loading** → `LoadingView` "Loading users…" (centered spinner + label).
- **Empty** (no rows after filter) → `EmptyState` title "No users found", description "Try clearing the
  filter or adding a new user."
- **Error** → `ErrorView` title "Could not load users" + message (replaces the whole page body).

**Per-role differences.** Admin-only route. Staff/cashier never reach it (bounced to `/access-denied`).
Self row: no ellipsis menu (can't self-deactivate); Edit link still shown.

**Icons** (heroicons 24/outline): Plus, Eye, EyeSlash, Pencil, EllipsisHorizontal, UserMinus,
UserPlus, User.

---

## Screen 2 — User form (`/users/add` & `/users/edit/:id`) · admin-only

**Job.** One component covering both create and edit. Create needs email + display name + role +
password; edit reuses the same layout but locks email, drops the password fields for a "send reset
email" card, and locks the self-role.

**Layout, top → bottom**
1. **Header** — back link **"Users"** (`ArrowLeftIcon`) → `/users`; h1 **"New user"** (create) /
   **"Edit user"** (edit).
2. **Avatar / role banner** card — 12×12 `bg-primary-dark` initial; name (or "New account" on create /
   "—" on edit) over email (or placeholder "Choose a role and email below"); right-side **role pill**
   tinted to the *selected* role (violet / green / blue, 11px uppercase). Updates live as the role
   picker changes.
3. **Mutation-error** banner — `border-error-light bg-error-light/40 text-error-dark`, shown on
   create/update failure.
4. **Reset-sent** success banner — green, `CheckCircleIcon`, "Password reset email sent to {email}."
   (edit mode, after Send reset email).
5. **Fields grid** (`grid-cols-1 sm:grid-cols-2`):
   - **Email** (`type=email`). **Disabled in edit mode** → `bg-light-subtle` fill + hint "Email can't
     be changed after creation." Validation: required + valid email.
   - **Display name** (text). Validation: ≥ 2 chars.
6. **Role fieldset** (legend "Role") — three selectable **role cards** stacked: admin / staff /
   cashier. Each card = 9×9 tone-tinted square with the uppercase initial + role name (bodyMedium
   semibold) + description:
   - admin — "Full access including user management and cost visibility"
   - staff — "POS, inventory, receiving (no cost visibility)"
   - cashier — "POS operations only"
   Selected card = `border-light-text bg-light-subtle` + trailing `CheckCircleIcon`. **When editing
   your own account**, the other role cards are disabled (`opacity-60`, `cursor-not-allowed`) and a
   hint reads "You can't change your own role. Ask another admin if you need this."
7. **Password section** — mode-dependent:
   - **Create:** grid of **Password** + **Confirm password** inputs, each with a show/hide eye toggle
     (`EyeIcon` / `EyeSlashIcon`), `autocomplete=new-password`. Validation: password ≥ 6, confirm must
     match ("Passwords do not match").
   - **Edit:** a **Reset password** card — title + subtitle "Sends a Firebase reset email so the user
     can choose a new one." + **Send reset email** button (outlined; `Spinner` + "Sending…" while
     pending); error text below on failure.
8. **Footer actions** — **Cancel** link → `/users`; **submit** button (dark) reading **"Create user"**
   / **"Save changes"**, → `Spinner` + "Saving…" while submitting.

**Field styling.** Shared `inputCls`: `rounded-md border`, focus ring = `outline-light-text`; error
state = `border-error` + 12px `text-error` message; hints in `text-light-text-hint`. Auth-error mapping:
`email-already-in-use` → email field error "This email is already in use"; `weak-password` → password
field error "Password is too weak".

**UI states**
- **Loading** (edit) → `LoadingView` "Loading user…".
- **Error** (edit, load failed) → `ErrorView` title "Could not load user" + message.
- **Submitting** → submit button spinner + "Saving…", disabled.
- **Reset pending** → Send-reset button spinner + "Sending…", disabled.

**Per-role differences.** Admin-only route (both add and edit). The only in-page role branch is the
**edit-self** case: role cards other than the current role are locked, per above.

**Icons** (heroicons 24/outline): ArrowLeft, CheckCircle, Eye, EyeSlash.

---

## Modals & overlays

### Row popover — `RowMenu` (Users list)
Absolute dropdown under the ellipsis button: `w-44`, `rounded-md border border-light-hairline
bg-light-card shadow-lg`, closes on outside mousedown. Contents:
- **Deactivate** (`UserMinusIcon`, `text-error-dark`, hover `bg-error-light/40`) — shown when the user
  is active; **or Reactivate** (`UserPlusIcon`, neutral text) — shown when inactive.
- **View details** (`UserIcon`) — divider above; → `/users/edit/:id`.
Never rendered on the self row (no ellipsis trigger there).

### Deactivate / Reactivate confirm — `Dialog`
Portaled modal: `bg-black/30` overlay, `max-w-md` card (`rounded-lg border border-light-hairline
bg-light-card shadow-xl`). Header = title + description + `XMarkIcon` close (close hidden while
pending). Copy variants:
- **Deactivate user** — "{name or email} will no longer be able to sign in."
- **Reactivate user** — "{name or email} will be able to sign in again."
Optional mutation-error line (`text-error`) above the buttons. Footer: **Cancel** (ghost) + confirm —
**Deactivate** = `bg-error text-white hover:bg-error-dark`; **Reactivate** = dark
`bg-light-text`. Confirm shows an inline `Spinner` while pending; the dialog is **non-dismissable while
pending** (ESC / click-outside / close-button all blocked, Cancel disabled).

---

## What I want *(fill this in, then hand back)*

Leave anything blank you don't care about. Specifics beat vibes — name the screen + region + the change.

### Direction
- Overall: keep the current flat/hairline table language, or push toward cards / a denser data grid? →
- Reference apps / dashboards you like the look of →

### Users list
- **Summary tiles** — keep 4 clickable filter tiles, or a segmented count strip / add a small chart of
  role mix? (A role-distribution chart is the one allowed *addition*, since the counts already exist.) →
- **Table** — hero column (avatar+name)? Row density? Keep avatar circles or initials-only? →
- **Role badge** — keep tone-tinted pills (violet/green/blue), or a quieter neutral treatment? →
- **Status** — dot + word, or a pill / colored row treatment? Inactive = `opacity-60` — keep or restyle? →
- **Row actions** — inline Edit + ellipsis menu, or a single kebab menu? Popover styling? →
- **Filter row** — keep the removable role pill + Show/Hide-inactive toggle, or a filter bar? →

### User form
- Single scroll vs grouped cards ("Identity · Role · Password")? →
- **Avatar/role banner** — keep the live-updating role pill, or rethink the header? →
- **Role picker** — three stacked cards vs a segmented control / radio list; how prominent should the
  descriptions be? →
- **Password vs reset** — create-mode dual password fields and edit-mode reset card — layout changes? →
- Field surfaces — outlined inputs vs filled; disabled (email in edit, locked role cards) treatment? →
- Footer — inline Cancel + submit vs a pinned action bar? →

### Constraints / must-keep
- **Admin-only** whole feature (staff/cashier bounce to `/access-denied`) — unchanged. →
- In-page rules: **no self-deactivate** (no ellipsis menu on self row) and **no self-role-change**
  (locked role cards + hint in edit-self) — unchanged. →
- All table columns (User / Role / Last sign-in / Status / Actions) and the "You" pill, "—" fallbacks. →
- All form fields + validation + auth-error mapping (email-in-use, weak-password); email disabled in
  edit; password ≥6 + confirm match on create; Send-reset flow on edit. →
- Row popover (Deactivate/Reactivate + View details) and the confirm Dialog with **both copy variants**,
  red-vs-dark confirm buttons, pending spinner, and **non-dismissable-while-pending** behavior. →
- All states: loading / empty ("No users found") / error ("Could not load users" / "Could not load
  user") / reset-sent success banner / mutation-error banners. →

---

*Bundles: w01-shell-login-dashboard · w02-pos-drafts · w03-inventory · w04-receiving · w05-suppliers ·
w06-reports · **w07-users (this)** · w08-settings · w09-logs — one bundle at a time, per
`design/handoff-web/ROADMAP.md`.*
