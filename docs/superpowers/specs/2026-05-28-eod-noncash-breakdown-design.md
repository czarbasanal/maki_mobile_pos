# End-of-Day Non-Cash Breakdown — Design

**Date:** 2026-05-28
**Status:** Approved (pending spec review)

## Problem

The End-of-Day closing report shows a single **"Non-cash sales"** figure (GCash +
Maya combined). The operator wants that figure broken down by method — **GCash** and
**Maya** — so they can reconcile each digital channel. The **Salmon balance** is already
shown as its own separate "Salmon receivable" line and stays that way.

## Decisions (from brainstorming)

| Question | Decision |
|---|---|
| Layout | **Keep the "Non-cash sales" total**, with **GCash** and **Maya** as indented sub-lines beneath it (each shown only when > 0). |
| Salmon balance | **Stays as its own separate line** ("Salmon receivable") — not folded into the non-cash breakdown. |
| Scope | **Everywhere** — review screen, closed (saved) view, and history. Requires persisting the per-method amounts on the closing record. |
| Data model | Two **discrete fields** (`gcashSales`, `mayaSales`), not a generic map. |

## Architecture

The breakdown values come from `SalesSummary.byPaymentMethod`, which already holds the
`gcash` and `maya` buckets at compute time. The closing **draft** computes them; the
**saved closing** snapshots them so the closed view and history are consistent.

`nonCashSales` is unchanged (still the gcash + maya total). `gcashSales` + `mayaSales`
are additive detail; they always satisfy `gcashSales + mayaSales == nonCashSales`.

## Data model

### `DailyClosingDraft` (`lib/domain/entities/daily_closing_entity.dart`)

Add fields `double gcashSales` and `double mayaSales`. In `fromData`:

```dart
final gcashSales = summary.byPaymentMethod[PaymentMethod.gcash] ?? 0;
final mayaSales = summary.byPaymentMethod[PaymentMethod.maya] ?? 0;
```

Add both to the constructor and `props`.

### `DailyClosingEntity` (same file)

Add `double gcashSales` and `double mayaSales` (required), plus `props`.

### `DailyClosingModel` (`lib/data/models/daily_closing_model.dart`)

Add `gcashSales` / `mayaSales`:
- `fromMap`: `gcashSales: d('gcashSales')`, `mayaSales: d('mayaSales')` (default 0 — old
  closings lack these keys and show just the non-cash total).
- `fromEntity`, `toMap`, `toEntity`: serialize/read like the other doubles.

### `CloseDayUseCase` (`lib/domain/usecases/daily_closing/close_day_usecase.dart`)

Populate from the draft: `gcashSales: draft.gcashSales`, `mayaSales: draft.mayaSales`.

## Display

All three End-of-Day views render the same shape: keep **Non-cash sales** (the total),
then indented **GCash** and **Maya** sub-lines, each only when `> 0`. The **Salmon
receivable** line is unchanged.

- **Review screen** (`end_of_day_screen.dart` `_buildReview`): after the `Non-cash sales`
  `_row`, conditionally add indented rows for GCash and Maya. (A small indented row
  variant is needed since `_row` is full-width; see Implementation note.)
- **Closed view** (`_ClosedView`): the Sales `_card` takes a `Map<String, double>`; add
  `'  GCash'` / `'  Maya'` entries (leading spaces for visual indent) right after
  `'Non-cash sales'`, guarded by `> 0`.
- **History** (`daily_closing_history_screen.dart` `_ClosingTile`): after the
  `Non-cash sales` `_kv`, add guarded `_kv` rows for GCash and Maya (indented label).

**Implementation note on indentation:** the review screen's `_row` and the history `_kv`
take a label string. The simplest consistent indent is a leading two-space label
(`'  GCash'`), matching how the closed-view `_card` map will read. No new widget needed.

## Testing

- Extend `test/domain/entities/daily_closing_draft_test.dart`: in the existing salmon/
  mixed summary case, assert `draft.gcashSales` and `draft.mayaSales` equal the
  corresponding `byPaymentMethod` buckets, and that `gcashSales + mayaSales == nonCashSales`.
- Update the existing literal constructors that build `DailyClosingDraft` /
  `DailyClosingEntity` / `DailyClosingModel` in tests to pass the two new fields
  (`gcashSales`, `mayaSales`) — `post_close_activity_test.dart`,
  `daily_closing_model_test.dart`, `close_day_usecase_test.dart`.
- UI verified manually.

## Out of scope

- Backfilling the GCash/Maya split for closings saved before this change (they show the
  non-cash total only).
- Any change to the sales-report payment-methods card (already itemized per method).
- Folding the Salmon balance into the non-cash breakdown (stays a separate line).
