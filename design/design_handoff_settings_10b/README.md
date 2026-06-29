# Handoff: MAKI POS — Settings 10b (admin editors)

> # ⚠️ CLAUDE CODE — COPY EVERY DETAIL IN THIS HANDOFF. NO EXCEPTIONS.
> **`MAKI POS Settings 10b.dc.html` is the single source of truth. Reproduce it EXACTLY.**
> Every color, hex, font size, weight, padding, gap, radius, border, shadow, icon, copy string, row order, and
> state below is **intentional and already verified** — replicate all of it. **Do NOT** redesign, "improve",
> simplify, round values, substitute icons, re-order sections, rename labels, or drop any state. Build **both light
> and dark**, every screen, every state shown.
> - If this README and the HTML ever disagree, **the HTML wins** — open it and read the inline styles directly.
> - Implement in the existing Flutter codebase using its real widgets/theme (this is a visual spec, not code to paste).
> - **Figures / codes are illustrative sample data — restyle only, never change a formula, mapping, or computed value.**
>
> ## 🛑 IF ANYTHING IS UNCLEAR, STOP AND ASK THE USER TO CONFIRM.
> **Do not guess, do not improvise, do not fill gaps with your own judgment.** If a value, behavior, mapping,
> permission rule, edge case, or anything else here is ambiguous, missing, or seems to conflict with the existing
> codebase — **pause and ask the user a direct question before writing code.** A wrong assumption is more expensive
> than a question. When in doubt, match the prototype exactly; when the prototype itself doesn't answer it, **ask**.

## Overview
Bundle **10** is the largest, split into two slices. **This is 10b** — the four **admin-only** sub-screens reached
from the hub's Administration section (slice **10a** covers the hub + theme picker + About):
- **Manage Lists** — one tile per `CategoryKind`.
- **Category editor** — per-kind CRUD list + FAB.
- **Edit form dialog** — category / mechanic (`AlertDialog` + `SwitchListTile`).
- **Cost Code Settings** — info · digit→letter mapping · test encoding · reset (password-gated).
- **Mechanics editor** — CRUD list + FAB.

This migrates raw Material onto the elevated global theme (bundles 01–09): outlined elevation-0 `Card` rows and the
native `Switch`/`AlertDialog` converge on the **soft-shadow `AppCard`** language; **every Cupertino glyph → Lucide**.
Full **dark parity (gold leads in dark)**. **All four screens are admin-only entry points.**

**Neutral-by-default discipline (MUST KEEP).** Color is reserved for the **slate/gold primary** (FAB · Save · focus
ring · code-cell outline) and **success-green** on the encoded test chips. **Inactive items stay** (struck-through
+ grey + "Inactive") so admin can reactivate — deactivate never deletes.

## About the Design Files
Design references created in HTML — a prototype, **not production code to ship**. Recreate in the Flutter codebase
using its real widgets (`SettingsTile`, `CostCodeEditor`, the shared form/`PasswordDialog`, theme layer).
- `MAKI POS Settings 10b.dc.html` — the redesign prototype (5 surfaces × light + dark). **Source of truth.**
- `reference_current-ui.html` — the current pre-redesign UI (all 9 Bundle-10 frames), before/after only.

## Fidelity
**High-fidelity (hifi).** Colors, type, spacing, radii, shadows, icons are final. **Match them precisely.**

---

## Source files (what to migrate)
| Surface | File |
|---|---|
| Manage Lists | `lib/presentation/mobile/screens/settings/category_settings_screen.dart` |
| Category editor (per kind) | `category_editor_screen.dart` |
| Edit form dialog | same / `mechanic_editor_screen.dart` (`AlertDialog` + `SwitchListTile`) |
| Cost Code Settings | `cost_code_settings_screen.dart` (+ `widgets/settings/cost_code_editor.dart`) |
| Mechanics editor | `mechanic_editor_screen.dart` |
Shared: `SettingsTile`, the shared **`PasswordDialog`** (`presentation/shared/widgets/common/password_dialog.dart`).

---

## Design Tokens
| Token | Light | Dark |
|---|---|---|
| Screen canvas | `#F6F5F3` | `#0C1415` |
| Card / row (`AppCard`) | `#FFFFFF` + shadow `0 2px 8px rgba(17,28,29,.06)` | `#18262A` + 1px border `#243234` |
| Neutral glyph tile | `rgba(40,62,70,.06)` bg · glyph `#8A9296` | `rgba(147,160,163,.12)` bg · glyph `#93A0A3` |
| Recessed fill (code digit-cell, dialog field) | `#FAFAFA` + 1px `#ECECEC` | `#0C1415` + 1px `#2C3C3E` |
| Primary (slate) — FAB · Save · focus · code outline | `#283E46` | gold `#E8B84C` (ink text `#121C1D`) |
| Text primary / muted | `#16201F` / `#8A9296` · chevron `#B4B8BA` | `#ECEFEF` / `#93A0A3` · chevron `#566163` |
| Inactive (name + subtitle) | `#9AA0A3` (name struck-through) | `#6C797C` |
| Reactivate (rotate-ccw) glyph | `#2E7D32` | `#8FE39A` |
| Success-green (test-encoding chip) | text `#2E7D32`, border `#4CAF50` | text `#8FE39A`, border `rgba(76,175,80,.5)` |
| Active switch (on) | track `#283E46`, knob `#FFF` | track `#E8B84C`, knob `#FFF` |

### Typography (Figtree; **Roboto Mono** for cost codes + test values)
App-bar title 18/600 · nav-row title 15/600 + subtitle 12.5 muted · CRUD-row title 15/600 (inactive struck + 12
"Inactive") · FAB 15/600 · dialog title 18/700 · field label 12 (slate/gold) · field value 15 · switch label
14.5/600 + sub 12 · section heading (Cost Code) 15/700 + helper 12 muted · info-card heading 14/700 + body 12.5 ·
mapping cell **mono 17/600** · test row **mono 14** · chip 14/600.

**Radii:** nav row / group 16 · CRUD row 14 · glyph tile 10–11 · code cell 10 · chip 8 · dialog 24 · field 14 ·
FAB 16 · phone frame 42.

### Icons — Lucide (stroke 1.85)
back `chevron-left` · Manage-Lists kinds `package` (Product) / `circle-dollar-sign` (Expense) / `ruler` (Units) /
`x-circle` (Void Reasons) + row `chevron-right` · editor overflow `more-vertical` · **edit `square-pen`** ·
**deactivate `archive`** · **reactivate `rotate-ccw`** (green) · FAB `plus` · form field `tag` (category) /
`wrench` (mechanic) · Cost Code app-bar **edit `square-pen`**, info `info`, mapping `arrow-right`, reset
`rotate-ccw` · Mechanics row glyph `wrench`.

---

## Screens / Views

### 4 — Manage Lists  (`category_settings_screen.dart`)
App bar: `chevron-left` + **"Manage Lists"**. Four **`AppCard` nav rows** (gap 10), each = neutral glyph tile +
title + "Used in …" subtitle + `chevron-right`: **Product Categories** (`package`, "Used in product form and
inventory filter") · **Expense Categories** (`circle-dollar-sign`, "Used in expense form") · **Units** (`ruler`,
"Used in product unit field") · **Void Reasons** (`x-circle`, "Used in void-sale dialog"). Each pushes the per-kind
editor (frame 5).

### 5 — Category editor  (`category_editor_screen.dart`)
App bar: `chevron-left` + the kind name (e.g. **"Product Categories"**) + trailing **`more-vertical`** overflow
(holds the **"Seed default …"** action **only for kinds with a starter set** — expense / unit / void-reason;
**product has none**). **CRUD rows** (separate `AppCard`s, gap 8): a title (15/600), then trailing **edit
`square-pen`** + **deactivate `archive`** icon buttons. **Inactive** rows show the name **struck-through + grey**
with an **"Inactive"** subtitle and a green **reactivate `rotate-ccw`** in place of archive. Tapping a row also
edits. **FAB "Add"** (`plus`, slate/gold, bottom-right). *(Sample: Brakes · Engine · Electrical active; Tires
inactive.)* **Empty state** (not shown) = kind glyph + "No {plural} yet" + "Tap Add to create one."

### 6 — Edit form dialog  (`AlertDialog` + `SwitchListTile`)
Over the dimmed editor. Title **"Edit Category"** (or "Add …" / mechanic equivalent). A **Name** field (label +
filled input, leading `tag` for category / `wrench` for mechanic) — **shown focused** (slate/gold 1.5px border +
ring). When **editing**, an **Active** `SwitchListTile` row ("Active" / "Visible in dropdowns" + themed switch,
on = slate/gold). Actions: **Cancel** (muted text) + **Save** (filled primary). **Validates name ≥ 2 chars.**

### 7 — Cost Code Settings  (`cost_code_settings_screen.dart`, password-gated)
App bar: `chevron-left` + **"Cost Code Settings"** + trailing **`square-pen`** (toggles edit mode). Body:
- **About Cost Codes** info card (slate/gold info tile + heading + muted paragraph).
- **Digit to Letter Mapping** (heading + helper) — a card of `digit → letter` rows: **mono digit cell** (recessed
  fill) · `arrow-right` · **mono code cell** (slate/gold outline). *(Display state; editing swaps in
  `CostCodeEditor`.)*
- **Test Encoding** — a card of `₱amount → CODE` rows (mono); the encoded code is a **success-green outlined chip**.
- **Reset to Default** — outlined full-width button (`rotate-ccw`).

> ⚠️ The mapping/test values here are **illustrative sample data** — **restyle only, never change the encoding**.
> **Saving and resetting both require `PasswordDialog` verification and log activity** (`logCostCodeChanged`);
> **Reset also shows a confirm `AlertDialog` first.** Edit mode toggles a bottom **Save** bar; **Cancel discards**.
> **Special codes (00 / 000)** also exist on this screen — wire them per the existing code; ask if their treatment
> is unclear.

### 8 — Mechanics editor  (`mechanic_editor_screen.dart`)
App bar: `chevron-left` + **"Mechanics"** (no overflow — mechanics has no seed). Same CRUD-row pattern as the
category editor, with a leading `wrench` glyph tile. *(Sample: Jun Reyes · Boy Garcia active; Pedro Cruz inactive.)*
**FAB "Add"**. Empty state = `wrench` + "No mechanics yet" + "Tap Add to create one."

---

## Interactions & rules (must keep)
- **Admin-only:** all four screens are admin entry points (gated upstream in the hub's Administration section).
- **Inactive stays, never deleted:** deactivate (archive) flips active→false; the row remains, struck-through +
  grey + "Inactive", with a **reactivate (rotate-ccw)** action. Historical records keep matching / snapshotted names.
- **Form dialog:** name ≥ 2 chars; the **Active** `SwitchListTile` shows only when editing; success/error snackbars.
- **Seed default:** the category editor's overflow offers "Seed default …" **only** for expense / unit / void-reason
  kinds (product has none).
- **Cost Code:** **Save & Reset are password-gated (`PasswordDialog`) and log activity**; Reset confirms first; edit
  toggles a Save bar, Cancel discards. Codes render in **mono**; encoded test chips use **success-green outline**.
- **Currency** grouped `₱1,234`.
- **Theme toggle** swaps the full light/dark token set (primary slate → gold on FAB / Save / focus / code outline).

## Must-keep (don't design these away)
CRUD rows with edit + archive/reactivate; **inactive struck-through + grey + reactivatable**; the **FAB Add**; the
form dialog's Name validation + conditional **Active** switch; the **password-gated, activity-logged** Cost Code
Save/Reset (+ Reset confirm); the digit→letter **mono** mapping with slate/gold code outlines + **green** test chips;
the Seed-default overflow scoping; **dark parity** on all five surfaces; **`AppCard`** everywhere (no outlined
Material `Card`); **Lucide** (off Cupertino); neutral-by-default discipline.

## Assets
Icons: **Lucide** (`lucide_icons`). Fonts: **Figtree** + **Roboto Mono** (cost codes / test values). No imagery.

## Files
- `MAKI POS Settings 10b.dc.html` — redesign prototype, **source of truth** (5 surfaces × light/dark).
- `reference_current-ui.html` — current/raw-Material UI (all 9 Bundle-10 frames), before/after only.
