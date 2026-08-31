# Handoff: Closing History (mobile) — current-state capture for redesign

## What this bundle is

A record of **how the mobile Closing History screen looks and behaves today**, so it can be
redesigned from an accurate starting point. It is *not* a proposal and *not* a target design.

- `reference_current-ui.html` — the two views, light and dark, reproduced faithfully.
- This README — structure, data, conditional rows, and the constraints a redesign must respect.

Source of truth in code:
`lib/presentation/mobile/screens/reports/daily_closing_history_screen.dart`
plus `closing_widgets.dart`, `closing_handover_panel.dart`, `after_close_card.dart`,
`variance_style.dart`. Captured from `main` on **2026-08-31**, shipped in **APK +31**.

> There is an older bundle, `design/design_handoff_eod/`, that covers End-of-Day *and* an earlier
> version of this list. It is now out of date for this screen — the summary was restructured on
> 2026-08-30/31. **Prefer this bundle for Closing History.**

## The screen in one line

A cashier or admin opens it to answer: *what happened on a day we already closed, and who was
supposed to receive which cash?*

## View 1 — list of closed days

- Reached from End-of-Day. Newest first. `ListView` of `AppCard` rows, 10px apart.
- No detail route: tapping a row **expands it in place**. The chevron flips.
- Row: business date (`EEE, MMM d, y`) · two-line muted sub-line (`Cash on hand ₱X` where only the
  amount is inked and semibold, then `Closed <MMM d, h:mm a>`) · variance pill · chevron.
- **Variance pill is the only colour on the screen.** Three states, from `VarianceStyle`:
  | State | When | Light text | Icon | Word |
  |---|---|---|---|---|
  | Balanced | variance == 0 | `#4CAF50` | check | Balanced |
  | Short | counted < expected | `#F44336` | trending-down | Short |
  | Over | counted > expected | `#F57C00` | trending-up | Over |
  In dark these become `#8FE39A` / `#FF6B5E` / `#F5B547`. The pill in the list shows the signed
  amount; the same style object drives the word+icon elsewhere.
- States: `ListSkeleton` while loading · `ErrorStateView` with Retry on error · `EmptyStateView`
  (history icon, "No closings yet" / "Closed days will show up here.") when there are none.

## View 2 — a day expanded

An inline block under the row, separated by a **top hairline**. Not a nested card. Padding
`16, 12, 16, 14`. Rows are the `dense` variant (13px, weight 500).

**Exact order.** Three small-caps headings (10px / 700 / `.7px` tracking / muted) group the rows;
anything that breaks down the row above it is indented 14px and uses dimmer label+value colours.

```
SALES
  Gross sales (parts)
  Labor (service)
  Cash sales
  Non-cash sales
    GCash                 (only if > 0)
    Maya                  (only if > 0)
    Salmon receivable     (only if > 0)
EXPENSES
  Total expenses
    Cash expenses
CASH RECONCILIATION
  Opening float
  Plate No DP
  Plate No Delivery
  Expected cash
  Counted cash
[ After close card ]      (only when the day drifted — see below)
[ CASH HAND-OVER panel ]  (always)
  Closed by <name> · <date · time>
  Notes: <text>           (only if notes were written)
```

### Why the grouping exists (do not flatten it back)

- **Gross is parts money only.** Labor and shop fees are separate tracks that were never added to
  it. The label says `(parts)` and `Labor (service)` sits directly underneath **because the
  hand-over below subtracts labor** — without labor visible arriving, it reads as being deducted
  twice. This was a real, reported complaint.
- **Rows render at zero.** `Plate No DP`, `Plate No Delivery` and `Labor (service)` are shown even
  when ₱0.00. They used to be hidden when empty, and an absent row was read as *"this screen does
  not show that"* rather than *"there was none"* — also a reported complaint.
- **Expected cash is reconcilable on screen**: `opening float + cash sales − cash expenses +
  plate DP − plate delivery`. Every term has a row. Do not remove one.

### The cash hand-over panel

Bordered box (1px hairline, radius 14), not a card — it sits inside the detail block.
Values use the **mono** family; labels are muted; the two destinations are emphasised.

```
CASH HAND-OVER          ← eyebrow, 10.5px/700, 1.1px tracking
Counted            ₱X
────────────────────
To mechanics       ₱Y   ← emphasised
    <mechanic>     ₱..  ← one indented line per mechanic, live from the day's sales
To management      ₱Z   ← emphasised
```

- `To mechanics` = the day's whole labor revenue. Mechanics are settled **in cash from the drawer
  even when the customer paid labor digitally** — that is deliberate.
- `To management` = counted cash − labor. The opening float is **not** held back.
- Per-mechanic lines are read from live sales while the total is frozen at closing, so they can
  disagree after a post-close void. When they do, a small muted note says so rather than silently
  substituting either figure.

### The drifted case (a day closed before the last customer left)

This is **routine at this shop** — the drawer is closed and late customers still arrive. When
anything landed after close:

1. An **After close** card renders *above* the hand-over (warning-toned icon, `ClosingSectionCard`):
   sales after close, cash collected after close, and — only when labor moved — indented
   `Sale items` / `Labor fees` sub-rows. It reports **what changed**, nothing else.
2. The hand-over then **supersedes its own sealed figures**: `To mechanics` becomes whole-day
   labor, `To management` is recomputed, and a footer row **`Updated cash on hand`** closes the
   panel (larger, accent-coloured, mono).
3. With drift, the two destinations add up to the **footer**, not to the `Counted` row at the top.
   Without drift there is no footer and `Counted` is the total.

Order matters: what changed is explained *before* the hand-over states amounts that moved.

## Constraints for the redesign

1. **Never change a figure, a formula, or the meaning of a row.** Everything is computed elsewhere
   and frozen into an immutable closing document. This is a restyle.
2. **Do not drop rows, and do not hide rows at zero.** Several exist specifically because hiding
   them caused misreadings.
3. **Keep the variance colour semantics** (balanced / short / over) and their dark counterparts.
4. **Colour stays scarce.** The screen is deliberately neutral; colour carries status only —
   the variance pill, the after-close warning tone, the accent on the updated total.
5. **Both themes.** Light and dark ship together; gold leads in dark, slate in light.
6. **Mono for money in the hand-over panel**, matching SKU/sale-number treatment elsewhere.
7. Expanding stays **in place**. A detail route would lose the list's scroll position and the
   at-a-glance comparison between days, which is most of why the list exists.

## Known rough edges (fair game to solve)

- The expanded block is long — around 18 rows before the panel on a busy day — and everything is
  the same size. There is little visual hierarchy between "reference figure" and "the number I act
  on".
- `Counted cash` appears twice: once as a reconciliation row and again as `Counted` at the top of
  the hand-over. That repetition is intentional today (the panel must show what it divides) but it
  is the kind of thing a better layout could resolve.
- On a drifted day the reader sees a sealed count, an after-close delta, and an updated total in
  three places. It is correct but dense.
- There is no way to jump from a closed day to that day's sales.

## Tokens (from `lib/core/theme/`)

| Role | Light | Dark |
|---|---|---|
| Canvas | `#FFFFFF` | `#0C1415` |
| Card | `#FFFFFF` | `#18262A` |
| Ink | `#16201F` | `#ECEFEF` |
| Muted label | M3 `onSurfaceVariant` | `#93A0A3` |
| Indented label | M3 `outline` | — |
| Indented value | `#5A6468` | `#AEC0C6` |
| Hairline | `#ECECEC` | `#243234` |
| Accent | slate `#283E46` | gold `#E8B84C` |

Type: **Figtree** throughout; **RobotoMono** for money in the hand-over panel.
Radii: card `AppRadius.field` (16), section/panel `AppRadius.md` (14), pill full.
Icons: **Lucide** (`chevron-up/down`, `check`, `trending-up/down`, `clock`, `user`, `history`).
