# Handoff: MAKI POS — Sale Detail (refinement)

## Overview
Bundle 03 of the MAKI POS redesign. Sale Detail was **already migrated to the global theme** (soft-shadow
`AppCard`, `SummaryRow`, Lucide, theme-aware colors). This bundle is a **refinement** of that shipped screen —
four targeted changes, not a rebuild. Completed and voided states, both themes.

## About the Design Files
Design references in HTML — **not production code**. Recreate the changes in the existing Flutter screen
`lib/presentation/mobile/screens/sales/sale_detail_screen.dart` using `AppCard`, `SummaryRow`, and the shared
theme layer. This is a refinement diff against what already ships — only the four items below change; everything
else (structure, copy, role rules, receipt sheet) stays.

- `MAKI POS Sale Detail.dc.html` — the refined prototype (completed + voided, light + dark).
- `reference_current-ui.html` — the currently-shipping (pre-refinement) screen, for before/after.

## Fidelity
**High-fidelity.** Match the values below.

---

## The four changes

### 1. One hero, not two
**Before:** header sale-total at 34/700 **and** the Payment card "Total" at 26/700 — two competing big numbers.
**After:** the **header total is the only hero** (34/700). In the Payment card, demote **Total** to a strong
recap row — **16/700, default ink color** (not slate/gold, not 26px), keeping the `SummaryRow` divider above and
below it. This removes the duplicate-hero tension; the glance target is the header.
- `SummaryRow` for the payment "Total" should render at body-strong size here, not the hero variant.

### 2. Change as a tinted block
**Before:** Change was a thin green text row inside the summary.
**After:** when **change > 0**, render Change as a **tinted success block** (radius 14, success-tint bg
`#E8F5E9` light / `rgba(76,175,80,.16)` + .40 border dark): label `14/600` + value **22/700**, both `successText`
(`#2E7D32` / `#8FE39A`). When **change == 0**, keep it a plain `SummaryRow` (no block) — don't draw an empty
green box (see the completed/Salmon state, where received < total and change is 0).

### 3. Notes — readable amber
**Before:** label used raw `#FFC107`, nearly invisible on the light card.
**After:** tint container `rgba(255,193,7,.14)` light / `rgba(232,184,76,.16)` dark, border at .40 alpha. **Label**
text darkened for contrast: **`#8A6100` light** (icon `#9A6B00`), **`#E8B84C` dark**. **Body** text uses normal
ink (`#16201F` / `#ECEFEF`), not amber. Icon `sticky-note`.

### 4. Void button — pinned, outlined
Keep the **outlined-red** treatment and **pin it to the bottom** of the screen (footer bar over the scroll body,
top shadow `0 -4px 16px rgba(17,28,29,.05)` / `rgba(0,0,0,.4)`), 50px, radius 16, `x-circle` + label. Light:
white fill, `#F44336` border + text. Dark: transparent fill, `#F44336` border, `#FF6B5E` text. Respect role gating
(below). Voided sales show **no** action bar.

---

## Tokens (unchanged global theme)
| Role | Light | Dark |
|---|---|---|
| Canvas / card | `#F6F5F3` / `#FFFFFF` (soft shadow) | `#0C1415` / `#18262A` (1px `#243234`) |
| Hero total / sale # / muted | `#16201F` / mono `#283E46` / `#8A9296` | `#FFFFFF` / mono `#E8B84C` / `#93A0A3` |
| Completed badge | text `#2E7D32` on `#E8F5E9` | text `#8FE39A` on `rgba(76,175,80,.18)` |
| Voided badge | white on `#F44336` | white on `#F44336` |
| Error tint (banner / void-info) | `rgba(244,67,54,.10)` + `.40` border; heading `#D32F2F`, sub `#C0392B` | `rgba(244,67,54,.16–.18)` + `.45` border; heading `#FF8A80`, text `#F2A7A0`/`#FFB3AC` |
| Qty badge / labor badge | slate `#283E46` (white text) / gold `#E8B84C` (ink wrench) | gold `#E8B84C` (ink text) / gold (ink wrench) |

**Type:** Figtree; Roboto Mono for sale #, SKU, cost code. **Radii:** hero card 24, cards 18, change/total-recap
14, badge pill 999. **Icons (Lucide, stroke 1.75):** `chevron-left`, `file-text` (receipt + reason), `user`,
`wrench`, `credit-card`, `shopping-bag`, `clock`, `sticky-note`, `x-circle` (void), `x`/`check` (badge).

## Screen structure (top → bottom, unchanged)
Voided banner *(voided only)* → **Sale header hero** (sale #, date, **₱ total hero 34/700**; voided = muted +
strikethrough; status badge) → **ITEMS** (qty/labor rows) → **PAYMENT** (Subtotal · Discount · Labor · divider ·
**Total recap 16/700** · divider · Received · **Change block / row** · split tenders) → **DETAILS** (icon rows) →
**Void Information** *(voided)* → **Notes** *(if any)* → **pinned Void action** *(non-voided)*.

## Must-keep
- Read-only; receipt action still opens the print-styled `ReceiptWidget` sheet (unchanged).
- Void role-gating: `voidSale` → "Void This Sale" (direct); `requestVoidSale` → "Request Void"; pending → muted
  "Void pending approval" chip; neither → no action bar.
- Multi-tender (Salmon downpayment / balance, Mixed) rows + math + labels.
- Dark-theme parity.

## Files
- `MAKI POS Sale Detail.dc.html` — refined prototype (source of truth).
- `reference_current-ui.html` — currently-shipping screen, before/after.
- `screenshots/` — light + dark.
