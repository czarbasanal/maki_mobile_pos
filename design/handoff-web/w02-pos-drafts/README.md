# MAKI POS Web Admin — Design Handoff w02: POS + Drafts

**Purpose.** A self-contained bundle showing the **current** web-admin UI of the point-of-sale
(`/pos`) and Drafts (`/drafts`) screens, so a design session can *see* exactly what exists today
and mark up what should change. Hand the marked-up version back and it gets implemented in React
(Vite + TypeScript + Tailwind, under `web_admin/src/presentation/`). This is a **light-theme,
desktop** reconstruction rendered inside the standard AdminShell chrome (240px sidebar).

> ## ⚠️ Redesign constraint — read first
> **Redesign what is currently present in these screens. Nothing more, nothing less.**
> Do NOT remove any component: every section, table column, form field, button, banner, badge,
> filter, state (loading/empty/error/success/disabled/capped), dialog, and popover listed below
> must exist in the redesign. Do NOT add components: no new features, fields, actions, nav
> items, or data. **Single exception: charts/graphs MAY be added** if they visualize data
> already present on the screen. Role gating, copy, validation, and behavior are fixed —
> restyle freely, do not re-scope.

**What's in here**
- `current-ui.html` — open in any browser: a token-accurate reconstruction of both screens (POS
  with all cart / labor / payment states, Drafts list with all states) plus the Save-as-draft
  dialog, all rendered inside the 240px sidebar chrome in the light theme.
- `README.md` (this file) — the design system, per-screen structure/copy/states/role rules, the
  modals section, and a **"What I want" template** to fill in.

**Surfaces.** React web admin:
- `web_admin/src/presentation/features/pos/PosPage.tsx` — POS shell: search, cart, totals, actions, save dialog
- `web_admin/src/presentation/features/pos/PaymentSection.tsx` — tender chips + per-mode inputs + validation
- `web_admin/src/presentation/features/pos/LaborSection.tsx` — labor rows + mechanic select
- `web_admin/src/presentation/features/drafts/DraftsPage.tsx` — held-drafts list (resume / delete)

Shared components used: `Dialog`, `EmptyState`, `ErrorView`, `LoadingView`/`Spinner`, `Sidebar`
(chrome — see w01). Heroicons (24/outline): `TrashIcon`, `PlusIcon`, `XMarkIcon`,
`ExclamationCircleIcon`.

**Not in scope (placeholder routes — no UI to redesign):** `/pos/checkout` (phase 11) and
`/drafts/:id` (phase 10) both render the shared `PagePlaceholder` ("Not available yet"). Editing a
draft is done by **Resume → POS** (the save dialog then shows "Update draft"), not by a dedicated
edit screen. They keep their behavior; there is nothing to restyle. Skip them.

---

## Design system (tokens these screens actually use)

Source of truth: `web_admin/src/core/theme/tokens.ts` → Tailwind via `tailwind.config.ts`.
Font: **Roboto** (`@fontsource/roboto` 300/400/500/700); mono `ui-monospace, Menlo`.

### Color
| Token | Hex | Use on these screens |
|---|---|---|
| `light-text` | `#0A0A0A` | primary text; **also the "black" button fill** (Complete sale, Resume, Save, selected tender chip) |
| `light-text-secondary` | `#666666` | labels (Discount, Qty/off, mechanic), unselected chip text |
| `light-text-hint` | `#A0A0A0` | sublines (SKU · on-hand), totals labels, empty-state hint, timestamps |
| `light-background` | `#FFFFFF` | page/sidebar bg; white button text on dark fills |
| `light-card` | `#FFFFFF` | cards, inputs, dialog |
| `light-subtle` | `#FAFAFA` | hover fills (search results, chips, list rows) |
| `light-hairline` | `#EAEAEA` | card borders + row dividers (near-invisible) |
| `light-border` | `#E0E0E0` | input / outline-button borders |
| `primary-dark` | `#121C1D` | button hover (Complete sale, Resume, Save) |
| success `#4CAF50` / light `#E8F5E9` / dark `#2E7D32` | sale-completed banner, saved-to-drafts banner |
| warning `#FFC107` / light `#FFF8E1` / dark `#F57C00` | low-stock (`#F57C00`) + labor-without-description inline warnings |
| error `#F44336` / light `#FFEBEE` / dark `#C62828` | checkout-error banner, payment validation line, delete-draft banner, ErrorView icon, trash hover |

### Type scale (px / weight)
`headingMedium` 24/600 (page titles) · `bodyMedium` 16/400 (Cart header, dialog title) ·
`bodySmall` 14/400 (rows, inputs, buttons) · `labelMedium` 14/500 · ad-hoc `text-[12px]`
(sublines, chip text, discount/qty labels, meta) and `text-[11px]` (inline warnings). Headings
are `font-semibold tracking-tight`. Numerics use `tabular-nums` where money is shown.

### Spacing (`tk-*`) · Radii · Shadows
Spacing: `tk-xs` 4 · `tk-sm` 8 · `tk-md` 16 · `tk-lg` 24 · `tk-xl` 32. Radii: `rounded-md` 6px
(inputs, buttons, chips-as-toggles), `rounded-lg` 8px (cards, dialog), `rounded-full` (tender
pills). Shadows: none on cards (weight is typography + hairlines); dialog uses `shadow-xl`.

### Button & control patterns
- **Primary / dark:** `bg-light-text` (#0A0A0A) `text-light-background`, hover `bg-primary-dark`
  (#121C1D). Full-width Complete sale + Save; compact Resume; dialog Save. Disabled →
  `cursor-not-allowed opacity-60`.
- **Outlined / secondary:** `border-light-border`, hover `bg-light-subtle`. Save-as-draft button,
  dialog Cancel, "Add labor".
- **Tender chip (pill):** `rounded-full border px-tk-md py-[6px] text-[12px]`; selected = dark
  fill; unselected = outlined `text-light-text-secondary` hover `bg-light-subtle`.
- **Sub-selector toggle:** small `rounded-md border` button; selected = `bg-light-subtle
  border-light-text`.
- **Inputs:** `rounded-md border border-light-border bg-light-card`, focus `border-light-text`
  (no glow). Number inputs are narrow (Qty `w-16`, discount `w-20`, fee `w-24`).
- **Card / list pattern:** `rounded-lg border border-light-hairline bg-light-card`; internal
  header row divided by `border-b border-light-hairline`; list rows `divide-y divide-light-hairline`.

---

## Screen 1 — POS  (`/pos`)

**Job:** single-screen point of sale — search products → build a cart → add labor + mechanic →
take payment → **Complete sale**, or hold the cart as a **draft**. `document.title = 'POS'`.

**Access / roles:** common route — **every authenticated role (admin / staff / cashier) sees the
identical screen.** No permission gate, no in-page role branching anywhere. Sidebar active item =
**POS** (Sell group).

**Layout:** 2-column responsive grid (`grid-cols-1 lg:grid-cols-2`, `px-tk-xl py-tk-lg`). Left =
product search; Right = banners → cart card → labor → totals → payment+actions card.

### Left column — Product search / browse
1. `<h1>` **"POS"** (headingMedium, semibold, tracking-tight).
2. **Search input** — full width, placeholder **"Search products by name or SKU"**, focus
   `border-light-text`. Filters active products by name/SKU substring, capped at 50 results.
3. **Results card** (bordered, divided rows). Each result = full-width button (hover
   `bg-light-subtle`): left = product name (bodySmall) over subline **"`{SKU} · {qty} on hand`"**
   (12px hint); right = price via `formatMoney`. Click → adds a cart line.
4. **Empty states (2):** no query → **"Type to search products."**; query with no hits →
   **"No matches."** (centered hint text).

### Right column — Banners (conditional, top→bottom)
- **Success banner** — green (`success-light`/`success-dark`): **"Sale `{saleNumber}` completed."**
  (saleNumber in `font-mono`). Auto-dismisses after 4s; also cleared once a new line is added.
- **Checkout-error banner** — red (`error-light`/`error-dark`): shows `checkout.error.message`.
- **Draft-saved banner** — green: **"Saved to drafts."** — shown only when the save succeeded and
  the cart is now empty.

### Right column — Cart card
- **Header row:** **"Cart"** (bodyMedium semibold) + right-side **Discount** `<select>` with
  options **"₱ amount"** and **"%"**.
- **Empty state:** **"Cart is empty."** (centered hint).
- **Line items** (`<ul>` divided). Per line:
  - Row 1: product name + **Trash** icon button (`TrashIcon` h-4, hover `text-error`) → remove.
  - Row 2: **"Qty"** number input (min 1); discount input labeled **"% off"** or **"₱ off"** (min 0,
    step 0.01); right-aligned **net line total** (`saleItemNet`).
  - **Low-stock warning** (conditional): **"⚠ exceeds on-hand stock"** (11px, `warning-dark`) when
    qty exceeds on-hand.
- **`<LaborSection />`** (see below) rendered inside the card, below the lines.
- **Totals** `<dl>` (local `Row`): **Subtotal**; **Discount** (prefixed "− "); **Labor** (only when
  labor > 0); **Total** (semibold/strong).

### Right column — Payment + Actions card
- **`<PaymentSection />`** (see below).
- **Complete sale** button — full-width dark fill, hover `primary-dark`. Enabled only when
  `lines > 0 && payment valid && !pending`; disabled → `cursor-not-allowed opacity-60`. Label →
  **"Completing…"** while pending (button-lock).
- **Save / Update draft** button — full-width outlined. Label = **"Update draft"** when editing an
  existing draft (`draftId` set) else **"Save as draft"**; **"Saving…"** while pending. Disabled
  when cart empty or save pending.

### 1a. PaymentSection (`PaymentSection.tsx`)
- **Tender chips** (pill row, wraps): **Cash · GCash · Maya · Mixed · Salmon**. Selected = dark
  fill; unselected = outlined. Selecting a mode clears entered amounts.
- **Cash mode:** **"Cash received"** number input + **"Change"** readout (`formatMoney`).
- **GCash / Maya mode:** static line **"Paid in full via GCash/Maya — `{grandTotal}`"** (no input).
- **Mixed mode:** SubSelector **"Digital"** (GCash | Maya toggle) + **"Digital amount"** input +
  read-only **"Cash portion"** row (remainder).
- **Salmon mode:** SubSelector **"Downpayment via"** (Cash | GCash | Maya) + **"Downpayment"** input
  + read-only **"Salmon balance (receivable)"** row (remainder → salmon receivable).
- **Validation error** line (12px `error-dark`): cash → *"Cash received is less than the total"*;
  mixed → *"Digital amount must be between ₱0 and the total"*; salmon → *"Downpayment must be
  between ₱0 and the total"*. GCash/Maya never error.
- Money fields are string-backed so decimals type cleanly.

### 1b. LaborSection (`LaborSection.tsx`)
- Header **"Labor"** + **"Add labor"** button (outlined, `PlusIcon` h-3.5).
- **LaborRow** per line: **Description** text input (flex-1) + **Fee** number input (w-24, min 0,
  step 0.01) + **Trash** button. Warning (11px `warning-dark`) **"Add a description to include this
  charge."** when a fee > 0 but the description is blank (the charge is silently dropped otherwise).
- **Mechanic** `<select>` labeled **"Mechanic"**: **"None"** + active mechanics. A
  deactivated-but-selected mechanic is preserved as **"`{name}` (inactive)"** so the stale id
  doesn't silently vanish.

**Icons (POS):** `TrashIcon` (remove cart line, remove labor row), `PlusIcon` (add labor),
`XMarkIcon` (dialog close). No icons on tender chips (text pills).

---

## Screen 2 — Drafts list  (`/drafts`)

**Job:** list held / open drafts (excludes converted ones); **resume** one into the POS or
**delete** it. `document.title = 'Drafts · MAKI POS Admin'`.

**Access / roles:** common route — **all authenticated roles see the identical screen.** No
permission gate, no role-conditional UI. Sidebar active item = **Drafts** (Sell group).

**Layout (top→bottom):**
1. **Header:** `<h1>` **"Drafts"** + subtitle **"Held orders — resume one into the POS or delete
   it."**
2. **Delete-error banner** (conditional): red — **"Could not delete the draft: `{message}`"**.
3. **List** (bordered card, divided `<ul>`). Per draft row:
   - Left: **draft name** (bodySmall medium) over meta subline
     **"`{count} item(s) · {total} [· {mechanicName}] · {createdAt date}`"**. Total via
     `cartGrandTotal`.
   - Right: **Resume** button (dark fill, hover `primary-dark`) + **Trash** icon button
     (`TrashIcon` h-4, hover `text-error`).

**States:**
- **Error** → `ErrorView` (title **"Could not load drafts"** + message, `ExclamationCircleIcon`).
- **Loading / no data yet** → `LoadingView` label **"Loading…"** (spinner).
- **Empty** → `EmptyState` title **"No drafts"**, description **"Hold a cart from the POS with
  "Save as draft"."**
- **Populated** → the list above.

**Actions use native `window.confirm` today (no custom dialog):**
- **Resume:** if the current cart is non-empty → confirm **"Replace the current cart with this
  draft?"**; then load the draft and navigate to `/pos`.
- **Delete:** confirm **`Delete draft "{name}"?`**; then delete.

**Icons (Drafts):** `TrashIcon` (delete), `ExclamationCircleIcon` (ErrorView). Shared:
`LoadingView`, `ErrorView`, `EmptyState`.

---

## Modals & overlays

### Save-as-draft dialog (shared `common/Dialog`)
- Opened by the **Save / Update draft** button on POS. Title = **"Update draft"** when editing an
  existing draft (`draftId` set) else **"Save as draft"**. Prefilled with the existing draft name.
- **Field:** **"Draft name"** text input, autofocus, placeholder **"e.g. Mr Cruz — blue Mio"**.
- **Buttons:** **Cancel** (outlined) + **Save** (dark fill). Save is disabled while pending or when
  the name is blank; its own label doesn't change (the parent Save button shows "Saving…").
- **Chrome / lock behavior:** body-portal modal, `bg-black/30` overlay, `shadow-xl` panel,
  `XMarkIcon` close in header, ESC + click-outside close. **While the save is pending the dialog is
  non-dismissable** (no ESC / overlay / X close — locks the modal mid-write). On success it closes
  and the cart clears.

### Native confirms (Drafts)
- **Resume** (when cart non-empty) and **Delete** use the browser's `window.confirm` — no styled
  dialog. Copy: *"Replace the current cart with this draft?"* and *`Delete draft "{name}"?`*.

---

## What I want  *(fill this in, then hand back)*

Leave anything blank you don't care about. Specifics beat vibes — name the screen + region + the change.

### Direction
- Overall: restyle POS + Drafts onto a sharper web language, or rethink the 2-column POS layout? →
- Reference apps / POS UIs you like the look of →

### POS — search & cart
- **Product search** — keep inline results card, or a richer result row (image / stock chip)? Empty-state treatment? →
- **Cart card** — line-item density; where should the net line total and low-stock warning sit? →
- **Discount control** — keep the header `₱ amount / %` select, or per-line only? →
- **Totals** — plain `<dl>` rows vs a stronger total; any chart (e.g. tender split) allowed only if it visualizes data already here →

### POS — labor & payment
- **LaborSection** — inline rows vs a compact add-line pattern; mechanic select placement →
- **Payment tender chips** — keep 5 pills (Cash/GCash/Maya/Mixed/Salmon)? Selected-state styling? →
- **Per-mode panels** (cash change, mixed split, salmon receivable) — layout of the read-only remainder rows →
- **Action buttons** — Complete sale + Save/Update draft; pending/disabled treatment →

### Drafts
- **Row layout** — name vs meta hierarchy; Resume + trash affordance placement →
- **States** — empty / loading / error / delete-error banner styling →
- Should Resume/Delete move from native `window.confirm` to the styled `Dialog`? *(behavior change — note it, don't assume)* →

### Constraints / must-keep
- **No role gating** on POS or Drafts — every role (admin/staff/cashier) sees the identical screen; keep it role-agnostic →
- All banners & states: sale-completed (auto-dismiss 4s) · checkout-error · saved-to-drafts · low-stock warning · labor-without-description warning · payment validation lines · drafts empty/loading/error/delete-error →
- Save-as-draft **Dialog** — both "Save as draft" / "Update draft" titles, "Draft name" field + placeholder, non-dismissable while writing →
- All copy verbatim (banners, validation, empty states, confirm prompts) →
- Tender modes + their split/validation math, string-backed money inputs →
- `/pos/checkout` and `/drafts/:id` stay placeholders (out of scope) →

---

*Bundles: w01-shell-login-dashboard · **w02-pos-drafts (this)** · w03-inventory · w04-receiving ·
w05-suppliers · w06-reports · w07-users · w08-settings · w09-logs — one bundle at a time
(per `design/handoff-web/ROADMAP.md`).*
