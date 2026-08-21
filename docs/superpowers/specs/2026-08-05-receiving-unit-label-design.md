# Receiving screens say "units", not "items"

**Date:** 2026-08-05
**Surfaces:** Flutter app (`lib/`) and web admin (`web_admin/`)
**Status:** Design approved, ready for planning

## Problem

Six receiving displays label a **quantity sum** with the word "items". A
receiving of 3 line items totalling 12 pieces reads "12 items" — the number
counts pieces, the word counts lines.

`ReceivingEntity.totalQuantity` is a sum over every line's `quantity`. Nothing
in the six sites renders a line count, so no site is mislabelled in the other
direction.

| Site | Current |
|---|---|
| `lib/presentation/mobile/screens/receiving/receiving_screen.dart:204` | inline `'${receiving.totalQuantity} items'` |
| `lib/presentation/mobile/screens/receiving/receiving_history_screen.dart:198` | inline `'${receiving.totalQuantity} items'` |
| `web_admin/src/presentation/features/receiving/ReceivingDashboardPage.tsx:68` | inline `{r.totalQuantity} items`, in the headerless Drafts table |
| `web_admin/src/presentation/features/receiving/ReceivingDashboardPage.tsx:102` | column header `Items`, over the bare value at `:119` |
| `web_admin/src/presentation/features/receiving/ReceivingHistoryPage.tsx:63` | column header `Items`, over the bare value at `:84` |
| `web_admin/src/presentation/features/receiving/ReceivingDetailPage.tsx:111` | label `Total items`, over the bare value at `:112` |

Two receiving displays already say it correctly and are **not** in scope:

- `receiving_drafts_screen.dart:105` — `'3 item(s) · 12 units · <date>'`, which
  separates the line count from the quantity
- `bulk_receiving_screen.dart:556` — `'12 total units'`

## Solution

Replace "items" with "units" at the six sites. Six string literals. No helper,
no logic, no data dependency, no schema or query change.

| Site | After |
|---|---|
| both mobile screens | `'12 units'` |
| Dashboard `:68` | `{r.totalQuantity} units` |
| Dashboard `:102`, History `:63` | column header `Units` |
| Detail `:111` | label `Total units`, which also reads better beside the `Total cost` row directly beneath it |

After this change all eight receiving quantity displays agree.

## Why "units" and not the real unit

The purchase-order screens, changed the same week, show the order's actual
shared unit (`12 set`) and fall back to a bare count when lines disagree. This
deliberately diverges, for two reasons:

1. **Half these sites are column headers or section labels.** A `<th>` cannot
   carry a per-row unit, so "show the real unit" does not apply to three of the
   six — it would leave the surface half-converted.
2. **A receiving is a broader event than a purchase order.** The shop confirms a
   PO never mixes units, which is what makes a single shared unit meaningful
   there. A receiving can span suppliers and products, so a shared unit is
   neither guaranteed nor especially informative.

"Units" is honest at all six sites and matches the two that were already right.

## Non-goals

- **Showing the real unit on receiving.** Ruled out above.
- **Reusing or relocating `sharedUnitOf` / `poQuantityLabel`.** With "units"
  chosen, receiving is not a second consumer, so the relocation to
  `lib/core/utils/` that a prior review anticipated is **not** triggered. Leave
  those helpers where they are.
- **Adding a line count** anywhere it isn't already shown. `receiving_drafts_screen.dart`
  shows both because it always did; the other sites show one number and will
  continue to.
- **Touching `totalQuantity` itself.** The sum is correct; only its label is wrong.

## Testing

TDD: failing test first.

**Mobile** — a widget test per screen: a receiving of 3 lines totalling 12
renders `12 units`, and does **not** render `12 items`. The negative half is
what catches a partial sweep.

**Web** — a component test per file: the Dashboard's Drafts row renders
`12 units`; the Dashboard and History column headers read `Units` and not
`Items`; the Detail summary reads `Total units` and not `Total items`.

Each assertion pairs a positive with the corresponding negative. A test that
only asserts "units" appears somewhere would pass while a sibling site still
said "items".

**Commands:** `flutter test`, `flutter analyze`; from `web_admin/`,
`npm run typecheck`, `npm run test`, `npm run build`.
