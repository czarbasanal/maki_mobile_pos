# MAKI POS Web Admin — Design Handoff w05: Suppliers

**Purpose.** A self-contained bundle showing the **current** web-admin UI of the Suppliers feature
(supplier directory + add/edit form) so a design session can *see* what exists today and mark up what
should change. Hand the marked-up version back and it gets implemented in React (Vite + TypeScript +
Tailwind, `web_admin/`). This bundle is desktop, light-theme only — the theme the web admin actually ships.

> ## ⚠️ Redesign constraint — read first
> **Redesign what is currently present in these screens. Nothing more, nothing less.**
> Do NOT remove any component: every section, table column, form field, button, banner, badge,
> filter, state (loading/empty/error/success/disabled/capped), dialog, and popover listed below
> must exist in the redesign. Do NOT add components: no new features, fields, actions, nav
> items, or data. **Single exception: charts/graphs MAY be added** if they visualize data
> already present on the screen. Role gating, copy, validation, and behavior are fixed —
> restyle freely, do not re-scope.

**Note on scope.** The inventory that seeded this bundle also covered **Expenses** and **Petty Cash**, but
those are unbuilt placeholder routes (they render the shared `PagePlaceholder` "Not available yet", planned
phase 9) — they have no screen to restyle and are **excluded** here. Only **Suppliers** is in scope.

**What's in here**
- `current-ui.html` — open in any browser: a token-accurate reconstruction of both Suppliers screens
  (list + form) plus the modals/overlays, each rendered inside the 240px admin sidebar chrome, light theme.
- `README.md` (this file) — the design system, per-screen structure/copy/states/role rules, the
  modals section, and a **"What I want" template** to fill in and hand back.

**Surfaces.** React web admin:
- `web_admin/src/presentation/features/suppliers/SuppliersListPage.tsx` — list, search, show/hide-inactive, table, deactivate flow
- `web_admin/src/presentation/features/suppliers/SupplierFormPage.tsx` — add / edit supplier (single component, both modes)

Shared components reused: `LoadingView`/`Spinner`, `ErrorView`, `EmptyState`, `Dialog` (all from
`web_admin/src/presentation/components/common/`); `Sidebar` + `AdminShell` chrome; enum labels from
`domain/enums/TransactionType.ts`.

---

## Design system (tokens in `web_admin/src/core/theme/tokens.ts`, surfaced via `tailwind.config.ts`)

### Colors used by these screens
| Token | Hex | Use here |
|---|---|---|
| `light-text` | `#0A0A0A` | primary text; also the **dark button fill** ("Add supplier", "Save"/"Create") |
| `light-text-secondary` | `#666666` | subtitles, contact number, terms cell, inactive-status label |
| `light-text-hint` | `#A0A0A0` | address line, inventory value, section labels, dashes |
| `light-background` | `#FFFFFF` | page / sidebar / dark-button text |
| `light-card` | `#FFFFFF` | cards, table body, dialog, inputs |
| `light-subtle` | `#FAFAFA` | table header row, hover fills, search focus target |
| `light-hairline` / `light-divider` | `#EAEAEA` | card borders, row dividers |
| `light-border` | `#E0E0E0` | input + toggle-button borders |
| `primary-dark` | `#121C1D` | dark-button hover |
| success base / dark | `#4CAF50` / `#2E7D32` | active-status text (`text-success-dark`); dot uses literal `#16a34a` |
| error base / light / dark | `#F44336` / `#FFEBEE` / `#C62828` | Deactivate button fill (`bg-error`, hover `bg-error-dark`), destructive menu item (`text-error-dark`, hover `bg-error-light/40`), error banner + inline error text |
| inactive dot | `#a3a3a3` (literal) | gray status dot for inactive rows |

### Type scale (custom `fontSize`; px / weight)
`headingMedium` 24/600 (page `h1`) · `bodyMedium` 16/400 (supplier name, dialog title @ semibold) ·
`bodySmall` 14/400 (most body, buttons, inputs) · ad-hoc `text-[11px]` (uppercase table headers +
section labels, semibold) · `text-[12px]` (address, contact number, inventory value, status label, field errors).

### Spacing (custom `tk-*`) & radii
Spacing: `tk-xs` 4 · `tk-sm` 8 · `tk-md` 16 · `tk-lg` 24 · `tk-xl` 32 · `tk-xxl` 48.
Radii (Tailwind defaults): `rounded-md` 6px (inputs, buttons, nav items, popover) · `rounded-lg` 8px
(cards, table shell, dialog) · `rounded-full` (status dots). Shadows: `shadow-lg` (row popover),
`shadow-xl` (Dialog); cards/table carry no shadow — weight is hairline + type only.

### Button styles
- **Primary / CTA** — dark fill `bg-light-text` (#0A0A0A), white text, hover `bg-primary-dark`; `disabled:opacity-60`. (Add supplier, Save changes / Create supplier.)
- **Outlined** — `border border-light-border`, transparent fill, hover `bg-light-subtle`. (Show/Hide inactive toggle.)
- **Ghost** — no border/fill, hover `bg-light-subtle`. (Edit link, Cancel, row popover trigger.)
- **Destructive** — `bg-error` white text, hover `bg-error-dark`, `disabled:opacity-60`; shows `Spinner` while pending. (Deactivate confirm.)

### Table pattern
Rounded hairline card (`overflow-hidden rounded-lg border border-light-hairline bg-light-card`); header row
`bg-light-subtle` with uppercase `text-[11px]` semibold labels; body rows divided by `divide-light-hairline`;
numerics right-aligned + `tabular-nums`; inactive rows dimmed `opacity-60`.

### Card / form pattern
Form is grouped into **Sections** = uppercase `text-[11px]` hint heading over a bordered card
(`rounded-lg border border-light-hairline bg-light-card p-tk-md`). Each **Field** = `text-bodySmall`
medium label + input + optional `text-[12px]` error line. Inputs: `rounded-md border border-light-border`,
focus adds a real 1px `outline`/`border` in `light-text` (no glow); error variant switches border+outline to `error`.

---

## Screen 1 — Suppliers list  (`/suppliers`)

**Job.** Vendor directory "used by inventory and receiving" — search, browse, jump to add/edit, and deactivate
a supplier. Mirrors the Flutter `suppliers_screen.dart`. Sets `document.title = "Suppliers · MAKI POS Admin"`.
Data via `useSuppliers()`; per-row `useDeactivateSupplier()`.

**Layout, top → bottom:**
1. **Header row** (`flex justify-between`, wraps) — left: `h1` **"Suppliers"** (headingMedium semibold) + subtitle
   *"Vendor directory used by inventory and receiving."* (bodySmall, secondary). Right: dark **"Add supplier"**
   button (`PlusIcon` h-3.5) → `/suppliers/add`.
2. **Toolbar row** (`flex gap`) —
   - **Search input** (flex-1, `max-w-md`) with leading `MagnifyingGlassIcon`; placeholder
     *"Search by name, contact, email, phone…"*. Filters client-side across name / contactPerson / email / contactNumber.
   - **Show/Hide inactive toggle** (outlined button): `EyeIcon` + **"Show inactive"** when inactive are hidden;
     `EyeSlashIcon` + **"Hide inactive"** when shown. Default **hides** inactive.
3. **Body** — one of: table (populated) · `LoadingView` · `EmptyState` · `ErrorView` (see states).

**Table columns** (left→right): **Supplier** · **Contact** · **Terms** · **Inventory** (right-aligned) ·
**Status** · **Actions** (right-aligned).

**Row cells:**
- **Supplier** — name (bodyMedium medium) + address below (`text-[12px]` hint, truncated) when present.
- **Contact** — contactPerson (bodySmall) over contactNumber (`text-[12px]` secondary); a hint **"—"** if both absent.
- **Terms** — `transactionTypeDisplayName` (**Cash / 30 Days / 45 Days / 60 Days / 90 Days**); **"—"** when N/A (`notApplicable`).
- **Inventory** — `productCount` (semibold, tabular-nums) over `formatMoney(totalInventoryValue)` (`text-[12px]` hint), right-aligned.
- **Status** — colored dot + label. **Active** = green dot `#16a34a` + `text-success-dark` "Active";
  **Inactive** = gray dot `#a3a3a3` + secondary "Inactive". Inactive rows get `opacity-60`.
- **Actions** — **Edit** ghost link (`PencilIcon` + "Edit") → `/suppliers/edit/:id`. **Active suppliers only** also
  get an `EllipsisHorizontalIcon` "More actions" button that toggles the row popover (see Modals).

**UI states:**
- **Loading** (`isLoading` or no data yet) → `LoadingView` label *"Loading suppliers…"*.
- **Empty** (`filtered.length === 0`) → `EmptyState` title *"No suppliers found"*; description *"Try a different search."*
  when a search is active, else *"Add your first supplier to get started."*
- **Error** → early-returns `ErrorView` title *"Could not load suppliers"* + message (replaces the whole page).
- **Populated** → the table.

**Per-role differences.** Entire feature is **admin-only**: the `/suppliers` route is gated by `viewSuppliers`.
Staff and cashier never see the Suppliers sidebar item and cannot reach the route (bounced by the router).
There is **no in-page role gating** — any viewer who reaches the page sees every control.

**Icons (heroicons 24/outline):** `PlusIcon`, `MagnifyingGlassIcon`, `EyeIcon`, `EyeSlashIcon`, `PencilIcon`,
`EllipsisHorizontalIcon`, `TrashIcon` (in popover), plus `XMarkIcon` / `ExclamationCircleIcon` via shared components.

---

## Screen 2 — Supplier form (add / edit)  (`/suppliers/add`, `/suppliers/edit/:id`)

**Job.** Create or edit a supplier; single component, mode from `useParams().id`. Mirrors Flutter
`supplier_form_screen.dart`. `document.title` = *"New supplier · MAKI POS Admin"* / *"Edit supplier · MAKI POS Admin"*.
Data via `useSupplierById(id)`, `useCreateSupplier()`, `useUpdateSupplier()`; validation is react-hook-form + zod.

**Layout, top → bottom:**
1. **Header** — back link `ArrowLeftIcon` + **"Suppliers"** → `/suppliers`; `h1` **"New supplier"** / **"Edit supplier"**.
2. **Mutation error banner** (conditional) — shown only when a create/update error exists *and* it isn't a name-field
   error: rounded `border-error-light bg-error-light/40 text-error-dark` box with the message.
3. **Form** (`noValidate`), grouped into Sections:
   - **Basic information** — **Name** (text, autofocus, required — *"Name is required"*; duplicate-name server error
     surfaces here as an *"…already exists"* field error) · **Address** (text).
   - **Contact** (2-col grid on `sm+`) — **Contact person** (text) · **Email** (type email; *"Invalid email"*, empty
     allowed) · **Contact number** (tel) · **Alternative number** (tel).
   - **Terms** — **Payment terms** `<select>`, options **Cash / 30 Days / 45 Days / 60 Days / 90 Days / N/A**; default **Cash**.
   - **Notes** — **Internal notes** (textarea, 3 rows, `resize-y`).
4. **Footer actions** (`flex justify-end`) — **Cancel** ghost link → `/suppliers`; **Submit** dark button
   (disabled while submitting, shows `Spinner`). Label: *"Saving…"* while submitting, else *"Create supplier"* (add) /
   *"Save changes"* (edit).

**Behavior.** Empty optional strings are converted to `null` on submit; on success navigates to `/suppliers`;
a duplicate-name server error sets a field error on **Name** (banner suppressed in that case).

**UI states (edit mode):** error loading target → `ErrorView` *"Could not load supplier"*; loading or missing target →
`LoadingView` *"Loading supplier…"*. Add mode has no pre-load state.

**Per-role differences.** Admin-only. `/suppliers/add` is gated by `addSupplier`, `/suppliers/edit/:id` by
`editSupplier`; both admin-only. No in-page role branching.

**Modals/menus:** none on this screen.

**Icons:** `ArrowLeftIcon` (+ shared-component icons).

---

## Modals & overlays

- **Row action popover** (`RowMenu`, list screen) — absolute dropdown (`w-44`, `rounded-md`, hairline border,
  `shadow-lg`) anchored under the `EllipsisHorizontalIcon` button; closes on outside `mousedown`. Rendered **only for
  active suppliers**. Single item: **Deactivate** (`TrashIcon` + "Deactivate", `text-error-dark`, hover `bg-error-light/40`).

- **Deactivate supplier confirm** (`Dialog`, `max-w-md`) — opened from the popover.
  - **Title:** "Deactivate supplier".
  - **Description:** *"{name} will be hidden from new product and receiving forms. Existing references stay intact."*
  - Optional inline error text (`text-error`) above the buttons if the mutation fails.
  - **Buttons:** **Cancel** (ghost) · **Deactivate** (red `bg-error` fill, white, shows `Spinner` while pending).
    Both disabled while `deactivate.isPending`; the dialog is **non-dismissable** during pending (ESC / click-outside /
    close-button all blocked until it resolves).

---

## What I want  *(fill this in, then hand back)*

Leave anything blank you don't care about. Specifics beat vibes — name the screen + region + the change.

### Direction
- Overall: restyle Suppliers within the current layout, or rethink the structure? →
- Reference apps / directories whose look you like →

### Suppliers list
- **Header / toolbar** — keep search + inline show/hide-inactive toggle, or move to a filter control? →
- **Table vs cards** — keep the 6-column table, or a card/list layout? Which column is the hero (name vs inventory value vs status)? →
- **Status** — keep dot + text, or a pill/badge? How should inactive rows read (opacity vs muted style)? →
- **Inventory column** — product count + total value stacked; any chart (e.g. a tiny value bar) worth adding? →
- **Row actions** — keep inline Edit + overflow popover, or a single actions menu? →

### Supplier form
- **Sections** — keep 4 stacked bordered cards (Basic / Contact / Terms / Notes), or a different grouping / 2-col page? →
- **Field surfaces** — outlined vs filled inputs; section-header styling; the Terms select treatment →
- **Footer** — keep inline Cancel + Submit at the end, or pin the action bar? →
- **Error banner** — placement / styling of the top mutation-error banner and inline field errors →

### Constraints / must-keep
- **Admin-only** feature (viewSuppliers / addSupplier / editSupplier). No in-page gating to add or remove. →
- All 6 table columns (Supplier · Contact · Terms · Inventory · Status · Actions) stay. →
- **Deactivate** flow: overflow popover (active rows only) → "Deactivate supplier" dialog with the exact copy
  *"{name} will be hidden from new product and receiving forms. Existing references stay intact."*; red Deactivate
  button + spinner; non-dismissable while pending. →
- All form fields + Terms options (Cash / 30 / 45 / 60 / 90 Days / N/A, default Cash) + validation
  (Name required, Invalid email, duplicate-name → Name field error) stay. →
- All states: loading / empty (two copies) / error / populated on the list; loading + error on edit. →
- Show/Hide-inactive toggle (default hides inactive) stays. →

---

*Bundles: w01-shell-login-dashboard · w02-pos-drafts · w03-inventory · w04-receiving ·
**w05-suppliers (this)** · w06-reports · w07-users · w08-settings · w09-logs.*
