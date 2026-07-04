# EOD Itemized Expenses Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Itemize the day's expenses on the End-of-Day screen — all included by default, individually removable (excluded from the closing's drawer math, expense record untouched), restorable before close, with an Add-Expense entry point — and persist the exclusions on the closing so post-close drift math stays honest.

**Architecture:** New `DailyClosingData` value (summary + day's expenses) with a pure `draftExcluding(Set<String>)` derivation; a `dailyClosingDataProvider` family feeds both the review screen and the closed view; `dailyClosingDraftProvider` becomes a thin full-list derive so existing consumers/tests keep working. `CloseDayUseCase` takes excluded ids, filters, and stamps them on the immutable closing (`excludedExpenseIds` list field — no firestore.rules change).

**Tech Stack:** Flutter + Riverpod, mocktail, existing closing widgets (`ClosingSectionCard`/`ClosingKvRow`).

**Spec:** `docs/superpowers/specs/2026-07-04-eod-itemized-expenses-design.md`
**Spec amendment (locked here):** the spec said `GetDailyClosingSummaryUseCase` returns the new data type — it does, but the *live today path* lives in `dailyClosingDataProvider` (the existing provider already bypasses the usecase for today); the usecase serves only the past-date fallback.

## Global Constraints

- Branch `feat/eod-itemized-expenses` off `main` before the first commit.
- Every task: `flutter analyze` clean + the task's tests green before its commit; full `flutter test` in Tasks 5 and 6.
- "Remove" = exclude from this closing's math only; the expense record is never touched (user-confirmed 2026-07-04).
- No firestore.rules change, no web change, mobile only.
- Lucide icons; currency via the screen's existing `_peso` helper; no new styling systems.
- Do not push / merge — finishing-a-development-branch decides at the end.

---

### Task 1: `DailyClosingData` + `excludedExpenseIds` on the entity

**Files:**
- Modify: `lib/domain/entities/daily_closing_entity.dart`
- Test: `test/domain/entities/daily_closing_data_test.dart` (create)

**Interfaces:**
- Produces:
```dart
class DailyClosingData extends Equatable {
  final DateTime businessDate;
  final SalesSummary summary;
  final List<ExpenseEntity> expenses;
  const DailyClosingData({required this.businessDate, required this.summary, required this.expenses});
  DailyClosingDraft draftExcluding(Set<String> excludedExpenseIds);
}
```
- `DailyClosingEntity.excludedExpenseIds` (`List<String>`, default `const []`), in `props`.

- [ ] **Step 1: Write the failing test**

```dart
// test/domain/entities/daily_closing_data_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:maki_mobile_pos/core/enums/payment_method.dart';
import 'package:maki_mobile_pos/domain/entities/daily_closing_entity.dart';
import 'package:maki_mobile_pos/domain/entities/expense_entity.dart';
import 'package:maki_mobile_pos/domain/repositories/sale_repository.dart';

ExpenseEntity _exp(String id, double amount, PaymentMethod paidVia) =>
    ExpenseEntity(
      id: id,
      description: 'x-$id',
      amount: amount,
      category: 'c',
      date: DateTime(2026, 7, 4),
      paidVia: paidVia,
      createdAt: DateTime(2026, 7, 4),
      createdBy: '',
      createdByName: '',
    );

void main() {
  const summary = SalesSummary(
    totalSalesCount: 2,
    voidedSalesCount: 0,
    grossAmount: 1000,
    totalDiscounts: 0,
    netAmount: 1000,
    totalCost: 0,
    totalProfit: 1000,
    byPaymentMethod: {PaymentMethod.cash: 700, PaymentMethod.gcash: 300},
  );

  final data = DailyClosingData(
    businessDate: DateTime(2026, 7, 4),
    summary: summary,
    expenses: [
      _exp('e1', 150, PaymentMethod.cash),
      _exp('e2', 50, PaymentMethod.gcash),
      _exp('e3', 200, PaymentMethod.cash),
    ],
  );

  group('DailyClosingData.draftExcluding', () {
    test('empty exclusions = full-list math', () {
      final draft = data.draftExcluding(const {});
      expect(draft.totalExpenses, 400);
      expect(draft.cashExpenses, 350);
      // float 1000 + cash 700 - cashExp 350
      expect(draft.expectedCashFor(1000), 1350);
    });

    test('excluding a cash expense removes it from totals AND drawer math',
        () {
      final draft = data.draftExcluding(const {'e3'});
      expect(draft.totalExpenses, 200); // 150 + 50
      expect(draft.cashExpenses, 150);
      expect(draft.expectedCashFor(1000), 1550); // 1000 + 700 - 150
    });

    test('excluding a non-cash expense changes totals but not drawer math',
        () {
      final draft = data.draftExcluding(const {'e2'});
      expect(draft.totalExpenses, 350);
      expect(draft.cashExpenses, 350);
      expect(draft.expectedCashFor(1000), 1350);
    });

    test('unknown ids are ignored', () {
      expect(data.draftExcluding(const {'nope'}).totalExpenses, 400);
    });
  });

  test('excludedExpenseIds participates in DailyClosingEntity equality', () {
    DailyClosingEntity closing(List<String> ids) => DailyClosingEntity(
          id: '2026-07-04',
          businessDate: DateTime(2026, 7, 4),
          grossSales: 0, netSales: 0, totalDiscounts: 0, cashSales: 0,
          nonCashSales: 0, gcashSales: 0, mayaSales: 0, totalExpenses: 0,
          cashExpenses: 0, salmonReceivable: 0, openingFloat: 0,
          expectedCash: 0, countedCash: 0, variance: 0, salesCount: 0,
          voidedCount: 0, closedBy: '', closedByName: '',
          closedAt: DateTime(2026, 7, 4),
          excludedExpenseIds: ids,
        );
    expect(closing(const ['a']) == closing(const ['b']), isFalse);
    expect(closing(const []).excludedExpenseIds, isEmpty);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/domain/entities/daily_closing_data_test.dart`
Expected: FAIL — `DailyClosingData` undefined, `excludedExpenseIds` not a parameter.

- [ ] **Step 3: Implement**

In `lib/domain/entities/daily_closing_entity.dart`, add above `DailyClosingDraft`:

```dart
/// The raw inputs of a day's closing — the sales summary plus the itemized
/// expense list. The EOD screen derives [DailyClosingDraft]s from this via
/// [draftExcluding], so removing/restoring an expense recomputes instantly
/// without refetching (fetch/derive split).
class DailyClosingData extends Equatable {
  final DateTime businessDate;
  final SalesSummary summary;
  final List<ExpenseEntity> expenses;

  const DailyClosingData({
    required this.businessDate,
    required this.summary,
    required this.expenses,
  });

  /// Draft computed over the expenses NOT in [excludedExpenseIds]. An
  /// excluded expense stays recorded in the ledger — it just doesn't count
  /// against this closing's totals or drawer math.
  DailyClosingDraft draftExcluding(Set<String> excludedExpenseIds) {
    return DailyClosingDraft.fromData(
      businessDate: businessDate,
      summary: summary,
      expenses: excludedExpenseIds.isEmpty
          ? expenses
          : expenses
              .where((e) => !excludedExpenseIds.contains(e.id))
              .toList(),
    );
  }

  @override
  List<Object?> get props => [businessDate, summary, expenses];
}
```

In `DailyClosingEntity`: add the field + constructor param (after `voidedCount`):

```dart
  /// Ids of same-day expenses the closer removed from the reconciliation —
  /// still recorded in the expenses ledger, just not deducted from the
  /// drawer in this closing. Needed so post-close drift math can filter
  /// them when recomputing the current draft.
  final List<String> excludedExpenseIds;
```
```dart
    this.excludedExpenseIds = const [],
```
and add `excludedExpenseIds` to `props` (after `voidedCount`).

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/domain/entities/ && flutter analyze`
Expected: PASS, clean.

- [ ] **Step 5: Commit**

```bash
git add lib/domain/entities/daily_closing_entity.dart test/domain/entities/daily_closing_data_test.dart
git commit -m "feat(eod): DailyClosingData.draftExcluding + excludedExpenseIds on the closing entity"
```

---

### Task 2: Model serialization

**Files:**
- Modify: `lib/data/models/daily_closing_model.dart`
- Test: `test/data/models/daily_closing_model_excluded_test.dart` (create)

**Interfaces:**
- Consumes: `DailyClosingEntity.excludedExpenseIds` (Task 1).
- Produces: Firestore key `'excludedExpenseIds'` in `toMap` (and therefore `toCreateMap`); tolerant `fromMap` (missing → `const []`).

- [ ] **Step 1: Write the failing test**

```dart
// test/data/models/daily_closing_model_excluded_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:maki_mobile_pos/data/models/daily_closing_model.dart';
import 'package:maki_mobile_pos/domain/entities/daily_closing_entity.dart';

DailyClosingEntity _closing({List<String> ids = const []}) =>
    DailyClosingEntity(
      id: '2026-07-04',
      businessDate: DateTime(2026, 7, 4),
      grossSales: 0, netSales: 0, totalDiscounts: 0, cashSales: 0,
      nonCashSales: 0, gcashSales: 0, mayaSales: 0, totalExpenses: 0,
      cashExpenses: 0, salmonReceivable: 0, openingFloat: 0, expectedCash: 0,
      countedCash: 0, variance: 0, salesCount: 0, voidedCount: 0,
      closedBy: 'u', closedByName: 'U', closedAt: DateTime(2026, 7, 4),
      excludedExpenseIds: ids,
    );

void main() {
  test('excludedExpenseIds round-trips entity → map → entity', () {
    final model =
        DailyClosingModel.fromEntity(_closing(ids: const ['e1', 'e2']));
    expect(model.toMap()['excludedExpenseIds'], ['e1', 'e2']);
    expect(model.toCreateMap()['excludedExpenseIds'], ['e1', 'e2']);
    expect(model.toEntity().excludedExpenseIds, ['e1', 'e2']);
  });

  test('fromMap tolerates a missing field (legacy closings)', () {
    final model = DailyClosingModel.fromMap({'closedBy': 'u'}, '2026-07-04');
    expect(model.excludedExpenseIds, isEmpty);
  });

  test('fromMap reads the field', () {
    final model = DailyClosingModel.fromMap(
        {'excludedExpenseIds': ['a', 'b']}, '2026-07-04');
    expect(model.excludedExpenseIds, ['a', 'b']);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/data/models/daily_closing_model_excluded_test.dart`
Expected: FAIL — `excludedExpenseIds` not defined on the model.

- [ ] **Step 3: Implement**

In `daily_closing_model.dart`, mirror the entity exactly:
- Field: `final List<String> excludedExpenseIds;` + constructor param `this.excludedExpenseIds = const [],`.
- `fromMap`: `excludedExpenseIds: (map['excludedExpenseIds'] as List?)?.cast<String>() ?? const [],`
- `fromEntity`: `excludedExpenseIds: e.excludedExpenseIds,`
- `toMap`: add `'excludedExpenseIds': excludedExpenseIds,` (with the other fields — `toCreateMap` delegates to `toMap`, so it rides the create automatically).
- `toEntity`: `excludedExpenseIds: excludedExpenseIds,`

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/data/models/ && flutter analyze`
Expected: PASS (including the existing `daily_closing_model_test.dart`), clean.

- [ ] **Step 5: Commit**

```bash
git add lib/data/models/daily_closing_model.dart test/data/models/daily_closing_model_excluded_test.dart
git commit -m "feat(eod): serialize excludedExpenseIds on the closing document"
```

---

### Task 3: `CloseDayUseCase` exclusions + summary usecase returns `DailyClosingData`

**Files:**
- Modify: `lib/domain/usecases/daily_closing/close_day_usecase.dart:35-108`
- Modify: `lib/domain/usecases/daily_closing/get_daily_closing_summary_usecase.dart:24-50`
- Test: extend `test/domain/usecases/daily_closing/close_day_usecase_test.dart`
- Test: update `test/domain/usecases/daily_closing/get_daily_closing_summary_usecase_test.dart:77-90`

**Interfaces:**
- Consumes: `DailyClosingData`, `draftExcluding` (Task 1).
- Produces: `CloseDayUseCase.execute(..., Set<String> excludedExpenseIds = const {})`;
  `GetDailyClosingSummaryUseCase.execute` now returns `UseCaseResult<DailyClosingData>`.

- [ ] **Step 1: Write the failing test (close-day)**

Append to `close_day_usecase_test.dart` (fixtures `_exp`/`summary` exist in the file — note `_exp` hardcodes id `'e'`; give it an id param first by changing the helper to
`ExpenseEntity _exp(double amount, PaymentMethod paidVia, {String id = 'e'})` and using `id: id,`):

```dart
  test('excluded expenses are removed from the math and persisted', () async {
    when(() => expenses.getExpenses(
          startDate: any(named: 'startDate'),
          endDate: any(named: 'endDate'),
          category: any(named: 'category'),
          limit: any(named: 'limit'),
        )).thenAnswer((_) async => [
          _exp(100, PaymentMethod.cash, id: 'keep'),
          _exp(500, PaymentMethod.cash, id: 'drop'),
        ]);

    final captured = <DailyClosingEntity>[];
    when(() => closings.saveClosing(any())).thenAnswer((inv) async {
      final c = inv.positionalArguments.first as DailyClosingEntity;
      captured.add(c);
      return c;
    });

    final result = await useCase.execute(
      actor: _user(UserRole.cashier),
      date: DateTime(2026, 5, 28),
      openingFloat: 2000,
      countedCash: 2600,
      excludedExpenseIds: {'drop'},
    );

    expect(result.success, true);
    final saved = captured.single;
    expect(saved.totalExpenses, 100);
    expect(saved.cashExpenses, 100);
    expect(saved.expectedCash, 2600); // 2000 + 700 - 100 (500 NOT deducted)
    expect(saved.variance, 0);
    expect(saved.excludedExpenseIds, ['drop']);
  });
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/domain/usecases/daily_closing/close_day_usecase_test.dart`
Expected: FAIL — `excludedExpenseIds` is not a defined named parameter.

- [ ] **Step 3: Implement close-day**

In `close_day_usecase.dart` `execute`: add param after `plateNoDelivery`:

```dart
    Set<String> excludedExpenseIds = const {},
```

After the expenses fetch, filter before computing, and stamp the ids:

```dart
      final includedExpenses = excludedExpenseIds.isEmpty
          ? expenses
          : expenses
              .where((e) => !excludedExpenseIds.contains(e.id))
              .toList();

      final draft = DailyClosingDraft.fromData(
        businessDate: dayStart,
        summary: summary,
        expenses: includedExpenses,
      );
```

and in the `DailyClosingEntity(` construction add (after `voidedCount`):

```dart
        excludedExpenseIds: excludedExpenseIds.toList()..sort(),
```

- [ ] **Step 4: Rework the summary usecase**

`get_daily_closing_summary_usecase.dart` — change the return type and payload
(the class doc comment should say it returns the raw inputs; drafts are derived
by callers via `draftExcluding`):

```dart
  Future<UseCaseResult<DailyClosingData>> execute({
    required UserEntity actor,
    required DateTime date,
  }) async {
    try {
      assertPermission(actor, Permission.viewEndOfDay);

      final dayStart = DateTime(date.year, date.month, date.day);
      final dayEnd =
          DateTime(date.year, date.month, date.day, 23, 59, 59, 999);

      final summary = await _saleRepository.getSalesSummary(
        startDate: dayStart,
        endDate: dayEnd,
      );
      final expenses = await _expenseRepository.getExpenses(
        startDate: dayStart,
        endDate: dayEnd,
        limit: 1000,
      );

      return UseCaseResult.successData(DailyClosingData(
        businessDate: dayStart,
        summary: summary,
        expenses: expenses,
      ));
    } on AppException catch (e) {
      return UseCaseResult.fromException(e);
    } catch (e) {
      return UseCaseResult.failure(
          message: 'Failed to compute closing summary: $e');
    }
  }
```

Update its test's first case (`computes the draft for an authorized actor`) to:

```dart
  test('returns the day data; draft derives from it', () async {
    final result = await useCase.execute(
      actor: _user(UserRole.cashier),
      date: DateTime(2026, 5, 28),
    );

    expect(result.success, true);
    final data = result.data!;
    expect(data.expenses, hasLength(2));
    final draft = data.draftExcluding(const {});
    expect(draft.grossSales, 1000);
    expect(draft.cashSales, 700);
    expect(draft.nonCashSales, 300);
    expect(draft.totalExpenses, 200);
    expect(draft.cashExpenses, 150);
  });
```

(The provider caller is fixed in Task 4 — `flutter analyze` will flag it until then; that's expected mid-task, so run the analyzer at Task 4's checkpoint, not here.)

- [ ] **Step 5: Run the usecase tests**

Run: `flutter test test/domain/usecases/daily_closing/`
Expected: PASS (both files).

- [ ] **Step 6: Commit**

```bash
git add lib/domain/usecases/daily_closing/ test/domain/usecases/daily_closing/
git commit -m "feat(eod): CloseDayUseCase excludes chosen expenses; summary usecase returns DailyClosingData"
```

---

### Task 4: Providers — `dailyClosingDataProvider` + thin draft derive + notifier pass-through

**Files:**
- Modify: `lib/presentation/providers/daily_closing_provider.dart:49-156`

**Interfaces:**
- Consumes: `DailyClosingData` (Task 1), usecase signatures (Task 3).
- Produces:
  - `dailyClosingDataProvider = FutureProvider.family<DailyClosingData, DateTime>`
  - `dailyClosingDraftProvider` unchanged in TYPE (`FutureProvider.family<DailyClosingDraft, DateTime>`) — now derives `draftExcluding(const {})` from the data provider (existing consumers/tests unaffected).
  - `DailyClosingOperationsNotifier.closeDay(..., Set<String> excludedExpenseIds = const {})`.

- [ ] **Step 1: Implement**

Replace `dailyClosingDraftProvider` (lines 49-85) with:

```dart
/// Raw closing inputs (sales summary + itemized expenses) for [date].
///
/// For **today** the figures are sourced from the same live providers the
/// rest of the app uses — [todaysSalesSummaryProvider] (sales) and
/// [expensesByDateRangeProvider] (expenses) — so the End-of-Day numbers
/// always match the dashboard and refresh on the same triggers (checkout /
/// void / expense edits). For a past date (not reached by the current UI)
/// it falls back to the one-shot use case.
final dailyClosingDataProvider =
    FutureProvider.family<DailyClosingData, DateTime>((ref, date) async {
  final dayStart = DateTime(date.year, date.month, date.day);
  final dayEnd = DateTime(date.year, date.month, date.day, 23, 59, 59, 999);
  final now = DateTime.now();
  final isToday = dayStart == DateTime(now.year, now.month, now.day);

  if (isToday) {
    final summary = await ref.watch(todaysSalesSummaryProvider.future);
    final expenses = await ref.watch(
      expensesByDateRangeProvider(
        ExpenseDateRangeParams(startDate: dayStart, endDate: dayEnd),
      ).future,
    );
    return DailyClosingData(
      businessDate: dayStart,
      summary: summary,
      expenses: expenses,
    );
  }

  // Past day — compute once via the use case (enforces viewEndOfDay).
  final actor = ref.watch(currentUserProvider).valueOrNull;
  if (actor == null) {
    throw const UnauthenticatedException();
  }
  final result = await ref
      .watch(getDailyClosingSummaryUseCaseProvider)
      .execute(actor: actor, date: date);
  if (!result.success) {
    throw AppExceptionWrapper(
      message: result.errorMessage ?? 'Failed to load closing summary',
      code: result.errorCode,
    );
  }
  return result.data!;
});

/// Full-day (no exclusions) draft for [date] — a thin derive over
/// [dailyClosingDataProvider] for consumers that only need the totals.
final dailyClosingDraftProvider =
    FutureProvider.family<DailyClosingDraft, DateTime>((ref, date) async {
  final data = await ref.watch(dailyClosingDataProvider(date).future);
  return data.draftExcluding(const {});
});
```

In `closeDay` (notifier): add param `Set<String> excludedExpenseIds = const {},` after `plateNoDelivery` and pass `excludedExpenseIds: excludedExpenseIds,` into the usecase call. Also add `_ref.invalidate(dailyClosingDataProvider);` alongside the existing `dailyClosingDraftProvider` invalidation.

- [ ] **Step 2: Verify existing provider + suite health**

Run: `flutter analyze && flutter test test/presentation/providers/daily_closing_draft_live_test.dart test/domain/usecases/daily_closing/`
Expected: analyzer clean; the live-rebuild test still passes (the derive chain preserves the watch graph).

- [ ] **Step 3: Commit**

```bash
git add lib/presentation/providers/daily_closing_provider.dart
git commit -m "feat(eod): dailyClosingDataProvider (fetch) + thin draft derive + closeDay exclusion pass-through"
```

---

### Task 5: `ClosingExpenseList` widget

**Files:**
- Create: `lib/presentation/mobile/widgets/reports/closing_expense_list.dart`
- Test: `test/presentation/mobile/widgets/reports/closing_expense_list_test.dart` (create; also create the directory)

**Interfaces:**
- Produces:
```dart
ClosingExpenseList({
  required List<ExpenseEntity> expenses,
  required Set<String> excludedIds,
  required void Function(String expenseId) onToggle,
  bool enabled = true,
})
```
Included rows show a ✕ remove button; excluded rows grey out with strikethrough and a Restore button. `onToggle` flips membership. Parent owns totals and the Add button.

- [ ] **Step 1: Write the failing test**

```dart
// test/presentation/mobile/widgets/reports/closing_expense_list_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:maki_mobile_pos/core/enums/payment_method.dart';
import 'package:maki_mobile_pos/domain/entities/expense_entity.dart';
import 'package:maki_mobile_pos/presentation/mobile/widgets/reports/closing_expense_list.dart';

ExpenseEntity _exp(String id, double amount,
        {PaymentMethod paidVia = PaymentMethod.cash}) =>
    ExpenseEntity(
      id: id,
      description: 'Expense $id',
      amount: amount,
      category: 'c',
      date: DateTime(2026, 7, 4),
      paidVia: paidVia,
      createdAt: DateTime(2026, 7, 4),
      createdBy: '',
      createdByName: '',
    );

void main() {
  Future<void> pump(
    WidgetTester tester, {
    required List<ExpenseEntity> expenses,
    Set<String> excludedIds = const {},
    void Function(String)? onToggle,
  }) {
    return tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: ClosingExpenseList(
          expenses: expenses,
          excludedIds: excludedIds,
          onToggle: onToggle ?? (_) {},
        ),
      ),
    ));
  }

  testWidgets('renders one row per expense with description and amount',
      (tester) async {
    await pump(tester, expenses: [_exp('e1', 150), _exp('e2', 50)]);
    expect(find.text('Expense e1'), findsOneWidget);
    expect(find.text('Expense e2'), findsOneWidget);
    expect(find.byIcon(LucideIcons.x), findsNWidgets(2));
    expect(find.text('Restore'), findsNothing);
  });

  testWidgets('excluded row shows Restore instead of the remove button',
      (tester) async {
    await pump(tester,
        expenses: [_exp('e1', 150), _exp('e2', 50)],
        excludedIds: const {'e2'});
    expect(find.byIcon(LucideIcons.x), findsOneWidget);
    expect(find.text('Restore'), findsOneWidget);
  });

  testWidgets('tapping remove and Restore both fire onToggle with the id',
      (tester) async {
    final toggled = <String>[];
    await pump(tester,
        expenses: [_exp('e1', 150), _exp('e2', 50)],
        excludedIds: const {'e2'},
        onToggle: toggled.add);
    await tester.tap(find.byIcon(LucideIcons.x));
    await tester.tap(find.text('Restore'));
    expect(toggled, ['e1', 'e2']);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/presentation/mobile/widgets/reports/closing_expense_list_test.dart`
Expected: FAIL — file does not exist.

- [ ] **Step 3: Implement**

```dart
// lib/presentation/mobile/widgets/reports/closing_expense_list.dart
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:maki_mobile_pos/core/constants/app_constants.dart';
import 'package:maki_mobile_pos/core/extensions/num_extensions.dart';
import 'package:maki_mobile_pos/domain/entities/expense_entity.dart';

/// Itemized expense rows inside the EOD "Expenses" card. Every same-day
/// expense is included in the closing by default; removing one excludes it
/// from the reconciliation (the expense record itself is untouched) and the
/// row stays visible, greyed with a Restore action, until the day is closed.
class ClosingExpenseList extends StatelessWidget {
  const ClosingExpenseList({
    super.key,
    required this.expenses,
    required this.excludedIds,
    required this.onToggle,
    this.enabled = true,
  });

  final List<ExpenseEntity> expenses;
  final Set<String> excludedIds;
  final void Function(String expenseId) onToggle;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (final e in expenses)
          _ExpenseRow(
            expense: e,
            excluded: excludedIds.contains(e.id),
            enabled: enabled,
            onToggle: () => onToggle(e.id),
          ),
      ],
    );
  }
}

class _ExpenseRow extends StatelessWidget {
  const _ExpenseRow({
    required this.expense,
    required this.excluded,
    required this.enabled,
    required this.onToggle,
  });

  final ExpenseEntity expense;
  final bool excluded;
  final bool enabled;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    final strike = TextStyle(
      decoration: excluded ? TextDecoration.lineThrough : null,
      color: excluded ? muted : null,
    );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  expense.description,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: strike.copyWith(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  expense.paidVia.displayName,
                  style: TextStyle(fontSize: 11.5, color: muted),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '${AppConstants.currencySymbol}${expense.amount.toCurrencyWithoutSymbol()}',
            style: strike.copyWith(
              fontSize: 13.5,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: 4),
          if (excluded)
            TextButton(
              onPressed: enabled ? onToggle : null,
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                minimumSize: const Size(0, 30),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                textStyle: const TextStyle(
                    fontSize: 12.5, fontWeight: FontWeight.w600),
              ),
              child: const Text('Restore'),
            )
          else
            IconButton(
              icon: const Icon(LucideIcons.x, size: 16),
              color: muted,
              tooltip: 'Remove from closing',
              visualDensity: VisualDensity.compact,
              onPressed: enabled ? onToggle : null,
            ),
        ],
      ),
    );
  }
}
```

Note: if `PaymentMethod.displayName` is not the getter name, check
`lib/core/enums/payment_method.dart` (the expense form uses `m.displayName`).

- [ ] **Step 4: Run tests + analyze**

Run: `flutter test test/presentation/mobile/widgets/reports/ && flutter analyze`
Expected: PASS, clean.

- [ ] **Step 5: Commit**

```bash
git add lib/presentation/mobile/widgets/reports/closing_expense_list.dart test/presentation/mobile/widgets/reports/
git commit -m "feat(eod): ClosingExpenseList — itemized rows with remove/Restore"
```

---

### Task 6: Screen integration — review derive, itemized card, add button, submit threading, exclusion-aware drift

**Files:**
- Modify: `lib/presentation/mobile/screens/reports/end_of_day_screen.dart`
- Test: update `test/presentation/widgets/end_of_day_closed_test.dart`; create `test/presentation/widgets/end_of_day_review_test.dart`

**Interfaces:**
- Consumes: `dailyClosingDataProvider` (Task 4), `ClosingExpenseList` (Task 5), `closeDay(excludedExpenseIds:)` (Task 4), `DailyClosingData.draftExcluding` (Task 1).

- [ ] **Step 1: Update the closed-view test + write the failing review test**

`end_of_day_closed_test.dart` — replace the `_draft` fixture + override with a
`DailyClosingData` whose derived draft matches the old figures. Replace lines 34-65 with:

```dart
// Live data with two more sales (+₱1,300 gross, +₱800 cash) than the
// snapshot → triggers the post-close warning + After-close card.
DailyClosingData _data(DateTime d) => DailyClosingData(
      businessDate: d,
      summary: const SalesSummary(
        totalSalesCount: 16,
        voidedSalesCount: 0,
        grossAmount: 9720,
        totalDiscounts: 120,
        netAmount: 9600,
        totalCost: 0,
        totalProfit: 9600,
        byPaymentMethod: {
          PaymentMethod.cash: 6000,
          PaymentMethod.gcash: 2540,
          PaymentMethod.maya: 980,
        },
        laborRevenue: 650,
      ),
      expenses: [
        ExpenseEntity(
          id: 'e1',
          description: 'Diesel',
          amount: 430,
          category: 'Fuel',
          date: d,
          createdAt: d,
          createdBy: '',
          createdByName: '',
        ),
      ],
    );

void main() {
  final now = DateTime.now();
  final dayStart = DateTime(now.year, now.month, now.day);

  Widget harness() => ProviderScope(
        overrides: [
          dailyClosingForDateProvider
              .overrideWith((ref, date) async => _closing(dayStart)),
          dailyClosingDataProvider
              .overrideWith((ref, date) async => _data(dayStart)),
        ],
        child: const MaterialApp(home: EndOfDayScreen()),
      );
```

(add imports `package:maki_mobile_pos/core/enums/payment_method.dart`,
`package:maki_mobile_pos/domain/entities/expense_entity.dart`, and
`package:maki_mobile_pos/domain/repositories/sale_repository.dart` for `SalesSummary`;
the existing testWidgets body stays unchanged.)

New `test/presentation/widgets/end_of_day_review_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:maki_mobile_pos/core/enums/payment_method.dart';
import 'package:maki_mobile_pos/domain/entities/daily_closing_entity.dart';
import 'package:maki_mobile_pos/domain/entities/expense_entity.dart';
import 'package:maki_mobile_pos/domain/repositories/sale_repository.dart';
import 'package:maki_mobile_pos/presentation/providers/daily_closing_provider.dart';
import 'package:maki_mobile_pos/presentation/mobile/screens/reports/end_of_day_screen.dart';
import 'package:maki_mobile_pos/presentation/mobile/widgets/reports/closing_expense_list.dart';

ExpenseEntity _exp(String id, double amount, DateTime d) => ExpenseEntity(
      id: id,
      description: 'Expense $id',
      amount: amount,
      category: 'c',
      date: d,
      createdAt: d,
      createdBy: '',
      createdByName: '',
    );

void main() {
  final now = DateTime.now();
  final dayStart = DateTime(now.year, now.month, now.day);

  DailyClosingData data() => DailyClosingData(
        businessDate: dayStart,
        summary: const SalesSummary(
          totalSalesCount: 2,
          voidedSalesCount: 0,
          grossAmount: 1000,
          totalDiscounts: 0,
          netAmount: 1000,
          totalCost: 0,
          totalProfit: 1000,
          byPaymentMethod: {PaymentMethod.cash: 700},
        ),
        expenses: [_exp('e1', 150, dayStart), _exp('e2', 50, dayStart)],
      );

  Widget harness() => ProviderScope(
        overrides: [
          dailyClosingForDateProvider.overrideWith((ref, date) async => null),
          dailyClosingDataProvider.overrideWith((ref, date) async => data()),
        ],
        child: const MaterialApp(home: EndOfDayScreen()),
      );

  testWidgets('review lists the day expenses itemized with an Add button',
      (tester) async {
    await tester.pumpWidget(harness());
    await tester.pumpAndSettle();

    expect(find.byType(ClosingExpenseList), findsOneWidget);
    expect(find.text('Expense e1'), findsOneWidget);
    expect(find.text('Expense e2'), findsOneWidget);
    expect(find.text('Add Expense'), findsOneWidget);
    expect(find.text('Close Day'), findsOneWidget);
  });

  testWidgets('removing an expense recomputes totals and expected cash',
      (tester) async {
    await tester.pumpWidget(harness());
    await tester.pumpAndSettle();

    // Included: 150 + 50 → total ₱200.00; expected cash = 700 - 200(cash both) = 500
    expect(find.text('₱200.00'), findsOneWidget); // Total expenses row
    await tester.tap(find.byIcon(LucideIcons.x).first); // remove e1 (₱150)
    await tester.pumpAndSettle();

    expect(find.text('₱50.00'), findsWidgets); // new total (also e2 row amount)
    expect(find.text('Restore'), findsOneWidget);

    // Restore brings it back
    await tester.tap(find.text('Restore'));
    await tester.pumpAndSettle();
    expect(find.text('₱200.00'), findsOneWidget);
    expect(find.text('Restore'), findsNothing);
  });
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `flutter test test/presentation/widgets/end_of_day_review_test.dart test/presentation/widgets/end_of_day_closed_test.dart`
Expected: FAIL — review screen has no `ClosingExpenseList`/`Add Expense`; closed test fails until `_ClosedView` watches `dailyClosingDataProvider`.

- [ ] **Step 3: Implement the screen changes**

In `end_of_day_screen.dart`:

1. Add state to `_EndOfDayScreenState`: `final Set<String> _excludedIds = {};`
2. `_buildReview()` — watch the data provider and derive:

```dart
  Widget _buildReview() {
    final dataAsync = ref.watch(dailyClosingDataProvider(_today));
    return dataAsync.when(
      loading: () => const FormSkeleton(),
      error: (e, _) => ErrorStateView(
        message: 'Error: $e',
        onRetry: () => ref.invalidate(dailyClosingDataProvider(_today)),
      ),
      data: (data) {
        final draft = data.draftExcluding(_excludedIds);
        final expected = draft.expectedCashFor(
          _float,
          plateNoDp: _plateDp,
          plateNoDelivery: _plateDelivery,
        );
        // ... body unchanged below, using `draft` and `data.expenses`
```

3. Replace the Expenses `ClosingSectionCard` children (previously the two
   aggregate rows) with:

```dart
                ClosingSectionCard(
                  icon: LucideIcons.arrowDownCircle,
                  title: 'Expenses',
                  children: [
                    if (data.expenses.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Text(
                          'No expenses today',
                          style: TextStyle(
                            fontSize: 13,
                            color:
                                Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                        ),
                      )
                    else ...[
                      ClosingExpenseList(
                        expenses: data.expenses,
                        excludedIds: _excludedIds,
                        enabled: !_busy,
                        onToggle: (id) => setState(() {
                          _excludedIds.contains(id)
                              ? _excludedIds.remove(id)
                              : _excludedIds.add(id);
                        }),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Divider(
                          height: 1,
                          color: AppColors.hairline(Theme.of(context)
                                  .brightness ==
                              Brightness.dark),
                        ),
                      ),
                      ClosingKvRow(
                          label: 'Total expenses',
                          value: _peso(draft.totalExpenses)),
                      ClosingKvRow(
                          label: 'Cash expenses',
                          value: _peso(draft.cashExpenses)),
                    ],
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: OutlinedButton.icon(
                        onPressed: _busy
                            ? null
                            : () => context.push(RoutePaths.expenseAdd),
                        icon: const Icon(LucideIcons.plus, size: 16),
                        label: const Text('Add Expense'),
                      ),
                    ),
                  ],
                ),
```

   (No manual refresh needed on return: creating an expense invalidates
   `expensesByDateRangeProvider`, which `dailyClosingDataProvider` watches.
   Import `closing_expense_list.dart`.)

4. `_submit()` — pass the exclusions:

```dart
        await ref.read(dailyClosingOperationsProvider.notifier).closeDay(
              date: _today,
              openingFloat: _float,
              countedCash: _counted ?? 0,
              plateNoDp: _plateDp,
              plateNoDelivery: _plateDelivery,
              notes: notes.isEmpty ? null : notes,
              excludedExpenseIds: Set.of(_excludedIds),
            );
```

5. `_ClosedView` — exclusion-aware drift (replace the `liveDraft` line):

```dart
    final liveData = ref.watch(dailyClosingDataProvider(date)).valueOrNull;
    final liveDraft =
        liveData?.draftExcluding(closing.excludedExpenseIds.toSet());
```

6. Swap the two remaining `Center(child: CircularProgressIndicator())` loading
   states (`build` line 77 and the old `_buildReview` one) for `const FormSkeleton()`.

- [ ] **Step 4: Run the widget tests + full suite + analyze**

Run: `flutter test test/presentation/widgets/end_of_day_review_test.dart test/presentation/widgets/end_of_day_closed_test.dart && flutter analyze && flutter test`
Expected: all PASS, analyzer clean, full suite green.

- [ ] **Step 5: Commit**

```bash
git add lib/presentation/mobile/screens/reports/end_of_day_screen.dart test/presentation/widgets/
git commit -m "feat(eod): itemized removable expenses + add-in-place on the EOD screen (#13)"
```

---

### Task 7: Wrap-up

- [ ] **Step 1: Full verification**

Run: `flutter analyze && flutter test`
Expected: clean, all green.

- [ ] **Step 2: Report + finish branch**

Use superpowers:finishing-a-development-branch. Remind the user: no rules
deploy needed; APK + device smoke still deferred at their request; #13 closes
the dictated backlog except #11 (void-requests tap-through).
