# End-of-Day Non-Cash Breakdown Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Break the End-of-Day "Non-cash sales" figure into indented GCash and Maya sub-lines across the review, closed, and history views.

**Architecture:** Add discrete `gcashSales`/`mayaSales` to the daily-closing draft + persisted record (sourced from `SalesSummary.byPaymentMethod`), then render them as indented sub-lines under the existing "Non-cash sales" total. The Salmon receivable line is unchanged.

**Tech Stack:** Flutter, Cloud Firestore, flutter_test.

**Spec:** `docs/superpowers/specs/2026-05-28-eod-noncash-breakdown-design.md`

**Run tests with:** `flutter` is at `/Users/czar/flutter/bin`; prefix with `export PATH="$PATH:/Users/czar/flutter/bin" &&` if not on PATH.

### Invariant
`gcashSales + mayaSales == nonCashSales`. Old closings (saved before this change) have `gcashSales == 0` and `mayaSales == 0`, so the sub-lines hide and only the total shows.

---

## Task 1: Persist `gcashSales` / `mayaSales` through the closing

**Files:**
- Modify: `lib/domain/entities/daily_closing_entity.dart` (DailyClosingDraft + DailyClosingEntity)
- Modify: `lib/data/models/daily_closing_model.dart`
- Modify: `lib/domain/usecases/daily_closing/close_day_usecase.dart`
- Test: `test/domain/entities/daily_closing_draft_test.dart` (extend)
- Test fixups: `test/domain/entities/post_close_activity_test.dart`, `test/data/models/daily_closing_model_test.dart`, `test/domain/usecases/daily_closing/close_day_usecase_test.dart`

- [ ] **Step 1: Write the failing test**

In `test/domain/entities/daily_closing_draft_test.dart`, add this test inside `group('DailyClosingDraft.fromData', ...)`:

```dart
    test('breaks non-cash into gcash + maya buckets', () {
      const summary = SalesSummary(
        totalSalesCount: 3,
        voidedSalesCount: 0,
        grossAmount: 5000,
        totalDiscounts: 0,
        netAmount: 5000,
        totalCost: 0,
        totalProfit: 5000,
        byPaymentMethod: {
          PaymentMethod.cash: 1000,
          PaymentMethod.gcash: 3000,
          PaymentMethod.maya: 1000,
        },
      );

      final draft = DailyClosingDraft.fromData(
        businessDate: DateTime(2026, 5, 28),
        summary: summary,
        expenses: const [],
      );

      expect(draft.gcashSales, 3000);
      expect(draft.mayaSales, 1000);
      expect(draft.nonCashSales, 4000);
      // Invariant.
      expect(draft.gcashSales + draft.mayaSales, draft.nonCashSales);
    });
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/domain/entities/daily_closing_draft_test.dart`
Expected: FAIL — `gcashSales` / `mayaSales` not defined on `DailyClosingDraft`.

- [ ] **Step 3: Add the fields to `DailyClosingDraft`**

In `lib/domain/entities/daily_closing_entity.dart`, `DailyClosingDraft`:

Add fields after `nonCashSales`:

```dart
  final double cashSales;
  final double nonCashSales;
  final double gcashSales;
  final double mayaSales;
```

Add to the const constructor after `required this.nonCashSales,`:

```dart
    required this.nonCashSales,
    required this.gcashSales,
    required this.mayaSales,
```

In `fromData`, after the `salmonReceivable` local is computed, add:

```dart
    final gcashSales = summary.byPaymentMethod[PaymentMethod.gcash] ?? 0;
    final mayaSales = summary.byPaymentMethod[PaymentMethod.maya] ?? 0;
```

In the returned `DailyClosingDraft(...)`, after `nonCashSales: nonCashSales,`:

```dart
      nonCashSales: nonCashSales,
      gcashSales: gcashSales,
      mayaSales: mayaSales,
```

Add to the draft `props` after `nonCashSales,`:

```dart
        nonCashSales,
        gcashSales,
        mayaSales,
```

- [ ] **Step 4: Add the fields to `DailyClosingEntity`**

Same file, `DailyClosingEntity`:

Add fields after `nonCashSales`:

```dart
  final double cashSales;
  final double nonCashSales;
  final double gcashSales;
  final double mayaSales;
```

Add to the const constructor after `required this.nonCashSales,`:

```dart
    required this.nonCashSales,
    required this.gcashSales,
    required this.mayaSales,
```

Add to `props` after `nonCashSales,`:

```dart
        nonCashSales,
        gcashSales,
        mayaSales,
```

- [ ] **Step 5: Add the fields to `DailyClosingModel`**

In `lib/data/models/daily_closing_model.dart`:
- Field after `nonCashSales`: `final double gcashSales;` `final double mayaSales;`
- Constructor after `required this.nonCashSales,`: `required this.gcashSales,` `required this.mayaSales,`
- `fromMap` after `nonCashSales: d('nonCashSales'),`: `gcashSales: d('gcashSales'),` `mayaSales: d('mayaSales'),`
- `fromEntity` after `nonCashSales: e.nonCashSales,`: `gcashSales: e.gcashSales,` `mayaSales: e.mayaSales,`
- `toMap` after `'nonCashSales': nonCashSales,`: `'gcashSales': gcashSales,` `'mayaSales': mayaSales,`
- `toEntity` after `nonCashSales: nonCashSales,`: `gcashSales: gcashSales,` `mayaSales: mayaSales,`

- [ ] **Step 6: Populate in `CloseDayUseCase`**

In `lib/domain/usecases/daily_closing/close_day_usecase.dart`, in the `DailyClosingEntity(...)` built inside `execute`, after `nonCashSales: draft.nonCashSales,`:

```dart
        nonCashSales: draft.nonCashSales,
        gcashSales: draft.gcashSales,
        mayaSales: draft.mayaSales,
```

- [ ] **Step 7: Fix existing test constructors**

These build literal `DailyClosingDraft` / `DailyClosingEntity` / `DailyClosingModel` and now need the two new required fields. Add `gcashSales: 0,` and `mayaSales: 0,` after the `nonCashSales:` line in each:
- `test/domain/entities/post_close_activity_test.dart` — the `_closing(...)` entity literal AND the `_draft(...)` draft literal.
- `test/data/models/daily_closing_model_test.dart` — the `entity` literal.
- `test/domain/usecases/daily_closing/close_day_usecase_test.dart` — the `_existingClosing()` entity literal.

Run `flutter test test/domain/ test/data/models/daily_closing_model_test.dart` and add `gcashSales: 0,`/`mayaSales: 0,` wherever the compiler reports a missing required parameter.

- [ ] **Step 8: Run tests**

Run: `flutter test test/domain/entities/daily_closing_draft_test.dart test/domain/entities/post_close_activity_test.dart test/data/models/daily_closing_model_test.dart test/domain/usecases/daily_closing/close_day_usecase_test.dart`
Expected: PASS (all).

- [ ] **Step 9: Commit**

```bash
git add lib/domain/entities/daily_closing_entity.dart lib/data/models/daily_closing_model.dart lib/domain/usecases/daily_closing/close_day_usecase.dart test/domain/entities/daily_closing_draft_test.dart test/domain/entities/post_close_activity_test.dart test/data/models/daily_closing_model_test.dart test/domain/usecases/daily_closing/close_day_usecase_test.dart
git commit -m "feat(eod): persist gcash/maya split on closing"
```

---

## Task 2: Show GCash/Maya sub-lines in the three EOD views

**Files:**
- Modify: `lib/presentation/mobile/screens/reports/end_of_day_screen.dart`
- Modify: `lib/presentation/mobile/screens/reports/daily_closing_history_screen.dart`

UI; verified manually. Indentation is achieved with a leading two-space label.

- [ ] **Step 1: Review screen sub-lines**

In `end_of_day_screen.dart` `_buildReview`, replace the `Non-cash sales` row:

```dart
                  _row('Non-cash sales', draft.nonCashSales),
```

with:

```dart
                  _row('Non-cash sales', draft.nonCashSales),
                  if (draft.gcashSales > 0) _row('  GCash', draft.gcashSales),
                  if (draft.mayaSales > 0) _row('  Maya', draft.mayaSales),
```

- [ ] **Step 2: Closed view sub-lines**

In `_ClosedView.build`, the Sales `_card` map — replace:

```dart
          _card(context, 'Sales', {
            'Gross sales': closing.grossSales,
            'Cash sales': closing.cashSales,
            'Non-cash sales': closing.nonCashSales,
            'Discounts': closing.totalDiscounts,
            if (closing.salmonReceivable > 0)
              'Salmon receivable': closing.salmonReceivable,
          }),
```

with:

```dart
          _card(context, 'Sales', {
            'Gross sales': closing.grossSales,
            'Cash sales': closing.cashSales,
            'Non-cash sales': closing.nonCashSales,
            if (closing.gcashSales > 0) '  GCash': closing.gcashSales,
            if (closing.mayaSales > 0) '  Maya': closing.mayaSales,
            'Discounts': closing.totalDiscounts,
            if (closing.salmonReceivable > 0)
              'Salmon receivable': closing.salmonReceivable,
          }),
```

- [ ] **Step 3: History detail sub-lines**

In `daily_closing_history_screen.dart` `_ClosingTile`, replace:

```dart
          _kv(context, 'Non-cash sales', closing.nonCashSales),
```

with:

```dart
          _kv(context, 'Non-cash sales', closing.nonCashSales),
          if (closing.gcashSales > 0) _kv(context, '  GCash', closing.gcashSales),
          if (closing.mayaSales > 0) _kv(context, '  Maya', closing.mayaSales),
```

- [ ] **Step 4: Verify it compiles**

Run: `flutter analyze lib/presentation/mobile/screens/reports/end_of_day_screen.dart lib/presentation/mobile/screens/reports/daily_closing_history_screen.dart`
Expected: No errors.

- [ ] **Step 5: Commit**

```bash
git add lib/presentation/mobile/screens/reports/end_of_day_screen.dart lib/presentation/mobile/screens/reports/daily_closing_history_screen.dart
git commit -m "feat(eod): GCash/Maya sub-lines under non-cash sales"
```

---

## Task 3: Full verification

- [ ] **Step 1: Analyze**

Run: `flutter analyze`
Expected: no new errors (pre-existing infos acceptable).

- [ ] **Step 2: Full test suite**

Run: `flutter test`
Expected: new draft test passes; the 8 pre-existing failures (cart_item_tile, product_list_tile, update_product) remain and are unrelated; no *new* failures.

- [ ] **Step 3: Manual smoke test**

Run the app, make GCash + Maya (and optionally Salmon) sales, open End-of-Day:
- Review screen shows `Non-cash sales` with indented `GCash` and `Maya` beneath it; Salmon receivable still its own line.
- Close the day → closed view shows the same sub-lines.
- History detail shows them too. A day with only cash sales shows no sub-lines.

---

## Self-Review notes

- **Spec coverage:** persist gcash/maya (T1: draft, entity, model, use case); display in review + closed + history (T2); test the split + invariant (T1 Step 1); update existing literals (T1 Step 7). All covered.
- **Backward compatibility:** `fromMap` defaults missing `gcashSales`/`mayaSales` to 0 → old closings show only the non-cash total (sub-lines guarded by `> 0`).
- **Type consistency:** `gcashSales` / `mayaSales` (double) used identically across draft, entity, model, use case, and all three views. `nonCashSales` and `salmonReceivable` unchanged.
