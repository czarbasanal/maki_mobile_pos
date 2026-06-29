# Handoff: MAKI POS — End-of-Day + Closing History

> # ⚠️ CLAUDE CODE — COPY EVERY DETAIL IN THIS HANDOFF. NO EXCEPTIONS.
> **`MAKI POS End of Day.dc.html` is the single source of truth. Reproduce it EXACTLY.**
> Every color, hex value, font size, weight, padding, gap, radius, border, shadow, icon, copy string, row order,
> and state below is **intentional and already verified** — replicate all of it, do not skip any. **Do NOT**
> redesign, "improve", simplify, round values, substitute icons, re-order sections, rename labels, or drop any
> state/banner/conditional row. Build **both light and dark** themes, every screen, every state shown.
> - If this README and the HTML ever disagree, **the HTML wins** — open it and read the inline styles directly.
> - Implement in the existing codebase using its real widgets/theme (this is a visual spec, not code to paste).
> - **The reconciliation math (expected cash, variance, after-close totals) is computed elsewhere — restyle only,
>   NEVER change a figure or a formula.**
>
> When in doubt, match the prototype rather than your own judgment. Treat "follow every detail" literally.

## Overview
Bundle **06b** of the MAKI POS redesign — the **cash-drawer closing flow**: the editable **End-of-Day** review/close
form, its immutable **closed** read-only view (with the optional post-close recalculation), and the **Closing
History** list. It brings all three states onto the **elevated global theme** (bundles 01–05): raw Material `Card`
sections, filled `TextFormField`s, and `ExpansionTile` rows become soft-shadow **`AppCard`** surfaces with the
app's field styling; **Cupertino icons → Lucide**. The **variance color semantics** and the success/post-close
status treatments are preserved exactly, with full dark parity (**gold leads in dark**). Sibling of bundle 06a.

This reuses the **global theme** — do **not** invent new tokens. Pull from `lib/core/theme/` (or the project's
established theme layer) exactly as bundles 01–05 did, and adopt the app's field styling (`AppRadius.field`, theme
input borders) used on the other redesigned screens.

## About the Design Files
These files are **design references created in HTML** — a prototype of the intended look and behavior, **not
production code to ship**. The task is to **recreate them in the existing Flutter codebase**
(`lib/presentation/mobile/screens/reports/…`) using its established widgets (`AppCard`, the shared input fields,
section/key-value patterns) and the theme layer. Translate the CSS values below into Flutter `ThemeData` / widget
styles. (If the target is some other environment, recreate faithfully using that stack's idioms — but the visual
result must be identical.)

- `MAKI POS End of Day.dc.html` — the redesign prototype (3 states × light + dark). **Source of truth.**
- `reference_current-ui.html` — the current pre-redesign UI (Cupertino + raw Material `Card`/`TextFormField`/`ExpansionTile`), for before/after only.

## Fidelity
**High-fidelity (hifi).** Colors, type, spacing, radii, shadows, and icons are final. **Match them precisely.**

---

## Source files (what to migrate)
| State | File |
|---|---|
| End-of-Day — review & close (open, editable form) | `lib/presentation/mobile/screens/reports/end_of_day_screen.dart` |
| End-of-Day — closed (read-only + post-close) | same file, `_ClosedView` |
| Closing History (expansion list) | `lib/presentation/mobile/screens/reports/daily_closing_history_screen.dart` |

Container surfaces migrate from Material `Card` → `lib/presentation/shared/widgets/common/app_card.dart` (`AppCard`):
light = soft shadow; dark = `darkCard` `#18262A` + 1px hairline `#243234`. Inputs migrate from filled
`InputDecoration` → the app's standard field style.

---

## Design Tokens

| Token | Light | Dark |
|---|---|---|
| Screen canvas | `#F6F5F3` | `#0C1415` |
| Card / section (`AppCard`) | `#FFFFFF` + shadow `0 2px 8px rgba(17,28,29,.06)` | `#18262A` + 1px border `#243234` (no shadow) |
| Row divider (in a card) | `#F0F0F0` | `#243234` |
| Primary (slate) | `#283E46` | gold `#E8B84C` **leads** |
| Text primary / muted / hint | `#16201F` / `#8A9296` / `#9AA0A3` | `#ECEFEF` / `#93A0A3` / `#6C797C` |
| KV value / indented sub-row value | `#16201F` (600) / `#5A6468` | `#ECEFEF` (600) / `#AEC0C6` |
| Input fill / border | `#FAFAFA` / `#E2E2E2` | `#0C1415` / `#2C3C3E` |
| Input focus (Counted cash) | 1.5px `#283E46` + ring `0 0 0 4px rgba(40,62,70,.07)`, label slate | 1.5px `#E8B84C` + ring `0 0 0 4px rgba(232,184,76,.12)`, label gold, fill `#18262A` |
| Expected-cash emphasis panel | bg `rgba(40,62,70,.06)`, value **slate** | bg `rgba(232,184,76,.10)`, value **gold** |
| Close Day button (destructive) | `#F44336`, white, shadow `0 8px 20px -6px rgba(244,67,54,.45)` | same red, shadow `…,.4` |

### Variance — color semantics (MUST KEEP, used on the form, the closed view, and every history row)
Computed as **counted − expected**. The chip/word, the value color, and the panel/pill tint all follow the sign:
| State | Rule | Light (text · tint · chip-icon) | Dark |
|---|---|---|---|
| **Balanced** | counted = expected (`₱0.00`) | `#2E7D32` · `rgba(76,175,80,.08)` panel / `#E8F5E9` pill · `check` | `#8FE39A` · `rgba(76,175,80,.16)` · `check` |
| **Short** | counted < expected (e.g. `-₱20.00`) | `#F44336` · `rgba(244,67,54,.07)` panel / `rgba(244,67,54,.10)` pill · `trending-down` | `#FF6B5E` · `rgba(255,107,94,.12–.14)` · `trending-down` |
| **Over** | counted > expected (e.g. `+₱50.00`) | `#F57C00` · `rgba(245,124,0,.09)` panel / `rgba(245,124,0,.12)` pill · `trending-up` | `#F5B547` · `rgba(245,181,71,.12–.14)` · `trending-up` |

The **form & closed view** show variance as a **tinted panel** (radius 13, padding 12×14): left = "Variance" 14/600
ink + small status chip (10/600, icon + word); right = **value 17/700 colored, `white-space:nowrap`**. The **history
rows** show it as a **tinted pill** (12/700, icon + signed amount). *(The mock shows "Short" on the EOD screens; the
history list shows all three.)*

### Status banners (closed view)
- **Closed-by (success):** bg `#E8F5E9` / `rgba(76,175,80,.14)`, radius 14, padding 12×14, `badge-check` icon + text `#2E7D32` / `#8FE39A`, 13.5/600. Copy: **"Closed by {name} at {time}"**.
- **Post-close warning (amber, conditional):** bg `#FFF6E6` border `#F0C36B` / dark bg `rgba(245,181,71,.12)` border `rgba(245,181,71,.4)`, `alert-triangle` icon + text `#C8881A`/`#8A5E12` (light) / `#F5B547` (dark), 12.5, line-height 1.45, top-aligned. **Only renders when sales/voids were recorded after the day was closed.** Copy: **"N sales totaling ₱… were recorded after this day was closed at {time}. See 'After close' below for the updated cash on hand."**

**Type:** **Figtree** (400/500/600/700/800) primary; **Roboto Mono** (500/600) reserved for sale numbers / SKUs (not
needed on these screens). Sizes: app-bar title 18/600 · card title 15/700 · KV 14 (label muted / value 600) ·
indented sub-row 13 · field value 15 · field label 12 · Expected-cash value 17/700 · variance value 17/700 ·
Updated-cash-on-hand value 18/700 · history date 14/700 · pill/chip 10–12. **Radii:** field 14 · emphasis/variance
panel 13 · section & history card 16–18 · button 16 · pill/chip 999. **Shadows:** card `0 2px 8px rgba(17,28,29,.06)`
(light only; dark = 1px hairline). Use explicit `BoxShadow` in Flutter — Material `elevation` alone won't match.

**Currency:** `toCurrencyWithoutSymbol()` with a `₱` prefix (`₱1,234.00`). **Dates:** `EEE, MMM d, y`
("Fri, Jun 27, 2026") and `MMM d, h:mm a` ("Jun 27, 6:32 PM").

**Icons — Lucide, stroke 1.75–1.9:** status `signal-high`/`wifi`/`battery-full` · back `chevron-left` · history
action `history` · **Sales** `receipt` · **Expenses** `arrow-down-circle` · **Plate No Orders** `clipboard-list` ·
**Cash reconciliation** `calculator` · **After close** `clock` (amber) · variance short `trending-down` / over
`trending-up` / balanced `check` · post-close `alert-triangle` · closed-by `badge-check` · **Close Day** `lock` ·
history meta `user` · expand `chevron-down` / `chevron-up`.

---

## Screens / Views

> Each screen is a flex **column**: status bar (36) → app bar (≈52) → **scrolling body** (padding `14 16 20`). App
> bar + status sit on the screen canvas. The EOD screens carry a trailing **History** action (`history`).

### State 1 — End-of-Day · review & close (open, editable form)  (`end_of_day_screen.dart`)
**App bar:** `chevron-left` back · **"End-of-Day Closing"** · trailing `history`.
**Body — stacked `AppCard` sections (margin-bottom 12):**

1. **Sales** (`receipt`) — read-only key/values: **Gross sales** ₱8,420.00 · **Cash sales** ₱5,200.00 ·
   **Non-cash sales** ₱3,220.00 → indented **GCash** ₱2,240.00, **Maya** ₱980.00 · **Discounts** ₱120.00 ·
   **Labor revenue (service)** ₱650.00 · **Sales count** 14. **Conditional rows render only when > 0** (this
   includes a **Salmon receivable** row, not shown here because it is 0).
2. **Expenses** (`arrow-down-circle`) — **Total expenses** ₱430.00 · **Cash expenses** ₱430.00.
3. **Plate No Orders** (`clipboard-list`) — **two ₱ input fields**: **Plate No DP** (placeholder `0`) and **Plate No Delivery** (placeholder `0`).
4. **Cash reconciliation** (`calculator`), in order:
   - **Opening float** — ₱ input (`1,000.00`).
   - **Expected cash** — **emphasis panel** (slate-tint / gold-tint), value 17/700 slate/gold — `₱5,770.00`.
   - **Counted cash \*** — **required** ₱ input, shown **focused** (primary 1.5px border + focus ring) — `5,750.00`.
   - **Variance** — tinted panel per the semantics table (mock = **Short**, `-₱20.00`).
5. **Notes** — labeled textarea (min-height 64), placeholder "Optional…".
6. **Close Day** — full-width **destructive red** button (`lock` + "Close Day") + helper line "Closing locks the day — it can't be edited afterward." **Tapping opens a confirm dialog** ("cannot be edited afterward") before closing.

### State 2 — End-of-Day · closed (read-only + post-close)  (`_ClosedView`)
Same app bar. Immutable — **no inputs, no Close button.** Body:
1. **Post-close warning** (amber, **conditional** — see banners) — *only when sales/voids landed after close.*
2. **Closed-by banner** (success) — "Closed by Maria Santos at 6:32 PM".
3. **Sales** card — same key/values as the form (no count, no inputs).
4. **Cash reconciliation** card — **Opening float** / **Expected cash** / **Counted cash** as flat key/values, then the **Variance** tinted panel (`-₱20.00`, Short).
5. **After close** card (`clock`, amber icon) — **only with post-close activity:** **Sales after close** `+2 · +₱1,300.00` · **Cash collected after close** `+₱800.00` · divider · **Updated cash on hand** (15/600 label + **18/700 slate/gold value**) `₱6,550.00`. *These are recomputed figures — restyle only.*

### Screen 3 — Closing History  (`daily_closing_history_screen.dart`)
**App bar:** `chevron-left` back · **"Closing History"**. **Body:** newest-first list of **expandable `AppCard`
rows** (radius 16).
- **Row header** (padding 14×16, gap 12): left = **date 14/700** (`Fri, Jun 27, 2026`) over **sub 12 muted**
  "Cash on hand **₱5,750.00**" + line-break + "Closed Jun 27, 6:32 PM"; trailing = **variance pill** (per semantics)
  + **chevron** (`chevron-up` expanded / `chevron-down` collapsed, muted).
- **Expanded detail** (top hairline, padding 12×16×14): full key/value reconciliation — Gross sales, Cash sales,
  Non-cash sales → indented GCash/Maya, Total expenses, Cash expenses, Opening float, Expected cash, Counted cash
  (13px rows, label muted / value 500) — then a **meta line** (`user` icon, 11.5 hint) "Closed by Maria Santos ·
  Jun 27, 2026 · 6:32 PM".
- **Mock rows:** Jun 27 **Short** `-₱20.00` (expanded) · Jun 26 **Balanced** `+₱0.00` · Jun 25 **Over** `+₱50.00` ·
  Jun 24 **Short** `-₱85.00`.
- **Empty state:** "No closings yet."

---

## Interactions & Behavior
- **Open form:** the two Plate-No fields, Opening float, Counted cash, and Notes are editable; everything else is
  computed. **Expected cash** and **Variance** recompute live as Opening float / Counted cash change (variance
  re-tints across balanced/short/over).
- **Close Day** → confirm dialog → on confirm the day is closed and the screen swaps to the **closed read-only**
  view. Closing is **irreversible** (no edit afterward).
- **Post-close:** if sales/voids are recorded after the close timestamp, the amber warning + "After close" card
  appear and "Updated cash on hand" reflects post-close cash. Don't alter the math — restyle only.
- **Closing History rows** expand/collapse (chevron flips) to reveal the full reconciliation.
- **Theme toggle** swaps the entire light/dark token set, including primary flipping slate → gold (section icons,
  Expected-cash / Updated-cash values, input focus).

## State Management
Reuse the existing closing providers/blocs. Needed: the day's aggregates (gross/cash/non-cash + GCash/Maya,
discounts, labor revenue, sales count, salmon receivable) · expenses (total, cash) · plate-no inputs (DP, delivery)
· reconciliation (opening float, **computed** expected cash, counted-cash input, **computed** variance + state) ·
notes · closing status (open vs closed: closed-by name + timestamp) · **post-close** activity (sales-after-close
count/total, cash-collected-after-close, **computed** updated cash on hand) · closing-history list (per day: date,
cash on hand, closed-at, variance + state, full reconciliation, closed-by) with expand state.

## Must-keep
- **Variance color semantics** (balanced green · short red · over amber) on the form, closed view, **and** every history row.
- **Closed view is immutable**; success closed-by banner; the **confirm dialog** before closing.
- **Post-close** amber warning + **After-close** recompute (figures computed — don't touch the math).
- **Conditional Sales rows** (render only when > 0), including **Salmon receivable**.
- Section order in the open form: **Sales → Expenses → Plate No Orders → Cash reconciliation → Notes → Close Day.**
- Cash-reconciliation order: **Opening float → Expected cash (emphasis) → Counted cash (required) → Variance.**
- **Dark parity** on all three states; **`AppCard`** everywhere (no leftover flat Material `Card`); **Lucide** (off Cupertino); app field styling.
- Currency via `toCurrencyWithoutSymbol()` + `₱`; dates `EEE, MMM d, y` / `MMM d, h:mm a`.

## Assets
- Icons: **Lucide** (`lucide_icons`) — migrate off Cupertino. No custom SVGs.
- Fonts: **Figtree** (+ Roboto Mono, already in project).
- No images/photography in these screens.

## Files
- `MAKI POS End of Day.dc.html` — redesign prototype, **source of truth** (3 states × light/dark).
- `reference_current-ui.html` — current/flat UI (Cupertino + Material), before/after only.
