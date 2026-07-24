# EOD Labor Split + After Close in History + Sales-History Icon Removal — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Show the mechanics-vs-management cash split on every EOD surface, surface post-close drift in Closing History, and remove the redundant reports icon from Sales History.

**Architecture:** Pure read-side Flutter change. Two derived getters on `DailyClosingEntity` (`forMechanics`, `forManagement`) plus a `laborDelta` on `PostCloseActivity` carry all the math; two new shared widgets (`ClosingHandoffRows`, `AfterCloseCard`) render it on the EOD review screen, the closed view, and the Closing History detail (which computes drift live on expand via the existing `dailyClosingDataProvider`). No Firestore schema, rules, or write-path changes.

**Tech Stack:** Flutter, Riverpod (`FutureProvider.family` overrides in tests), flutter_test widget tests.

**Spec:** `docs/superpowers/specs/2026-07-24-eod-labor-split-after-close-design.md`

## Global Constraints

- Branch: `feat/eod-labor-split-after-close` (already created; spec committed on it).
- Mobile Flutter surface only. NO changes to Firestore documents, rules, indexes, `CloseDayUseCase`, or web admin.
- Money rule: `forMechanics = laborRevenue` (whole day, all tenders — mechanics always paid from the drawer); `forManagement = countedCash − laborRevenue` (float not held back). Variance/expected-cash formulas unchanged.
- Tests mirror `lib/` structure under `test/`.
- Verify with `flutter test <file>` per task; full `flutter test` + `flutter analyze` in the final task.
- Peso format: `AppConstants.currencySymbol` = `₱`, `toCurrencyWithoutSymbol()` → `1,234.56`.

---

### Task 1: Domain — handoff getters + labor drift on PostCloseActivity

**Files:**
- Modify: `lib/domain/entities/daily_closing_entity.dart`
- Test: `test/domain/entities/post_close_activity_test.dart`

**Interfaces:**
- Consumes: existing `DailyClosingEntity`, `DailyClosingDraft`, `PostCloseActivity`.
- Produces (used by Tasks 2–4):
  - `DailyClosingEntity.forMechanics → double` (= `laborRevenue`)
  - `DailyClosingEntity.forManagement → double` (= `countedCash - laborRevenue`)
  - `PostCloseActivity.laborDelta → double` (constructor param, default 0)
  - `PostCloseActivity.currentLaborRevenue → double` (constructor param, default 0)
  - `PostCloseActivity.updatedForManagement → double` getter (= `updatedCashOnHand - currentLaborRevenue`)
  - `PostCloseActivity.hasChanged` now also true when `laborDelta.abs() > 0.005`

- [ ] **Step 1: Extend the test helpers and write the failing tests**

In `test/domain/entities/post_close_activity_test.dart`, add a `labor` parameter to both fixture helpers. In `_closing`, change the signature and add the field:

```dart
DailyClosingEntity _closing({
  double gross = 1000,
  int salesCount = 5,
  double cashSales = 600,
  double cashExpenses = 100,
  double countedCash = 2500,
  double labor = 0,
}) =>
```

and inside the constructor call add (next to `salmonReceivable: 0,`):

```dart
      laborRevenue: labor,
```

Same for `_draft`:

```dart
DailyClosingDraft _draft({
  double gross = 1000,
  int salesCount = 5,
  double cashSales = 600,
  double cashExpenses = 100,
  double labor = 0,
}) =>
```

with `laborRevenue: labor,` added inside its constructor call (next to `salmonReceivable: 0,`).

Then add a new group at the end of `main()` (after the existing `PostCloseActivity.between` group):

```dart
  group('labor handoff split', () {
    test('closing exposes forMechanics / forManagement', () {
      final c = _closing(labor: 450, countedCash: 2500);
      expect(c.forMechanics, 450);
      // Management takes everything counted minus labor; float not held back.
      expect(c.forManagement, 2050);
    });

    test('computes laborDelta and updated handoff figures', () {
      final a = PostCloseActivity.between(
        closing: _closing(labor: 200, cashSales: 600, countedCash: 2500),
        current: _draft(labor: 450, cashSales: 850, salesCount: 6),
      );
      expect(a.laborDelta, 250);
      expect(a.currentLaborRevenue, 450);
      expect(a.cashSalesDelta, 250);
      // Updated cash on hand 2750 minus whole-day labor 450.
      expect(a.updatedForManagement, 2300);
    });

    test('cash labor-only sale after close: sale-items split is zero', () {
      final a = PostCloseActivity.between(
        closing: _closing(
            gross: 1000, salesCount: 5, cashSales: 600, countedCash: 2500),
        current:
            _draft(gross: 1000, salesCount: 6, cashSales: 1050, labor: 450),
      );
      expect(a.extraSales, 1);
      expect(a.grossDelta, 0); // labor is never in parts gross
      expect(a.cashSalesDelta, 450);
      expect(a.laborDelta, 450);
      expect(a.cashSalesDelta - a.laborDelta, 0);
      expect(a.updatedCashOnHand, 2950);
      expect(a.updatedForManagement, 2500); // 2950 − 450 whole-day labor
    });

    test('labor-only drift flags hasChanged; digital labor goes negative', () {
      // Digital (GCash) labor after close moves labor but not drawer cash.
      final a = PostCloseActivity.between(
        closing: _closing(labor: 0),
        current: _draft(labor: 300),
      );
      expect(a.hasChanged, true);
      expect(a.cashSalesDelta, 0);
      // Sale-items sub-line (cash − labor) can go negative — shown as-is.
      expect(a.cashSalesDelta - a.laborDelta, -300);
    });
  });
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `flutter test test/domain/entities/post_close_activity_test.dart`
Expected: COMPILE ERRORS — `forMechanics`, `forManagement`, `laborDelta`, `currentLaborRevenue`, `updatedForManagement` are not defined.

- [ ] **Step 3: Implement in `lib/domain/entities/daily_closing_entity.dart`**

(a) In `DailyClosingEntity`, immediately after the constructor (before `@override List<Object?> get props`), add:

```dart
  /// Labor fees owed to mechanics from the drawer — the whole day, all
  /// tenders, since mechanics are settled in cash from the drawer even when
  /// the customer paid labor digitally.
  double get forMechanics => laborRevenue;

  /// Cash handed to management at close: everything counted minus the labor
  /// owed to mechanics. The opening float is not held back.
  double get forManagement => countedCash - laborRevenue;
```

(b) In `PostCloseActivity`, after the `updatedCashOnHand` field declaration, add:

```dart
  /// Labor revenue recorded after close (current minus snapshot).
  final double laborDelta;

  /// Whole-day labor revenue including post-close sales — what the
  /// mechanics are owed out of the drawer.
  final double currentLaborRevenue;
```

(c) Extend the const constructor with two optional params (after `required this.updatedCashOnHand,`):

```dart
    this.laborDelta = 0,
    this.currentLaborRevenue = 0,
```

(d) In `PostCloseActivity.between`, add to the returned constructor call (after `updatedCashOnHand: ...,`):

```dart
      laborDelta: current.laborRevenue - closing.laborRevenue,
      currentLaborRevenue: current.laborRevenue,
```

(e) After the factory, add the getter:

```dart
  /// [updatedCashOnHand] minus the whole-day labor owed to mechanics —
  /// what management should receive after post-close drift.
  double get updatedForManagement => updatedCashOnHand - currentLaborRevenue;
```

(f) Extend `hasChanged` with a labor clause:

```dart
  bool get hasChanged =>
      extraSales != 0 ||
      grossDelta.abs() > 0.005 ||
      cashSalesDelta.abs() > 0.005 ||
      cashExpensesDelta.abs() > 0.005 ||
      laborDelta.abs() > 0.005;
```

(g) Add `laborDelta` and `currentLaborRevenue` to `PostCloseActivity.props`.

- [ ] **Step 4: Run the tests to verify they pass**

Run: `flutter test test/domain/entities/post_close_activity_test.dart`
Expected: ALL PASS (existing 6 + new 4).

- [ ] **Step 5: Commit**

```bash
git add lib/domain/entities/daily_closing_entity.dart test/domain/entities/post_close_activity_test.dart
git commit -m "feat(mobile): labor handoff math — forMechanics/forManagement + PostCloseActivity laborDelta"
```

---

### Task 2: Shared widgets — ClosingHandoffRows + AfterCloseCard

**Files:**
- Create: `lib/presentation/mobile/widgets/reports/closing_handoff_rows.dart`
- Create: `lib/presentation/mobile/widgets/reports/after_close_card.dart`
- Modify: `lib/presentation/mobile/widgets/reports/reports_widgets.dart` (barrel)
- Test: `test/presentation/mobile/widgets/reports/closing_handoff_rows_test.dart`
- Test: `test/presentation/mobile/widgets/reports/after_close_card_test.dart`

**Interfaces:**
- Consumes: Task 1's `PostCloseActivity` fields/getters; existing `ClosingSectionCard`, `ClosingKvRow` (from `closing_widgets.dart`), `AppColors.hairline`/`warningIcon`.
- Produces (used by Tasks 3–4):
  - `ClosingHandoffRows({required double laborFees, required double forManagement, bool dense = false})` — divider + two KV rows.
  - `AfterCloseCard({required PostCloseActivity activity})` — the full "After close" section card with labor split.
  - Both exported via the `reports_widgets.dart` barrel (already imported by both screens).

- [ ] **Step 1: Write the failing widget tests**

Create `test/presentation/mobile/widgets/reports/closing_handoff_rows_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maki_mobile_pos/presentation/mobile/widgets/reports/reports_widgets.dart';

void main() {
  testWidgets('shows labor→mechanics and items→management rows',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
        body: ClosingHandoffRows(laborFees: 450, forManagement: 2050),
      ),
    ));
    expect(find.text('Labor fees → mechanics'), findsOneWidget);
    expect(find.text('₱450.00'), findsOneWidget);
    expect(find.text('Sale items → management'), findsOneWidget);
    expect(find.text('₱2,050.00'), findsOneWidget);
  });
}
```

Create `test/presentation/mobile/widgets/reports/after_close_card_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maki_mobile_pos/domain/entities/daily_closing_entity.dart';
import 'package:maki_mobile_pos/presentation/mobile/widgets/reports/reports_widgets.dart';

Widget _harness(PostCloseActivity activity) => MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(child: AfterCloseCard(activity: activity)),
      ),
    );

void main() {
  testWidgets('splits after-close cash into sale items vs labor and shows '
      'handoff totals', (tester) async {
    // One cash sale after close: parts ₱200 + labor ₱300 (cash +500).
    // Whole-day labor is 750. All expected strings below are unique in the
    // card — the 'Sales after close' row renders a combined '+1 · +₱200.00'
    // string, so '+₱200.00' matches only the Sale items sub-line.
    const activity = PostCloseActivity(
      extraSales: 1,
      grossDelta: 200,
      cashSalesDelta: 500,
      cashExpensesDelta: 0,
      updatedCashOnHand: 1950,
      laborDelta: 300,
      currentLaborRevenue: 750,
    );
    await tester.pumpWidget(_harness(activity));

    expect(find.text('After close'), findsOneWidget);
    expect(find.text('Cash collected after close'), findsOneWidget);
    expect(find.text('+₱500.00'), findsOneWidget);
    expect(find.text('Sale items'), findsOneWidget);
    expect(find.text('+₱200.00'), findsOneWidget); // 500 cash − 300 labor
    expect(find.text('Labor fees'), findsOneWidget);
    expect(find.text('+₱300.00'), findsOneWidget);
    expect(find.text('Updated cash on hand'), findsOneWidget);
    expect(find.text('₱1,950.00'), findsOneWidget);
    expect(find.text('Updated for management'), findsOneWidget);
    expect(find.text('₱1,200.00'), findsOneWidget); // 1950 − 750
    expect(find.text('For mechanics (whole day)'), findsOneWidget);
    expect(find.text('₱750.00'), findsOneWidget);
  });

  testWidgets('hides the split sub-lines when no labor drifted',
      (tester) async {
    const activity = PostCloseActivity(
      extraSales: 1,
      grossDelta: 240,
      cashSalesDelta: 240,
      cashExpensesDelta: 0,
      updatedCashOnHand: 2740,
      laborDelta: 0,
      currentLaborRevenue: 450,
    );
    await tester.pumpWidget(_harness(activity));

    expect(find.text('Sale items'), findsNothing);
    expect(find.text('Labor fees'), findsNothing);
    // Bottom handoff rows still shown.
    expect(find.text('Updated for management'), findsOneWidget);
    expect(find.text('₱2,290.00'), findsOneWidget); // 2740 − 450
  });
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `flutter test test/presentation/mobile/widgets/reports/`
Expected: COMPILE ERRORS — `ClosingHandoffRows` / `AfterCloseCard` undefined.

- [ ] **Step 3: Implement the widgets**

Create `lib/presentation/mobile/widgets/reports/closing_handoff_rows.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:maki_mobile_pos/core/constants/app_constants.dart';
import 'package:maki_mobile_pos/core/extensions/num_extensions.dart';
import 'package:maki_mobile_pos/core/theme/theme.dart';
import 'package:maki_mobile_pos/presentation/mobile/widgets/reports/closing_widgets.dart';

/// End-of-day cash handoff split: labor fees go to the mechanics (always in
/// cash from the drawer, whatever tender the customer used), the rest of the
/// counted drawer goes to management. Rendered inside the Cash reconciliation
/// card (EOD review + closed view) and the closing-history detail.
class ClosingHandoffRows extends StatelessWidget {
  const ClosingHandoffRows({
    super.key,
    required this.laborFees,
    required this.forManagement,
    this.dense = false,
  });

  /// Whole-day labor fees owed to mechanics.
  final double laborFees;

  /// Counted cash minus [laborFees].
  final double forManagement;

  final bool dense;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    String peso(double v) =>
        '${AppConstants.currencySymbol}${v.toCurrencyWithoutSymbol()}';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: EdgeInsets.symmetric(vertical: dense ? 8 : 11),
          child: Divider(height: 1, color: AppColors.hairline(isDark)),
        ),
        ClosingKvRow(
          label: 'Labor fees → mechanics',
          value: peso(laborFees),
          dense: dense,
        ),
        ClosingKvRow(
          label: 'Sale items → management',
          value: peso(forManagement),
          dense: dense,
        ),
      ],
    );
  }
}
```

Create `lib/presentation/mobile/widgets/reports/after_close_card.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:maki_mobile_pos/core/constants/app_constants.dart';
import 'package:maki_mobile_pos/core/extensions/num_extensions.dart';
import 'package:maki_mobile_pos/core/theme/theme.dart';
import 'package:maki_mobile_pos/domain/entities/daily_closing_entity.dart';
import 'package:maki_mobile_pos/presentation/mobile/widgets/reports/closing_widgets.dart';

/// "After close" drift card: sales and cash recorded after the day was
/// closed, split into sale items (management's share) vs labor fees (the
/// mechanics'), plus the updated drawer and handoff figures. Shared by the
/// closed EOD view and the closing-history detail so both render identically.
class AfterCloseCard extends StatelessWidget {
  const AfterCloseCard({super.key, required this.activity});

  final PostCloseActivity activity;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    String peso(double v) =>
        '${AppConstants.currencySymbol}${v.toCurrencyWithoutSymbol()}';
    String signed(double v) =>
        '${v >= 0 ? '+' : '-'}${AppConstants.currencySymbol}${v.abs().toCurrencyWithoutSymbol()}';
    final showLaborSplit = activity.laborDelta.abs() > 0.005;

    return ClosingSectionCard(
      icon: LucideIcons.clock,
      title: 'After close',
      iconColor: AppColors.warningIcon(isDark),
      children: [
        ClosingKvRow(
          label: 'Sales after close',
          value: '${activity.extraSales >= 0 ? '+' : ''}${activity.extraSales}'
              ' · ${signed(activity.grossDelta)}',
        ),
        ClosingKvRow(
          label: 'Cash collected after close',
          value: signed(activity.cashSalesDelta),
        ),
        if (showLaborSplit) ...[
          ClosingKvRow(
            label: 'Sale items',
            value: signed(activity.cashSalesDelta - activity.laborDelta),
            indented: true,
          ),
          ClosingKvRow(
            label: 'Labor fees',
            value: signed(activity.laborDelta),
            indented: true,
          ),
        ],
        if (activity.cashExpensesDelta.abs() > 0.005)
          ClosingKvRow(
            label: 'Cash expenses after close',
            value: signed(-activity.cashExpensesDelta),
          ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 11),
          child: Divider(height: 1, color: AppColors.hairline(isDark)),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Updated cash on hand',
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w600, fontSize: 15),
            ),
            Text(
              peso(activity.updatedCashOnHand),
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: theme.colorScheme.primary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClosingKvRow(
          label: 'Updated for management',
          value: peso(activity.updatedForManagement),
        ),
        ClosingKvRow(
          label: 'For mechanics (whole day)',
          value: peso(activity.currentLaborRevenue),
        ),
      ],
    );
  }
}
```

Append to `lib/presentation/mobile/widgets/reports/reports_widgets.dart`:

```dart
export 'after_close_card.dart';
export 'closing_handoff_rows.dart';
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/presentation/mobile/widgets/reports/`
Expected: 3 tests PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/presentation/mobile/widgets/reports/ test/presentation/mobile/widgets/reports/
git commit -m "feat(mobile): shared ClosingHandoffRows + AfterCloseCard widgets with labor split"
```

---

### Task 3: EOD screen wiring (review + closed view)

**Files:**
- Modify: `lib/presentation/mobile/screens/reports/end_of_day_screen.dart`
- Test: `test/presentation/mobile/screens/reports/end_of_day_screen_test.dart` (new)

**Interfaces:**
- Consumes: `ClosingHandoffRows`, `AfterCloseCard` (via `reports_widgets.dart` barrel, already imported by the screen); `closing.forMechanics` / `closing.forManagement` from Task 1.
- Produces: no new API — screen-internal wiring. `_afterCloseCard` private method is DELETED (replaced by `AfterCloseCard`).

- [ ] **Step 1: Write the failing widget tests**

Create `test/presentation/mobile/screens/reports/end_of_day_screen_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maki_mobile_pos/core/enums/payment_method.dart';
import 'package:maki_mobile_pos/domain/entities/daily_closing_entity.dart';
import 'package:maki_mobile_pos/domain/repositories/sale_repository.dart';
import 'package:maki_mobile_pos/presentation/mobile/screens/reports/end_of_day_screen.dart';
import 'package:maki_mobile_pos/presentation/providers/providers.dart';

/// Day with parts ₱1,000 + labor ₱450, all cash (drawer holds ₱1,450).
SalesSummary _summary({
  int salesCount = 2,
  double cash = 1450,
  double labor = 450,
}) =>
    SalesSummary(
      totalSalesCount: salesCount,
      voidedSalesCount: 0,
      grossAmount: 1000,
      totalDiscounts: 0,
      netAmount: 1000,
      totalCost: 0,
      totalProfit: 1000,
      byPaymentMethod: {PaymentMethod.cash: cash},
      laborRevenue: labor,
      laborProfit: labor,
    );

DailyClosingData _data(DateTime date, {SalesSummary? summary}) =>
    DailyClosingData(
      businessDate: date,
      summary: summary ?? _summary(),
      expenses: const [],
    );

DailyClosingEntity _closing(DateTime date) => DailyClosingEntity(
      id: 'today',
      businessDate: date,
      grossSales: 1000,
      netSales: 1000,
      totalDiscounts: 0,
      cashSales: 1450,
      nonCashSales: 0,
      gcashSales: 0,
      mayaSales: 0,
      totalExpenses: 0,
      cashExpenses: 0,
      salmonReceivable: 0,
      laborRevenue: 450,
      openingFloat: 0,
      expectedCash: 1450,
      // 2000 (not 1450) so 'Sale items → management' = ₱1,550.00 is a
      // string no other row on the screen renders (gross is ₱1,000.00).
      countedCash: 2000,
      variance: 550,
      salesCount: 2,
      voidedCount: 0,
      closedBy: 'u',
      closedByName: 'U',
      closedAt: DateTime(2026, 7, 24, 18, 0),
    );

Widget _harness({
  DailyClosingEntity? closing,
  SalesSummary? liveSummary,
}) =>
    ProviderScope(
      overrides: [
        dailyClosingForDateProvider
            .overrideWith((ref, date) async => closing),
        dailyClosingDataProvider.overrideWith(
            (ref, date) async => _data(date, summary: liveSummary)),
      ],
      child: const MaterialApp(home: EndOfDayScreen()),
    );

void main() {
  testWidgets('review: handoff rows appear only once counted cash is entered',
      (tester) async {
    await tester.pumpWidget(_harness(closing: null));
    await tester.pump();
    await tester.pump();

    expect(find.text('Labor fees → mechanics'), findsNothing);

    await tester.ensureVisible(find.byKey(const ValueKey('counted-cash')));
    await tester.enterText(
      find.descendant(
        of: find.byKey(const ValueKey('counted-cash')),
        matching: find.byType(TextFormField),
      ),
      '3000',
    );
    await tester.pump();

    expect(find.text('Labor fees → mechanics'), findsOneWidget);
    // ₱450.00 appears twice: 'Labor revenue (service)' in the Sales card
    // plus the new handoff row.
    expect(find.text('₱450.00'), findsNWidgets(2));
    expect(find.text('Sale items → management'), findsOneWidget);
    expect(find.text('₱2,550.00'), findsOneWidget); // 3000 − 450
  });

  testWidgets('closed view: handoff rows from the frozen record; no drift '
      'section when nothing changed', (tester) async {
    final closing = _closing(DateTime(2026, 7, 24));
    await tester.pumpWidget(_harness(closing: closing));
    await tester.pump();
    await tester.pump();

    expect(find.text('Labor fees → mechanics'), findsOneWidget);
    expect(find.text('Sale items → management'), findsOneWidget);
    expect(find.text('₱1,550.00'), findsOneWidget); // 2000 − 450
    expect(find.text('After close'), findsNothing);
  });

  testWidgets('closed view: drift shows the shared AfterCloseCard with split',
      (tester) async {
    final closing = _closing(DateTime(2026, 7, 24));
    // One more cash labor-only sale (₱300) after close.
    await tester.pumpWidget(_harness(
      closing: closing,
      liveSummary: _summary(salesCount: 3, cash: 1750, labor: 750),
    ));
    await tester.pump();
    await tester.pump();

    expect(find.text('After close'), findsOneWidget);
    expect(find.text('Sale items'), findsOneWidget);
    expect(find.text('Labor fees'), findsOneWidget);
    expect(find.text('Updated for management'), findsOneWidget);
    expect(find.text('For mechanics (whole day)'), findsOneWidget);
    expect(find.text('₱750.00'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `flutter test test/presentation/mobile/screens/reports/end_of_day_screen_test.dart`
Expected: FAIL — first test can't find `ValueKey('counted-cash')`; the others can't find the handoff labels.

- [ ] **Step 3: Wire the screen**

In `lib/presentation/mobile/screens/reports/end_of_day_screen.dart`:

(a) **Review — key the counted-cash field.** In `_buildReview()`'s Cash reconciliation card, add a key to the Counted cash `ClosingField`:

```dart
                    ClosingField(
                      key: const ValueKey('counted-cash'),
                      label: 'Counted cash',
```

(b) **Review — handoff rows.** Replace:

```dart
                    if (variance != null) ...[
                      const SizedBox(height: 12),
                      VariancePanel(variance: variance),
                    ],
```

with:

```dart
                    if (counted != null && variance != null) ...[
                      const SizedBox(height: 12),
                      VariancePanel(variance: variance),
                      ClosingHandoffRows(
                        laborFees: draft.laborRevenue,
                        forManagement: counted - draft.laborRevenue,
                      ),
                    ],
```

(c) **Closed view — handoff rows.** In `_ClosedView`'s Cash reconciliation `ClosingSectionCard`, after `VariancePanel(variance: closing.variance),` add:

```dart
              ClosingHandoffRows(
                laborFees: closing.forMechanics,
                forManagement: closing.forManagement,
              ),
```

(d) **Closed view — shared card.** Replace the call site:

```dart
          if (showActivity) ...[
            const SizedBox(height: 12),
            _afterCloseCard(context, activity),
          ],
```

with:

```dart
          if (showActivity) ...[
            const SizedBox(height: 12),
            AfterCloseCard(activity: activity),
          ],
```

then DELETE the entire private `_afterCloseCard` method (the `Widget _afterCloseCard(BuildContext context, PostCloseActivity activity) { ... }` block). Keep `_peso` — it is still used by other rows in the closed view.

No import changes: the screen already imports `reports_widgets.dart`, which exports both new widgets.

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/presentation/mobile/screens/reports/end_of_day_screen_test.dart`
Expected: 3 tests PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/presentation/mobile/screens/reports/end_of_day_screen.dart test/presentation/mobile/screens/reports/end_of_day_screen_test.dart
git commit -m "feat(mobile): EOD handoff split (labor→mechanics / items→management) on review + closed views"
```

---

### Task 4: Closing History — handoff rows + live After Close on expand

**Files:**
- Modify: `lib/presentation/mobile/screens/reports/daily_closing_history_screen.dart`
- Test: `test/presentation/mobile/screens/reports/daily_closing_history_screen_test.dart` (new)

**Interfaces:**
- Consumes: `ClosingHandoffRows`, `AfterCloseCard` (barrel already imported); `dailyClosingDataProvider` (existing `FutureProvider.family<DailyClosingData, DateTime>`); `PostCloseActivity.between`; `c.forMechanics` / `c.forManagement`.
- Produces: no new API — `_ClosingTile` becomes a `ConsumerStatefulWidget` (still private).

- [ ] **Step 1: Write the failing widget tests**

Create `test/presentation/mobile/screens/reports/daily_closing_history_screen_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maki_mobile_pos/core/enums/payment_method.dart';
import 'package:maki_mobile_pos/domain/entities/daily_closing_entity.dart';
import 'package:maki_mobile_pos/domain/repositories/sale_repository.dart';
import 'package:maki_mobile_pos/presentation/mobile/screens/reports/daily_closing_history_screen.dart';
import 'package:maki_mobile_pos/presentation/providers/providers.dart';

final _date = DateTime(2026, 7, 20);

DailyClosingEntity _closing() => DailyClosingEntity(
      id: '2026-07-20',
      businessDate: _date,
      grossSales: 1000,
      netSales: 1000,
      totalDiscounts: 0,
      cashSales: 1450,
      nonCashSales: 0,
      gcashSales: 0,
      mayaSales: 0,
      totalExpenses: 0,
      cashExpenses: 0,
      salmonReceivable: 0,
      laborRevenue: 450,
      openingFloat: 0,
      expectedCash: 1450,
      // 2000 (not 1450) so 'Sale items → management' = ₱1,550.00 collides
      // with no other detail row (gross renders ₱1,000.00).
      countedCash: 2000,
      variance: 550,
      salesCount: 2,
      voidedCount: 0,
      closedBy: 'u',
      closedByName: 'U',
      closedAt: DateTime(2026, 7, 20, 18, 0),
    );

SalesSummary _summary({int salesCount = 2, double cash = 1450, double labor = 450}) =>
    SalesSummary(
      totalSalesCount: salesCount,
      voidedSalesCount: 0,
      grossAmount: 1000,
      totalDiscounts: 0,
      netAmount: 1000,
      totalCost: 0,
      totalProfit: 1000,
      byPaymentMethod: {PaymentMethod.cash: cash},
      laborRevenue: labor,
      laborProfit: labor,
    );

Widget _harness({SalesSummary? liveSummary}) => ProviderScope(
      overrides: [
        dailyClosingHistoryProvider
            .overrideWith((ref) => Stream.value([_closing()])),
        dailyClosingDataProvider.overrideWith((ref, date) async =>
            DailyClosingData(
              businessDate: date,
              summary: liveSummary ?? _summary(),
              expenses: const [],
            )),
      ],
      child: const MaterialApp(home: DailyClosingHistoryScreen()),
    );

Future<void> _expandFirstTile(WidgetTester tester) async {
  await tester.tap(find.byType(InkWell).first);
  await tester.pump();
  await tester.pump();
}

void main() {
  testWidgets('expanded day shows handoff rows; no After close when in sync',
      (tester) async {
    await tester.pumpWidget(_harness());
    await tester.pump();
    await tester.pump();

    expect(find.text('Labor fees → mechanics'), findsNothing);
    await _expandFirstTile(tester);

    expect(find.text('Labor fees → mechanics'), findsOneWidget);
    // Unique here: the history detail has no labor-revenue row of its own.
    expect(find.text('₱450.00'), findsOneWidget);
    expect(find.text('Sale items → management'), findsOneWidget);
    expect(find.text('₱1,550.00'), findsOneWidget); // 2000 − 450
    expect(find.text('After close'), findsNothing);
  });

  testWidgets('expanded day that drifted shows the After close block',
      (tester) async {
    // One extra cash labor-only sale (₱300) after that day closed.
    await tester.pumpWidget(
        _harness(liveSummary: _summary(salesCount: 3, cash: 1750, labor: 750)));
    await tester.pump();
    await tester.pump();
    await _expandFirstTile(tester);

    expect(find.text('After close'), findsOneWidget);
    expect(find.text('Updated for management'), findsOneWidget);
    expect(find.text('For mechanics (whole day)'), findsOneWidget);
    expect(find.text('₱750.00'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `flutter test test/presentation/mobile/screens/reports/daily_closing_history_screen_test.dart`
Expected: FAIL — handoff labels not found after expanding.

- [ ] **Step 3: Implement in `daily_closing_history_screen.dart`**

(a) Convert the tile to Riverpod:

```dart
class _ClosingTile extends ConsumerStatefulWidget {
  final DailyClosingEntity closing;

  const _ClosingTile({required this.closing});

  @override
  ConsumerState<_ClosingTile> createState() => _ClosingTileState();
}

class _ClosingTileState extends ConsumerState<_ClosingTile> {
```

(the body of `build` is unchanged — `widget.closing` references already compile).

(b) In `_buildDetail`, at the top of the method (before `return Container(`), derive the drift the same way `_ClosedView` does. The provider is only watched when the tile is expanded, since `_buildDetail` is only invoked then:

```dart
    // Live drift check — the same diff the closed EOD view performs. The
    // comparison draft must honor the snapshot's exclusions. Loading and
    // error states simply omit the After-close block.
    final liveData =
        ref.watch(dailyClosingDataProvider(c.businessDate)).valueOrNull;
    final liveDraft = liveData?.draftExcluding(c.excludedExpenseIds.toSet());
    final activity = liveDraft == null
        ? null
        : PostCloseActivity.between(closing: c, current: liveDraft);
```

(c) In the detail `Column`'s children, immediately after the `'Counted cash'` `ClosingKvRow`, insert:

```dart
          ClosingHandoffRows(
            laborFees: c.forMechanics,
            forManagement: c.forManagement,
            dense: true,
          ),
          if (activity != null && activity.hasChanged)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: AfterCloseCard(activity: activity),
            ),
```

No import changes needed (`reports_widgets.dart` barrel + `daily_closing_entity.dart` + `providers.dart` are already imported).

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/presentation/mobile/screens/reports/daily_closing_history_screen_test.dart`
Expected: 2 tests PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/presentation/mobile/screens/reports/daily_closing_history_screen.dart test/presentation/mobile/screens/reports/daily_closing_history_screen_test.dart
git commit -m "feat(mobile): closing history — handoff split + live After-close drift on expand"
```

---

### Task 5: Sales History — remove the reports icon

**Files:**
- Modify: `lib/presentation/mobile/screens/reports/sales_list_screen.dart`
- Test: `test/presentation/mobile/screens/reports/sales_list_screen_test.dart` (new)

**Interfaces:**
- Consumes: existing `SalesListScreen`, `currentUserProvider`, `salesByDateRangeProvider`.
- Produces: nothing — pure removal. `_navigateToSaleDetail` and everything else stays.

- [ ] **Step 1: Write the failing widget test**

Create `test/presentation/mobile/screens/reports/sales_list_screen_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:maki_mobile_pos/core/enums/enums.dart';
import 'package:maki_mobile_pos/domain/entities/entities.dart';
import 'package:maki_mobile_pos/presentation/mobile/screens/reports/sales_list_screen.dart';
import 'package:maki_mobile_pos/presentation/providers/providers.dart';

UserEntity _user() => UserEntity(
      id: 'u1',
      email: 'a@x.com',
      displayName: 'U',
      role: UserRole.admin,
      isActive: true,
      createdAt: DateTime(2026, 6, 1),
    );

void main() {
  testWidgets('AppBar has no reports shortcut icon', (tester) async {
    await tester.pumpWidget(ProviderScope(
      overrides: [
        currentUserProvider.overrideWith((ref) => Stream.value(_user())),
        salesByDateRangeProvider
            .overrideWith((ref, params) async => <SaleEntity>[]),
      ],
      child: const MaterialApp(home: SalesListScreen()),
    ));
    await tester.pump();
    await tester.pump();

    expect(find.text('Sales History'), findsOneWidget);
    expect(find.byIcon(LucideIcons.barChart3), findsNothing);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/presentation/mobile/screens/reports/sales_list_screen_test.dart`
Expected: FAIL — `find.byIcon(LucideIcons.barChart3)` finds one widget.

- [ ] **Step 3: Remove the icon and dead handler**

In `lib/presentation/mobile/screens/reports/sales_list_screen.dart`:

(a) Delete the whole `actions:` block from the AppBar (lines ~57–63):

```dart
        actions: [
          IconButton(
            icon: const Icon(LucideIcons.barChart3),
            tooltip: 'Reports',
            onPressed: () => _navigateToReports(context),
          ),
        ],
```

(b) Delete the now-dead method (lines ~381–383):

```dart
  void _navigateToReports(BuildContext context) {
    context.push(RoutePaths.salesReport);
  }
```

(c) Leave all imports as-is unless `flutter analyze` flags one unused (then remove exactly the flagged import). `LucideIcons` and `RoutePaths` are still used elsewhere in the file; `context.push` remains used by `_navigateToSaleDetail`.

- [ ] **Step 4: Run test + analyze to verify**

Run: `flutter test test/presentation/mobile/screens/reports/sales_list_screen_test.dart`
Expected: PASS.
Run: `flutter analyze lib/presentation/mobile/screens/reports/sales_list_screen.dart`
Expected: No issues (fix any unused-import hint per (c)).

- [ ] **Step 5: Commit**

```bash
git add lib/presentation/mobile/screens/reports/sales_list_screen.dart test/presentation/mobile/screens/reports/sales_list_screen_test.dart
git commit -m "feat(mobile): remove sales-report shortcut icon from Sales History app bar"
```

---

### Task 6: Full verification

**Files:** none new.

- [ ] **Step 1: Full test suite**

Run: `flutter test`
Expected: ALL tests pass (was 1141 before this feature; now ~1150).

- [ ] **Step 2: Analyzer**

Run: `flutter analyze`
Expected: `No issues found!`

- [ ] **Step 3: Commit any stragglers**

`git status --short` must be clean apart from intentionally-untracked files (`scripts/create-user.mjs`, `scripts/rename-product-category.mjs`). If a fix was needed in Steps 1–2, commit it:

```bash
git add -A -- lib test && git commit -m "fix(mobile): post-verification cleanups for EOD labor split"
```

After this task: run `/code-review` on the branch diff, then `/verify`, then finish the branch per `superpowers:finishing-a-development-branch` (per CLAUDE.md the dev loop's last steps happen outside this plan).
