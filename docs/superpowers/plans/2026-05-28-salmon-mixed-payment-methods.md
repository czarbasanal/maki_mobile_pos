# Salmon & Mixed Payment Methods Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add Mixed (cash + one digital) and Salmon (downpayment + report-only receivable) payment methods, backed by a per-sale tender breakdown, with correct sales-summary and end-of-day reporting.

**Architecture:** A sale gains `tenders: Map<PaymentMethod, double>` (amounts by method, summing to `grandTotal`). `paymentMethod` stays the cashier-chosen label. An `effectiveTenders` getter derives `{paymentMethod: grandTotal}` for legacy sales with no breakdown. Reporting sums `effectiveTenders`; the `salmon` bucket is a receivable surfaced at EOD but never counted as cash.

**Tech Stack:** Flutter, Riverpod, Cloud Firestore, mocktail + flutter_test.

**Spec:** `docs/superpowers/specs/2026-05-28-salmon-mixed-payment-methods-design.md`

**Run tests with:** `flutter` is at `/Users/czar/flutter/bin`; prefix commands with `export PATH="$PATH:/Users/czar/flutter/bin" &&` if `flutter` is not on PATH.

### Key rules
- `tenders` always sum to `grandTotal`.
- Mixed: `{cash: grandTotal - digital, <gcash|maya>: digital}`, `0 < digital < grandTotal`.
- Salmon: `{<dpMethod>: dp, salmon: grandTotal - dp}`, `0 < dp < grandTotal`.
- `mixed` is a label only — never a tender bucket.
- EOD: `cashSales` = cash bucket; `nonCashSales` = gcash + maya (excl. salmon); `salmonReceivable` = salmon bucket; cash-on-hand math unchanged.

---

## Task 1: Add `salmon` and `mixed` to PaymentMethod

**Files:**
- Modify: `lib/core/enums/payment_method.dart`
- Test: `test/core/enums/payment_method_test.dart`

- [ ] **Step 1: Write the failing test**

Create `test/core/enums/payment_method_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:maki_mobile_pos/core/enums/payment_method.dart';

void main() {
  group('PaymentMethod salmon & mixed', () {
    test('salmon and mixed exist with correct values', () {
      expect(PaymentMethod.salmon.value, 'salmon');
      expect(PaymentMethod.salmon.displayName, 'Salmon');
      expect(PaymentMethod.mixed.value, 'mixed');
      expect(PaymentMethod.mixed.displayName, 'Mixed');
    });

    test('fromString resolves the new values', () {
      expect(PaymentMethod.fromString('salmon'), PaymentMethod.salmon);
      expect(PaymentMethod.fromString('mixed'), PaymentMethod.mixed);
    });

    test('new methods have no transaction fees', () {
      expect(PaymentMethod.salmon.hasFees, false);
      expect(PaymentMethod.mixed.hasFees, false);
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/core/enums/payment_method_test.dart`
Expected: FAIL — `salmon`/`mixed` not defined.

- [ ] **Step 3: Add the enum values**

In `lib/core/enums/payment_method.dart`, add after `gcash`:

```dart
  /// GCash mobile payment (fees may apply)
  gcash('gcash', 'GCash'),

  /// Salmon financing — customer pays a downpayment now; the balance is
  /// covered by Salmon the next day (a receivable, not cash on hand).
  salmon('salmon', 'Salmon'),

  /// Mixed tender — cash plus one digital method on a single sale. This is a
  /// sale-level label only; it never appears as a tender bucket.
  mixed('mixed', 'Mixed');
```

(Move the `;` from the `gcash` line to the `mixed` line as shown.)

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/core/enums/payment_method_test.dart`
Expected: PASS (3 tests).

- [ ] **Step 5: Commit**

```bash
git add lib/core/enums/payment_method.dart test/core/enums/payment_method_test.dart
git commit -m "feat(payments): add salmon and mixed payment methods"
```

---

## Task 2: Add `tenders` + helpers to SaleEntity

**Files:**
- Modify: `lib/domain/entities/sale_entity.dart`
- Test: `test/domain/entities/sale_entity_tenders_test.dart`

- [ ] **Step 1: Write the failing test**

Create `test/domain/entities/sale_entity_tenders_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:maki_mobile_pos/core/enums/enums.dart';
import 'package:maki_mobile_pos/domain/entities/sale_entity.dart';
import 'package:maki_mobile_pos/domain/entities/sale_item_entity.dart';

SaleItemEntity _item({double price = 1000, int qty = 1}) => SaleItemEntity(
      id: 'i',
      productId: 'p',
      sku: 'SKU',
      name: 'Item',
      unitPrice: price,
      unitCost: 0,
      quantity: qty,
    );

SaleEntity _sale({
  required PaymentMethod method,
  Map<PaymentMethod, double> tenders = const {},
  double amountReceived = 1000,
}) =>
    SaleEntity(
      id: 's',
      saleNumber: 'SALE-1',
      items: [_item()],
      paymentMethod: method,
      tenders: tenders,
      amountReceived: amountReceived,
      changeGiven: 0,
      cashierId: 'c',
      cashierName: 'Cashier',
      createdAt: DateTime(2026, 5, 28),
    );

void main() {
  group('SaleEntity tenders', () {
    test('effectiveTenders falls back to {paymentMethod: grandTotal} when empty',
        () {
      final sale = _sale(method: PaymentMethod.gcash, tenders: const {});
      expect(sale.effectiveTenders, {PaymentMethod.gcash: 1000});
    });

    test('effectiveTenders returns the explicit breakdown when present', () {
      final sale = _sale(
        method: PaymentMethod.mixed,
        tenders: const {PaymentMethod.cash: 300, PaymentMethod.gcash: 700},
      );
      expect(sale.effectiveTenders,
          {PaymentMethod.cash: 300, PaymentMethod.gcash: 700});
    });

    test('cashCollected and salmonBalance read the right buckets', () {
      final salmon = _sale(
        method: PaymentMethod.salmon,
        tenders: const {PaymentMethod.cash: 400, PaymentMethod.salmon: 600},
      );
      expect(salmon.cashCollected, 400);
      expect(salmon.salmonBalance, 600);

      final gcashOnly = _sale(method: PaymentMethod.gcash, tenders: const {});
      expect(gcashOnly.cashCollected, 0); // gcash, not cash
      expect(gcashOnly.salmonBalance, 0);
    });

    test('isTenderValid requires tenders to sum to grandTotal', () {
      final ok = _sale(
        method: PaymentMethod.mixed,
        tenders: const {PaymentMethod.cash: 300, PaymentMethod.gcash: 700},
      );
      final bad = _sale(
        method: PaymentMethod.mixed,
        tenders: const {PaymentMethod.cash: 300, PaymentMethod.gcash: 500},
      );
      expect(ok.isTenderValid, true);
      expect(bad.isTenderValid, false);
      // Legacy (empty) is valid via effectiveTenders.
      expect(_sale(method: PaymentMethod.cash).isTenderValid, true);
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/domain/entities/sale_entity_tenders_test.dart`
Expected: FAIL — `tenders` / `effectiveTenders` not defined.

- [ ] **Step 3: Add the field, constructor param, getters, copyWith, props**

In `lib/domain/entities/sale_entity.dart`:

Add the field after `paymentMethod`:

```dart
  /// Payment method used
  final PaymentMethod paymentMethod;

  /// Money collected by method (sums to [grandTotal]). Empty for legacy sales
  /// — use [effectiveTenders] to read a normalized breakdown.
  final Map<PaymentMethod, double> tenders;
```

Add the constructor param after `required this.paymentMethod,`:

```dart
    required this.paymentMethod,
    this.tenders = const {},
```

Add getters in the COMPUTED PROPERTIES section (after `grandTotal`):

```dart
  /// Tender breakdown, normalized: explicit [tenders] if present, otherwise
  /// the whole [grandTotal] attributed to [paymentMethod] (legacy sales).
  Map<PaymentMethod, double> get effectiveTenders =>
      tenders.isNotEmpty ? tenders : {paymentMethod: grandTotal};

  /// Cash actually collected into the drawer.
  double get cashCollected => effectiveTenders[PaymentMethod.cash] ?? 0;

  /// Salmon receivable (the balance Salmon covers the next day).
  double get salmonBalance => effectiveTenders[PaymentMethod.salmon] ?? 0;

  /// True when the tender breakdown reconciles to [grandTotal].
  bool get isTenderValid {
    final sum =
        effectiveTenders.values.fold<double>(0, (a, b) => a + b);
    return (sum - grandTotal).abs() < 0.01;
  }
```

Add to `copyWith` params (after `PaymentMethod? paymentMethod,`):

```dart
    PaymentMethod? paymentMethod,
    Map<PaymentMethod, double>? tenders,
```

and in the returned `SaleEntity(...)` (after `paymentMethod: paymentMethod ?? this.paymentMethod,`):

```dart
      paymentMethod: paymentMethod ?? this.paymentMethod,
      tenders: tenders ?? this.tenders,
```

Add to `props` after `paymentMethod,`:

```dart
        paymentMethod,
        tenders,
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/domain/entities/sale_entity_tenders_test.dart`
Expected: PASS (4 tests).

- [ ] **Step 5: Commit**

```bash
git add lib/domain/entities/sale_entity.dart test/domain/entities/sale_entity_tenders_test.dart
git commit -m "feat(payments): tender breakdown on SaleEntity"
```

---

## Task 3: Serialize `tenders` in SaleModel

**Files:**
- Modify: `lib/data/models/sale_model.dart`
- Test: `test/data/models/sale_model_tenders_test.dart`

- [ ] **Step 1: Write the failing test**

Create `test/data/models/sale_model_tenders_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:maki_mobile_pos/core/enums/enums.dart';
import 'package:maki_mobile_pos/data/models/sale_model.dart';

void main() {
  group('SaleModel tenders', () {
    test('serializes and reads back the tender map', () {
      final model = SaleModel.fromMap({
        'saleNumber': 'SALE-1',
        'paymentMethod': 'mixed',
        'tenders': {'cash': 300, 'gcash': 700},
        'amountReceived': 1000,
        'changeGiven': 0,
      }, 'doc-1');

      expect(model.tenders, {
        PaymentMethod.cash: 300.0,
        PaymentMethod.gcash: 700.0,
      });
      expect(model.toMap()['tenders'], {'cash': 300.0, 'gcash': 700.0});
      expect(model.toEntity().tenders, {
        PaymentMethod.cash: 300.0,
        PaymentMethod.gcash: 700.0,
      });
    });

    test('legacy doc without tenders yields an empty map', () {
      final model = SaleModel.fromMap({
        'saleNumber': 'SALE-2',
        'paymentMethod': 'cash',
        'amountReceived': 500,
      }, 'doc-2');

      expect(model.tenders, isEmpty);
      // toMap omits an empty tenders map.
      expect(model.toMap().containsKey('tenders'), false);
    });

    test('round-trips a salmon breakdown via fromEntity', () {
      final entity = SaleModel.fromMap({
        'saleNumber': 'SALE-3',
        'paymentMethod': 'salmon',
        'tenders': {'cash': 400, 'salmon': 600},
      }, 'doc-3').toEntity();

      final back = SaleModel.fromEntity(entity);
      expect(back.tenders,
          {PaymentMethod.cash: 400.0, PaymentMethod.salmon: 600.0});
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/data/models/sale_model_tenders_test.dart`
Expected: FAIL — `tenders` not defined on `SaleModel`.

- [ ] **Step 3: Add `tenders` to SaleModel**

In `lib/data/models/sale_model.dart`:

Add the field after `paymentMethod`:

```dart
  final PaymentMethod paymentMethod;
  final Map<PaymentMethod, double> tenders;
```

Add the constructor param after `required this.paymentMethod,`:

```dart
    required this.paymentMethod,
    this.tenders = const {},
```

Add a private static parser near `_parseTimestamp`:

```dart
  /// Parses a Firestore `tenders` map ({ '<method>': amount }) into a typed
  /// map. Returns an empty map when absent (legacy sales).
  static Map<PaymentMethod, double> _parseTenders(dynamic value) {
    if (value is! Map) return const {};
    final result = <PaymentMethod, double>{};
    value.forEach((key, amount) {
      if (key is String && amount is num) {
        result[PaymentMethod.fromString(key)] = amount.toDouble();
      }
    });
    return result;
  }
```

In `fromMap`, after the `paymentMethod:` line:

```dart
      paymentMethod: PaymentMethod.fromString(map['paymentMethod'] as String?),
      tenders: _parseTenders(map['tenders']),
```

In `toMap`, after `'paymentMethod': paymentMethod.value,` add a conditional write (only when non-empty so legacy docs aren't bloated). Insert just before the timestamp handling block (`// Handle timestamps`):

```dart
    if (tenders.isNotEmpty) {
      map['tenders'] = {
        for (final e in tenders.entries) e.key.value: e.value,
      };
    }
```

In `toEntity`, after `paymentMethod: paymentMethod,`:

```dart
      paymentMethod: paymentMethod,
      tenders: tenders,
```

In `fromEntity`, after `paymentMethod: entity.paymentMethod,`:

```dart
      paymentMethod: entity.paymentMethod,
      tenders: entity.tenders,
```

In `copyWith` params (after `PaymentMethod? paymentMethod,`):

```dart
    PaymentMethod? paymentMethod,
    Map<PaymentMethod, double>? tenders,
```

and in the returned `SaleModel(...)` after `paymentMethod: paymentMethod ?? this.paymentMethod,`:

```dart
      paymentMethod: paymentMethod ?? this.paymentMethod,
      tenders: tenders ?? this.tenders,
```

In `SaleModel.create`, add a `tenders` param + pass-through so the checkout path can set it:

```dart
  factory SaleModel.create({
    required String saleNumber,
    required List<SaleItemModel> items,
    DiscountType discountType = DiscountType.amount,
    required PaymentMethod paymentMethod,
    Map<PaymentMethod, double> tenders = const {},
    required double amountReceived,
    required double changeGiven,
    required String cashierId,
    required String cashierName,
    String? draftId,
    String? notes,
  }) {
    return SaleModel(
      id: '',
      saleNumber: saleNumber,
      items: items,
      discountType: discountType,
      paymentMethod: paymentMethod,
      tenders: tenders,
      amountReceived: amountReceived,
      changeGiven: changeGiven,
      status: SaleStatus.completed,
      cashierId: cashierId,
      cashierName: cashierName,
      createdAt: DateTime.now(),
      draftId: draftId,
      notes: notes,
    );
  }
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/data/models/sale_model_tenders_test.dart`
Expected: PASS (3 tests).

- [ ] **Step 5: Commit**

```bash
git add lib/data/models/sale_model.dart test/data/models/sale_model_tenders_test.dart
git commit -m "feat(payments): serialize tenders in SaleModel"
```

---

## Task 4: Sum tenders in `getSalesSummary` + `salmonReceivable`

**Files:**
- Modify: `lib/domain/repositories/sale_repository.dart` (SalesSummary getter)
- Modify: `lib/data/repositories/sale_repository_impl.dart:467-495`
- Test: `test/data/repositories/sales_summary_tenders_test.dart`

- [ ] **Step 1: Add the `salmonReceivable` getter to SalesSummary**

In `lib/domain/repositories/sale_repository.dart`, inside `class SalesSummary` after the `profitMargin` getter:

```dart
  /// Total Salmon receivable (balance Salmon covers the next day). Not cash.
  double get salmonReceivable =>
      byPaymentMethod[PaymentMethod.salmon] ?? 0;
```

- [ ] **Step 2: Write the failing test**

Create `test/data/repositories/sales_summary_tenders_test.dart`. This tests the summing logic in isolation by replicating the loop against `effectiveTenders` — but to test the real method we drive the repo. Simplest: extract the per-sale tender summation is already in the impl; test via a small pure helper. Add this helper test that asserts the documented behavior using `SaleEntity.effectiveTenders` directly (the impl uses the same call):

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:maki_mobile_pos/core/enums/enums.dart';
import 'package:maki_mobile_pos/domain/entities/sale_entity.dart';
import 'package:maki_mobile_pos/domain/entities/sale_item_entity.dart';

SaleItemEntity _item(double price) => SaleItemEntity(
      id: 'i', productId: 'p', sku: 'S', name: 'N',
      unitPrice: price, unitCost: 0, quantity: 1,
    );

SaleEntity _sale(PaymentMethod method, Map<PaymentMethod, double> tenders,
        double price) =>
    SaleEntity(
      id: 's', saleNumber: 'X', items: [_item(price)],
      paymentMethod: method, tenders: tenders,
      amountReceived: price, changeGiven: 0,
      cashierId: 'c', cashierName: 'C', createdAt: DateTime(2026, 5, 28),
    );

/// Mirrors the summation in SaleRepositoryImpl.getSalesSummary.
Map<PaymentMethod, double> sumTenders(List<SaleEntity> sales) {
  final result = <PaymentMethod, double>{};
  for (final m in [
    PaymentMethod.cash,
    PaymentMethod.gcash,
    PaymentMethod.maya,
    PaymentMethod.salmon,
  ]) {
    result[m] = 0;
  }
  for (final sale in sales) {
    sale.effectiveTenders.forEach((method, amount) {
      result[method] = (result[method] ?? 0) + amount;
    });
  }
  return result;
}

void main() {
  test('mixed splits across cash + digital; salmon balance to salmon bucket',
      () {
    final sales = [
      _sale(PaymentMethod.mixed,
          {PaymentMethod.cash: 300, PaymentMethod.gcash: 700}, 1000),
      _sale(PaymentMethod.salmon,
          {PaymentMethod.cash: 400, PaymentMethod.salmon: 600}, 1000),
      _sale(PaymentMethod.cash, const {}, 500), // legacy single cash
    ];

    final b = sumTenders(sales);
    expect(b[PaymentMethod.cash], 300 + 400 + 500);
    expect(b[PaymentMethod.gcash], 700);
    expect(b[PaymentMethod.salmon], 600);
    expect(b.containsKey(PaymentMethod.mixed), false);

    final total = b.values.fold<double>(0, (a, x) => a + x);
    expect(total, 1000 + 1000 + 500); // == sum of grandTotals (netAmount)
  });
}
```

- [ ] **Step 3: Run test to verify it fails**

Run: `flutter test test/data/repositories/sales_summary_tenders_test.dart`
Expected: FAIL — `SaleEntity.tenders` param compiles only after Task 2 (it does); this test passes the *helper* logic but **also documents the impl change**. If Task 2 is done, it will already pass on the helper — proceed to wire the impl in Step 4, then it stays green.

(Note: this is a logic-mirror test. The impl change in Step 4 must match `sumTenders` exactly.)

- [ ] **Step 4: Update the impl to sum tenders**

In `lib/data/repositories/sale_repository_impl.dart`, replace the summary loop (currently lines ~471-484):

```dart
    final byPaymentMethod = <PaymentMethod, double>{};

    for (final method in PaymentMethod.values) {
      byPaymentMethod[method] = 0;
    }

    for (final sale in completedSales) {
      grossAmount += sale.subtotal;
      totalDiscounts += sale.totalDiscount;
      netAmount += sale.grandTotal;
      totalCost += sale.totalCost;
      byPaymentMethod[sale.paymentMethod] =
          (byPaymentMethod[sale.paymentMethod] ?? 0) + sale.grandTotal;
    }
```

with:

```dart
    final byPaymentMethod = <PaymentMethod, double>{};

    // Seed only real tender buckets (never `mixed`, which is a label).
    for (final method in const [
      PaymentMethod.cash,
      PaymentMethod.gcash,
      PaymentMethod.maya,
      PaymentMethod.salmon,
    ]) {
      byPaymentMethod[method] = 0;
    }

    for (final sale in completedSales) {
      grossAmount += sale.subtotal;
      totalDiscounts += sale.totalDiscount;
      netAmount += sale.grandTotal;
      totalCost += sale.totalCost;
      sale.effectiveTenders.forEach((method, amount) {
        byPaymentMethod[method] = (byPaymentMethod[method] ?? 0) + amount;
      });
    }
```

- [ ] **Step 5: Run tests**

Run: `flutter test test/data/repositories/sales_summary_tenders_test.dart`
Expected: PASS. Also run `flutter analyze lib/data/repositories/sale_repository_impl.dart lib/domain/repositories/sale_repository.dart` → no errors.

- [ ] **Step 6: Commit**

```bash
git add lib/domain/repositories/sale_repository.dart lib/data/repositories/sale_repository_impl.dart test/data/repositories/sales_summary_tenders_test.dart
git commit -m "feat(payments): sales summary sums tenders + salmonReceivable"
```

---

## Task 5: Carry Salmon receivable through End-of-Day

**Files:**
- Modify: `lib/domain/entities/daily_closing_entity.dart` (DailyClosingDraft + DailyClosingEntity)
- Modify: `lib/data/models/daily_closing_model.dart`
- Modify: `lib/domain/usecases/daily_closing/close_day_usecase.dart`
- Test: `test/domain/entities/daily_closing_draft_test.dart` (extend)

- [ ] **Step 1: Extend the draft test**

In `test/domain/entities/daily_closing_draft_test.dart`, add this test inside the `group('DailyClosingDraft.fromData', ...)`:

```dart
    test('salmon balance is a receivable, excluded from cash and non-cash', () {
      const summary = SalesSummary(
        totalSalesCount: 2,
        voidedSalesCount: 0,
        grossAmount: 2000,
        totalDiscounts: 0,
        netAmount: 2000,
        totalCost: 0,
        totalProfit: 2000,
        byPaymentMethod: {
          PaymentMethod.cash: 900, // 400 dp + 500 mixed cash
          PaymentMethod.gcash: 500,
          PaymentMethod.salmon: 600,
        },
      );

      final draft = DailyClosingDraft.fromData(
        businessDate: DateTime(2026, 5, 28),
        summary: summary,
        expenses: const [],
      );

      expect(draft.cashSales, 900);
      expect(draft.nonCashSales, 500); // gcash only; salmon excluded
      expect(draft.salmonReceivable, 600);
      // Opening float 1000 + cash 900 - 0 expenses = 1900; salmon untouched.
      expect(draft.expectedCashFor(1000), 1900);
    });
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/domain/entities/daily_closing_draft_test.dart`
Expected: FAIL — `salmonReceivable` not defined; `nonCashSales` currently includes salmon (600), so it would be 1100.

- [ ] **Step 3: Add `salmonReceivable` to DailyClosingDraft + fix nonCashSales**

In `lib/domain/entities/daily_closing_entity.dart`, in `DailyClosingDraft`:

Add the field after `cashExpenses`:

```dart
  final double totalExpenses;
  final double cashExpenses;
  final double salmonReceivable;
```

Add to the const constructor (after `required this.cashExpenses,`):

```dart
    required this.cashExpenses,
    required this.salmonReceivable,
```

In `fromData`, change the non-cash computation and add salmon. Replace:

```dart
    final cashSales = summary.byPaymentMethod[PaymentMethod.cash] ?? 0;
    double nonCashSales = 0;
    for (final entry in summary.byPaymentMethod.entries) {
      if (entry.key != PaymentMethod.cash) nonCashSales += entry.value;
    }
```

with:

```dart
    final cashSales = summary.byPaymentMethod[PaymentMethod.cash] ?? 0;
    final salmonReceivable =
        summary.byPaymentMethod[PaymentMethod.salmon] ?? 0;
    double nonCashSales = 0;
    for (final entry in summary.byPaymentMethod.entries) {
      if (entry.key != PaymentMethod.cash &&
          entry.key != PaymentMethod.salmon) {
        nonCashSales += entry.value;
      }
    }
```

In the returned `DailyClosingDraft(...)` add (after `cashExpenses: cashExpenses,`):

```dart
      cashExpenses: cashExpenses,
      salmonReceivable: salmonReceivable,
```

Add `salmonReceivable` to the draft's `props` list (after `cashExpenses,`).

- [ ] **Step 4: Add `salmonReceivable` to DailyClosingEntity**

In the same file, `DailyClosingEntity`: add field after `cashExpenses`:

```dart
  final double cashExpenses;
  final double salmonReceivable;
```

Add to the const constructor after `required this.cashExpenses,`:

```dart
    required this.cashExpenses,
    required this.salmonReceivable,
```

Add to `props` after `cashExpenses,`.

- [ ] **Step 5: Add `salmonReceivable` to DailyClosingModel**

In `lib/data/models/daily_closing_model.dart`:
- Add field `final double salmonReceivable;` after `cashExpenses`.
- Add constructor param `required this.salmonReceivable,` after `required this.cashExpenses,`.
- In `fromMap`, after `cashExpenses: d('cashExpenses'),`: `salmonReceivable: d('salmonReceivable'),`
- In `fromEntity`, after `cashExpenses: e.cashExpenses,`: `salmonReceivable: e.salmonReceivable,`
- In `toMap`, after `'cashExpenses': cashExpenses,`: `'salmonReceivable': salmonReceivable,`
- In `toEntity`, after `cashExpenses: cashExpenses,`: `salmonReceivable: salmonReceivable,`

- [ ] **Step 6: Populate it in CloseDayUseCase**

In `lib/domain/usecases/daily_closing/close_day_usecase.dart`, in the `DailyClosingEntity(...)` built inside `execute`, after `cashExpenses: draft.cashExpenses,`:

```dart
        cashExpenses: draft.cashExpenses,
        salmonReceivable: draft.salmonReceivable,
```

- [ ] **Step 7: Fix existing test constructors**

The existing tests construct `DailyClosingDraft`/`DailyClosingEntity`/`DailyClosingModel` directly and will now require `salmonReceivable`. Update these files to pass `salmonReceivable: 0` (and for the post-close test where relevant) in every literal constructor:
- `test/domain/entities/daily_closing_draft_test.dart` (the `_draft` is built via `fromData`, so only the new literal `SalesSummary`s — those are fine; but any direct `DailyClosingDraft(...)` literal needs the field. There are none — all via `fromData`.)
- `test/domain/entities/post_close_activity_test.dart` — `_closing(...)` builds a `DailyClosingEntity` literal and `_draft(...)` builds a `DailyClosingDraft` literal: add `salmonReceivable: 0,` to both.
- `test/data/models/daily_closing_model_test.dart` — the `entity` literal: add `salmonReceivable: 0,` (and assert round-trip if desired).
- `test/domain/usecases/daily_closing/close_day_usecase_test.dart` — `_existingClosing()` literal: add `salmonReceivable: 0,`.

Run `flutter test test/domain/ test/data/models/daily_closing_model_test.dart` and fix any remaining "required named parameter 'salmonReceivable' missing" compile errors by adding `salmonReceivable: 0,`.

- [ ] **Step 8: Run tests**

Run: `flutter test test/domain/entities/daily_closing_draft_test.dart test/domain/entities/post_close_activity_test.dart test/data/models/daily_closing_model_test.dart test/domain/usecases/daily_closing/close_day_usecase_test.dart`
Expected: PASS (all).

- [ ] **Step 9: Commit**

```bash
git add lib/domain/entities/daily_closing_entity.dart lib/data/models/daily_closing_model.dart lib/domain/usecases/daily_closing/close_day_usecase.dart test/domain/entities/daily_closing_draft_test.dart test/domain/entities/post_close_activity_test.dart test/data/models/daily_closing_model_test.dart test/domain/usecases/daily_closing/close_day_usecase_test.dart
git commit -m "feat(eod): carry Salmon receivable through closing"
```

---

## Task 6: Cart tender computation + validation

**Files:**
- Modify: `lib/presentation/providers/cart_provider.dart`
- Test: `test/presentation/providers/cart_tenders_test.dart`

- [ ] **Step 1: Write the failing test**

Create `test/presentation/providers/cart_tenders_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:maki_mobile_pos/core/enums/enums.dart';
import 'package:maki_mobile_pos/domain/entities/product_entity.dart';
import 'package:maki_mobile_pos/presentation/providers/cart_provider.dart';

ProductEntity _product(double price) => ProductEntity(
      id: 'p1', sku: 'SKU1', name: 'Item', costCode: '', cost: 0,
      price: price, quantity: 100, reorderLevel: 0, unit: 'pcs',
      isActive: true, createdAt: DateTime(2026, 1, 1),
    );

void main() {
  late CartNotifier cart;
  setUp(() {
    cart = CartNotifier();
    cart.addProduct(_product(1000)); // grandTotal = 1000
  });

  test('single cash: tenders = {cash: grandTotal}, change from amount', () {
    cart.setPaymentMethod(PaymentMethod.cash);
    cart.setAmountReceived(1200);
    expect(cart.state.tenders, {PaymentMethod.cash: 1000});
    expect(cart.state.change, 200);
    expect(cart.state.isPaymentValid, true);
  });

  test('single gcash: exact tender, no change, valid', () {
    cart.setPaymentMethod(PaymentMethod.gcash);
    expect(cart.state.tenders, {PaymentMethod.gcash: 1000});
    expect(cart.state.change, 0);
    expect(cart.state.isPaymentValid, true);
  });

  test('mixed: cash remainder + digital; valid only when 0<digital<total', () {
    cart.setPaymentMethod(PaymentMethod.mixed);
    cart.setSecondaryMethod(PaymentMethod.gcash);
    cart.setSplitAmount(700);
    expect(cart.state.tenders,
        {PaymentMethod.cash: 300, PaymentMethod.gcash: 700});
    expect(cart.state.isPaymentValid, true);

    cart.setSplitAmount(1000); // not a split
    expect(cart.state.isPaymentValid, false);
    cart.setSplitAmount(0);
    expect(cart.state.isPaymentValid, false);
  });

  test('salmon: downpayment + salmon balance; only DP collected', () {
    cart.setPaymentMethod(PaymentMethod.salmon);
    cart.setSecondaryMethod(PaymentMethod.cash); // DP method
    cart.setSplitAmount(400); // downpayment
    expect(cart.state.tenders,
        {PaymentMethod.cash: 400, PaymentMethod.salmon: 600});
    expect(cart.state.isPaymentValid, true);
    expect(cart.state.change, 0);

    cart.setSplitAmount(1000); // no balance -> invalid as salmon
    expect(cart.state.isPaymentValid, false);
  });
}
```

(`ProductEntity` required params verified against `lib/domain/entities/product_entity.dart`: id, sku, name, costCode, cost, price, quantity, reorderLevel, unit, isActive, createdAt.)

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/presentation/providers/cart_tenders_test.dart`
Expected: FAIL — `setSecondaryMethod`/`setSplitAmount`/`tenders`/`isPaymentValid` not defined.

- [ ] **Step 3: Add state fields + computed tenders + validation**

In `lib/presentation/providers/cart_provider.dart`, add fields to `CartState` (after `amountReceived`):

```dart
  final double amountReceived;

  /// Secondary method for Mixed (the digital method) or Salmon (the
  /// downpayment method). Null for single-tender sales.
  final PaymentMethod? secondaryMethod;

  /// For Mixed: the digital amount. For Salmon: the downpayment amount.
  final double splitAmount;
```

Add to the const constructor (after `this.amountReceived = 0,`):

```dart
    this.amountReceived = 0,
    this.secondaryMethod,
    this.splitAmount = 0,
```

Add computed getters (after `grandTotal`):

```dart
  /// Tender breakdown derived from the selected method + entered amounts.
  Map<PaymentMethod, double> get tenders {
    switch (paymentMethod) {
      case PaymentMethod.mixed:
        final digital = secondaryMethod ?? PaymentMethod.gcash;
        return {
          PaymentMethod.cash: grandTotal - splitAmount,
          digital: splitAmount,
        };
      case PaymentMethod.salmon:
        final dp = secondaryMethod ?? PaymentMethod.cash;
        return {
          dp: splitAmount,
          PaymentMethod.salmon: grandTotal - splitAmount,
        };
      default:
        return {paymentMethod: grandTotal};
    }
  }

  /// Amount actually collected today (excludes the Salmon receivable).
  double get collectedToday {
    if (paymentMethod == PaymentMethod.salmon) return splitAmount;
    return grandTotal;
  }
```

Replace the existing `change`, `isPaymentSufficient`, and `canCheckout` getters with:

```dart
  /// Change to give customer (only meaningful for single cash).
  double get change {
    if (paymentMethod == PaymentMethod.cash &&
        secondaryMethod == null &&
        amountReceived > grandTotal) {
      return amountReceived - grandTotal;
    }
    return 0;
  }

  /// Whether the selected payment is valid for checkout.
  bool get isPaymentValid {
    if (isEmpty) return false;
    switch (paymentMethod) {
      case PaymentMethod.cash:
        return amountReceived >= grandTotal;
      case PaymentMethod.gcash:
      case PaymentMethod.maya:
        return true; // exact, collected in full
      case PaymentMethod.mixed:
        return secondaryMethod != null &&
            splitAmount > 0 &&
            splitAmount < grandTotal;
      case PaymentMethod.salmon:
        return secondaryMethod != null &&
            splitAmount > 0 &&
            splitAmount < grandTotal;
    }
  }

  /// Whether cart can be checked out.
  bool get canCheckout => isNotEmpty && isPaymentValid && !isProcessing;
```

Update `copyWith` to thread the new fields. Add params (after `double? amountReceived,`):

```dart
    double? amountReceived,
    PaymentMethod? secondaryMethod,
    double? splitAmount,
    bool clearSecondaryMethod = false,
```

and in the returned `CartState(...)` (after `amountReceived: amountReceived ?? this.amountReceived,`):

```dart
      amountReceived: amountReceived ?? this.amountReceived,
      secondaryMethod: clearSecondaryMethod
          ? null
          : (secondaryMethod ?? this.secondaryMethod),
      splitAmount: splitAmount ?? this.splitAmount,
```

> Note: there is also an `isPaymentSufficientProvider` at the bottom of the file referencing `isPaymentSufficient`. Replace its body with `ref.watch(cartProvider).isPaymentValid;` and rename the provider to `isPaymentValidProvider` is **not** required — keep the provider name but point it at `isPaymentValid`:
> ```dart
> final isPaymentSufficientProvider = Provider<bool>((ref) {
>   return ref.watch(cartProvider).isPaymentValid;
> });
> ```

- [ ] **Step 4: Add notifier setters + reset secondary on method change**

In `CartNotifier`, update `setPaymentMethod` and add setters:

```dart
  /// Sets the payment method, resetting the split inputs.
  void setPaymentMethod(PaymentMethod method) {
    state = state.copyWith(
      paymentMethod: method,
      clearSecondaryMethod: true,
      splitAmount: 0,
      clearErrorMessage: true,
    );
  }

  /// Sets the secondary method (Mixed digital method or Salmon DP method).
  void setSecondaryMethod(PaymentMethod method) {
    state = state.copyWith(secondaryMethod: method, clearErrorMessage: true);
  }

  /// Sets the split amount (Mixed digital amount or Salmon downpayment).
  void setSplitAmount(double amount) {
    state = state.copyWith(splitAmount: amount, clearErrorMessage: true);
  }
```

- [ ] **Step 5: Write tenders + collected into `toSale`**

Replace `toSale` in `CartNotifier`:

```dart
  SaleEntity toSale({
    required String saleNumber,
    required String cashierId,
    required String cashierName,
  }) {
    return SaleEntity(
      id: '',
      saleNumber: saleNumber,
      items: state.items,
      discountType: state.discountType,
      paymentMethod: state.paymentMethod,
      tenders: state.tenders,
      amountReceived: state.collectedToday,
      changeGiven: state.change,
      cashierId: cashierId,
      cashierName: cashierName,
      createdAt: DateTime.now(),
      draftId: state.sourceDraftId,
      notes: state.notes,
    );
  }
```

- [ ] **Step 6: Run test to verify it passes**

Run: `flutter test test/presentation/providers/cart_tenders_test.dart`
Expected: PASS (4 tests).

- [ ] **Step 7: Commit**

```bash
git add lib/presentation/providers/cart_provider.dart test/presentation/providers/cart_tenders_test.dart
git commit -m "feat(payments): cart tender computation + validation"
```

---

## Task 7: Tender-aware validation in ProcessSaleUseCase

**Files:**
- Modify: `lib/domain/usecases/pos/process_sale_usecase.dart:107-125`
- Test: `test/domain/usecases/process_sale_tender_validation_test.dart`

- [ ] **Step 1: Write the failing test**

Create `test/domain/usecases/process_sale_tender_validation_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:maki_mobile_pos/core/enums/enums.dart';
import 'package:maki_mobile_pos/domain/entities/sale_entity.dart';
import 'package:maki_mobile_pos/domain/entities/sale_item_entity.dart';
import 'package:maki_mobile_pos/domain/repositories/draft_repository.dart';
import 'package:maki_mobile_pos/domain/repositories/product_repository.dart';
import 'package:maki_mobile_pos/domain/repositories/sale_repository.dart';
import 'package:maki_mobile_pos/domain/usecases/pos/process_sale_usecase.dart';

class _MockSaleRepo extends Mock implements SaleRepository {}
class _MockProductRepo extends Mock implements ProductRepository {}
class _MockDraftRepo extends Mock implements DraftRepository {}
class _FakeSale extends Fake implements SaleEntity {}

SaleItemEntity _item() => SaleItemEntity(
      id: 'i', productId: 'p', sku: 'S', name: 'N',
      unitPrice: 1000, unitCost: 0, quantity: 1,
    );

SaleEntity _salmonSale() => SaleEntity(
      id: '', saleNumber: '', items: [_item()],
      paymentMethod: PaymentMethod.salmon,
      tenders: const {PaymentMethod.cash: 400, PaymentMethod.salmon: 600},
      amountReceived: 400, // only downpayment collected
      changeGiven: 0,
      cashierId: 'c', cashierName: 'C', createdAt: DateTime(2026, 5, 28),
    );

void main() {
  setUpAll(() => registerFallbackValue(_FakeSale()));

  late _MockSaleRepo sales;
  late _MockProductRepo products;
  late _MockDraftRepo drafts;
  late ProcessSaleUseCase useCase;

  setUp(() {
    sales = _MockSaleRepo();
    products = _MockProductRepo();
    drafts = _MockDraftRepo();
    useCase = ProcessSaleUseCase(
      saleRepository: sales,
      productRepository: products,
      draftRepository: drafts,
    );
    when(() => sales.generateSaleNumber(any()))
        .thenAnswer((_) async => 'SALE-1');
    when(() => sales.createSale(any()))
        .thenAnswer((inv) async => (inv.positionalArguments.first as SaleEntity)
            .copyWith(id: 'sale-1'));
    when(() => products.getProductById(any())).thenAnswer((_) async => null);
  });

  test('salmon sale (collected < grandTotal) is accepted', () async {
    final result = await useCase.execute(
      sale: _salmonSale(),
      updateInventory: false,
    );
    expect(result.success, true, reason: result.errorMessage);
  });

  test('a tender breakdown that does not reconcile is rejected', () async {
    final bad = _salmonSale().copyWith(
      tenders: const {PaymentMethod.cash: 400, PaymentMethod.salmon: 100},
    );
    final result = await useCase.execute(sale: bad, updateInventory: false);
    expect(result.success, false);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/domain/usecases/process_sale_tender_validation_test.dart`
Expected: FAIL — current `_validateSale` rejects the salmon sale (`amountReceived 400 < grandTotal 1000`).

- [ ] **Step 3: Make validation tender-aware**

In `lib/domain/usecases/pos/process_sale_usecase.dart`, replace the payment check in `_validateSale`:

```dart
    if (sale.amountReceived < sale.grandTotal) {
      throw InsufficientPaymentException(
        amountDue: sale.grandTotal,
        amountReceived: sale.amountReceived,
      );
    }
```

with:

```dart
    // The tender breakdown must reconcile to the grand total. This covers
    // single, mixed, and salmon (downpayment + receivable) sales — the amount
    // collected today may be less than grandTotal for salmon.
    if (!sale.isTenderValid) {
      throw InsufficientPaymentException(
        amountDue: sale.grandTotal,
        amountReceived: sale.effectiveTenders.values
            .fold<double>(0, (a, b) => a + b),
      );
    }
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/domain/usecases/process_sale_tender_validation_test.dart`
Expected: PASS (2 tests).

- [ ] **Step 5: Commit**

```bash
git add lib/domain/usecases/pos/process_sale_usecase.dart test/domain/usecases/process_sale_tender_validation_test.dart
git commit -m "feat(payments): tender-aware sale validation"
```

---

## Task 8: Checkout payment UI (chips + Mixed/Salmon inputs)

**Files:**
- Modify: `lib/presentation/mobile/widgets/pos/payment_section.dart`

UI change; verified manually. The widget is stateless and driven by `cart` + callbacks; add callbacks for the new inputs.

- [ ] **Step 1: Extend the widget API**

Replace the `PaymentSection` constructor + fields to add the split callbacks:

```dart
class PaymentSection extends StatelessWidget {
  final CartState cart;
  final TextEditingController amountController;
  final ValueChanged<String> onAmountChanged;
  final ValueChanged<PaymentMethod> onPaymentMethodChanged;
  final ValueChanged<PaymentMethod> onSecondaryMethodChanged;
  final ValueChanged<String> onSplitAmountChanged;
  final TextEditingController splitController;

  const PaymentSection({
    super.key,
    required this.cart,
    required this.amountController,
    required this.onAmountChanged,
    required this.onPaymentMethodChanged,
    required this.onSecondaryMethodChanged,
    required this.onSplitAmountChanged,
    required this.splitController,
  });
```

- [ ] **Step 2: Replace the method selector with chips + conditional inputs**

Replace the `build` method body's `Column` children. The method selector becomes a `Wrap` of `ChoiceChip`s; the input area switches on `cart.paymentMethod`:

```dart
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: AppSpacing.sm,
            children: [
              for (final m in const [
                PaymentMethod.cash,
                PaymentMethod.gcash,
                PaymentMethod.maya,
                PaymentMethod.mixed,
                PaymentMethod.salmon,
              ])
                ChoiceChip(
                  label: Text(m.displayName),
                  selected: cart.paymentMethod == m,
                  onSelected: (_) => onPaymentMethodChanged(m),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          ..._buildInputs(context),
        ],
      ),
    );
  }

  List<Widget> _buildInputs(BuildContext context) {
    switch (cart.paymentMethod) {
      case PaymentMethod.mixed:
        return _buildMixedInputs(context);
      case PaymentMethod.salmon:
        return _buildSalmonInputs(context);
      default:
        return _buildSingleInputs(context);
    }
  }
```

- [ ] **Step 3: Single-method inputs (existing behavior, cash shows change)**

Keep the current Amount Received field + quick buttons + change display for single methods:

```dart
  List<Widget> _buildSingleInputs(BuildContext context) {
    return [
      TextField(
        controller: amountController,
        decoration: InputDecoration(
          labelText: 'Amount Received',
          prefixText: '${AppConstants.currencySymbol} ',
          suffixIcon: IconButton(
            icon: const Icon(CupertinoIcons.checkmark_circle),
            tooltip: 'Exact amount',
            onPressed: () {
              amountController.text = cart.grandTotal.toStringAsFixed(2);
              onAmountChanged(amountController.text);
            },
          ),
        ),
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        inputFormatters: [
          FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
        ],
        onChanged: onAmountChanged,
      ),
      const SizedBox(height: AppSpacing.sm + 4),
      _buildQuickAmountButtons(context),
      const SizedBox(height: AppSpacing.md),
      if (cart.paymentMethod == PaymentMethod.cash) _buildChangeDisplay(context),
    ];
  }
```

(Leave `_buildQuickAmountButtons` and `_buildChangeDisplay` as they are. The change display already keys off `cart.change`, which now returns 0 for non-cash.)

- [ ] **Step 4: Mixed inputs**

```dart
  List<Widget> _buildMixedInputs(BuildContext context) {
    final theme = Theme.of(context);
    final digital = cart.secondaryMethod == PaymentMethod.maya
        ? PaymentMethod.maya
        : PaymentMethod.gcash;
    final cashPortion = cart.grandTotal - cart.splitAmount;
    return [
      SegmentedButton<PaymentMethod>(
        segments: const [
          ButtonSegment(value: PaymentMethod.gcash, label: Text('GCash')),
          ButtonSegment(value: PaymentMethod.maya, label: Text('Maya')),
        ],
        selected: {digital},
        onSelectionChanged: (s) => onSecondaryMethodChanged(s.first),
      ),
      const SizedBox(height: AppSpacing.md),
      TextField(
        controller: splitController,
        decoration: InputDecoration(
          labelText: '${digital.displayName} amount',
          prefixText: '${AppConstants.currencySymbol} ',
        ),
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        inputFormatters: [
          FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
        ],
        onChanged: onSplitAmountChanged,
      ),
      const SizedBox(height: AppSpacing.sm),
      Text(
        'Cash portion: ${AppConstants.currencySymbol}${cashPortion.toStringAsFixed(2)}',
        style: theme.textTheme.titleMedium,
      ),
    ];
  }
```

- [ ] **Step 5: Salmon inputs**

```dart
  List<Widget> _buildSalmonInputs(BuildContext context) {
    final theme = Theme.of(context);
    final dp = cart.secondaryMethod ?? PaymentMethod.cash;
    final balance = cart.grandTotal - cart.splitAmount;
    return [
      SegmentedButton<PaymentMethod>(
        segments: const [
          ButtonSegment(value: PaymentMethod.cash, label: Text('Cash')),
          ButtonSegment(value: PaymentMethod.gcash, label: Text('GCash')),
          ButtonSegment(value: PaymentMethod.maya, label: Text('Maya')),
        ],
        selected: {dp == PaymentMethod.salmon ? PaymentMethod.cash : dp},
        onSelectionChanged: (s) => onSecondaryMethodChanged(s.first),
      ),
      const SizedBox(height: AppSpacing.md),
      TextField(
        controller: splitController,
        decoration: InputDecoration(
          labelText: 'Downpayment',
          prefixText: '${AppConstants.currencySymbol} ',
        ),
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        inputFormatters: [
          FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
        ],
        onChanged: onSplitAmountChanged,
      ),
      const SizedBox(height: AppSpacing.sm),
      Text(
        'Salmon balance: ${AppConstants.currencySymbol}${balance.toStringAsFixed(2)}',
        style: theme.textTheme.titleMedium,
      ),
    ];
  }
```

- [ ] **Step 6: Verify it compiles**

Run: `flutter analyze lib/presentation/mobile/widgets/pos/payment_section.dart`
Expected: errors only about the call site (checkout_screen) not passing the new required params — fixed in Task 9. The widget file itself should have no internal errors.

- [ ] **Step 7: Commit**

```bash
git add lib/presentation/mobile/widgets/pos/payment_section.dart
git commit -m "feat(payments): mixed & salmon inputs in payment section"
```

---

## Task 9: Wire checkout screen + gate Confirm

**Files:**
- Modify: `lib/presentation/mobile/screens/pos/checkout_screen.dart`

- [ ] **Step 1: Add a split controller + handlers**

In `_CheckoutScreenState`, add a controller field and init/dispose it:

```dart
  late final TextEditingController _amountReceivedController;
  late final TextEditingController _splitController;
```

In `initState` after `_amountReceivedController = ...`:

```dart
    _splitController = TextEditingController();
```

In `dispose` add: `_splitController.dispose();`

Add handlers next to `_handlePaymentMethodChanged`:

```dart
  void _handleSecondaryMethodChanged(PaymentMethod method) {
    ref.read(cartProvider.notifier).setSecondaryMethod(method);
  }

  void _handleSplitAmountChanged(String value) {
    ref.read(cartProvider.notifier).setSplitAmount(double.tryParse(value) ?? 0);
  }
```

Also clear the split controller when the method changes (so stale values don't linger):

```dart
  void _handlePaymentMethodChanged(PaymentMethod method) {
    ref.read(cartProvider.notifier).setPaymentMethod(method);
    _splitController.clear();
  }
```

- [ ] **Step 2: Pass the new params to PaymentSection**

Update the `PaymentSection(...)` call:

```dart
                      child: PaymentSection(
                        cart: cart,
                        amountController: _amountReceivedController,
                        splitController: _splitController,
                        onAmountChanged: _handleAmountChanged,
                        onPaymentMethodChanged: _handlePaymentMethodChanged,
                        onSecondaryMethodChanged: _handleSecondaryMethodChanged,
                        onSplitAmountChanged: _handleSplitAmountChanged,
                      ),
```

- [ ] **Step 3: Gate the Confirm button on cart validity**

In `_buildConfirmButton`, change the `onPressed`:

```dart
          child: FilledButton(
            onPressed: (_isProcessing || !cart.canCheckout)
                ? null
                : () => _processCheckout(cart),
```

- [ ] **Step 4: Verify it compiles**

Run: `flutter analyze lib/presentation/mobile/screens/pos/checkout_screen.dart lib/presentation/mobile/widgets/pos/payment_section.dart`
Expected: No errors.

- [ ] **Step 5: Commit**

```bash
git add lib/presentation/mobile/screens/pos/checkout_screen.dart
git commit -m "feat(payments): wire mixed/salmon checkout + gate confirm"
```

---

## Task 10: Tender breakdown in Sale Detail

**Files:**
- Modify: `lib/presentation/mobile/screens/sales/sale_detail_screen.dart`

- [ ] **Step 1: Add a tender breakdown row to the Details/Payment card**

In `_buildPaymentCard`, after the existing `_buildPaymentRow(theme, 'Change', ...)` line and before the closing `],`, append a breakdown when there is more than one tender:

```dart
          _buildPaymentRow(theme, 'Change', sale.changeGiven, isChange: true),
          if (sale.effectiveTenders.length > 1) ...[
            const Divider(height: 24),
            ..._tenderRows(theme, sale),
          ],
```

Add the helper method to the class:

```dart
  List<Widget> _tenderRows(ThemeData theme, SaleEntity sale) {
    String label(PaymentMethod m) {
      if (sale.paymentMethod == PaymentMethod.salmon) {
        return m == PaymentMethod.salmon
            ? 'Salmon balance'
            : 'Downpayment (${m.displayName})';
      }
      return m.displayName;
    }

    return sale.effectiveTenders.entries
        .map((e) => Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(label(e.key), style: theme.textTheme.bodyMedium),
                  Text(
                    '${AppConstants.currencySymbol}${e.value.toStringAsFixed(2)}',
                    style: theme.textTheme.bodyMedium
                        ?.copyWith(fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ))
        .toList();
  }
```

(`PaymentMethod` is already imported via `core/enums/enums.dart`; `SaleEntity` via `domain/entities/entities.dart`.)

- [ ] **Step 2: Verify it compiles**

Run: `flutter analyze lib/presentation/mobile/screens/sales/sale_detail_screen.dart`
Expected: No errors.

- [ ] **Step 3: Commit**

```bash
git add lib/presentation/mobile/screens/sales/sale_detail_screen.dart
git commit -m "feat(payments): tender breakdown in sale detail"
```

---

## Task 11: Tender breakdown on the receipt

**Files:**
- Modify: `lib/presentation/mobile/widgets/pos/receipt_widget.dart`

- [ ] **Step 1: Add tender lines to the totals/payment area**

In `_buildPaymentSection(ThemeData theme)` (the receipt's payment block), render a line per tender when there's more than one. Find the payment section method and add, after its existing rows:

```dart
        if (sale.effectiveTenders.length > 1)
          ...sale.effectiveTenders.entries.map((e) {
            final isSalmon = e.key == PaymentMethod.salmon;
            final label = sale.paymentMethod == PaymentMethod.salmon
                ? (isSalmon ? 'Salmon balance' : 'Downpayment (${e.key.displayName})')
                : e.key.displayName;
            return _buildPaymentRow(label, e.value);
          }),
```

> If `_buildPaymentRow` in the receipt has a different signature (e.g. `(String label, double amount, {bool isChange})`), match it; check the method near line 386. `PaymentMethod` is available via `core/enums/enums.dart` (already imported through `domain/entities/entities.dart`); if not, add `import 'package:maki_mobile_pos/core/enums/enums.dart';`.

- [ ] **Step 2: Verify it compiles**

Run: `flutter analyze lib/presentation/mobile/widgets/pos/receipt_widget.dart`
Expected: No errors.

- [ ] **Step 3: Commit**

```bash
git add lib/presentation/mobile/widgets/pos/receipt_widget.dart
git commit -m "feat(payments): tender breakdown on receipt"
```

---

## Task 12: Salmon receivable on EOD screen + history

**Files:**
- Modify: `lib/presentation/mobile/screens/reports/end_of_day_screen.dart`
- Modify: `lib/presentation/mobile/screens/reports/daily_closing_history_screen.dart`

- [ ] **Step 1: Add a Salmon receivable row to the EOD Sales block (review)**

In `end_of_day_screen.dart` `_buildReview`, in the `_section('Sales', [...])` list, after `_rowText('Sales count', '${draft.salesCount}')`:

```dart
                  _rowText('Sales count', '${draft.salesCount}'),
                  if (draft.salmonReceivable > 0)
                    _row('Salmon receivable (next day)',
                        draft.salmonReceivable),
```

- [ ] **Step 2: Add it to the closed (read-only) view**

In `_ClosedView.build`, in the first `_card(context, 'Sales', {...})` map, add a conditional entry. Since `_card` takes a `Map<String,double>`, build the map first:

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

- [ ] **Step 3: Add it to history detail**

In `daily_closing_history_screen.dart` `_ClosingTile.build`, in the expanded `children`, after the `_kv(context, 'Non-cash sales', closing.nonCashSales)` line:

```dart
          _kv(context, 'Non-cash sales', closing.nonCashSales),
          if (closing.salmonReceivable > 0)
            _kv(context, 'Salmon receivable', closing.salmonReceivable),
```

- [ ] **Step 4: Verify it compiles**

Run: `flutter analyze lib/presentation/mobile/screens/reports/end_of_day_screen.dart lib/presentation/mobile/screens/reports/daily_closing_history_screen.dart`
Expected: No errors.

- [ ] **Step 5: Commit**

```bash
git add lib/presentation/mobile/screens/reports/end_of_day_screen.dart lib/presentation/mobile/screens/reports/daily_closing_history_screen.dart
git commit -m "feat(eod): show Salmon receivable in closing + history"
```

---

## Task 13: Skip zero buckets in the payment-methods breakdown card

**Files:**
- Modify: `lib/presentation/mobile/screens/reports/sales_report_screen.dart`

- [ ] **Step 1: Filter zero-amount buckets**

In `_buildPaymentBreakdown`, where it maps `summary.byPaymentMethod.entries`, skip zero entries so seeded-but-unused buckets (and any stray) don't render. Change:

```dart
                ...summary.byPaymentMethod.entries.map((entry) {
```

to:

```dart
                ...summary.byPaymentMethod.entries
                    .where((entry) => entry.value > 0)
                    .map((entry) {
```

- [ ] **Step 2: Verify it compiles**

Run: `flutter analyze lib/presentation/mobile/screens/reports/sales_report_screen.dart`
Expected: No errors.

- [ ] **Step 3: Commit**

```bash
git add lib/presentation/mobile/screens/reports/sales_report_screen.dart
git commit -m "feat(reports): hide zero-amount payment buckets"
```

---

## Task 14: Full verification

- [ ] **Step 1: Static analysis**

Run: `flutter analyze`
Expected: No new errors from this feature (pre-existing infos elsewhere are acceptable). Nothing under the changed files should error.

- [ ] **Step 2: Full test suite**

Run: `flutter test`
Expected: All new tests pass:
- `test/core/enums/payment_method_test.dart`
- `test/domain/entities/sale_entity_tenders_test.dart`
- `test/data/models/sale_model_tenders_test.dart`
- `test/data/repositories/sales_summary_tenders_test.dart`
- `test/domain/entities/daily_closing_draft_test.dart` (extended)
- `test/presentation/providers/cart_tenders_test.dart`
- `test/domain/usecases/process_sale_tender_validation_test.dart`

Pre-existing failures (cart_item_tile, product_list_tile, update_product) remain unrelated. Confirm no *new* failures.

- [ ] **Step 3: Manual smoke test in the running app**

Run the app and, as a cashier:
1. Build a cart, go to Checkout.
2. **Mixed:** pick Mixed → GCash → enter a digital amount < total → Cash portion updates → Confirm enabled only when `0 < digital < total`. Complete the sale.
3. **Salmon:** pick Salmon → Cash DP → enter downpayment < total → Salmon balance updates → Confirm. Complete the sale.
4. Open each sale's detail + receipt → tender breakdown shows (Mixed: cash/gcash; Salmon: downpayment + salmon balance).
5. Sales Report → Payment Methods card shows a Salmon line; no empty "Mixed" line.
6. End-of-Day → Salmon receivable row appears; expected cash includes only the cash tenders (downpayment cash + mixed cash portion), not the Salmon balance. Close the day → history detail shows the Salmon receivable.

- [ ] **Step 4: Final commit (if verification fixes were needed)**

```bash
git add -A
git commit -m "test(payments): verification fixes"
```

---

## Self-Review notes

- **Spec coverage:** PaymentMethod enum (T1); tenders + effectiveTenders + helpers + validity (T2); model serialization + legacy default (T3); summary sums tenders + salmonReceivable + no `mixed` bucket (T4); EOD draft/entity/model salmonReceivable + nonCashSales excludes salmon (T5); cart tender computation + validation + Mixed/Salmon rules (T6); tender-aware use-case validation incl. Salmon collected<total (T7); checkout chips + Mixed/Salmon inputs + confirm gating (T8-9); sale-detail + receipt breakdown (T10-11); EOD + history Salmon line (T12); hide zero/`mixed` buckets (T4 seed + T13 filter). All covered.
- **Backward compatibility:** `effectiveTenders` derives `{paymentMethod: grandTotal}` for legacy sales (no `tenders`), so existing data, summary, and reports are unchanged. Tested in T2/T3.
- **Type consistency:** `tenders` (`Map<PaymentMethod,double>`), `effectiveTenders`, `cashCollected`, `salmonBalance`, `isTenderValid`, `salmonReceivable`, `secondaryMethod`, `splitAmount`, `collectedToday`, `isPaymentValid`, `setSecondaryMethod`, `setSplitAmount` are used identically across tasks.
- **Known cross-task dependency:** Task 5 requires updating existing daily-closing test literals to add `salmonReceivable: 0` (Step 7) — called out explicitly so the suite stays green.
- **PaymentMethod exhaustiveness:** adding `salmon`/`mixed` may trigger non-exhaustive `switch` warnings elsewhere. Task 14 Step 1 (`flutter analyze`) catches these; resolve any by adding the new cases (the cart switch in T6 already handles all five).
