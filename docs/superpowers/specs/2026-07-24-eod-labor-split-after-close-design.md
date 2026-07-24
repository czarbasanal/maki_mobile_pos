# EOD labor split + After Close in Closing History + sales-history icon removal

Date: 2026-07-24
Surface: Flutter mobile app only. No Firestore schema, index, or rules changes.

## Problem

1. At end-of-day handoff, the drawer cash contains both money for sale items
   (goes to management) and labor/service fees (paid out to mechanics). The EOD
   screens show only combined cash figures, so staff must do the split by hand.
2. Sales made after the drawer is closed already surface on the closed EOD
   screen (the existing "After close" card), but the Closing History screen
   shows only the frozen snapshot — a day that drifted after close looks final.
3. The Sales History screen has an upper-right bar-chart icon that duplicates
   navigation to the sales report (already reachable from the Reports hub).

## Decisions (confirmed with user)

- **Mechanics are always paid from the drawer**, even when the customer paid
  labor by GCash/Maya. So the mechanics' share = the day's total labor fees
  (`laborRevenue`), regardless of tender.
- **Management takes everything else**: hand-to-management = counted cash −
  total labor fees. The opening float is NOT held back (re-issued next morning).
- **Variance math is unchanged.** Labor cash physically sits in the drawer, so
  expected cash and variance keep including it.
- The labor split applies to the **whole EOD screen** (not just after-close
  figures).
- After Close info appears **both** on the live closed-EOD screen (already
  exists) **and** in Closing History.
- History After Close data is **computed live on expand** (same diff the EOD
  screen already performs), not persisted. One extra read per expanded day;
  old closings get the section automatically.

## Design

### Money rule (single source of truth)

For any day:

- `forMechanics = laborRevenue` (whole day, all tenders)
- `forManagement = countedCash − laborRevenue`

Both derivable from fields already stored on `DailyClosingEntity`
(`lib/domain/entities/daily_closing_entity.dart`) — add them as entity getters
so every screen shares one implementation.

### 1. EOD review screen (before close)

`end_of_day_screen.dart` `_buildReview()`, Cash reconciliation card: below the
variance panel add a "Handoff" block with two lines:

- **Labor fees → mechanics**: live `draft.laborRevenue`
- **Sale items → management**: entered counted cash − labor fees

Shown only once a counted-cash amount has been entered (the management figure
is meaningless before that). If labor is ₱0, the block still shows (management
line equals counted cash) for consistency.

### 2. Closed view (same screen)

Same two handoff lines in the Cash reconciliation card, computed from the
frozen closing record via the new entity getters.

### 3. After Close split

`PostCloseActivity` (`daily_closing_entity.dart`) gains:

- `laborDelta = current.laborRevenue − closing.laborRevenue`

The After Close card changes:

- "Cash collected after close" keeps its total, plus two indented sub-lines:
  - *Sale items*: `cashSalesDelta − laborDelta`
  - *Labor fees*: `laborDelta`
  (Sub-lines shown only when `laborDelta ≠ 0`.)
- Two new rows at the bottom:
  - **Updated for management**: `updatedCashOnHand − current.laborRevenue`
  - **For mechanics**: `current.laborRevenue` (whole day incl. after close)

Note `cashSalesDelta` is cash-tender-only while `laborDelta` is all-tender; a
negative "Sale items" sub-line is possible when after-close labor was paid
digitally — acceptable, consistent with the mechanics-paid-from-drawer rule.

### 4. Closing History screen

`daily_closing_history_screen.dart` `_ClosingTile._buildDetail`:

- Add the two handoff lines (from stored fields — no extra read).
- When expanded, watch `dailyClosingDataProvider(date)`, build the live draft
  honoring the closing's `excludedExpenseIds` (mirroring
  `_ClosedView.build`), compute `PostCloseActivity.between`, and if
  `hasChanged`, render the After Close block.
- The After Close block is extracted from `end_of_day_screen.dart` into a
  shared widget (e.g. `lib/presentation/mobile/widgets/after_close_card.dart`)
  so both screens render identically.
- While the day's data is loading or on error, the After Close block is simply
  omitted (no spinner/error UI in the tile).
- The live-draft construction from `dailyClosingData` + `excludedExpenseIds`
  is likewise shared (helper or entity constructor), not duplicated.

Cost note: the per-date query runs only for expanded tiles, so browsing the
list stays cheap.

### 5. Sales History screen

`sales_list_screen.dart`: delete the `LucideIcons.barChart3` AppBar
`IconButton` (lines ~58–62) and the now-dead `_navigateToReports` handler.
The sales report remains reachable from the Reports hub.

## Not changing

- Firestore documents, rules, indexes; web admin.
- Expected-cash / variance formulas.
- The close-day write path (`CloseDayUseCase`).

## Testing (TDD, tests mirror lib/ structure)

- Unit (`test/domain/entities/`): `forManagement` / `forMechanics` getters;
  `PostCloseActivity.laborDelta` and the updated-for-management math,
  including a digital-labor (negative sale-items sub-line) case.
- Widget: review screen shows handoff block only after counted cash entered;
  closed view shows handoff lines; After Close card shows the split rows;
  history tile shows handoff lines and shows the After Close block only when
  the day drifted; Sales History AppBar no longer contains the reports icon.
