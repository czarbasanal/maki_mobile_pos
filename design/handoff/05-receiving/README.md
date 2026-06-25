# Handoff: MAKI POS — Receiving (migration)

> ## ⚠ IMPLEMENTATION DIRECTIVE — READ FIRST
> **Follow EVERY detail presented in the design prototype (`MAKI POS Receiving.dc.html`) exactly.** It is the
> source of truth, not a loose suggestion. Match every color, hex value, font size, weight, icon, spacing, radius,
> shadow, padding, border, badge, label, and copy string as built — in **both light and dark themes**, across all
> five screens. Do **not** substitute your own values, "improve" layouts, swap icons, round off spacing, or skip
> states. If a detail in this README and the prototype ever disagree, **the prototype wins** — and flag it. When a
> value isn't shown for a given element, derive it from the token tables below (which are taken from the same
> prototype), never from guesswork. Pixel fidelity to the prototype is the acceptance bar for this bundle.

## Overview
Bundle 05. Migrates the five Receiving surfaces — **landing, bulk receiving, batch import, drafts, history** —
onto the elevated global theme. These screens shipped **Cupertino icons**, **Material `Card` / flat bordered
containers** (no `AppCard`), and **hardcoded `Colors.green/orange/blue/grey`** status tints with **no dark
parity**. This bundle brings all of it up to the language used in bundles 02–04: **Lucide icons**, **soft-shadow
`AppCard` surfaces**, and **theme-aware status tokens with full dark parity**.

## About the Design Files
HTML references — **not production code**. Recreate in the existing Flutter screens
(`lib/presentation/mobile/screens/receiving/…` + `lib/presentation/mobile/widgets/receiving/…`) using `AppCard`,
the shared theme layer, `AppDropdown`, `EmptyStateView`/`LoadingView`/`ErrorStateView`, and the existing
`ReceivingItemRow` / `ReceivingSummaryCardsRow` / `ImportPreview` / `CsvImportDialog` widgets. Translate the
prototype's CSS values to Flutter **faithfully** (see directive above).

- `MAKI POS Receiving.dc.html` — the migrated prototype (5 screens, light + dark). **Source of truth.**
- `reference_current-ui.html` — current pre-migration surfaces, for before/after only.
- `screenshots/01-light-theme.png`, `02-dark-theme.png`.

## Fidelity
**High-fidelity — pixel-faithful.** Per the directive, match every detail in the prototype.

---

## The migration changes
1. **Theme-aware status colors** — replace hardcoded `Colors.green/orange/blue/grey` with `AppColors` tokens:
   completed → `success`, draft → `warning`, total → `info`, cancelled → muted. Full dark parity (lightened icon
   variants in dark — see table).
2. **`AppCard` surfaces** — every Material `Card` and flat bordered `Container` (summary stats, list rows, item
   rows, add-product panel, import rows, error box) becomes a soft-shadow `AppCard` (light) / `#18262A` + 1px
   `#243234` (dark).
3. **Cupertino → Lucide** everywhere (map below).
4. **Bulk form** inputs get the standard fielded treatment (label + `AppCard`/field fill, paired two-up where
   short); **pinned summary + Complete** footer bar matching POS/Sale-Detail/Inventory.
5. **Batch import** keeps its already-semantic chips/badges, restyled onto `AppCard` rows + token error box.

## Tokens (global theme — taken from the prototype)
| Role | Light | Dark |
|---|---|---|
| Canvas / card | `#F6F5F3` / `#FFFFFF` (shadow `0 2px 8px rgba(17,28,29,.06)`) | `#0C1415` / `#18262A` (1px `#243234`) |
| Primary | slate `#283E46` (Add, Complete, New Receiving, Import, links) | gold `#E8B84C` (ink text on fills) |
| Field fill / border | `#FAFAFA` / `#E2E2E2` | `#0C1415` / `#2C3C3E` |
| Text primary / muted / hint | `#16201F` / `#8A9296` / `#9AA0A3` | `#ECEFEF` / `#93A0A3` / `#6C797C` |
| Completed / success | icon `#4CAF50`, text `#2E7D32` on `#E8F5E9` | icon `#5FC86A`, text `#8FE39A` on `rgba(76,175,80,.16–.18)` |
| Draft / warning | icon `#F57C00`, badge text `#9A6300` on `rgba(245,124,0,.12–.14)` | icon/text `#F5B547` on `rgba(245,181,71,.16–.18)` |
| Total / info | icon `#2196F3`; new-variant badge text `#1976D2` on `rgba(33,150,243,.13)` | icon `#5AA9F0`; badge `#7FB6FF` on `rgba(33,150,243,.2)` |
| Error | text `#D32F2F`/`#C0392B` on `rgba(244,67,54,.07)`, border `.40` | text `#FF8A80`/`#F2A7A0` on `rgba(244,67,54,.12)`, border `.45` |
| Cost-diff up / down | `#C62828` / `#2E7D32` (outlined badge) | `#FF6B5E` / `#8FE39A` |

**Type:** Figtree; Roboto Mono for ref # / SKU. Sizes (from prototype): stat value 22/700 (total 20/700) · section
header 16/700 · month header 12/600 uppercase muted · ref # 13/600 mono · item name 13/600 · summary total 22/700
· badge 10–11/600. **Radii:** field/btn/card 14–16, badge 8, pill 999. **Pinned footers:** top shadow
`0 -4px 16px rgba(17,28,29,.05)` light / `rgba(0,0,0,.4)` dark; primary button shadow
`0 8px 20px -6px rgba(40,62,70,.55)` slate / `rgba(232,184,76,.45)` gold.

### Icons (Cupertino → Lucide, `lucide_icons`)
back `chevron-left` · batch import `upload-cloud` · new/add `plus` · drafts `square-pen` · completed `check-circle`
· total `trending-up` · supplier `briefcase` · dropdown `chevron-down` · search `search` · qty stepper
`minus-circle`/`plus-circle` · remove `x` · save draft `save` · cost-up `arrow-up`/`arrow-up-right` · cost-down
`arrow-down`/`arrow-down-right` · import action `arrow-right-circle` · adjust-stock (read-only) `square-pen` ·
delete (swipe) `trash-2` · empty-state `package`/`shopping-cart`.

---

## Screens (match the prototype for each)

### 1 · Receiving landing (`receiving_screen.dart`)
App bar: back · "Receiving" · batch import (`upload-cloud`). Body: **3 summary `AppCard` stats** (Drafts warning
`square-pen` · Completed success `check-circle` · Received info `trending-up`, compact `₱45.6K`; value 22/700, tap
Drafts→drafts, Completed→history) → "Recent Receivings" + "View all" → this-week **`AppCard` rows**: status-tint
leading circle, ref # (mono), `date · time · supplier` (ellipsis), trailing **status badge** + item count + ₱total
*(admin)*. Pinned **"New Receiving"** (primary, `plus`). Empty/loading/error per README states. Admin → per-row
₱total + Received card.

### 2 · Bulk receiving (`bulk_receiving_screen.dart`)
App bar: back · "Receive Stock" / "Receiving Details" + ref # subtitle · Import CSV (`upload-cloud`) · Save Draft
(`save`, disabled when empty). Body: **Supplier** field (`briefcase`, "No supplier" default) → *(edit)*
**Add Product `AppCard` panel**: search → **Quantity** (+ unit) + **Unit Cost** *(admin, ₱)* two-up + **Add**;
**cost-diff warning** (warning-tint, "Cost increased/decreased X% — a new SKU variation will be created") →
**item `AppCard` rows** (`ReceivingItemRow`): name · SKU (+ **New Variant** info badge) · `Cost ₱ · Sells ₱`
(+ cost-diff outlined badge admin) · qty **stepper** (`minus-circle`/field/`plus-circle`; read-only `×N`) · line
total *(admin)* + unit · `x` remove (read-only → `square-pen` "Adjust stock"). Swipe-left delete (red `trash-2`).
**Pinned summary**: "N products / M units" + **Total Cost ₱** *(admin)* + **"Complete Receiving"** (`check-circle`,
spinner while processing) → confirm dialog "Complete Receiving?" (lists cost-different lines for admin) → "Post
Receiving". Read-only completed view: success banner "Completed on {date}. Read-only." States + validation per
README. Admin → unit cost, search cost, line totals, total-cost, cost-diff badges/warnings, price-change dialog.

### 3 · Batch import (`batch_import_screen.dart` + `csv_import_dialog.dart` + `import_preview.dart`)
App bar: back · "Batch Import". **Idle:** expandable "CSV format" help card (column spec, GENERATE rule, variation
rule) → Supplier dropdown ("applies to all rows") → "Pick CSV file" (`upload-cloud`). **Parsing/Importing:**
centered spinner. **Preview** (prototype shown): **summary chips** — Match (success) · Cost variation (warning) ·
New product (info) · Errors (error) → **error `AppCard`** ("Skipped rows") → **classified `AppCard` rows**: name ·
`SKU · qty unit · ₱cost` + right **badge** (Match/Variation/New) → bottom **Cancel** + **"Import N rows"**
(`arrow-right-circle`, disabled when blocked/empty). New-product rows require `Permission.addProduct` (else banner
+ disabled import). **Done:** `check-circle` + "Import completed" + "Reference: …" + "Back to receiving" / "Import
another". **Errored:** `alert-triangle` + message + "Try again".

### 4 · Drafts list (`receiving_drafts_screen.dart`)
App bar: back · "Draft Receivings". **`AppCard` rows**: warning `square-pen` leading, ref #, `N items · M units ·
date`, trailing **"Resume"**. Empty ("No Drafts" / "In-progress receivings appear here") / loading / error.

### 5 · Receiving history (`receiving_history_screen.dart`)
App bar: back · "Receiving History". **Month-grouped** ("MMMM y" header 12/600 uppercase + count) → **`AppCard`
rows**: success `check-circle` leading, ref #, `date · supplier`, trailing item count + ₱total *(admin)*; tap →
bulk receiving read-only. Empty ("No Receiving History" / "Completed receivings will appear here") / loading /
error. Admin → per-row ₱total.

## Must-keep
- All role-gating (admin: unit cost, search cost, line/total costs, cost-diff badges/warnings, price-change
  dialog; `addProduct` for CSV new-product rows).
- Read-only mode for completed receivings; SKU-variation-on-cost-change behavior + its warnings/dialog copy.
- CSV format rules + GENERATE + variation logic; draft save/resume; supplier optional.
- Currency grouped (`₱1,234.00`); dates `MMM d, y • h:mm a`, month `MMMM y`.
- Dark-theme parity on every screen.

## Files
- `MAKI POS Receiving.dc.html` — migrated prototype (**source of truth — follow every detail**).
- `reference_current-ui.html` — current surfaces, before/after.
- `screenshots/01-light-theme.png`, `02-dark-theme.png`.
