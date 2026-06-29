# Handoff: MAKI POS — Expenses (dashboard · form · history · delete)

> # ⚠️ CLAUDE CODE — COPY EVERY DETAIL IN THIS HANDOFF. NO EXCEPTIONS.
> **`MAKI POS Expenses.dc.html` is the single source of truth. Reproduce it EXACTLY.**
> Every color, hex, font size, weight, padding, gap, radius, border, shadow, icon, copy string, row order, and
> state below is **intentional and already verified** — replicate all of it. **Do NOT** redesign, "improve",
> simplify, round values, substitute icons, re-order sections, rename labels, invent per-category colors, or drop
> any state. Build **both light and dark**, every screen, every state shown.
> - If this README and the HTML ever disagree, **the HTML wins** — open it and read the inline styles directly.
> - Implement in the existing Flutter codebase using its real widgets/theme (this is a visual spec, not code to paste).
> - **Figures are illustrative sample data — restyle only, never change a formula or a computed total.**
>
> When in doubt, match the prototype rather than your own judgment.

## Overview
Bundle **08** of the MAKI POS redesign — the **Expenses** feature: the **dashboard** (category filter → three-up
totals → Recent list → pinned Add Expense), its **empty** state, the **add / edit** form, the **delete** confirm
+ swipe-to-delete reveal, and the grouped **expense history**. It migrates the raw-Material surface onto the
elevated global theme (bundles 01–07): Material `Card` + `ListTile` rows become soft-shadow **`AppCard`** rows;
the three totals become elevated **`SummaryCard`s**; **Cupertino icons → Lucide**; the delete confirm collapses
into the **shared dialog shell** (bundle 08-Modals). Full **dark parity (gold leads in dark)**.

**The defining rule — neutral-by-default discipline (MUST KEEP):** color carries **status meaning only**. Every
expense row reads identically — the **same muted document glyph in a neutral tile**, regardless of category or
payment method. **Do not invent per-category colors.** The only color on these screens is the slate/gold primary
(buttons, links, focus) and **red on the destructive delete path** (swipe background + delete dialog).

This reuses the **global theme** — do **not** invent new tokens. Pull from `lib/core/theme/` exactly as bundles
01–07 did, and adopt the app's field styling used on the other redesigned screens.

## About the Design Files
These are **design references created in HTML** — a prototype of the intended look and behavior, **not production
code to ship**. Recreate them in the Flutter codebase (`lib/presentation/mobile/screens/expenses/…`) using its
established widgets (`AppCard`, `SummaryCard`, the shared input fields, `AppDropdown`, `EmptyStateView`, the shared
dialog shell) and the theme layer. Translate the CSS values below into Flutter `ThemeData` / widget styles.

- `MAKI POS Expenses.dc.html` — the redesign prototype (5 surfaces × light + dark). **Source of truth.**
- `reference_current-ui.html` — the current pre-redesign UI (Cupertino + raw Material `Card`/`ListTile`), before/after only.

## Fidelity
**High-fidelity (hifi).** Colors, type, spacing, radii, shadows, and icons are final. **Match them precisely.**

---

## Source files (what to migrate)
| Surface | File |
|---|---|
| Expenses dashboard (filter + totals + Recent) | `lib/presentation/mobile/screens/expenses/expenses_screen.dart` |
| Empty state | same (`EmptyStateView`) |
| Add / Edit form | `lib/presentation/mobile/screens/expenses/expense_form_screen.dart` |
| Delete confirm + swipe-to-delete reveal | `expenses_screen.dart` (`Dismissible` + dialog) |
| Expense history (grouped by month-year) | `lib/presentation/mobile/screens/expenses/expense_history_screen.dart` |

Shared widgets: `SummaryCard` (totals), `AppDropdown` (category + paid-via), `EmptyStateView`, the shared **dialog
shell** (delete confirm), and `groupExpensesByMonthYear` (`core/utils/expense_filters.dart`). Rows migrate Material
`Card` → `AppCard`; inputs migrate filled `InputDecoration` → the app's standard field style; **Cupertino → Lucide**.

---

## Design Tokens

| Token | Light | Dark |
|---|---|---|
| Screen canvas | `#F6F5F3` | `#0C1415` |
| Card / row (`AppCard`) | `#FFFFFF` + shadow `0 2px 8px rgba(17,28,29,.06)` | `#18262A` + 1px border `#243234` (no shadow) |
| Neutral row tile (glyph chip) | `rgba(40,62,70,.06)` bg · glyph `#8A9296` | `rgba(147,160,163,.12)` bg · glyph `#93A0A3` |
| Primary (slate) | `#283E46` | gold `#E8B84C` **leads** (ink text `#121C1D`) |
| Text primary / muted / hint | `#16201F` / `#8A9296` / `#9AA0A3` | `#ECEFEF` / `#93A0A3` / `#6C797C` |
| Input fill / border (form) | `#FAFAFA` / `#E2E2E2` | `#0C1415` / `#2C3C3E` |
| Input focus (required, shown on Description) | 1.5px `#283E46` + ring `0 0 0 4px rgba(40,62,70,.07)`, label slate, fill `#fff` | 1.5px `#E8B84C` + ring `0 0 0 4px rgba(232,184,76,.12)`, label gold, fill `#18262A` |
| Filter / dropdown surface (dashboard, elevated) | `#FFFFFF` + card shadow, radius 14 | `#18262A` + 1px `#243234`, radius 14 |
| Add Expense / Update Expense button (primary) | `#283E46`, white, shadow `0 8px 20px -6px rgba(40,62,70,.5)` | `#E8B84C`, ink `#121C1D`, shadow `…rgba(232,184,76,.45)` |
| Error (delete only) | `#F44336` | swipe bg `#F44336`; trash glyph / app-bar trash `#FF6B5E` |
| Required asterisk | `#F44336` | `#FF6B5E` |
| Section divider / actbar top hairline | `#ECECEC` / `#F0F0F0` | `#243234` |

### Typography
**Figtree** (400–800) primary. **Roboto Mono** is **NOT used on these screens** — there are no sale numbers / SKUs
/ codes here, so **all currency renders in Figtree** (this is a deliberate change from the current UI, which mono'd
every amount). Reserve mono for codes elsewhere in the app.

| Element | Size / Weight |
|---|---|
| App-bar title | 18 / 600 |
| Section header ("Recent") | 15 / 700 |
| Totals value (`SummaryCard`) | 16 / 700 · label 11 muted |
| Row title (`{description}`) | 14.5 / 600, single line + ellipsis |
| Row subtitle | 12 / muted |
| Row amount | 15 / 600 |
| Filter / field value | 14.5–15 |
| Field label | 12 (muted; slate/gold when focused) |
| Month header | label 13.5 / 600 muted · `{count} • {total}` 12 / 600 muted |
| Dialog title | 18 / 600 · body 14.5 / 1.55 |
| Empty title / sub | 16 / 600 · 13 hint |

**Radii:** field / filter / button 14–16 · row & totals card 14–16 · neutral glyph tile 11 · dialog 24 · dialog
chip 13 · phone frame 42. **Shadows:** card `0 2px 8px rgba(17,28,29,.06)` (light only; dark = 1px hairline);
primary button as tokened. Use explicit `BoxShadow` in Flutter — Material `elevation` alone won't match.

**Currency:** grouped `₱1,234.00`. **Dates:** `MMM d, y • h:mm a` (dashboard rows) / `MMM d, y` is implicit in
history rows shown as `{date} • {category}`; month headers `MMMM y` ("June 2026").

### Icons — Lucide (stroke 1.75–1.85)
status `signal-high`/`wifi`/`battery-full` · back `chevron-left` · filter `tag` + `chevron-down` · totals
**Today** `sun` / **This Week** `calendar` / **This Month** `bar-chart-3` · **every expense row** `file-text`
(neutral) · Recent "View all" `chevron-right` · Add Expense `plus` · form trash `trash-2` · date field `calendar`
· dropdown fields `chevron-down` · swipe `trash-2` · delete dialog chip `trash-2` + close `x`. **No category or
payment glyphs** — one neutral `file-text` for all rows.

---

## Screens / Views

> Each screen is a flex **column**: status bar (36) → flat app bar (≈52, on canvas) → body. Dashboard & empty pin a
> bottom **Add Expense** action bar (flat on canvas, 1px top hairline) below a scrolling body.

### 1 — Expenses dashboard  (`expenses_screen.dart`)
**App bar:** `chevron-left` · **"Expenses"** (no trailing). **Body (top → bottom):**
1. **Category filter** — elevated dropdown (white/`#18262A` + card shadow / hairline, radius 14, min-h 50): leading
   `tag` (muted) · value · trailing `chevron-down`. `null` = **"All categories"**. A selected-but-deactivated
   category renders inline as `{name} (inactive)` (italic + muted). Filtering re-scopes the list **and** the totals.
2. **Totals** — three-up `SummaryCard`s (gap 8): each a column of `icon` (18 muted) → **value 16/700** → label 11
   muted. **Today** `₱340.00` · **This Week** `₱2,180.00` · **This Month** `₱9,640.00`. Shows `…` while loading,
   `—` on error. Re-scopes to the active category.
3. **Recent** section header (15/700) + **View all** link (13/600, slate/gold) with `chevron-right`.
4. **Up to 5** most-recent expense **`AppCard` rows** (newest first), gap 8 — see Row anatomy.
5. **Add Expense** — pinned bottom primary button (slate/gold, `plus` + label, elevated). **Hidden** without the
   `addExpense` permission.

**Row anatomy (the `AppCard` expense row).** `display:flex; gap:12; padding:11×13; radius:16`, card surface. Left =
**neutral glyph tile** 40×40 radius 11 (`rgba(40,62,70,.06)` / `rgba(147,160,163,.12)`) holding `file-text` (20px,
muted). Middle = **title** `{description}` (14.5/600, single line + ellipsis) over **subtitle** (12 muted) =
`{date} • {time}` on the dashboard / `{date} • {category}` in history. Right = **amount** (15/600).

### 2 — Empty state  (`EmptyStateView`)
Same chrome, filter, and totals (all `₱0.00`) + Recent header (View-all muted/disabled). Centered empty block:
soft rounded tile (76×76, radius 22, neutral) holding `file-text` (34, faint `#C2C8CA` / `#54646A`), **"No
Expenses"** (16/600), **"Tap + to add an expense"** (13 hint). When a category filter is active the copy is
**"No matches"** instead. Bottom Add Expense button still pinned.

### 3 — Add / Edit form  (`expense_form_screen.dart`)
**App bar:** `chevron-left` · **"Edit Expense"** (or **"Add Expense"**) · trailing **`trash-2`** (red `#F44336` /
`#FF6B5E`) — shown only with `deleteExpense`, only when editing. **Body — labeled fields (label above, radius 14,
min-h 50), in order:**
1. **Description \*** — text. **Shown focused** (slate/gold 1.5px border + focus ring, label colored).
2. **Amount \*** — numeric, **`₱` prefix** (decimal, must be > 0).
3. **Category \*** — dropdown (`chevron-down`). Admin-managed list; when empty show **"No categories defined — ask
   admin"** error state.
4. **Paid via \*** — dropdown (`chevron-down`). `PaymentMethod`: **Cash / GCash / Maya / Salmon / Mixed**; defaults
   **Cash**.
5. **Date \*** — field with trailing `calendar` (date picker, **max = today**).
6. **Notes** — optional 3-line textarea (min-h 80), placeholder "Optional details…".
7. **Submit** — full-width primary (slate/gold). Label flips **Add Expense** / **Update Expense**; show an inline
   spinner while saving.

### 4 — Delete confirm + swipe reveal  (`Dismissible` + shared dialog shell)
Over the dashboard list. **Swipe-to-delete reveal:** the row sits in a `position:relative` wrapper over a full-bleed
**`#F44336`** background (radius 16) with a right-aligned `trash-2` + **"Delete"** (white); the card is translated
left to reveal it. Swipe bg stays `#F44336` in **both** themes. **Delete confirm** = the **shared dialog shell,
destructive variant** (scrim `rgba(17,28,29,.32)` / `rgba(0,0,0,.6)`; surface radius 24, white / `#18262A`+hairline):
- **Header:** red leading chip (42×42, radius 13, `rgba(244,67,54,.10)` / `.16`) with `trash-2` (`#F44336` /
  `#FF6B5E`) + title **"Delete expense?"** (18/600) + optional close `x`.
- **Body:** **"{description}" will be permanently deleted. This action can't be undone."** (quoted description bold).
- **Actions** (right-aligned): **Cancel** (text, muted, left) + **Delete** (red filled `#F44336`, white, shadow,
  right). Primary is always filled and right; never two filled buttons.

Every delete path (swipe, long-press, form app-bar trash) routes through this confirm, then a success/error snackbar.

### 5 — Expense history  (`expense_history_screen.dart`)
**App bar:** `chevron-left` · **"Expense History"**. **Body:** the same category filter, then **month-year groups**
(newest first). Each group: a **header** — `{Month Year}` left (13.5/600 muted) + `{count} • {total}` right
(12/600 muted) — then its `AppCard` rows (subtitle = `{date} • {category}`). Honours an initial category from the
route query param (deep-link from the dashboard **View all**).
- **Mock data:** **June 2026** `4 • ₱2,174.00` (Shop electricity ₱340 · Cleaning supplies ₱215 · Internet bill
  ₱1,499 · Tricycle delivery fee ₱120) · **May 2026** `2 • ₱1,840.00` (Shop rent ₱1,500 · Coffee for staff ₱340).

---

## Interactions & Behavior
- **Category filter** re-scopes both the Recent/history list **and** the three totals. `null` = All categories;
  deactivated selection shown as `{name} (inactive)`, italic + muted.
- **View all** opens the grouped history, deep-linking the active category via query param.
- **Row:** tap = edit (with `editExpense`); swipe-to-delete + long-press = delete (with `deleteExpense`).
- **Form:** Amount must be > 0; Date max = today; submit shows an inline spinner; label flips Add/Update.
- **Theme toggle** swaps the entire light/dark token set, including the primary flipping slate → gold (buttons,
  links, input focus, Add/Update button).

## State Management
Reuse existing expense providers/blocs. Needed: filter category (nullable; inactive-flag) · three totals (Today /
This Week / This Month, each its own `ExpenseDateRangeParams`, loading/error) · recent list (limit 5, newest first)
· history (grouped via `groupExpensesByMonthYear`, per-group count + total) · form fields (description, amount,
category, paidVia, date, notes) + save state · role permissions (`addExpense` / `editExpense` / `deleteExpense`).

## Role rules (must keep)
- **add** (`addExpense`) — hides the bottom **Add Expense** button if absent.
- **edit** (`editExpense`) — enables tap-to-edit.
- **delete** (`deleteExpense`) — enables swipe-to-delete + long-press + the form app-bar trash (each behind the
  confirm dialog).
- Staff/cashier can view + add; admin gets full CRUD.

## Must-keep (don't design these away)
- **Neutral-by-default discipline** — one muted `file-text` glyph in a neutral tile for **every** row; **no
  per-category / per-payment colors**. Color = status only; red appears **only** on the delete path.
- **Dashboard order:** filter → totals → Recent (View all) → ≤5 rows → pinned Add Expense.
- **Totals** keep the elevated `SummaryCard` treatment and re-scope to the active category (`…`/`—` states).
- **Form field order + requiredness**, the **empty-categories** error, **Paid via** defaulting to Cash, **Date** max
  = today, the **Add/Update** label flip + saving spinner.
- **History** grouped by month-year with per-group `count • total`; deep-link category from View all.
- **Delete** stays **red + explicit confirm** via the **shared dialog shell** (destructive); swipe bg `#F44336`.
- **All role gating.** **Dark parity** on all five surfaces; **`AppCard`** everywhere (no flat Material `Card`);
  **Lucide** (off Cupertino); app field styling. Currency `₱1,234.00` in **Figtree** (no mono on these screens).

## Assets
- Icons: **Lucide** (`lucide_icons`) — migrate off Cupertino. No custom SVGs.
- Fonts: **Figtree** (Roboto Mono already in project but unused here).
- No images/photography on these screens.

## Files
- `MAKI POS Expenses.dc.html` — redesign prototype, **source of truth** (5 surfaces × light/dark).
- `reference_current-ui.html` — current/flat UI (Cupertino + Material `Card`/`ListTile`), before/after only.
