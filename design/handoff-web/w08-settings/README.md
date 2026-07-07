# MAKI POS Web Admin — Design Handoff w08: Settings

**Purpose.** A self-contained bundle showing the **current** web-admin UI of the five Settings
screens (plus their dialogs) so a design session can *see* what exists today and mark up what to
change. Hand the marked-up version back and it gets implemented in React (Vite + TypeScript +
Tailwind at `web_admin/`). Every screen here renders inside the shared AdminShell chrome (240px
sidebar, no top bar — each page owns its header), documented in bundle w01.

> ## ⚠️ Redesign constraint — read first
> **Redesign what is currently present in these screens. Nothing more, nothing less.**
> Do NOT remove any component: every section, table column, form field, button, banner, badge,
> filter, state (loading/empty/error/success/disabled/capped), dialog, and popover listed below
> must exist in the redesign. Do NOT add components: no new features, fields, actions, nav
> items, or data. **Single exception: charts/graphs MAY be added** if they visualize data
> already present on the screen. Role gating, copy, validation, and behavior are fixed —
> restyle freely, do not re-scope.

**What's in here**
- `current-ui.html` — open in any browser: a token-accurate static reconstruction of all five
  Settings screens (light theme, desktop, ~1280px including the sidebar) plus a **Modals &
  overlays** section drawing every dialog. No JS, no external requests.
- `README.md` (this file) — the design system, per-screen structure/copy/states/role rules, the
  modal specs, and a **"What I want" template** to fill in and hand back.

**Surfaces.** React web admin (`web_admin/src/presentation/features/settings/`):
- `SettingsPage.tsx` — Settings hub (`/settings`): profile + administration + general rows
- `CostCodeSettingsPage.tsx` — Cost codes (`/settings/cost-codes`): view/edit mapping, password-gated save
- `ManageListsPage.tsx` — Manage lists (`/settings/lists`): 4 category kinds, add/edit dialog
- `MechanicsPage.tsx` — Mechanics (`/settings/mechanics`): mechanics list, add/edit dialog
- `AboutPage.tsx` — About (`/settings/about`): version + technical info (static)
- `PageHeader.tsx` — shared back-link + title header (Cost codes & About)
- `ChangePasswordDialog.tsx`, `EditDisplayNameDialog.tsx` — profile dialogs mounted by the hub

Shared components restyled once, reused everywhere (see w01): `Dialog`, `LoadingView`/`Spinner`,
`ErrorView`, `EmptyState`, `toneBadgeClasses` (`core/theme/tones.ts`).

---

## ⚠️ Role gating — flag for the redesign

The web admin is **currently admin-only at the door**: `ProtectedRoute` bounces any signed-in
non-admin to `/access-denied` before per-route permission checks run. But the RBAC matrix
(`domain/permissions/Permission.ts`) is fully implemented underneath, and the redesign must keep
the per-role structure intact:

- `/settings` (hub) and `/settings/about` require only `viewSettings` — **cashier, staff, and
  admin all have it.** If the app were opened past the admin-only door, staff/cashier would reach
  the hub and About.
- `/settings/cost-codes`, `/settings/lists`, `/settings/mechanics` require `editCostCodeMapping`
  / `manageCategories` — **admin only.**
- **The hub's Administration section always renders all five rows regardless of role — there is
  NO role-conditional hiding in `SettingsPage`.** Gating is purely at the router: a
  staff/cashier tapping User management / Activity logs / Cost codes / Manage lists / Mechanics
  would bounce to Access Denied. *(Flag: the design may want to visually distinguish or hide
  admin-only rows for non-admins, but that is a re-scope — call it out, don't silently add it.)*
- **Cost-code save is additionally password-gated** (a fresh password re-verification via the
  PasswordConfirmDialog), on top of being admin-only.

---

## Design system (tokens these screens use)

Source of truth: `core/theme/tokens.ts` → Tailwind via `tailwind.config.ts`. Font: Roboto
(`@fontsource/roboto`), `ui-monospace` for cost-code / digit / preview mono text.

### Color
| Token | Hex | Use in this bundle |
|---|---|---|
| `light-text` | `#0A0A0A` | primary text; **also the "black" button fill** |
| `light-text-secondary` | `#666666` | subtitles, row subtitles, `dt` labels |
| `light-text-hint` | `#A0A0A0` | section labels (11px uppercase), hints, "(optional)", inactive names, timestamps |
| `light-background` | `#FFFFFF` | page/card bg; text on dark buttons |
| `light-subtle` / `light-surface` | `#FAFAFA` | hover fills, role pill bg, mono digit square, active tab |
| `light-card` | `#FFFFFF` | cards, dialogs, inputs |
| `light-hairline` / `light-divider` | `#EAEAEA` | card borders, row dividers, read-only code boxes |
| `light-border` | `#E0E0E0` | input borders, outlined buttons |
| `primary-dark` | `#121C1D` | avatar bg (profile card), dark-button hover |
| success | `#4CAF50` / light `#E8F5E9` / dark `#2E7D32` | success banners + `CheckCircleIcon` |
| error | `#F44336` / light `#FFEBEE` / dark `#C62828` | validation banner, inline field errors, error input border |
| Tone tints (`toneBadgeClasses`) | `bg-{tone}-50 text-{tone}-600` | Row icon squares: blue / red / violet / orange / green |

### Type scale (custom `fontSize`, px)
headingMedium 24/600 (page h1) · bodyLarge 18/400 (About app name) · bodyMedium 16/400 (row
titles, dialog titles, mono digit/letter) · bodySmall 14/400 (subtitles, inputs, list rows,
buttons) · plus ad-hoc `text-[11px]` (section labels, role pill), `[12px]` (hints, field errors),
`[26px]` (About "M" glyph). Mono = `font-mono` for digits, letters, codes, encoding preview.

### Spacing (`tk-*`) & radii
Spacing: `tk-xs 4 · tk-sm 8 · tk-md 16 · tk-lg 24 · tk-xl 32`. Page shell = `space-y-tk-xl
px-tk-xl py-tk-lg`. Radii: `rounded-md` (6px, buttons/inputs/nav/icon squares), `rounded-lg`
(8px, cards/dialogs), `rounded-full` (avatar, role pill). Dialog uses `shadow-xl`; cards carry no
shadow (weight = hairline + type).

### Buttons
- **Dark / primary:** `bg-light-text text-light-background hover:bg-primary-dark`, bodySmall
  semibold — Add, Edit mapping, Save changes, Save, Confirm, Change password. Spinner + "…"ing
  label + `disabled:opacity-60` while pending.
- **Outlined:** `border border-light-border … hover:bg-light-subtle` — Reset to default,
  dialog Cancel (lists/mechanics).
- **Ghost:** `hover:bg-light-subtle` no border — Cancel (cost-codes edit, password/profile dialogs).
- **Destructive:** none in this bundle.

### Card / list / row patterns
- **Card:** `rounded-lg border border-light-hairline bg-light-card`.
- **Divided list card:** add `divide-y divide-light-hairline`, rows `px-tk-md py-tk-sm`.
- **Section:** 11px uppercase-hint `<h2>` label + a bordered (often divided) card.
- **Row (hub):** 9×9 tone-tinted icon square + title (bodyMedium) + optional subtitle
  (bodySmall secondary) + trailing `ChevronRightIcon` hint. Link / button / disabled variants.

---

## Screen 1 — Settings hub (`/settings`)

**Job:** landing page for account self-service + administration links + app info. Renders `null`
if no signed-in user.

**Layout top → bottom:**
1. **Header** — h1 "Settings"; subtitle "Account, administration, and app information."
2. **Success banner** (green) — appears after a profile change: "Password updated." or "Display
   name updated." Auto-clears after 4s. (`border-success-light bg-success-light/40 text-success-dark`.)
3. **Section "My profile"** (divided card):
   - **Profile card** — 12×12 `bg-primary-dark` avatar showing the email's first letter (white,
     bodyMedium semibold); displayName-or-email (bodyMedium semibold); email (bodySmall
     secondary); **role pill** — `bg-light-subtle` rounded-full, 11px uppercase, **plain grey
     (NOT tone-colored here)**, text = Admin/Staff/Cashier.
   - **Row "Display name"** — `UserIcon`, tone **blue**; subtitle = current displayName or "—";
     opens Edit display name dialog.
   - **Row "Change password"** — `KeyIcon`, tone **red**; subtitle "Update your sign-in
     password"; opens Change password dialog.
4. **Section "Administration"** (divided card — **all five rows always render, no role guard**):
   - **User management** — `UsersIcon`, blue → `/users`; "Add, edit, and manage users".
   - **Activity logs** — `ClockIcon`, violet → `/logs`; "View user activity and audit trail".
   - **Cost code settings** — `CodeBracketSquareIcon`, orange → `/settings/cost-codes`;
     "Configure cost encoding".
   - **Manage lists** — `QueueListIcon`, blue → `/settings/lists`; "Categories, units, and
     other dropdown values".
   - **Mechanics** — `WrenchScrewdriverIcon`, orange → `/settings/mechanics`; "Mechanics for
     labor on service sales".
5. **Section "General"** (divided card):
   - **About** — `InformationCircleIcon`, green → `/settings/about`; "App version and info".

**States:** no dedicated loading/error — reads `user` synchronously from `authStore`; only the
transient success banner. **Per-role:** admin sees everything. Staff/cashier can't currently
reach it (admin-only door); if reached, they'd see profile + About but the five Administration
rows would bounce to Access Denied. **Icons:** User, Key, Users, Clock, CodeBracketSquare,
QueueList, WrenchScrewdriver, InformationCircle, ChevronRight (heroicons 24/outline).

---

## Screen 2 — Cost codes (`/settings/cost-codes`)  *(admin only)*

**Job:** view/edit the digit→letter cost-encoding mapping (so product costs read as letters,
hidden from non-admins). Saves require a fresh password re-verification.

**Layout top → bottom:**
1. **Header row** — `PageHeader` (back link "Settings" + `ArrowLeftIcon`) title "Cost codes" /
   "Encode product costs as letters so they're hidden from non-admins." Right action buttons:
   - **View mode:** **Reset to default** (outlined, `ArrowPathIcon`) + **Edit mapping** (dark,
     `PencilSquareIcon`).
   - **Edit mode:** **Cancel** (ghost) + **Save changes** (dark). Both disabled while a save is
     pending.
2. **Save-success banner** (green, `CheckCircleIcon`) "Cost code mapping saved." (4s).
3. **Validation-error banner** (red) — e.g. "Letter for digit 3 cannot be empty", "Letter for
   digit 3 must be one character", "Each digit must map to a unique letter (B repeats)", "Double-
   zero code cannot be empty", "Triple-zero code cannot be empty", "Already using the default
   mapping".
4. **Section "Digit → letter mapping"** — card with a **grid (2-col / sm:5-col) of 10
   MappingCells**, one per digit 0–9. Each cell: 9×9 mono digit square (`bg-light-subtle`) →
   `ArrowRightIcon` → letter box. Letter box is an editable 1-char uppercase input (12-wide) in
   edit mode, else a read-only hairline box showing the letter or "—".
5. **Section "Special codes"** — card with two **SpecialCodeRows**: "00" Double zero, "000"
   Triple zero. Mono digits → arrow → code (editable maxLength-4 uppercase input, or read-only
   box) → right-aligned grey label.
6. **Section "Encoding preview"** — divided card, six sample rows: 99 / 125 / 500 / 1,000 /
   1,234 / 10,000 → `formatMoney` → `ArrowRightIcon` → encoded result (mono, bold). Live-updates
   with edits.
7. **PasswordConfirmDialog** (mounted; see Modals).

**States:** error → `ErrorView "Could not load cost codes"`; loading → `LoadingView "Loading cost
codes…"`. **Per-role:** admin only (route bounces others). **Icons:** ArrowPath, PencilSquare,
CheckCircle, ArrowRight.

---

## Screen 3 — Manage lists (`/settings/lists`)  *(admin only)*

**Job:** admin-managed dropdown values used across the app (4 kinds).

**Layout top → bottom:**
1. **Header** — h1 "Manage Lists"; subtitle "Admin-managed dropdown values used across the app."
   Right: **Add** button (dark, `PlusIcon`).
2. **Segmented kind tabs** — bordered pill container, 4 tabs: **Product categories · Units ·
   Expense categories · Void reasons**. Active tab = `bg-light-subtle` semibold; inactive =
   secondary text.
3. **Content** — one of: `ErrorView "Could not load list"` / `LoadingView "Loading…"` /
   `EmptyState "No entries yet" · "Add the first entry for this list."` / **list card**.
4. **List** — divided `<ul>`; each row: name (bodySmall) — **inactive** rows render
   `text-light-text-hint line-through` with " (inactive)" appended. Right buttons: **Edit**
   (`PencilIcon`) + **Deactivate / Reactivate** toggle (`EyeSlashIcon` when active /
   `EyeIcon` when inactive). Both disabled while any mutation is busy.
5. **Add/Edit entry dialog** (mounted; see Modals).

**States:** error / loading / empty / populated (above); buttons disabled during mutation.
**Per-role:** admin only. **Icons:** Plus, Pencil, EyeSlash, Eye.

---

## Screen 4 — Mechanics (`/settings/mechanics`)  *(admin only)*

**Job:** mechanics available for the labor picker on service sales. Same list pattern as Manage
lists, with a secondary contact/address line per row.

**Layout top → bottom:**
1. **Header** — h1 "Mechanics"; subtitle "Mechanics available for the labor picker on service
   sales." Right: **Add** button (dark, `PlusIcon`).
2. **Content** — `ErrorView "Could not load mechanics"` / `LoadingView "Loading…"` /
   `EmptyState "No mechanics yet" · "Add the first mechanic."` / **list card**.
3. **List** — divided `<ul>`; each row: name (bodySmall, truncated; inactive = hint +
   line-through + " (inactive)"); **secondary line** joining `contactNumber · address` (12px
   secondary, shown only if either present). Right buttons: **Edit** (`PencilIcon`) +
   **Deactivate / Reactivate** (`EyeSlashIcon`/`EyeIcon`), disabled while busy.
4. **Add/Edit mechanic dialog** (mounted; see Modals).

**States:** error / loading / empty / populated; buttons disabled during mutation. **Per-role:**
admin only. **Icons:** Plus, Pencil, EyeSlash, Eye.

---

## Screen 5 — About (`/settings/about`)  *(all roles per matrix)*

**Job:** static version + technical info. No interactive state, no modals.

**Layout top → bottom:**
1. **Header** — `PageHeader` (back "Settings") title "About" / "Version and technical
   information."
2. **App card** (centered, `p-tk-xl`) — 16×16 bordered **"M" glyph** badge (26px semibold);
   "MAKI POS Admin" (bodyLarge semibold); "Version 1.0.0".
3. **Section "About this app"** — card with descriptive paragraph: "A web admin for the MAKI POS
   system, used for inventory management, sales reporting, and store administration. Sales
   transactions are entered through the mobile POS app and synchronised in real time via
   Firestore."
4. **Section "Technical"** — divided `<dl>` label/value rows: Platform = React + TypeScript ·
   Bundler = Vite 6 · Backend = Firebase (Auth + Firestore + Storage) · Currency = Philippine
   Peso (₱) · Project = maki-mobile-pos.
5. **Footer** — "© {year} MAKI POS · All rights reserved" (11px hint, centered).

**Per-role:** requires only `viewSettings`, so reachable by all roles per the matrix (currently
gated behind the admin-only door). No modals.

---

## Modals & overlays

All use the shared `Dialog` (portal, `bg-black/30` backdrop, `max-w-md` card, `rounded-lg border
border-light-hairline bg-light-card shadow-xl`; header = title bodyMedium-semibold + optional
description + `XMarkIcon` close). ESC + click-outside close **only when dismissable**; body
scroll locked while open.

1. **Change password dialog** (`ChangePasswordDialog`, from hub) — title "Change password",
   description "Enter your current password, then choose a new one." Fields (all type=password):
   **Current password** (autofocus), **New password** (≥6 chars), **Confirm new password** (must
   match). Wrong current password → **inline field error "Current password is incorrect"**; other
   failures → generic error line (text-error). Buttons: **Cancel** (ghost) + **Change password**
   (dark; Spinner + "Updating…" while pending). Non-dismissable while pending.

2. **Edit display name dialog** (`EditDisplayNameDialog`, from hub) — self-edit only. Title "Edit
   display name", description "The name shown next to your sign-ins and audit log entries." Single
   **Display name** field (≥2 chars, autofocus). Update error text below. No-op close if
   unchanged. Buttons: **Cancel** (ghost) + **Save** (dark; Spinner + "Saving…"). Non-dismissable
   while pending.

3. **Password confirm dialog** (cost codes; `PasswordConfirmDialog`) — two variants:
   - **Save:** title "Save cost code changes", description "Enter your password to save these
     changes."
   - **Reset:** title "Reset to default", description "Enter your password to reset the mapping
     to the original values."
   Single **Password** field (autofocus, current-password). Error line (text-error) on wrong
   password. Buttons: **Cancel** (ghost) + **Confirm** (dark; Spinner + "Confirming…"; disabled
   until a password is typed). Non-dismissable while pending.

4. **Add / Edit entry dialog** (Manage lists) — title "Add entry" / "Edit entry". Field: **Name**
   (text, autofocus). **Edit mode adds an "Active" checkbox.** Buttons: **Cancel** (outlined) +
   **Save** (dark; Spinner while busy; disabled if name empty). Non-dismissable while busy.

5. **Add / Edit mechanic dialog** (Mechanics) — title "Add mechanic" / "Edit mechanic". Fields:
   **Name** (text, autofocus), **Contact number** (type=tel, labeled "(optional)"), **Address**
   (textarea rows=2, resize-none, "(optional)"). **Edit mode adds an "Active" checkbox.** Blank
   optional fields collapse to null on save. Buttons: **Cancel** (outlined) + **Save** (dark;
   Spinner; disabled if name empty). Non-dismissable while busy.

---

## What I want  *(fill this in, then hand back)*

Leave anything blank you don't care about. Specifics beat vibes — name the screen + region + the
change.

### Direction
- Overall: keep the vertical stacked-section hub, or rethink navigation (e.g. tabs / two-column)? →
- Reference apps / settings pages you like the look of →

### Settings hub
- Profile card — keep the round avatar-initial + grey role pill, or a richer profile header? →
- Rows — icon-square + chevron list rows: keep, or group into a cleaner settings grid/cards? →
- Should admin-only Administration rows look different for (future) staff/cashier, or stay identical? *(re-scope — flag only)* →
- Success banner treatment (password/name updated) →

### Cost codes
- Mapping grid — 10 digit→letter cells: keep the 2/5-col grid, or a tighter table / keypad look? →
- Edit vs view affordance — inline edit toggle vs a dedicated edit surface? →
- Special codes (00 / 000) and Encoding preview — layout & emphasis →
- Password-confirm step — keep as a dialog, or inline? *(behavior is fixed — must stay password-gated)* →

### Manage lists & Mechanics
- Segmented kind tabs (lists) — pill tabs vs dropdown vs sidebar sub-nav? →
- List rows — inactive strike-through + Edit/Deactivate buttons: keep, or row-menu / toggle switch? →
- Mechanics secondary contact/address line — layout →

### About
- App card + Technical `<dl>` — keep, or a leaner single card? →

### Constraints / must-keep
- **Role gating is fixed:** hub + About = `viewSettings` (all roles); cost-codes / lists /
  mechanics = admin-only; cost-code save is additionally password-gated. Administration section
  currently renders all rows regardless of role (gating at router) — don't silently hide/add. →
- All five dialogs must stay, with their exact titles, fields, validation copy, and pending/lock
  behavior (Change password, Edit display name, Password confirm ×2 variants, Add/Edit entry,
  Add/Edit mechanic). →
- All states must stay: success banners, validation banner, ErrorView, LoadingView, EmptyState,
  disabled-while-busy buttons, inactive strike-through rows. →
- Copy, field labels, validation messages, "(optional)" markers, and encoding-preview samples
  are fixed. →

---

*Bundles: w01-shell-login-dashboard · w02-pos-drafts · w03-inventory · w04-receiving ·
w05-suppliers · w06-reports · w07-users · **w08-settings (this)** · w09-logs.*
