# End-of-Day Closing Report Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a mobile-first End-of-Day Closing report that reconciles the sales drawer — gross sales, cash vs non-cash split, cash expenses, opening float, counted cash, and variance — saved as a once-per-day record with history.

**Architecture:** Full clean-architecture feature mirroring the existing petty cash / expense pattern: entity + `DailyClosingDraft` value object → Firestore model → repository (interface + impl) → two use cases (compute live draft, close day) → Riverpod provider → two screens. Adds a `paidVia` payment field to expenses so only cash-paid expenses reduce cash on hand. Petty cash is left untouched.

**Tech Stack:** Flutter, Riverpod (StateNotifier + FutureProvider/StreamProvider families), Cloud Firestore, mocktail + flutter_test.

**Spec:** `docs/superpowers/specs/2026-05-28-end-of-day-closing-report-design.md`

### Key formula

```
cash sales    = salesSummary.byPaymentMethod[PaymentMethod.cash]   // net cash received
non-cash sales= sum of byPaymentMethod for gcash + maya
cash expenses = sum(expense.amount where paidVia == cash) for the day
expected cash = openingFloat + cashSales − cashExpenses
variance      = countedCash − expectedCash
```

`grossSales` (= `summary.grossAmount`) is the headline figure; the drawer math uses **net cash** (what customers actually paid), which is what `byPaymentMethod` holds.

### Note on PaymentMethod

The enum has exactly three values: `cash`, `gcash`, `maya` (no "card"). Non-cash = `gcash` + `maya`.

---

## Task 1: Add `paidVia` field to expenses (entity + model)

**Files:**
- Modify: `lib/domain/entities/expense_entity.dart`
- Modify: `lib/data/models/expense_model.dart`
- Test: `test/data/models/expense_model_paid_via_test.dart`

- [ ] **Step 1: Write the failing test**

Create `test/data/models/expense_model_paid_via_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:maki_mobile_pos/core/enums/payment_method.dart';
import 'package:maki_mobile_pos/data/models/expense_model.dart';

void main() {
  group('ExpenseModel paidVia', () {
    test('defaults to cash when the field is missing (legacy records)', () {
      final model = ExpenseModel.fromMap({
        'description': 'Legacy expense',
        'amount': 100.0,
        'category': 'Utilities',
      }, 'exp-legacy');

      expect(model.paidVia, PaymentMethod.cash);
      expect(model.toEntity().paidVia, PaymentMethod.cash);
    });

    test('round-trips a non-cash paidVia through map serialization', () {
      final model = ExpenseModel.fromMap({
        'description': 'GCash supplies',
        'amount': 50.0,
        'category': 'Supplies',
        'paidVia': 'gcash',
      }, 'exp-1');

      expect(model.paidVia, PaymentMethod.gcash);
      expect(model.toMap()['paidVia'], 'gcash');
      expect(model.toCreateMap()['paidVia'], 'gcash');
      expect(model.toUpdateMap()['paidVia'], 'gcash');
    });

    test('entity copyWith updates paidVia', () {
      final entity = ExpenseModel.fromMap({
        'description': 'x',
        'amount': 1.0,
        'category': 'c',
      }, 'id').toEntity();

      expect(entity.copyWith(paidVia: PaymentMethod.maya).paidVia,
          PaymentMethod.maya);
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/data/models/expense_model_paid_via_test.dart`
Expected: FAIL — `paidVia` is not defined on `ExpenseEntity` / `ExpenseModel` (compile error).

- [ ] **Step 3: Add `paidVia` to `ExpenseEntity`**

In `lib/domain/entities/expense_entity.dart`:

Add the import at the top (after the equatable import):

```dart
import 'package:maki_mobile_pos/core/enums/payment_method.dart';
```

Add the field after `amount` (the doc comment + field):

```dart
  /// Amount in PHP
  final double amount;

  /// How the expense was paid. Defaults to cash. Only cash-paid expenses
  /// reduce drawer cash on hand in the end-of-day closing.
  final PaymentMethod paidVia;
```

Add the constructor parameter (with default) — insert after `required this.amount,`:

```dart
    required this.amount,
    this.paidVia = PaymentMethod.cash,
```

Add to `copyWith` — add the parameter after `double? amount,`:

```dart
    double? amount,
    PaymentMethod? paidVia,
```

and in the returned `ExpenseEntity(...)` after `amount: amount ?? this.amount,`:

```dart
      amount: amount ?? this.amount,
      paidVia: paidVia ?? this.paidVia,
```

Add to `props` after `amount,`:

```dart
        amount,
        paidVia,
```

- [ ] **Step 4: Add `paidVia` to `ExpenseModel`**

In `lib/data/models/expense_model.dart`:

Add the import at the top (after the entities import):

```dart
import 'package:maki_mobile_pos/core/enums/payment_method.dart';
```

Add the field after `amount`:

```dart
  final double amount;
  final PaymentMethod paidVia;
```

Add to the constructor after `required this.amount,`:

```dart
    required this.amount,
    this.paidVia = PaymentMethod.cash,
```

In `fromMap`, after the `amount:` line:

```dart
      amount: (map['amount'] as num?)?.toDouble() ?? 0.0,
      paidVia: PaymentMethod.fromString(map['paidVia'] as String?),
```

(`PaymentMethod.fromString` already returns `cash` for null/invalid — backward compatible.)

In `fromEntity`, after `amount: entity.amount,`:

```dart
      amount: entity.amount,
      paidVia: entity.paidVia,
```

In `toMap`, after `'amount': amount,`:

```dart
      'amount': amount,
      'paidVia': paidVia.value,
```

In `toCreateMap`, after `'amount': amount,`:

```dart
      'amount': amount,
      'paidVia': paidVia.value,
```

In `toUpdateMap`, after `'amount': amount,`:

```dart
      'amount': amount,
      'paidVia': paidVia.value,
```

In `toEntity`, after `amount: amount,`:

```dart
      amount: amount,
      paidVia: paidVia,
```

- [ ] **Step 5: Run test to verify it passes**

Run: `flutter test test/data/models/expense_model_paid_via_test.dart`
Expected: PASS (3 tests).

- [ ] **Step 6: Commit**

```bash
git add lib/domain/entities/expense_entity.dart lib/data/models/expense_model.dart test/data/models/expense_model_paid_via_test.dart
git commit -m "feat(expenses): add paidVia payment field"
```

---

## Task 2: Expense form — payment method selector

**Files:**
- Modify: `lib/presentation/mobile/screens/expenses/expense_form_screen.dart`

This is a UI change; verified manually (no widget test — the project verifies forms in-app).

- [ ] **Step 1: Add `_paidVia` state**

In `_ExpenseFormScreenState` (after `String? _selectedCategory;`):

```dart
  String? _selectedCategory;
  PaymentMethod _paidVia = PaymentMethod.cash;
```

`PaymentMethod` is already available via `import 'package:maki_mobile_pos/core/enums/enums.dart';` (already imported at line 7).

- [ ] **Step 2: Load `paidVia` when editing**

In `_loadExpense()`, after `_selectedCategory = expense.category;`:

```dart
      _selectedCategory = expense.category;
      _paidVia = expense.paidVia;
```

- [ ] **Step 3: Add the selector to the form**

In `build`, insert a new block after the Category dropdown block (after its trailing `const SizedBox(height: 16),` that follows `_ExpenseCategoryDropdown`), before the Date `InkWell`:

```dart
              // Paid via — which payment method funded this expense.
              AppDropdown<PaymentMethod>(
                initialValue: _paidVia,
                decoration: const InputDecoration(
                  labelText: 'Paid via *',
                  prefixIcon: Icon(CupertinoIcons.creditcard),
                ),
                items: PaymentMethod.values
                    .map(
                      (m) => DropdownMenuItem(
                        value: m,
                        child: Text(m.displayName),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  if (value != null) setState(() => _paidVia = value);
                },
              ),
              const SizedBox(height: 16),
```

`AppDropdown` is exported via `common_widgets.dart` (already imported at line 12).

- [ ] **Step 4: Pass `paidVia` on create and update**

In `_handleSubmit()`, in the editing branch, add `paidVia: _paidVia,` to the `existing.copyWith(...)` call (after `date: _selectedDate,`):

```dart
        final updated = existing.copyWith(
          description: _descriptionController.text.trim(),
          amount: amount,
          category: _selectedCategory!,
          date: _selectedDate,
          paidVia: _paidVia,
          notes: notes.isEmpty ? null : notes,
          clearNotes: notes.isEmpty,
        );
```

In the create branch, add `paidVia: _paidVia,` to the `ExpenseEntity(...)` draft (after `date: _selectedDate,`):

```dart
        final draft = ExpenseEntity(
          id: '',
          description: _descriptionController.text.trim(),
          amount: amount,
          category: _selectedCategory!,
          date: _selectedDate,
          paidVia: _paidVia,
          notes: notes.isEmpty ? null : notes,
          createdAt: now,
          createdBy: '',
          createdByName: '',
        );
```

- [ ] **Step 5: Verify it compiles**

Run: `flutter analyze lib/presentation/mobile/screens/expenses/expense_form_screen.dart`
Expected: No errors (warnings about existing code are acceptable).

- [ ] **Step 6: Commit**

```bash
git add lib/presentation/mobile/screens/expenses/expense_form_screen.dart
git commit -m "feat(expenses): payment method selector in expense form"
```

---

## Task 3: `DailyClosingEntity` + `DailyClosingDraft`

**Files:**
- Create: `lib/domain/entities/daily_closing_entity.dart`
- Modify: `lib/domain/entities/entities.dart`
- Test: `test/domain/entities/daily_closing_draft_test.dart`

- [ ] **Step 1: Write the failing test for the draft computation**

Create `test/domain/entities/daily_closing_draft_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:maki_mobile_pos/core/enums/payment_method.dart';
import 'package:maki_mobile_pos/domain/entities/daily_closing_entity.dart';
import 'package:maki_mobile_pos/domain/entities/expense_entity.dart';
import 'package:maki_mobile_pos/domain/repositories/sale_repository.dart';

ExpenseEntity _exp(double amount, PaymentMethod paidVia) => ExpenseEntity(
      id: 'e',
      description: 'x',
      amount: amount,
      category: 'c',
      date: DateTime(2026, 5, 28),
      paidVia: paidVia,
      createdAt: DateTime(2026, 5, 28),
      createdBy: '',
      createdByName: '',
    );

void main() {
  group('DailyClosingDraft.fromData', () {
    test('splits cash vs non-cash sales and cash expenses', () {
      const summary = SalesSummary(
        totalSalesCount: 5,
        voidedSalesCount: 1,
        grossAmount: 1000,
        totalDiscounts: 50,
        netAmount: 950,
        totalCost: 400,
        totalProfit: 550,
        byPaymentMethod: {
          PaymentMethod.cash: 600,
          PaymentMethod.gcash: 250,
          PaymentMethod.maya: 100,
        },
      );

      final draft = DailyClosingDraft.fromData(
        businessDate: DateTime(2026, 5, 28),
        summary: summary,
        expenses: [
          _exp(200, PaymentMethod.cash),
          _exp(80, PaymentMethod.gcash),
          _exp(20, PaymentMethod.cash),
        ],
      );

      expect(draft.grossSales, 1000);
      expect(draft.netSales, 950);
      expect(draft.cashSales, 600);
      expect(draft.nonCashSales, 350); // 250 + 100
      expect(draft.totalExpenses, 300); // 200 + 80 + 20
      expect(draft.cashExpenses, 220); // 200 + 20
      expect(draft.salesCount, 5);
      expect(draft.voidedCount, 1);
    });

    test('handles a day with no cash sales and no expenses', () {
      const summary = SalesSummary(
        totalSalesCount: 0,
        voidedSalesCount: 0,
        grossAmount: 0,
        totalDiscounts: 0,
        netAmount: 0,
        totalCost: 0,
        totalProfit: 0,
        byPaymentMethod: {},
      );

      final draft = DailyClosingDraft.fromData(
        businessDate: DateTime(2026, 5, 28),
        summary: summary,
        expenses: const [],
      );

      expect(draft.cashSales, 0);
      expect(draft.nonCashSales, 0);
      expect(draft.cashExpenses, 0);
      expect(draft.totalExpenses, 0);
    });

    test('expectedCash applies the opening float', () {
      const summary = SalesSummary(
        totalSalesCount: 1,
        voidedSalesCount: 0,
        grossAmount: 600,
        totalDiscounts: 0,
        netAmount: 600,
        totalCost: 0,
        totalProfit: 600,
        byPaymentMethod: {PaymentMethod.cash: 600},
      );
      final draft = DailyClosingDraft.fromData(
        businessDate: DateTime(2026, 5, 28),
        summary: summary,
        expenses: [_exp(100, PaymentMethod.cash)],
      );

      // 2000 float + 600 cash sales - 100 cash expenses = 2500
      expect(draft.expectedCashFor(2000), 2500);
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/domain/entities/daily_closing_draft_test.dart`
Expected: FAIL — `daily_closing_entity.dart` does not exist (compile error).

- [ ] **Step 3: Create the entity + draft**

Create `lib/domain/entities/daily_closing_entity.dart`:

```dart
import 'package:equatable/equatable.dart';
import 'package:maki_mobile_pos/core/enums/payment_method.dart';
import 'package:maki_mobile_pos/domain/entities/expense_entity.dart';
import 'package:maki_mobile_pos/domain/repositories/sale_repository.dart';

/// Live, unsaved end-of-day figures computed from the day's sales + expenses.
///
/// The manual inputs (opening float, counted cash) are layered on top by the
/// UI / [CloseDayUseCase]; [expectedCashFor] and [varianceFor] derive the
/// reconciliation once a float / count is known.
class DailyClosingDraft extends Equatable {
  final DateTime businessDate;
  final double grossSales;
  final double netSales;
  final double totalDiscounts;
  final double cashSales;
  final double nonCashSales;
  final double totalExpenses;
  final double cashExpenses;
  final int salesCount;
  final int voidedCount;

  const DailyClosingDraft({
    required this.businessDate,
    required this.grossSales,
    required this.netSales,
    required this.totalDiscounts,
    required this.cashSales,
    required this.nonCashSales,
    required this.totalExpenses,
    required this.cashExpenses,
    required this.salesCount,
    required this.voidedCount,
  });

  /// Builds a draft from a [SalesSummary] and the day's [expenses].
  ///
  /// Cash sales come from the cash payment-method bucket (net cash received).
  /// Non-cash sales are every other payment method summed. Cash expenses are
  /// only those with `paidVia == cash`.
  factory DailyClosingDraft.fromData({
    required DateTime businessDate,
    required SalesSummary summary,
    required List<ExpenseEntity> expenses,
  }) {
    final cashSales = summary.byPaymentMethod[PaymentMethod.cash] ?? 0;
    double nonCashSales = 0;
    for (final entry in summary.byPaymentMethod.entries) {
      if (entry.key != PaymentMethod.cash) nonCashSales += entry.value;
    }

    double totalExpenses = 0;
    double cashExpenses = 0;
    for (final e in expenses) {
      totalExpenses += e.amount;
      if (e.paidVia == PaymentMethod.cash) cashExpenses += e.amount;
    }

    return DailyClosingDraft(
      businessDate: businessDate,
      grossSales: summary.grossAmount,
      netSales: summary.netAmount,
      totalDiscounts: summary.totalDiscounts,
      cashSales: cashSales,
      nonCashSales: nonCashSales,
      totalExpenses: totalExpenses,
      cashExpenses: cashExpenses,
      salesCount: summary.totalSalesCount,
      voidedCount: summary.voidedSalesCount,
    );
  }

  /// Expected drawer cash given an [openingFloat].
  double expectedCashFor(double openingFloat) =>
      openingFloat + cashSales - cashExpenses;

  /// Variance given an [openingFloat] and a physical [countedCash].
  double varianceFor(double openingFloat, double countedCash) =>
      countedCash - expectedCashFor(openingFloat);

  @override
  List<Object?> get props => [
        businessDate,
        grossSales,
        netSales,
        totalDiscounts,
        cashSales,
        nonCashSales,
        totalExpenses,
        cashExpenses,
        salesCount,
        voidedCount,
      ];
}

/// A persisted end-of-day closing for a single business day.
///
/// Document id is the business date as `YYYY-MM-DD`, which enforces one
/// closing per day. Immutable once saved (audit record).
class DailyClosingEntity extends Equatable {
  final String id;
  final DateTime businessDate;
  final double grossSales;
  final double netSales;
  final double totalDiscounts;
  final double cashSales;
  final double nonCashSales;
  final double totalExpenses;
  final double cashExpenses;
  final double openingFloat;
  final double expectedCash;
  final double countedCash;
  final double variance;
  final int salesCount;
  final int voidedCount;
  final String? notes;
  final String closedBy;
  final String closedByName;
  final DateTime closedAt;

  const DailyClosingEntity({
    required this.id,
    required this.businessDate,
    required this.grossSales,
    required this.netSales,
    required this.totalDiscounts,
    required this.cashSales,
    required this.nonCashSales,
    required this.totalExpenses,
    required this.cashExpenses,
    required this.openingFloat,
    required this.expectedCash,
    required this.countedCash,
    required this.variance,
    required this.salesCount,
    required this.voidedCount,
    this.notes,
    required this.closedBy,
    required this.closedByName,
    required this.closedAt,
  });

  @override
  List<Object?> get props => [
        id,
        businessDate,
        grossSales,
        netSales,
        totalDiscounts,
        cashSales,
        nonCashSales,
        totalExpenses,
        cashExpenses,
        openingFloat,
        expectedCash,
        countedCash,
        variance,
        salesCount,
        voidedCount,
        notes,
        closedBy,
        closedByName,
        closedAt,
      ];
}
```

- [ ] **Step 4: Export the entity**

In `lib/domain/entities/entities.dart`, add after the `daily_*`/alphabetical-appropriate spot (e.g. after `export 'activity_log_entity.dart';` or near `expense_entity`):

```dart
export 'daily_closing_entity.dart';
```

- [ ] **Step 5: Run test to verify it passes**

Run: `flutter test test/domain/entities/daily_closing_draft_test.dart`
Expected: PASS (3 tests).

- [ ] **Step 6: Commit**

```bash
git add lib/domain/entities/daily_closing_entity.dart lib/domain/entities/entities.dart test/domain/entities/daily_closing_draft_test.dart
git commit -m "feat(eod): DailyClosingEntity + draft computation"
```

---

## Task 4: `DailyClosingModel` (Firestore serialization)

**Files:**
- Create: `lib/data/models/daily_closing_model.dart`
- Modify: `lib/data/models/models.dart`
- Test: `test/data/models/daily_closing_model_test.dart`

- [ ] **Step 1: Write the failing test**

Create `test/data/models/daily_closing_model_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:maki_mobile_pos/data/models/daily_closing_model.dart';
import 'package:maki_mobile_pos/domain/entities/daily_closing_entity.dart';

void main() {
  group('DailyClosingModel', () {
    final entity = DailyClosingEntity(
      id: '2026-05-28',
      businessDate: DateTime(2026, 5, 28),
      grossSales: 1000,
      netSales: 950,
      totalDiscounts: 50,
      cashSales: 600,
      nonCashSales: 350,
      totalExpenses: 300,
      cashExpenses: 220,
      openingFloat: 2000,
      expectedCash: 2380, // 2000 + 600 - 220
      countedCash: 2375,
      variance: -5,
      salesCount: 5,
      voidedCount: 1,
      notes: 'short by 5',
      closedBy: 'u-1',
      closedByName: 'Cashier One',
      closedAt: DateTime(2026, 5, 28, 21, 30),
    );

    test('round-trips entity -> map -> entity', () {
      final map = DailyClosingModel.fromEntity(entity).toMap();
      final back = DailyClosingModel.fromMap(map, '2026-05-28').toEntity();

      expect(back.id, '2026-05-28');
      expect(back.grossSales, 1000);
      expect(back.cashSales, 600);
      expect(back.nonCashSales, 350);
      expect(back.cashExpenses, 220);
      expect(back.openingFloat, 2000);
      expect(back.expectedCash, 2380);
      expect(back.countedCash, 2375);
      expect(back.variance, -5);
      expect(back.notes, 'short by 5');
      expect(back.closedByName, 'Cashier One');
    });

    test('defaults numeric fields to 0 when missing', () {
      final model = DailyClosingModel.fromMap({}, '2026-01-01');
      expect(model.grossSales, 0);
      expect(model.variance, 0);
      expect(model.salesCount, 0);
      expect(model.notes, isNull);
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/data/models/daily_closing_model_test.dart`
Expected: FAIL — `daily_closing_model.dart` does not exist.

- [ ] **Step 3: Create the model**

Create `lib/data/models/daily_closing_model.dart`:

```dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:maki_mobile_pos/domain/entities/daily_closing_entity.dart';

/// Firestore data model for end-of-day closings.
class DailyClosingModel {
  final String id;
  final DateTime businessDate;
  final double grossSales;
  final double netSales;
  final double totalDiscounts;
  final double cashSales;
  final double nonCashSales;
  final double totalExpenses;
  final double cashExpenses;
  final double openingFloat;
  final double expectedCash;
  final double countedCash;
  final double variance;
  final int salesCount;
  final int voidedCount;
  final String? notes;
  final String closedBy;
  final String closedByName;
  final DateTime closedAt;

  const DailyClosingModel({
    required this.id,
    required this.businessDate,
    required this.grossSales,
    required this.netSales,
    required this.totalDiscounts,
    required this.cashSales,
    required this.nonCashSales,
    required this.totalExpenses,
    required this.cashExpenses,
    required this.openingFloat,
    required this.expectedCash,
    required this.countedCash,
    required this.variance,
    required this.salesCount,
    required this.voidedCount,
    this.notes,
    required this.closedBy,
    required this.closedByName,
    required this.closedAt,
  });

  factory DailyClosingModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return DailyClosingModel.fromMap(data, doc.id);
  }

  factory DailyClosingModel.fromMap(Map<String, dynamic> map, String id) {
    double d(String k) => (map[k] as num?)?.toDouble() ?? 0.0;
    int i(String k) => (map[k] as num?)?.toInt() ?? 0;
    return DailyClosingModel(
      id: id,
      businessDate:
          (map['businessDate'] as Timestamp?)?.toDate() ?? DateTime.now(),
      grossSales: d('grossSales'),
      netSales: d('netSales'),
      totalDiscounts: d('totalDiscounts'),
      cashSales: d('cashSales'),
      nonCashSales: d('nonCashSales'),
      totalExpenses: d('totalExpenses'),
      cashExpenses: d('cashExpenses'),
      openingFloat: d('openingFloat'),
      expectedCash: d('expectedCash'),
      countedCash: d('countedCash'),
      variance: d('variance'),
      salesCount: i('salesCount'),
      voidedCount: i('voidedCount'),
      notes: map['notes'] as String?,
      closedBy: map['closedBy'] as String? ?? '',
      closedByName: map['closedByName'] as String? ?? '',
      closedAt: (map['closedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  factory DailyClosingModel.fromEntity(DailyClosingEntity e) {
    return DailyClosingModel(
      id: e.id,
      businessDate: e.businessDate,
      grossSales: e.grossSales,
      netSales: e.netSales,
      totalDiscounts: e.totalDiscounts,
      cashSales: e.cashSales,
      nonCashSales: e.nonCashSales,
      totalExpenses: e.totalExpenses,
      cashExpenses: e.cashExpenses,
      openingFloat: e.openingFloat,
      expectedCash: e.expectedCash,
      countedCash: e.countedCash,
      variance: e.variance,
      salesCount: e.salesCount,
      voidedCount: e.voidedCount,
      notes: e.notes,
      closedBy: e.closedBy,
      closedByName: e.closedByName,
      closedAt: e.closedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'businessDate': Timestamp.fromDate(businessDate),
      'grossSales': grossSales,
      'netSales': netSales,
      'totalDiscounts': totalDiscounts,
      'cashSales': cashSales,
      'nonCashSales': nonCashSales,
      'totalExpenses': totalExpenses,
      'cashExpenses': cashExpenses,
      'openingFloat': openingFloat,
      'expectedCash': expectedCash,
      'countedCash': countedCash,
      'variance': variance,
      'salesCount': salesCount,
      'voidedCount': voidedCount,
      'notes': notes,
      'closedBy': closedBy,
      'closedByName': closedByName,
      'closedAt': Timestamp.fromDate(closedAt),
    };
  }

  /// Same as [toMap] but stamps the close time with a server timestamp.
  Map<String, dynamic> toCreateMap() {
    final map = toMap();
    map['closedAt'] = FieldValue.serverTimestamp();
    return map;
  }

  DailyClosingEntity toEntity() {
    return DailyClosingEntity(
      id: id,
      businessDate: businessDate,
      grossSales: grossSales,
      netSales: netSales,
      totalDiscounts: totalDiscounts,
      cashSales: cashSales,
      nonCashSales: nonCashSales,
      totalExpenses: totalExpenses,
      cashExpenses: cashExpenses,
      openingFloat: openingFloat,
      expectedCash: expectedCash,
      countedCash: countedCash,
      variance: variance,
      salesCount: salesCount,
      voidedCount: voidedCount,
      notes: notes,
      closedBy: closedBy,
      closedByName: closedByName,
      closedAt: closedAt,
    );
  }
}
```

- [ ] **Step 4: Export the model**

In `lib/data/models/models.dart`, add:

```dart
export 'daily_closing_model.dart';
```

- [ ] **Step 5: Run test to verify it passes**

Run: `flutter test test/data/models/daily_closing_model_test.dart`
Expected: PASS (2 tests).

- [ ] **Step 6: Commit**

```bash
git add lib/data/models/daily_closing_model.dart lib/data/models/models.dart test/data/models/daily_closing_model_test.dart
git commit -m "feat(eod): DailyClosingModel firestore serialization"
```

---

## Task 5: Collection constant + repository (interface + impl)

**Files:**
- Modify: `lib/core/constants/firestore_collections.dart`
- Create: `lib/domain/repositories/daily_closing_repository.dart`
- Modify: `lib/domain/repositories/repositories.dart`
- Create: `lib/data/repositories/daily_closing_repository_impl.dart`
- Modify: `lib/data/repositories/repositories.dart`

No unit test for the impl (Firestore I/O is verified manually + via the use case tests with a mocked repository). This task is plumbing.

- [ ] **Step 1: Add the collection constant**

In `lib/core/constants/firestore_collections.dart`, after the `pettyCash` constant:

```dart
  /// Petty cash collection - cash fund records
  static const String pettyCash = 'petty_cash';

  /// Daily closings collection - end-of-day sales-drawer reconciliations
  static const String dailyClosings = 'daily_closings';
```

- [ ] **Step 2: Create the repository interface**

Create `lib/domain/repositories/daily_closing_repository.dart`:

```dart
import 'package:maki_mobile_pos/domain/entities/daily_closing_entity.dart';

/// Abstract repository contract for end-of-day closings.
abstract class DailyClosingRepository {
  /// Returns the saved closing for [date]'s business day, or null if the day
  /// has not been closed yet.
  Future<DailyClosingEntity?> getClosing(DateTime date);

  /// Persists a closing. The document id is the business date (`YYYY-MM-DD`).
  Future<DailyClosingEntity> saveClosing(DailyClosingEntity closing);

  /// Streams saved closings, newest first.
  Stream<List<DailyClosingEntity>> watchClosings({int limit = 60});
}
```

- [ ] **Step 3: Export the interface**

In `lib/domain/repositories/repositories.dart`, add:

```dart
export 'daily_closing_repository.dart';
```

- [ ] **Step 4: Create the implementation**

Create `lib/data/repositories/daily_closing_repository_impl.dart`:

```dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:maki_mobile_pos/core/constants/firestore_collections.dart';
import 'package:maki_mobile_pos/core/errors/exceptions.dart';
import 'package:maki_mobile_pos/data/models/daily_closing_model.dart';
import 'package:maki_mobile_pos/domain/entities/daily_closing_entity.dart';
import 'package:maki_mobile_pos/domain/repositories/daily_closing_repository.dart';

/// Firestore implementation of [DailyClosingRepository].
///
/// Document id is the business date formatted `YYYY-MM-DD`, so each calendar
/// day maps to exactly one closing document.
class DailyClosingRepositoryImpl implements DailyClosingRepository {
  final FirebaseFirestore _firestore;

  DailyClosingRepositoryImpl({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  CollectionReference get _ref =>
      _firestore.collection(FirestoreCollections.dailyClosings);

  /// Formats a date as the deterministic `YYYY-MM-DD` document id.
  static String docIdFor(DateTime date) {
    final y = date.year.toString().padLeft(4, '0');
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  @override
  Future<DailyClosingEntity?> getClosing(DateTime date) async {
    try {
      final doc = await _ref.doc(docIdFor(date)).get();
      if (!doc.exists) return null;
      return DailyClosingModel.fromFirestore(doc).toEntity();
    } on FirebaseException catch (e) {
      throw DatabaseException(
        message: 'Failed to load closing: ${e.message}',
        code: e.code,
        originalError: e,
      );
    }
  }

  @override
  Future<DailyClosingEntity> saveClosing(DailyClosingEntity closing) async {
    try {
      debugPrint('DailyClosingRepository: saving closing ${closing.id}');
      final model = DailyClosingModel.fromEntity(closing);
      final docRef = _ref.doc(closing.id);
      await docRef.set(model.toCreateMap());
      final doc = await docRef.get();
      return DailyClosingModel.fromFirestore(doc).toEntity();
    } on FirebaseException catch (e) {
      throw DatabaseException(
        message: 'Failed to save closing: ${e.message}',
        code: e.code,
        originalError: e,
      );
    }
  }

  @override
  Stream<List<DailyClosingEntity>> watchClosings({int limit = 60}) {
    return _ref
        .orderBy('businessDate', descending: true)
        .limit(limit)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => DailyClosingModel.fromFirestore(doc).toEntity())
            .toList());
  }
}
```

- [ ] **Step 5: Export the implementation**

In `lib/data/repositories/repositories.dart`, add:

```dart
export 'daily_closing_repository_impl.dart';
```

- [ ] **Step 6: Verify it compiles**

Run: `flutter analyze lib/data/repositories/daily_closing_repository_impl.dart lib/domain/repositories/daily_closing_repository.dart`
Expected: No errors.

- [ ] **Step 7: Commit**

```bash
git add lib/core/constants/firestore_collections.dart lib/domain/repositories/daily_closing_repository.dart lib/domain/repositories/repositories.dart lib/data/repositories/daily_closing_repository_impl.dart lib/data/repositories/repositories.dart
git commit -m "feat(eod): daily_closings collection + repository"
```

---

## Task 6: Permissions + ActivityType

**Files:**
- Modify: `lib/core/constants/role_permissions.dart`
- Modify: `lib/domain/entities/activity_log_entity.dart`
- Test: `test/core/constants/daily_closing_permissions_test.dart`

- [ ] **Step 1: Write the failing test**

Create `test/core/constants/daily_closing_permissions_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:maki_mobile_pos/core/constants/role_permissions.dart';
import 'package:maki_mobile_pos/core/enums/user_role.dart';

void main() {
  group('End-of-day permissions', () {
    for (final role in UserRole.values) {
      test('${role.value} can view and close the day', () {
        expect(
            RolePermissions.hasPermission(role, Permission.viewEndOfDay), true);
        expect(RolePermissions.hasPermission(role, Permission.closeDay), true);
      });
    }
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/core/constants/daily_closing_permissions_test.dart`
Expected: FAIL — `Permission.viewEndOfDay` / `Permission.closeDay` are not defined.

- [ ] **Step 3: Add the permissions to the enum**

In `lib/core/constants/role_permissions.dart`, in the `Permission` enum after the Cash Management block:

```dart
  // Cash Management
  managePettyCash,
  performCutOff,

  // End-of-Day Closing
  viewEndOfDay,
  closeDay,
```

- [ ] **Step 4: Grant to all three roles**

Add the two permissions to each role set. In `_cashierPermissions`, after the `Permission.addExpense,` line in the Expenses block:

```dart
    // Expenses (add only)
    Permission.viewExpenses,
    Permission.addExpense,
    // End-of-day closing
    Permission.viewEndOfDay,
    Permission.closeDay,
```

In `_staffPermissions`, after its `Permission.addExpense,`:

```dart
    // Expenses (add only)
    Permission.viewExpenses,
    Permission.addExpense,
    // End-of-day closing
    Permission.viewEndOfDay,
    Permission.closeDay,
```

In `_adminPermissions`, after the Cash Management block (`Permission.performCutOff,`):

```dart
    // Cash Management
    Permission.managePettyCash,
    Permission.performCutOff,
    // End-of-day closing
    Permission.viewEndOfDay,
    Permission.closeDay,
```

- [ ] **Step 5: Add the activity type**

In `lib/domain/entities/activity_log_entity.dart`, in the `ActivityType` enum after the Petty Cash entries:

```dart
  // Petty Cash
  pettyCash('petty_cash', 'Petty Cash', '💵'),
  pettyCashCutOff('petty_cash_cutoff', 'Petty Cash Cut-off', '🧮'),

  // End-of-Day
  dayClosed('day_closed', 'Day Closed', '📒'),
```

- [ ] **Step 6: Run test to verify it passes**

Run: `flutter test test/core/constants/daily_closing_permissions_test.dart`
Expected: PASS.

- [ ] **Step 7: Commit**

```bash
git add lib/core/constants/role_permissions.dart lib/domain/entities/activity_log_entity.dart test/core/constants/daily_closing_permissions_test.dart
git commit -m "feat(eod): viewEndOfDay/closeDay permissions + activity type"
```

---

## Task 7: `GetDailyClosingSummaryUseCase`

**Files:**
- Create: `lib/domain/usecases/daily_closing/get_daily_closing_summary_usecase.dart`
- Test: `test/domain/usecases/daily_closing/get_daily_closing_summary_usecase_test.dart`

- [ ] **Step 1: Write the failing test**

Create `test/domain/usecases/daily_closing/get_daily_closing_summary_usecase_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:maki_mobile_pos/core/enums/payment_method.dart';
import 'package:maki_mobile_pos/core/enums/user_role.dart';
import 'package:maki_mobile_pos/domain/entities/expense_entity.dart';
import 'package:maki_mobile_pos/domain/entities/user_entity.dart';
import 'package:maki_mobile_pos/domain/repositories/expense_repository.dart';
import 'package:maki_mobile_pos/domain/repositories/sale_repository.dart';
import 'package:maki_mobile_pos/domain/usecases/daily_closing/get_daily_closing_summary_usecase.dart';

class _MockSaleRepository extends Mock implements SaleRepository {}

class _MockExpenseRepository extends Mock implements ExpenseRepository {}

UserEntity _user(UserRole role, {bool active = true}) => UserEntity(
      id: 'u-${role.value}',
      email: '${role.value}@test',
      displayName: '${role.value} user',
      role: role,
      isActive: active,
      createdAt: DateTime(2025, 1, 1),
    );

ExpenseEntity _exp(double amount, PaymentMethod paidVia) => ExpenseEntity(
      id: 'e',
      description: 'x',
      amount: amount,
      category: 'c',
      date: DateTime(2026, 5, 28),
      paidVia: paidVia,
      createdAt: DateTime(2026, 5, 28),
      createdBy: '',
      createdByName: '',
    );

void main() {
  late _MockSaleRepository sales;
  late _MockExpenseRepository expenses;
  late GetDailyClosingSummaryUseCase useCase;

  const summary = SalesSummary(
    totalSalesCount: 4,
    voidedSalesCount: 0,
    grossAmount: 1000,
    totalDiscounts: 0,
    netAmount: 1000,
    totalCost: 0,
    totalProfit: 1000,
    byPaymentMethod: {
      PaymentMethod.cash: 700,
      PaymentMethod.gcash: 300,
    },
  );

  setUp(() {
    sales = _MockSaleRepository();
    expenses = _MockExpenseRepository();
    useCase = GetDailyClosingSummaryUseCase(
      saleRepository: sales,
      expenseRepository: expenses,
    );

    when(() => sales.getSalesSummary(
        startDate: any(named: 'startDate'),
        endDate: any(named: 'endDate'))).thenAnswer((_) async => summary);
    when(() => expenses.getExpenses(
          startDate: any(named: 'startDate'),
          endDate: any(named: 'endDate'),
          category: any(named: 'category'),
          limit: any(named: 'limit'),
        )).thenAnswer((_) async => [
          _exp(150, PaymentMethod.cash),
          _exp(50, PaymentMethod.gcash),
        ]);
  });

  test('computes the draft for an authorized actor', () async {
    final result = await useCase.execute(
      actor: _user(UserRole.cashier),
      date: DateTime(2026, 5, 28),
    );

    expect(result.success, true);
    final draft = result.data!;
    expect(draft.grossSales, 1000);
    expect(draft.cashSales, 700);
    expect(draft.nonCashSales, 300);
    expect(draft.totalExpenses, 200);
    expect(draft.cashExpenses, 150);
  });

  test('inactive user is denied', () async {
    final result = await useCase.execute(
      actor: _user(UserRole.cashier, active: false),
      date: DateTime(2026, 5, 28),
    );

    expect(result.success, false);
    expect(result.errorCode, 'permission-denied');
    verifyNever(() => sales.getSalesSummary(
        startDate: any(named: 'startDate'), endDate: any(named: 'endDate')));
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/domain/usecases/daily_closing/get_daily_closing_summary_usecase_test.dart`
Expected: FAIL — use case file does not exist.

- [ ] **Step 3: Create the use case**

Create `lib/domain/usecases/daily_closing/get_daily_closing_summary_usecase.dart`:

```dart
import 'package:maki_mobile_pos/core/constants/role_permissions.dart';
import 'package:maki_mobile_pos/core/errors/exceptions.dart';
import 'package:maki_mobile_pos/core/permissions/permission_assert.dart';
import 'package:maki_mobile_pos/domain/entities/daily_closing_entity.dart';
import 'package:maki_mobile_pos/domain/entities/user_entity.dart';
import 'package:maki_mobile_pos/domain/repositories/expense_repository.dart';
import 'package:maki_mobile_pos/domain/repositories/sale_repository.dart';
import 'package:maki_mobile_pos/domain/usecases/base/use_case.dart';

/// Computes the live, unsaved [DailyClosingDraft] for a business day by
/// combining the sales summary with the day's expenses.
///
/// Permission: [Permission.viewEndOfDay].
class GetDailyClosingSummaryUseCase {
  final SaleRepository _saleRepository;
  final ExpenseRepository _expenseRepository;

  GetDailyClosingSummaryUseCase({
    required SaleRepository saleRepository,
    required ExpenseRepository expenseRepository,
  })  : _saleRepository = saleRepository,
        _expenseRepository = expenseRepository;

  Future<UseCaseResult<DailyClosingDraft>> execute({
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

      final draft = DailyClosingDraft.fromData(
        businessDate: dayStart,
        summary: summary,
        expenses: expenses,
      );
      return UseCaseResult.successData(draft);
    } on AppException catch (e) {
      return UseCaseResult.fromException(e);
    } catch (e) {
      return UseCaseResult.failure(
          message: 'Failed to compute closing summary: $e');
    }
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/domain/usecases/daily_closing/get_daily_closing_summary_usecase_test.dart`
Expected: PASS (2 tests).

- [ ] **Step 5: Commit**

```bash
git add lib/domain/usecases/daily_closing/get_daily_closing_summary_usecase.dart test/domain/usecases/daily_closing/get_daily_closing_summary_usecase_test.dart
git commit -m "feat(eod): GetDailyClosingSummaryUseCase"
```

---

## Task 8: `CloseDayUseCase`

**Files:**
- Create: `lib/domain/usecases/daily_closing/close_day_usecase.dart`
- Test: `test/domain/usecases/daily_closing/close_day_usecase_test.dart`

- [ ] **Step 1: Write the failing test**

Create `test/domain/usecases/daily_closing/close_day_usecase_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:maki_mobile_pos/core/enums/payment_method.dart';
import 'package:maki_mobile_pos/core/enums/user_role.dart';
import 'package:maki_mobile_pos/domain/entities/activity_log_entity.dart';
import 'package:maki_mobile_pos/domain/entities/daily_closing_entity.dart';
import 'package:maki_mobile_pos/domain/entities/expense_entity.dart';
import 'package:maki_mobile_pos/domain/entities/user_entity.dart';
import 'package:maki_mobile_pos/domain/repositories/activity_log_repository.dart';
import 'package:maki_mobile_pos/domain/repositories/daily_closing_repository.dart';
import 'package:maki_mobile_pos/domain/repositories/expense_repository.dart';
import 'package:maki_mobile_pos/domain/repositories/sale_repository.dart';
import 'package:maki_mobile_pos/domain/usecases/daily_closing/close_day_usecase.dart';
import 'package:maki_mobile_pos/services/activity_logger.dart';

class _MockSaleRepository extends Mock implements SaleRepository {}

class _MockExpenseRepository extends Mock implements ExpenseRepository {}

class _MockClosingRepository extends Mock implements DailyClosingRepository {}

class _MockActivityLogRepository extends Mock
    implements ActivityLogRepository {}

class _FakeClosing extends Fake implements DailyClosingEntity {}

class _FakeActivityLog extends Fake implements ActivityLogEntity {}

UserEntity _user(UserRole role, {bool active = true}) => UserEntity(
      id: 'u-${role.value}',
      email: '${role.value}@test',
      displayName: '${role.value} user',
      role: role,
      isActive: active,
      createdAt: DateTime(2025, 1, 1),
    );

ExpenseEntity _exp(double amount, PaymentMethod paidVia) => ExpenseEntity(
      id: 'e',
      description: 'x',
      amount: amount,
      category: 'c',
      date: DateTime(2026, 5, 28),
      paidVia: paidVia,
      createdAt: DateTime(2026, 5, 28),
      createdBy: '',
      createdByName: '',
    );

void main() {
  setUpAll(() {
    registerFallbackValue(_FakeClosing());
    registerFallbackValue(_FakeActivityLog());
  });

  late _MockSaleRepository sales;
  late _MockExpenseRepository expenses;
  late _MockClosingRepository closings;
  late _MockActivityLogRepository logRepo;
  late CloseDayUseCase useCase;

  const summary = SalesSummary(
    totalSalesCount: 3,
    voidedSalesCount: 0,
    grossAmount: 1000,
    totalDiscounts: 0,
    netAmount: 1000,
    totalCost: 0,
    totalProfit: 1000,
    byPaymentMethod: {PaymentMethod.cash: 700, PaymentMethod.gcash: 300},
  );

  setUp(() {
    sales = _MockSaleRepository();
    expenses = _MockExpenseRepository();
    closings = _MockClosingRepository();
    logRepo = _MockActivityLogRepository();
    useCase = CloseDayUseCase(
      closingRepository: closings,
      saleRepository: sales,
      expenseRepository: expenses,
      logger: ActivityLogger(logRepo),
    );

    when(() => sales.getSalesSummary(
        startDate: any(named: 'startDate'),
        endDate: any(named: 'endDate'))).thenAnswer((_) async => summary);
    when(() => expenses.getExpenses(
          startDate: any(named: 'startDate'),
          endDate: any(named: 'endDate'),
          category: any(named: 'category'),
          limit: any(named: 'limit'),
        )).thenAnswer((_) async => [_exp(100, PaymentMethod.cash)]);
    when(() => closings.getClosing(any())).thenAnswer((_) async => null);
    when(() => closings.saveClosing(any())).thenAnswer(
        (inv) async => inv.positionalArguments.first as DailyClosingEntity);
    when(() => logRepo.logActivity(any()))
        .thenAnswer((inv) async => inv.positionalArguments.first);
  });

  test('computes expectedCash and variance and saves the closing', () async {
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
      countedCash: 2590,
      notes: null,
    );

    expect(result.success, true);
    final saved = captured.single;
    expect(saved.id, '2026-05-28');
    expect(saved.cashSales, 700);
    expect(saved.cashExpenses, 100);
    expect(saved.expectedCash, 2600); // 2000 + 700 - 100
    expect(saved.variance, -10); // 2590 - 2600
    expect(saved.closedBy, 'u-cashier');
    verify(() => logRepo.logActivity(any())).called(1);
  });

  test('rejects when the day is already closed', () async {
    when(() => closings.getClosing(any())).thenAnswer((_) async =>
        captured_existing);

    final result = await useCase.execute(
      actor: _user(UserRole.admin),
      date: DateTime(2026, 5, 28),
      openingFloat: 0,
      countedCash: 0,
    );

    expect(result.success, false);
    expect(result.errorCode, 'already-closed');
    verifyNever(() => closings.saveClosing(any()));
  });

  test('inactive user is denied', () async {
    final result = await useCase.execute(
      actor: _user(UserRole.cashier, active: false),
      date: DateTime(2026, 5, 28),
      openingFloat: 0,
      countedCash: 0,
    );

    expect(result.success, false);
    expect(result.errorCode, 'permission-denied');
    verifyNever(() => closings.saveClosing(any()));
  });
}

final captured_existing = DailyClosingEntity(
  id: '2026-05-28',
  businessDate: DateTime(2026, 5, 28),
  grossSales: 0,
  netSales: 0,
  totalDiscounts: 0,
  cashSales: 0,
  nonCashSales: 0,
  totalExpenses: 0,
  cashExpenses: 0,
  openingFloat: 0,
  expectedCash: 0,
  countedCash: 0,
  variance: 0,
  salesCount: 0,
  voidedCount: 0,
  closedBy: 'someone',
  closedByName: 'Someone',
  closedAt: DateTime(2026, 5, 28),
);
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/domain/usecases/daily_closing/close_day_usecase_test.dart`
Expected: FAIL — use case file does not exist.

- [ ] **Step 3: Create the use case**

Create `lib/domain/usecases/daily_closing/close_day_usecase.dart`:

```dart
import 'package:maki_mobile_pos/core/constants/role_permissions.dart';
import 'package:maki_mobile_pos/core/errors/exceptions.dart';
import 'package:maki_mobile_pos/core/permissions/permission_assert.dart';
import 'package:maki_mobile_pos/data/repositories/daily_closing_repository_impl.dart';
import 'package:maki_mobile_pos/domain/entities/activity_log_entity.dart';
import 'package:maki_mobile_pos/domain/entities/daily_closing_entity.dart';
import 'package:maki_mobile_pos/domain/entities/user_entity.dart';
import 'package:maki_mobile_pos/domain/repositories/daily_closing_repository.dart';
import 'package:maki_mobile_pos/domain/repositories/expense_repository.dart';
import 'package:maki_mobile_pos/domain/repositories/sale_repository.dart';
import 'package:maki_mobile_pos/domain/usecases/base/use_case.dart';
import 'package:maki_mobile_pos/services/activity_logger.dart';

/// Closes a business day: recomputes the figures, captures the manual float +
/// counted cash, persists the closing, and writes an activity log.
///
/// Permission: [Permission.closeDay]. Rejects with `already-closed` if a
/// closing already exists for that day (one closing per day).
class CloseDayUseCase {
  final DailyClosingRepository _closingRepository;
  final SaleRepository _saleRepository;
  final ExpenseRepository _expenseRepository;
  final ActivityLogger _logger;

  CloseDayUseCase({
    required DailyClosingRepository closingRepository,
    required SaleRepository saleRepository,
    required ExpenseRepository expenseRepository,
    required ActivityLogger logger,
  })  : _closingRepository = closingRepository,
        _saleRepository = saleRepository,
        _expenseRepository = expenseRepository,
        _logger = logger;

  Future<UseCaseResult<DailyClosingEntity>> execute({
    required UserEntity actor,
    required DateTime date,
    required double openingFloat,
    required double countedCash,
    String? notes,
  }) async {
    try {
      assertPermission(actor, Permission.closeDay);

      final existing = await _closingRepository.getClosing(date);
      if (existing != null) {
        return const UseCaseResult.failure(
          message: 'This day has already been closed.',
          code: 'already-closed',
        );
      }

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

      final draft = DailyClosingDraft.fromData(
        businessDate: dayStart,
        summary: summary,
        expenses: expenses,
      );
      final expectedCash = draft.expectedCashFor(openingFloat);
      final variance = countedCash - expectedCash;
      final id = DailyClosingRepositoryImpl.docIdFor(dayStart);

      final entity = DailyClosingEntity(
        id: id,
        businessDate: dayStart,
        grossSales: draft.grossSales,
        netSales: draft.netSales,
        totalDiscounts: draft.totalDiscounts,
        cashSales: draft.cashSales,
        nonCashSales: draft.nonCashSales,
        totalExpenses: draft.totalExpenses,
        cashExpenses: draft.cashExpenses,
        openingFloat: openingFloat,
        expectedCash: expectedCash,
        countedCash: countedCash,
        variance: variance,
        salesCount: draft.salesCount,
        voidedCount: draft.voidedCount,
        notes: (notes == null || notes.trim().isEmpty) ? null : notes.trim(),
        closedBy: actor.id,
        closedByName: actor.displayName,
        closedAt: DateTime.now(),
      );

      final saved = await _closingRepository.saveClosing(entity);

      await _logger.log(
        type: ActivityType.dayClosed,
        action: 'Closed business day $id',
        details:
            'Expected ₱${expectedCash.toStringAsFixed(2)}, counted ₱${countedCash.toStringAsFixed(2)} (variance ${variance >= 0 ? '+' : ''}${variance.toStringAsFixed(2)})',
        userId: actor.id,
        userName: actor.displayName,
        userRole: actor.role.value,
        entityId: saved.id,
        entityType: 'daily_closing',
        metadata: {
          'expectedCash': expectedCash,
          'countedCash': countedCash,
          'variance': variance,
          'openingFloat': openingFloat,
        },
      );

      return UseCaseResult.successData(saved);
    } on AppException catch (e) {
      return UseCaseResult.fromException(e);
    } catch (e) {
      return UseCaseResult.failure(message: 'Failed to close day: $e');
    }
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/domain/usecases/daily_closing/close_day_usecase_test.dart`
Expected: PASS (3 tests).

- [ ] **Step 5: Commit**

```bash
git add lib/domain/usecases/daily_closing/close_day_usecase.dart test/domain/usecases/daily_closing/close_day_usecase_test.dart
git commit -m "feat(eod): CloseDayUseCase with already-closed guard"
```

---

## Task 9: Riverpod provider

**Files:**
- Create: `lib/presentation/providers/daily_closing_provider.dart`
- Modify: `lib/presentation/providers/providers.dart`

No unit test (provider wiring is verified by the screens + the use case tests). The actor-resolution + invalidation patterns mirror `petty_cash_provider.dart`.

- [ ] **Step 1: Create the provider file**

Create `lib/presentation/providers/daily_closing_provider.dart`:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:maki_mobile_pos/core/errors/exceptions.dart';
import 'package:maki_mobile_pos/data/repositories/repositories.dart';
import 'package:maki_mobile_pos/domain/entities/entities.dart';
import 'package:maki_mobile_pos/domain/repositories/repositories.dart';
import 'package:maki_mobile_pos/domain/usecases/daily_closing/close_day_usecase.dart';
import 'package:maki_mobile_pos/domain/usecases/daily_closing/get_daily_closing_summary_usecase.dart';
import 'package:maki_mobile_pos/presentation/providers/auth_provider.dart';
import 'package:maki_mobile_pos/presentation/providers/expense_provider.dart';
import 'package:maki_mobile_pos/presentation/providers/sale_provider.dart';
import 'package:maki_mobile_pos/services/activity_logger.dart';
import 'package:maki_mobile_pos/services/firebase_service.dart';

// ==================== REPOSITORY PROVIDER ====================

final dailyClosingRepositoryProvider =
    Provider<DailyClosingRepository>((ref) {
  return DailyClosingRepositoryImpl(firestore: ref.watch(firestoreProvider));
});

// ==================== USE-CASE PROVIDERS ====================

final getDailyClosingSummaryUseCaseProvider =
    Provider<GetDailyClosingSummaryUseCase>((ref) {
  return GetDailyClosingSummaryUseCase(
    saleRepository: ref.watch(saleRepositoryProvider),
    expenseRepository: ref.watch(expenseRepositoryProvider),
  );
});

final closeDayUseCaseProvider = Provider<CloseDayUseCase>((ref) {
  return CloseDayUseCase(
    closingRepository: ref.watch(dailyClosingRepositoryProvider),
    saleRepository: ref.watch(saleRepositoryProvider),
    expenseRepository: ref.watch(expenseRepositoryProvider),
    logger: ref.watch(activityLoggerProvider),
  );
});

// ==================== QUERIES ====================

/// Live, unsaved closing figures for [date]. Drives the review screen.
final dailyClosingDraftProvider =
    FutureProvider.family<DailyClosingDraft, DateTime>((ref, date) async {
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

/// The saved closing for [date], or null if the day is still open.
final dailyClosingForDateProvider =
    FutureProvider.family<DailyClosingEntity?, DateTime>((ref, date) async {
  return ref.watch(dailyClosingRepositoryProvider).getClosing(date);
});

/// Stream of past closings, newest first.
final dailyClosingHistoryProvider =
    StreamProvider<List<DailyClosingEntity>>((ref) {
  return authGatedStream(ref, (_) {
    return ref.watch(dailyClosingRepositoryProvider).watchClosings();
  });
});

// ==================== OPERATIONS ====================

/// Notifier wrapping the close-day mutation. Resolves the actor from
/// [currentUserProvider] and invalidates dependent providers on success.
class DailyClosingOperationsNotifier extends StateNotifier<AsyncValue<void>> {
  final Ref _ref;

  DailyClosingOperationsNotifier(this._ref)
      : super(const AsyncValue.data(null));

  UserEntity _requireUser() {
    final user = _ref.read(currentUserProvider).valueOrNull;
    if (user == null) {
      throw const UnauthenticatedException();
    }
    return user;
  }

  Future<DailyClosingEntity?> closeDay({
    required DateTime date,
    required double openingFloat,
    required double countedCash,
    String? notes,
  }) async {
    state = const AsyncValue.loading();
    try {
      final actor = _requireUser();
      final result = await _ref.read(closeDayUseCaseProvider).execute(
            actor: actor,
            date: date,
            openingFloat: openingFloat,
            countedCash: countedCash,
            notes: notes,
          );
      if (result.success) {
        state = const AsyncValue.data(null);
        _ref.invalidate(dailyClosingForDateProvider);
        _ref.invalidate(dailyClosingDraftProvider);
        _ref.invalidate(dailyClosingHistoryProvider);
        _ref.invalidate(todaysSalesSummaryProvider);
        return result.data;
      }
      state = AsyncValue.error(
        result.errorMessage ?? 'Failed to close day',
        StackTrace.current,
      );
      return null;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return null;
    }
  }
}

final dailyClosingOperationsProvider = StateNotifierProvider<
    DailyClosingOperationsNotifier, AsyncValue<void>>((ref) {
  return DailyClosingOperationsNotifier(ref);
});
```

`saleRepositoryProvider` and `expenseRepositoryProvider` already exist (in `sale_provider.dart` and `expense_provider.dart` respectively) and are re-exported via the providers barrel — import them directly as shown.

- [ ] **Step 2: Export the provider**

In `lib/presentation/providers/providers.dart`, add:

```dart
export 'daily_closing_provider.dart';
```

- [ ] **Step 3: Verify it compiles**

Run: `flutter analyze lib/presentation/providers/daily_closing_provider.dart`
Expected: No errors.

- [ ] **Step 4: Commit**

```bash
git add lib/presentation/providers/daily_closing_provider.dart lib/presentation/providers/providers.dart
git commit -m "feat(eod): daily closing providers"
```

---

## Task 10: Firestore security rules

**Files:**
- Modify: `firestore.rules`

- [ ] **Step 1: Add the `daily_closings` rule block**

In `firestore.rules`, after the `petty_cash` block (ends at the line with `}` following `allow read, write: if isAdmin()...`) and before the `user_logs` block, insert:

```javascript
    // ==================== DAILY CLOSINGS COLLECTION ====================

    match /daily_closings/{closingId} {
      // Any active valid user (cashier/staff/admin) can read closings.
      allow read: if isValidUser() && isActiveUser();

      // Active valid users can create a closing (cashier closes, admin too).
      allow create: if isValidUser() && isActiveUser();

      // Closings are immutable once saved (audit record).
      allow update, delete: if false;
    }
```

- [ ] **Step 2: Verify rules syntax (compile check)**

Run: `firebase deploy --only firestore:rules --dry-run`
Expected: rules compile with no syntax errors. (If the Firebase CLI is unavailable in the environment, visually confirm the block matches the `void_requests` style — balanced braces, `isValidUser()`/`isActiveUser()` helpers exist.)

- [ ] **Step 3: Commit**

```bash
git add firestore.rules
git commit -m "feat(eod): daily_closings firestore rules"
```

---

## Task 11: Routing (names, routes, guards)

**Files:**
- Modify: `lib/config/router/route_names.dart`
- Modify: `lib/config/router/app_routes.dart`
- Modify: `lib/config/router/route_guards.dart`

UI screens are created in Tasks 12-13; this task wires routes that reference them. To avoid a broken build between tasks, **do Task 12 and 13 first if executing strictly in order**, OR create the routes here pointing at the screens and accept that the build only compiles once the screens exist. Recommended order: 12 → 13 → 11. The steps below assume the screen classes `EndOfDayScreen` and `DailyClosingHistoryScreen` exist.

- [ ] **Step 1: Add route name + path constants**

In `lib/config/router/route_names.dart`, in the `RouteNames` section after `saleDetail`:

```dart
  static const String saleDetail = 'saleDetail';
  static const String endOfDay = 'endOfDay';
  static const String endOfDayHistory = 'endOfDayHistory';
```

In the `RoutePaths` section after `saleDetail`:

```dart
  static const String saleDetail = '/reports/sale/:id';
  static const String endOfDay = '/reports/end-of-day';
  static const String endOfDayHistory = '/reports/end-of-day/history';
```

- [ ] **Step 2: Add the import + child routes**

In `lib/config/router/app_routes.dart`, add imports near the other reports-screen imports (find the block importing `sales_report_screen.dart` etc.):

```dart
import 'package:maki_mobile_pos/presentation/mobile/screens/reports/end_of_day_screen.dart';
import 'package:maki_mobile_pos/presentation/mobile/screens/reports/daily_closing_history_screen.dart';
```

In the `/reports` `GoRoute`'s `routes:` list, after the `sale/:id` child route, add:

```dart
          GoRoute(
            path: 'end-of-day',
            name: RouteNames.endOfDay,
            builder: (context, state) => const EndOfDayScreen(),
            routes: [
              GoRoute(
                path: 'history',
                name: RouteNames.endOfDayHistory,
                builder: (context, state) =>
                    const DailyClosingHistoryScreen(),
              ),
            ],
          ),
```

- [ ] **Step 3: Add route-permission guards**

In `lib/config/router/route_guards.dart`, in the `_routePermissions` map after the `/reports/top-selling` entry:

```dart
    '/reports/top-selling': Permission.viewSalesReports,
    '/reports/end-of-day': Permission.viewEndOfDay,
    '/reports/end-of-day/history': Permission.viewEndOfDay,
```

- [ ] **Step 4: Verify it compiles**

Run: `flutter analyze lib/config/router/`
Expected: No errors (requires Tasks 12-13 done first).

- [ ] **Step 5: Commit**

```bash
git add lib/config/router/route_names.dart lib/config/router/app_routes.dart lib/config/router/route_guards.dart
git commit -m "feat(eod): routes + guards for end-of-day screens"
```

---

## Task 12: `EndOfDayScreen` (review + close)

**Files:**
- Create: `lib/presentation/mobile/screens/reports/end_of_day_screen.dart`

UI; verified manually in-app (Task 15). Styled with neutral surfaces; color only for the variance per the project's color discipline.

- [ ] **Step 1: Create the screen**

Create `lib/presentation/mobile/screens/reports/end_of_day_screen.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:maki_mobile_pos/config/router/router.dart';
import 'package:maki_mobile_pos/core/constants/app_constants.dart';
import 'package:maki_mobile_pos/core/extensions/navigation_extensions.dart';
import 'package:maki_mobile_pos/core/extensions/num_extensions.dart';
import 'package:maki_mobile_pos/core/theme/theme.dart';
import 'package:maki_mobile_pos/domain/entities/daily_closing_entity.dart';
import 'package:maki_mobile_pos/presentation/providers/providers.dart';

/// End-of-day review + close flow for the current business day.
///
/// Shows the sales + expenses figures, captures the opening float and counted
/// cash, surfaces the variance, and persists the closing. If the day is
/// already closed, renders the saved record read-only.
class EndOfDayScreen extends ConsumerStatefulWidget {
  const EndOfDayScreen({super.key});

  @override
  ConsumerState<EndOfDayScreen> createState() => _EndOfDayScreenState();
}

class _EndOfDayScreenState extends ConsumerState<EndOfDayScreen> {
  final _formKey = GlobalKey<FormState>();
  final _floatController = TextEditingController();
  final _countedController = TextEditingController();
  final _notesController = TextEditingController();
  bool _busy = false;

  DateTime get _today {
    final n = DateTime.now();
    return DateTime(n.year, n.month, n.day);
  }

  @override
  void dispose() {
    _floatController.dispose();
    _countedController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  double get _float => double.tryParse(_floatController.text) ?? 0;
  double? get _counted => double.tryParse(_countedController.text);

  @override
  Widget build(BuildContext context) {
    final existingAsync = ref.watch(dailyClosingForDateProvider(_today));

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(CupertinoIcons.back),
          onPressed: () => context.goBackOr(RoutePaths.reports),
        ),
        title: const Text('End-of-Day Closing'),
        actions: [
          IconButton(
            icon: const Icon(CupertinoIcons.clock),
            tooltip: 'History',
            onPressed: () => context.pushNamed(RouteNames.endOfDayHistory),
          ),
        ],
      ),
      body: existingAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (existing) => existing != null
            ? _ClosedView(closing: existing)
            : _buildReview(),
      ),
    );
  }

  Widget _buildReview() {
    final draftAsync = ref.watch(dailyClosingDraftProvider(_today));
    return draftAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (draft) {
        final expected = draft.expectedCashFor(_float);
        final counted = _counted;
        final variance = counted == null ? null : counted - expected;

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _section('Sales', [
                  _row('Gross sales', draft.grossSales),
                  _row('Cash sales', draft.cashSales),
                  _row('Non-cash sales', draft.nonCashSales),
                  _row('Discounts', draft.totalDiscounts),
                  _rowText('Sales count', '${draft.salesCount}'),
                ]),
                const SizedBox(height: 16),
                _section('Expenses', [
                  _row('Total expenses', draft.totalExpenses),
                  _row('Cash expenses', draft.cashExpenses),
                ]),
                const SizedBox(height: 16),
                _section('Cash reconciliation', [
                  TextFormField(
                    controller: _floatController,
                    enabled: !_busy,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'Opening float',
                      prefixText: '₱ ',
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                  const SizedBox(height: 12),
                  _row('Expected cash', expected, emphasize: true),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _countedController,
                    enabled: !_busy,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'Counted cash *',
                      prefixText: '₱ ',
                    ),
                    validator: (v) {
                      if (v == null || v.isEmpty) {
                        return 'Counted cash is required';
                      }
                      final parsed = double.tryParse(v);
                      if (parsed == null || parsed < 0) {
                        return 'Enter a valid amount';
                      }
                      return null;
                    },
                    onChanged: (_) => setState(() {}),
                  ),
                  if (variance != null) ...[
                    const SizedBox(height: 12),
                    _varianceRow(variance),
                  ],
                ]),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _notesController,
                  enabled: !_busy,
                  maxLines: 2,
                  decoration: const InputDecoration(labelText: 'Notes'),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _busy ? null : _submit,
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: _busy
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white),
                          )
                        : const Text('Close Day'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate() || _busy) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Close this day?'),
        content: const Text(
          'This saves the end-of-day closing. It cannot be edited afterward.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Close Day'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _busy = true);
    final notes = _notesController.text.trim();
    final saved =
        await ref.read(dailyClosingOperationsProvider.notifier).closeDay(
              date: _today,
              openingFloat: _float,
              countedCash: _counted ?? 0,
              notes: notes.isEmpty ? null : notes,
            );
    if (!mounted) return;
    setState(() => _busy = false);

    if (saved == null) {
      final err = ref.read(dailyClosingOperationsProvider).error;
      context.showErrorSnackBar('Could not close day: ${err ?? 'unknown'}');
      return;
    }
    context.showSuccessSnackBar('Day closed');
  }

  Widget _section(String title, List<Widget> children) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              title,
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: AppSpacing.md),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _row(String label, double value, {bool emphasize = false}) {
    final theme = Theme.of(context);
    final style = emphasize
        ? theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)
        : theme.textTheme.bodyMedium;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: theme.textTheme.bodyMedium),
          Text(
            '${AppConstants.currencySymbol}${value.toCurrencyWithoutSymbol()}',
            style: style,
          ),
        ],
      ),
    );
  }

  Widget _rowText(String label, String value) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: theme.textTheme.bodyMedium),
          Text(value, style: theme.textTheme.bodyMedium),
        ],
      ),
    );
  }

  Widget _varianceRow(double variance) {
    final theme = Theme.of(context);
    final color = variance == 0
        ? AppColors.successDark
        : (variance < 0 ? AppColors.error : AppColors.warningDark);
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text('Variance', style: theme.textTheme.bodyMedium),
        Text(
          '${variance >= 0 ? '+' : ''}${AppConstants.currencySymbol}${variance.toCurrencyWithoutSymbol()}',
          style: theme.textTheme.titleMedium
              ?.copyWith(color: color, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }
}

/// Read-only view of an already-saved closing.
class _ClosedView extends StatelessWidget {
  final DailyClosingEntity closing;

  const _ClosedView({required this.closing});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final variance = closing.variance;
    final varianceColor = variance == 0
        ? AppColors.successDark
        : (variance < 0 ? AppColors.error : AppColors.warningDark);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppRadius.md),
              border: Border.all(color: AppColors.successDark),
            ),
            child: Row(
              children: [
                const Icon(CupertinoIcons.checkmark_seal,
                    color: AppColors.successDark),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    'Closed by ${closing.closedByName} at '
                    '${TimeOfDay.fromDateTime(closing.closedAt).format(context)}',
                    style: theme.textTheme.bodyMedium,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _card(context, 'Sales', {
            'Gross sales': closing.grossSales,
            'Cash sales': closing.cashSales,
            'Non-cash sales': closing.nonCashSales,
            'Discounts': closing.totalDiscounts,
          }),
          const SizedBox(height: 16),
          _card(context, 'Expenses', {
            'Total expenses': closing.totalExpenses,
            'Cash expenses': closing.cashExpenses,
          }),
          const SizedBox(height: 16),
          _card(context, 'Cash reconciliation', {
            'Opening float': closing.openingFloat,
            'Expected cash': closing.expectedCash,
            'Counted cash': closing.countedCash,
          }),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Variance', style: theme.textTheme.titleMedium),
                Text(
                  '${variance >= 0 ? '+' : ''}${AppConstants.currencySymbol}${variance.toCurrencyWithoutSymbol()}',
                  style: theme.textTheme.titleMedium
                      ?.copyWith(color: varianceColor, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
          if (closing.notes != null) ...[
            const SizedBox(height: 16),
            Text('Notes: ${closing.notes}', style: theme.textTheme.bodyMedium),
          ],
        ],
      ),
    );
  }

  Widget _card(BuildContext context, String title, Map<String, double> rows) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(title,
                style: theme.textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(height: AppSpacing.md),
            ...rows.entries.map(
              (e) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(e.key, style: theme.textTheme.bodyMedium),
                    Text(
                      '${AppConstants.currencySymbol}${e.value.toCurrencyWithoutSymbol()}',
                      style: theme.textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 2: Verify it compiles**

Run: `flutter analyze lib/presentation/mobile/screens/reports/end_of_day_screen.dart`
Expected: No errors. (If `context.showErrorSnackBar` / `showSuccessSnackBar` / `goBackOr` / `pushNamed` extension names differ, confirm via `grep -rn "showSuccessSnackBar\|goBackOr" lib/core/extensions/navigation_extensions.dart` and adjust — they are used the same way in `expense_form_screen.dart`.)

- [ ] **Step 3: Commit**

```bash
git add lib/presentation/mobile/screens/reports/end_of_day_screen.dart
git commit -m "feat(eod): end-of-day review + close screen"
```

---

## Task 13: `DailyClosingHistoryScreen`

**Files:**
- Create: `lib/presentation/mobile/screens/reports/daily_closing_history_screen.dart`

- [ ] **Step 1: Create the screen**

Create `lib/presentation/mobile/screens/reports/daily_closing_history_screen.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:maki_mobile_pos/config/router/router.dart';
import 'package:maki_mobile_pos/core/constants/app_constants.dart';
import 'package:maki_mobile_pos/core/extensions/navigation_extensions.dart';
import 'package:maki_mobile_pos/core/extensions/num_extensions.dart';
import 'package:maki_mobile_pos/core/theme/theme.dart';
import 'package:maki_mobile_pos/domain/entities/daily_closing_entity.dart';
import 'package:maki_mobile_pos/presentation/providers/providers.dart';

/// List of past end-of-day closings, newest first. Tap a row to expand its
/// reconciliation detail.
class DailyClosingHistoryScreen extends ConsumerWidget {
  const DailyClosingHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final historyAsync = ref.watch(dailyClosingHistoryProvider);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(CupertinoIcons.back),
          onPressed: () => context.goBackOr(RoutePaths.endOfDay),
        ),
        title: const Text('Closing History'),
      ),
      body: historyAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (closings) {
          if (closings.isEmpty) {
            return const Center(child: Text('No closings yet.'));
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: closings.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, i) => _ClosingTile(closing: closings[i]),
          );
        },
      ),
    );
  }
}

class _ClosingTile extends StatelessWidget {
  final DailyClosingEntity closing;

  const _ClosingTile({required this.closing});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final variance = closing.variance;
    final color = variance == 0
        ? AppColors.successDark
        : (variance < 0 ? AppColors.error : AppColors.warningDark);
    final dateLabel = DateFormat('EEE, MMM d, y').format(closing.businessDate);
    final cashOnHand = closing.countedCash;

    return Card(
      margin: EdgeInsets.zero,
      child: ExpansionTile(
        shape: const Border(),
        title: Text(dateLabel,
            style: theme.textTheme.titleSmall
                ?.copyWith(fontWeight: FontWeight.w600)),
        subtitle: Text(
          'Cash on hand: ${AppConstants.currencySymbol}${cashOnHand.toCurrencyWithoutSymbol()}',
          style: theme.textTheme.bodySmall,
        ),
        trailing: Text(
          '${variance >= 0 ? '+' : ''}${AppConstants.currencySymbol}${variance.toCurrencyWithoutSymbol()}',
          style: theme.textTheme.bodyMedium
              ?.copyWith(color: color, fontWeight: FontWeight.bold),
        ),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        children: [
          _kv(context, 'Gross sales', closing.grossSales),
          _kv(context, 'Cash sales', closing.cashSales),
          _kv(context, 'Non-cash sales', closing.nonCashSales),
          _kv(context, 'Total expenses', closing.totalExpenses),
          _kv(context, 'Cash expenses', closing.cashExpenses),
          _kv(context, 'Opening float', closing.openingFloat),
          _kv(context, 'Expected cash', closing.expectedCash),
          _kv(context, 'Counted cash', closing.countedCash),
          const SizedBox(height: 4),
          Text('Closed by ${closing.closedByName}',
              style: theme.textTheme.bodySmall),
          if (closing.notes != null)
            Text('Notes: ${closing.notes}', style: theme.textTheme.bodySmall),
        ],
      ),
    );
  }

  Widget _kv(BuildContext context, String label, double value) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: theme.textTheme.bodySmall),
          Text(
            '${AppConstants.currencySymbol}${value.toCurrencyWithoutSymbol()}',
            style: theme.textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 2: Verify it compiles**

Run: `flutter analyze lib/presentation/mobile/screens/reports/daily_closing_history_screen.dart`
Expected: No errors.

- [ ] **Step 3: Commit**

```bash
git add lib/presentation/mobile/screens/reports/daily_closing_history_screen.dart
git commit -m "feat(eod): closing history screen"
```

---

## Task 14: Entry points (reports tile + dashboard quick action)

**Files:**
- Modify: `lib/presentation/mobile/screens/reports/sales_report_screen.dart`
- Modify: `lib/presentation/shared/widgets/dashboard/quick_actions.dart`
- Modify: `lib/presentation/mobile/screens/dashboard/dashboard_screen.dart`

- [ ] **Step 1: Add an End-of-Day tile to the Sales Report screen**

In `lib/presentation/mobile/screens/reports/sales_report_screen.dart`, add the navigation import if not present (it imports `router.dart` via `config/router/router.dart` at line 4 — `RoutePaths`/`RouteNames` are available; `context.pushNamed` comes from go_router which the screen already transitively uses, but add the import to be safe):

```dart
import 'package:go_router/go_router.dart';
```

In the `build` body `Column`, after the "Payment method breakdown" `Padding` block and before `const SizedBox(height: 32),`, add:

```dart
              // End-of-day closing entry
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Card(
                  margin: EdgeInsets.zero,
                  child: ListTile(
                    leading: const Icon(CupertinoIcons.money_dollar_circle),
                    title: const Text('End-of-Day Closing'),
                    subtitle: const Text('Reconcile the cash drawer'),
                    trailing: const Icon(CupertinoIcons.chevron_right),
                    onTap: () => context.pushNamed(RouteNames.endOfDay),
                  ),
                ),
              ),
```

- [ ] **Step 2: Add a `onCloseDay` action to `QuickActions`**

In `lib/presentation/shared/widgets/dashboard/quick_actions.dart`, add the field:

```dart
  final VoidCallback? onReports;
  final VoidCallback? onCloseDay;
```

Add to the constructor:

```dart
    this.onReports,
    this.onCloseDay,
```

Add the button after the Reports button (inside the `Row`'s children, after the `if (onReports != null)` block):

```dart
          if (onCloseDay != null)
            _QuickActionButton(
              icon: CupertinoIcons.money_dollar_circle,
              label: 'Close Day',
              onTap: onCloseDay!,
            ),
```

- [ ] **Step 3: Wire the dashboard permission getter + action**

In `lib/presentation/mobile/screens/dashboard/dashboard_screen.dart`, add a getter after `_canViewExpenses` (around line 96):

```dart
  bool get _canCloseDay =>
      RolePermissions.hasPermission(_role, Permission.closeDay);
```

In the `QuickActions(...)` call (around line 249), add after `onReports: ...`:

```dart
            onReports: _canViewReports
                ? () => context.go(RoutePaths.reports)
                : null,
            onCloseDay: _canCloseDay
                ? () => context.pushNamed(RouteNames.endOfDay)
                : null,
```

(`RouteNames` is available via the router import already used in the file; if `context.pushNamed` is not resolved, add `import 'package:go_router/go_router.dart';` — verify with `grep -n "go_router\|import.*router" lib/presentation/mobile/screens/dashboard/dashboard_screen.dart`.)

- [ ] **Step 4: Verify it compiles**

Run: `flutter analyze lib/presentation/mobile/screens/reports/sales_report_screen.dart lib/presentation/shared/widgets/dashboard/quick_actions.dart lib/presentation/mobile/screens/dashboard/dashboard_screen.dart`
Expected: No errors.

- [ ] **Step 5: Commit**

```bash
git add lib/presentation/mobile/screens/reports/sales_report_screen.dart lib/presentation/shared/widgets/dashboard/quick_actions.dart lib/presentation/mobile/screens/dashboard/dashboard_screen.dart
git commit -m "feat(eod): entry points from reports + dashboard"
```

---

## Task 15: Full verification

**Files:** none (verification only).

- [ ] **Step 1: Static analysis**

Run: `flutter analyze`
Expected: No new errors introduced by this feature. (Pre-existing warnings elsewhere are acceptable; nothing in `lib/...daily_closing...`, `end_of_day_screen.dart`, expense files, routing, or permissions should error.)

- [ ] **Step 2: Run the full test suite**

Run: `flutter test`
Expected: All tests pass, including the new tests:
- `test/data/models/expense_model_paid_via_test.dart`
- `test/domain/entities/daily_closing_draft_test.dart`
- `test/data/models/daily_closing_model_test.dart`
- `test/core/constants/daily_closing_permissions_test.dart`
- `test/domain/usecases/daily_closing/get_daily_closing_summary_usecase_test.dart`
- `test/domain/usecases/daily_closing/close_day_usecase_test.dart`

- [ ] **Step 3: Manual smoke test in the running app**

Run the app (`flutter run`) and, signed in as each of admin and cashier:
1. Dashboard → **Close Day** quick action opens the End-of-Day screen.
2. Today's gross/cash/non-cash sales and expenses match the data; create a test expense with `paidVia = GCash` and confirm it appears in **Total expenses** but not **Cash expenses**.
3. Enter an opening float and a counted cash value → expected cash + variance update live, variance colored correctly (green/red/amber).
4. **Close Day** → confirm → success; the screen now shows the read-only "Closed by … at …" view.
5. Reopen the screen → it still shows the closed view (one closing per day enforced).
6. History icon → the closing appears in the list; expanding shows the detail.
7. Reports screen → **End-of-Day Closing** tile also opens the screen.

- [ ] **Step 4: Deploy Firestore rules (only when ready to test against live Firestore)**

Run: `firebase deploy --only firestore:rules`
Expected: rules deploy successfully. (Confirm with the user before deploying — this affects the shared backend.)

- [ ] **Step 5: Final commit (if any verification fixes were needed)**

```bash
git add -A
git commit -m "test(eod): verification fixes"
```

---

## Self-Review notes

- **Spec coverage:** cash-on-hand formula (Task 3), opening float manual entry (Task 12), `paidVia` field + cash-only expenses (Tasks 1-2, 3), saved daily record + once-per-day (Tasks 4-5, 8), history (Tasks 5, 13), access for cashier/staff/admin (Task 6), keep petty cash untouched (no petty cash files modified), Firestore rules (Task 10), use-case tests (Tasks 7-8). All covered.
- **PaymentMethod correction:** the spec mentioned "card"; the enum has only cash/gcash/maya. Non-cash = gcash + maya throughout (Task 3). `nonCashSales` is computed as the sum of non-cash payment-method buckets (net cash received per method), which is the accounting-correct drawer figure — a refinement over the spec's "gross − cash".
- **Type consistency:** `DailyClosingDraft.fromData`, `expectedCashFor`, `varianceFor`, `DailyClosingEntity` field names, `DailyClosingRepositoryImpl.docIdFor`, provider names, and permission names are used identically across tasks.
- **Known verification point:** Task 9 depends on a public `saleRepositoryProvider` in `sale_provider.dart`; the task includes a NOTE + grep to confirm or add it.
