# Avg Daily Info Button + Auto-SKU Convention Fix — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make the dashboard's Avg Daily figure mean "completed days only" and explain it with an info button, and stop the product form's auto-SKU from ever emitting the old pre-revamp SKU format.

**Architecture:** Two independent items sharing no code. Item 1 fixes a numerator/denominator mismatch in two Riverpod providers, then adds an optional info affordance to the shared dashboard stat card. Item 2 removes the name-based SKU fallback from both product forms so the field is category-driven or empty.

**Tech Stack:** Flutter + Riverpod + `mocktail` (mobile); React + Vite + TypeScript + Vitest + Testing Library (web).

**Spec:** `docs/superpowers/specs/2026-07-29-dashboard-info-and-auto-sku-design.md`

## Global Constraints

- Avg Daily counts **completed days only**. Both the sales total and the day count exclude today.
- On the 1st of the month there are no completed days: the provider issues **no query** and the card shows **`—`**, never `₱0.00`.
- With auto-generate on, the SKU field is **category-driven or empty**. It must never display a value in the old `SKU-A3B7K9M2` / `MLKCHCLT-A3B7K9` format.
- The product name must not drive the SKU on any surface, in any code path.
- Mobile and web behave identically for auto-SKU. Where both show the same message, the wording is byte-identical.
- **Keep** `SkuGenerator.generateForName` / `generate` (mobile) and `generateSku` (web). Receiving still uses them (`receiving_import_resolver.dart:77`, `planReceive.ts:111`, `applyReceivedItems.ts:112`, `ReceivingEntryPage.tsx:50`). Do not touch Receiving.
- Editing an existing product is unchanged — auto-SKU has always been create-only.
- Exact copy, used verbatim:
  - Avg Daily dialog title: `Avg Daily`
  - Avg Daily dialog body, two paragraphs:
    - `Your average sales per day this month, counting only days that have finished.`
    - `It adds up sales from the 1st up to yesterday, then divides by that many days. Today isn't counted yet because it's still going.`
  - SKU hint, no category chosen: `Pick a category to generate the SKU.`
  - SKU hint, category has no code: `This category has no code — pick another, or turn off auto-generate and type a SKU.`
- Mobile gates: `flutter analyze` clean, `flutter test` passing. Web gates from `web_admin/`: `npm run typecheck`, `npm run test`, `npm run build`.
- No Firestore rules, index, or schema change. Deploy nothing.
- End every commit message with this trailer on its own line after a blank line:
  `Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>`
- **Every assertion must be able to fail.** On the previous branch, six plan-authored
  tests passed regardless of whether the implementation worked, and every one had to be
  caught in review. Before committing a test, name the specific broken implementation it
  would catch; where it is cheap, temporarily break the implementation, confirm the test
  fails, and restore it (never commit the broken variant). If an assertion in this plan
  looks like it would pass against an obviously wrong implementation, say so in your
  report rather than letting it through — flagging it is the expected behavior, not a
  failure.

## File Structure

| File | Responsibility |
|---|---|
| `lib/presentation/providers/sale_provider.dart:165-203` | Modify — rename the summary provider, move its end bound to end-of-yesterday, make avg-daily nullable |
| `lib/presentation/mobile/screens/dashboard/dashboard_screen.dart:130-132` | Modify — follow the rename |
| `lib/presentation/shared/widgets/dashboard/sales_summary_section.dart` | Modify — optional `onInfo` on `_StatCard`, wire it on Avg Daily only |
| `test/presentation/providers/sale_provider_business_day_test.dart` | Modify — rename group, new range and null expectations |
| `test/presentation/widgets/dashboard_screen_test.dart:51` | Modify — follow the rename |
| `lib/presentation/mobile/screens/inventory/product_form_screen.dart` | Modify — drop name-based generation, blank + hint, remove regenerate |
| `web_admin/src/presentation/features/inventory/InventoryFormPage.tsx` | Modify — same, plus remove the Enter-submit SKU backfill |
| `web_admin/src/presentation/features/inventory/InventoryFormPage.test.tsx` | Modify — label change + new cases |

---

### Task 1: Avg Daily — make the maths mean completed days

**Files:**
- Modify: `lib/presentation/providers/sale_provider.dart:165-203`
- Modify: `lib/presentation/mobile/screens/dashboard/dashboard_screen.dart:130-132`
- Modify: `test/presentation/widgets/dashboard_screen_test.dart:51`
- Test: `test/presentation/providers/sale_provider_business_day_test.dart:107-144`

**Interfaces:**
- Consumes: `monthToDate(DateTime)` → `MonthToDate{start, end, daysElapsed}` and `avgDailyFromGross(double, int)` from `lib/core/utils/week_range.dart` (both unchanged); `SalesSummary.empty()` from `lib/domain/repositories/sale_repository.dart:300`.
- Produces:
  - `monthCompletedDaysSummaryProvider` — `FutureProvider<SalesSummary>` (renamed from `monthToDateSummaryProvider`)
  - `avgDailySalesProvider` — now `Provider<AsyncValue<double?>>`, `null` when there are no completed days

- [ ] **Step 1: Rewrite the two provider tests**

In `test/presentation/providers/sale_provider_business_day_test.dart`, replace the whole `group('monthToDateSummaryProvider', ...)` block (lines 107-144) with:

```dart
  group('monthCompletedDaysSummaryProvider', () {
    test('queries the 1st through end of YESTERDAY, and follows the flip',
        () async {
      final repo = _MockSaleRepository();
      when(() => repo.getSalesSummary(
            startDate: any(named: 'startDate'),
            endDate: any(named: 'endDate'),
          )).thenAnswer((_) async => SalesSummary.empty());

      final dayNotifier = _FixedBusinessDayNotifier(DateTime(2026, 7, 24));
      final container = ProviderContainer(overrides: [
        currentUserProvider.overrideWith((ref) => Stream.value(_admin())),
        saleRepositoryProvider.overrideWithValue(repo),
        businessDayProvider.overrideWith(() => dayNotifier),
      ]);
      addTearDown(container.dispose);
      final sub =
          container.listen(monthCompletedDaysSummaryProvider, (_, __) {});
      addTearDown(sub.close);

      await container.read(monthCompletedDaysSummaryProvider.future);
      var captured = verify(() => repo.getSalesSummary(
            startDate: captureAny(named: 'startDate'),
            endDate: captureAny(named: 'endDate'),
          )).captured;
      expect(captured[0], DateTime(2026, 7, 1));
      // End of the 23rd — today (the 24th) is NOT included.
      expect(captured[1], DateTime(2026, 7, 23, 23, 59, 59, 999));

      dayNotifier.set(DateTime(2026, 7, 25));
      await Future<void>.delayed(Duration.zero);
      await container.read(monthCompletedDaysSummaryProvider.future);
      captured = verify(() => repo.getSalesSummary(
            startDate: captureAny(named: 'startDate'),
            endDate: captureAny(named: 'endDate'),
          )).captured;
      expect(captured[0], DateTime(2026, 7, 1));
      expect(captured[1], DateTime(2026, 7, 24, 23, 59, 59, 999));
    });

    test('issues NO query on the 1st — there are no completed days', () async {
      final repo = _MockSaleRepository();
      when(() => repo.getSalesSummary(
            startDate: any(named: 'startDate'),
            endDate: any(named: 'endDate'),
          )).thenAnswer((_) async => SalesSummary.empty());

      final container = ProviderContainer(overrides: [
        currentUserProvider.overrideWith((ref) => Stream.value(_admin())),
        saleRepositoryProvider.overrideWithValue(repo),
        businessDayProvider
            .overrideWith(() => _FixedBusinessDayNotifier(DateTime(2026, 7, 1))),
      ]);
      addTearDown(container.dispose);

      final summary =
          await container.read(monthCompletedDaysSummaryProvider.future);

      expect(summary.grossAmount, 0);
      verifyNever(() => repo.getSalesSummary(
            startDate: any(named: 'startDate'),
            endDate: any(named: 'endDate'),
          ));
    });
  });

  group('avgDailySalesProvider — completed-days average', () {
    Future<AsyncValue<double?>> readAvg(DateTime day, double gross) async {
      final repo = _MockSaleRepository();
      when(() => repo.getSalesSummary(
            startDate: any(named: 'startDate'),
            endDate: any(named: 'endDate'),
          )).thenAnswer((_) async => SalesSummary.empty().copyWith(
                grossAmount: gross,
              ));

      final container = ProviderContainer(overrides: [
        currentUserProvider.overrideWith((ref) => Stream.value(_admin())),
        saleRepositoryProvider.overrideWithValue(repo),
        businessDayProvider
            .overrideWith(() => _FixedBusinessDayNotifier(day)),
      ]);
      addTearDown(container.dispose);
      final sub =
          container.listen(monthCompletedDaysSummaryProvider, (_, __) {});
      addTearDown(sub.close);
      await container.read(monthCompletedDaysSummaryProvider.future);
      return container.read(avgDailySalesProvider);
    }

    test('divides by completed days only', () async {
      // The 25th → 24 completed days. 2400 / 24 = 100.
      final avg = await readAvg(DateTime(2026, 7, 25), 2400);
      expect(avg.valueOrNull, 100);
    });

    test('returns null on the 1st rather than a misleading zero', () async {
      final avg = await readAvg(DateTime(2026, 7, 1), 0);
      expect(avg.valueOrNull, isNull);
    });
  });
```

If `SalesSummary` has no `copyWith`, construct the summary with its normal constructor setting `grossAmount` and zeroes elsewhere — check `lib/domain/repositories/sale_repository.dart:235-300` and use whichever the class actually offers. Do not add a `copyWith` just for the test.

Delete the pre-existing `group('avgDailySalesProvider', ...)` block that follows (it starts around line 146 and asserts the old divide-including-today behavior) — the two groups above replace it. Keep the `todaysSalesSummaryProvider` group untouched.

- [ ] **Step 2: Run the tests to verify they fail**

Run: `flutter test test/presentation/providers/sale_provider_business_day_test.dart`
Expected: FAIL — `monthCompletedDaysSummaryProvider` is undefined.

- [ ] **Step 3: Rewrite the providers**

Replace `lib/presentation/providers/sale_provider.dart:165-203` with:

```dart
/// Sales summary over the *completed* days of the current month
/// (1st 00:00 → end of yesterday). Today is deliberately excluded: it is
/// still in progress, and dividing a partial day's takings by a whole-day
/// count inflates the Avg Daily figure.
final monthCompletedDaysSummaryProvider =
    FutureProvider<SalesSummary>((ref) async {
  final actor = _requireActor(ref);
  // Watch the clock (not a raw DateTime.now() snapshot) so a midnight
  // rollover re-runs this query with one more completed day.
  final today = ref.watch(businessDayProvider);
  final m = monthToDate(today);

  // On the 1st nothing has completed yet — skip the round-trip entirely.
  if (m.daysElapsed <= 0) return SalesSummary.empty();

  final yesterdayEnd = DateTime(today.year, today.month, today.day)
      .subtract(const Duration(milliseconds: 1));

  final result = await ref.watch(getSalesReportUseCaseProvider).execute(
        actor: actor,
        startDate: m.start,
        endDate: yesterdayEnd,
      );
  if (!result.success) {
    throw AppExceptionWrapper(
        message: result.errorMessage ?? 'Failed to load summary',
        code: result.errorCode);
  }
  return result.data!;
});

/// Average daily gross sales across the *completed* days of this month.
///
/// Total from [monthCompletedDaysSummaryProvider] (1st → end of yesterday)
/// divided by the number of completed days, so numerator and denominator
/// cover the same span. Returns null on the 1st — there is no completed day
/// to average, and the card renders `—` rather than a misleading ₱0.
final avgDailySalesProvider = Provider<AsyncValue<double?>>((ref) {
  final summaryAsync = ref.watch(monthCompletedDaysSummaryProvider);
  final today = ref.watch(businessDayProvider);
  final daysElapsed = monthToDate(today).daysElapsed;
  if (daysElapsed <= 0) return const AsyncValue.data(null);
  return summaryAsync.whenData<double?>(
    (summary) => avgDailyFromGross(summary.grossAmount, daysElapsed),
  );
});
```

- [ ] **Step 4: Follow the rename at both call sites**

In `lib/presentation/mobile/screens/dashboard/dashboard_screen.dart` around line 130-132, update the comment and the invalidate:

```dart
    // Feeds the Avg Daily Sales card — without this, its completed-days query
    // keeps yesterday's answer after a pull-to-refresh.
    ref.invalidate(monthCompletedDaysSummaryProvider);
```

In `test/presentation/widgets/dashboard_screen_test.dart:51`, rename the override:

```dart
          monthCompletedDaysSummaryProvider.overrideWith((ref) async => emptySummary),
```

- [ ] **Step 5: Run the tests to verify they pass**

Run: `flutter test test/presentation/providers/sale_provider_business_day_test.dart test/presentation/widgets/dashboard_screen_test.dart`
Expected: PASS.

- [ ] **Step 6: Confirm no stale references and run the full gates**

Run:

```bash
grep -rn "monthToDateSummaryProvider" --include="*.dart" lib test
flutter analyze && flutter test
```

Expected: the grep returns nothing; analyze clean; suite passing.

- [ ] **Step 7: Commit**

```bash
git add lib/presentation/providers/sale_provider.dart lib/presentation/mobile/screens/dashboard/dashboard_screen.dart test/presentation/providers/sale_provider_business_day_test.dart test/presentation/widgets/dashboard_screen_test.dart
git commit -m "fix(dashboard): average daily sales over completed days only

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>"
```

---

### Task 2: Avg Daily — the info button

**Files:**
- Modify: `lib/presentation/shared/widgets/dashboard/sales_summary_section.dart:41-47` and `:219-260`
- Test: `test/presentation/widgets/sales_summary_section_test.dart` (create)

**Interfaces:**
- Consumes: `avgDailySalesProvider` as `AsyncValue<double?>` from Task 1; `AppDialog` from `lib/presentation/shared/widgets/common/app_dialog.dart` (named params `title`, `content`, `leadingIcon`, `intent`, `onClose`, `actions`).
- Produces: `_StatCard` gains `final VoidCallback? onInfo;` as its last optional named parameter.

- [ ] **Step 1: Write the failing test**

Create `test/presentation/widgets/sales_summary_section_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:maki_mobile_pos/domain/repositories/sale_repository.dart';
import 'package:maki_mobile_pos/presentation/providers/sale_provider.dart';
import 'package:maki_mobile_pos/presentation/shared/widgets/dashboard/sales_summary_section.dart';

void main() {
  Future<void> pump(WidgetTester tester, {required double? avgDaily}) async {
    await tester.pumpWidget(ProviderScope(
      overrides: [
        todaysSalesSummaryProvider
            .overrideWith((ref) async => SalesSummary.empty()),
        avgDailySalesProvider.overrideWithValue(AsyncValue.data(avgDaily)),
      ],
      child: const MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: SalesSummarySection(isAdmin: true),
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();
  }

  testWidgets('shows a dash when there is no completed day yet',
      (tester) async {
    await pump(tester, avgDaily: null);
    expect(find.text('—'), findsOneWidget);
  });

  testWidgets('exactly one info button — on the Avg Daily card',
      (tester) async {
    await pump(tester, avgDaily: 1234);
    expect(find.byIcon(LucideIcons.info), findsOneWidget);
  });

  testWidgets('tapping the info button explains the completed-days rule',
      (tester) async {
    await pump(tester, avgDaily: 1234);

    await tester.tap(find.byIcon(LucideIcons.info));
    await tester.pumpAndSettle();

    expect(
      find.text(
        'Your average sales per day this month, counting only days that '
        'have finished.',
      ),
      findsOneWidget,
    );
    expect(
      find.text(
        "It adds up sales from the 1st up to yesterday, then divides by that "
        "many days. Today isn't counted yet because it's still going.",
      ),
      findsOneWidget,
    );
  });
}
```

If `avgDailySalesProvider` cannot be overridden with `overrideWithValue` because it is a plain `Provider` returning `AsyncValue<double?>`, use `avgDailySalesProvider.overrideWith((ref) => AsyncValue.data(avgDaily))` instead — pick whichever the provider's type accepts and keep the rest of the test identical.

- [ ] **Step 2: Run to verify it fails**

Run: `flutter test test/presentation/widgets/sales_summary_section_test.dart`
Expected: FAIL — no `LucideIcons.info` is rendered.

- [ ] **Step 3: Add `onInfo` to `_StatCard`**

In `lib/presentation/shared/widgets/dashboard/sales_summary_section.dart`, add the field and constructor parameter to `_StatCard` (currently line 219-232):

```dart
  final IconData icon;
  final String label;
  final String value;
  final Color? iconColor;
  final String? subtitle;

  /// When supplied, a small ⓘ sits opposite the leading icon; tapping it is
  /// how the metric explains itself. Only cards whose meaning isn't obvious
  /// from the label pass this.
  final VoidCallback? onInfo;

  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    this.iconColor,
    this.subtitle,
    this.onInfo,
  });
```

Then replace the bare leading `Icon(...)` in its `build` (currently line 250) with a row that keeps the icon left and puts the ⓘ right:

```dart
          Row(
            children: [
              Icon(icon, size: 18, color: iconColor ?? muted),
              if (onInfo != null) ...[
                const Spacer(),
                InkWell(
                  onTap: onInfo,
                  customBorder: const CircleBorder(),
                  child: Padding(
                    padding: const EdgeInsets.all(2),
                    child: Icon(LucideIcons.info, size: 14, color: muted),
                  ),
                ),
              ],
            ],
          ),
```

- [ ] **Step 4: Wire it on the Avg Daily card only**

Replace the Avg Daily `_StatCard` (currently `sales_summary_section.dart:41-47`) with:

```dart
                      child: _StatCard(
                        icon: LucideIcons.barChart3,
                        label: 'Avg Daily',
                        value: avgDaily != null
                            ? _money(avgDaily, compact: true)
                            : '—',
                        onInfo: () => _showAvgDailyInfo(context),
                      ),
```

Add this top-level function at the bottom of the same file:

```dart
/// Explains what the Avg Daily figure actually averages. Tap-to-open rather
/// than a long-press tooltip — a tooltip is undiscoverable on a phone.
void _showAvgDailyInfo(BuildContext context) {
  final theme = Theme.of(context);
  showDialog<void>(
    context: context,
    barrierColor:
        AppDialog.scrimColor(theme.brightness == Brightness.dark),
    builder: (context) => AppDialog(
      title: 'Avg Daily',
      leadingIcon: LucideIcons.barChart3,
      onClose: () => Navigator.of(context).pop(),
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Your average sales per day this month, counting only days that '
            'have finished.',
            style: theme.textTheme.bodyMedium?.copyWith(height: 1.45),
          ),
          const SizedBox(height: 12),
          Text(
            "It adds up sales from the 1st up to yesterday, then divides by "
            "that many days. Today isn't counted yet because it's still "
            "going.",
            style: theme.textTheme.bodySmall?.copyWith(
              height: 1.45,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    ),
  );
}
```

Add the `AppDialog` import if the file does not already have it:

```dart
import 'package:maki_mobile_pos/presentation/shared/widgets/common/common_widgets.dart';
```

Check whether `common_widgets.dart` re-exports `app_dialog.dart`; if it does not, import `app_dialog.dart` directly.

**Note on the test's string matching:** `find.text` compares the fully concatenated string, so the adjacent-literal line breaks above must produce exactly the two sentences in the Global Constraints. Verify character-for-character — a doubled or missing space between concatenated literals is the easy mistake here.

- [ ] **Step 5: Run the test to verify it passes**

Run: `flutter test test/presentation/widgets/sales_summary_section_test.dart`
Expected: PASS (3 tests).

- [ ] **Step 6: Full mobile gates**

Run: `flutter analyze && flutter test`
Expected: analyze clean, suite passing.

- [ ] **Step 7: Commit**

```bash
git add lib/presentation/shared/widgets/dashboard/sales_summary_section.dart test/presentation/widgets/sales_summary_section_test.dart
git commit -m "feat(dashboard): explain Avg Daily with an info button

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>"
```

---

### Task 3: Mobile auto-SKU — category-driven or empty

**Files:**
- Modify: `lib/presentation/mobile/screens/inventory/product_form_screen.dart` — lines 142-145, 461-483, 525-551, 718-742, 750-765
- Test: `test/presentation/widgets/product_form_auto_sku_test.dart` (create)

**Interfaces:**
- Consumes: `SkuGenerator.composeAutoSku(String, int)` and `SkuGenerator.matchesAutoPattern(String, String)`, both unchanged; `CategoryRepository.peekNextSequence(String)`.
- Produces: a new private field `String? _skuHint` on `_ProductFormScreenState`, rendered as the SKU field's `helperText` while creating with auto-generate on.

- [ ] **Step 1: Write the failing test**

Create `test/presentation/widgets/product_form_auto_sku_test.dart`. Model the harness on the existing `test/presentation/widgets/product_form_screen_test.dart` — reuse its mock repositories, its `ProviderScope` overrides and its `Key('product-sku-field')` finder rather than inventing new ones. Read that file first and copy its `setUp` verbatim, adding a mock `CategoryRepository` whose `peekNextSequence` is stubbed per test.

```dart
  group('ProductFormScreen — auto-SKU (create mode)', () {
    testWidgets('opens with an empty SKU and the pick-a-category hint',
        (tester) async {
      await pumpCreateScreen(tester, categories: [_uncodedCategory]);

      expect(skuField(tester).controller!.text, isEmpty);
      expect(find.text('Pick a category to generate the SKU.'), findsOneWidget);
    });

    testWidgets('typing and blurring the name generates nothing',
        (tester) async {
      await pumpCreateScreen(tester, categories: [_uncodedCategory]);

      await tester.enterText(find.byKey(const Key('product-name-field')),
          'MILK CHOCOLATE');
      await tester.pumpAndSettle();
      // Move focus away to fire the blur handler.
      await tester.tap(find.byKey(const Key('product-sku-field')));
      await tester.pumpAndSettle();

      expect(skuField(tester).controller!.text, isEmpty);
    });

    testWidgets('choosing a coded category fills the 8-digit SKU',
        (tester) async {
      when(() => categoryRepo.peekNextSequence('0007'))
          .thenAnswer((_) async => 5);
      await pumpCreateScreen(tester, categories: [_codedCategory]);

      await selectCategory(tester, _codedCategory.name);

      expect(skuField(tester).controller!.text, '00070005');
      expect(find.text('Pick a category to generate the SKU.'), findsNothing);
    });

    testWidgets('choosing an uncoded category leaves it empty and says why',
        (tester) async {
      await pumpCreateScreen(tester, categories: [_uncodedCategory]);

      await selectCategory(tester, _uncodedCategory.name);

      expect(skuField(tester).controller!.text, isEmpty);
      expect(
        find.text('This category has no code — pick another, or turn off '
            'auto-generate and type a SKU.'),
        findsOneWidget,
      );
    });

    testWidgets('a failed peek leaves it empty rather than falling back',
        (tester) async {
      when(() => categoryRepo.peekNextSequence('0007'))
          .thenThrow(Exception('offline'));
      await pumpCreateScreen(tester, categories: [_codedCategory]);

      await selectCategory(tester, _codedCategory.name);
      await tester.pumpAndSettle();

      expect(skuField(tester).controller!.text, isEmpty);
    });

    testWidgets('no regenerate button while auto-generate is on',
        (tester) async {
      await pumpCreateScreen(tester, categories: [_codedCategory]);

      expect(find.byIcon(LucideIcons.refreshCw), findsNothing);
    });
  });
```

Write `pumpCreateScreen`, `selectCategory`, `skuField`, `_codedCategory` (code `'0007'`) and `_uncodedCategory` (code `null`) as helpers in this file, following the existing test's patterns. If the name field has no key, add `key: const Key('product-name-field')` to it as part of Step 3 — a test-only key on a field the test must drive is acceptable and matches the existing `product-sku-field` key.

- [ ] **Step 2: Run to verify it fails**

Run: `flutter test test/presentation/widgets/product_form_auto_sku_test.dart`
Expected: FAIL — the field is pre-seeded with a `SKU-…` value and the hint does not exist.

- [ ] **Step 3: Remove the seed and add the hint field**

In `_ProductFormScreenState`, add the hint field next to `_autoGenerateSku` (near line 73):

```dart
  // Helper text under the SKU field while creating with auto-generate on.
  // Null once a coded category has filled the field.
  String? _skuHint = 'Pick a category to generate the SKU.';
```

Delete the seeding block at lines 142-145 entirely — the two lines that set
`_skuController.text = SkuGenerator.generateForName(null);` and their comment.
The field now starts empty.

- [ ] **Step 4: Stop the name from driving the SKU**

Replace `_onNameFocusChange` (lines 461-471) so it no longer touches the SKU:

```dart
  void _onNameFocusChange() {
    // The product name no longer drives the SKU — auto-generate is
    // category-driven or nothing. Kept as a hook for future name-blur work.
  }
```

If nothing else uses `_nameFocusNode`, remove the listener registration and the
node itself rather than leaving a dead handler — check its other uses first and
prefer deletion when it has none.

Delete `_regenerateSku` (lines 473-483) entirely.

- [ ] **Step 5: Make category selection the only source**

Replace `_applyCategoryForSku` (lines 525-551):

```dart
  /// Re-derives the SKU for [category] when auto-generate is on and we're
  /// creating (no-op on edit — auto-SKU is a create-time convenience only).
  /// A category with a `code` peeks the next sequence and composes
  /// `code+sequence`. Anything else — no category, no code, or a failed peek
  /// — leaves the field EMPTY with an explanatory hint. It must never fall
  /// back to the old name-based format. [_skuPeekToken] guards a stale
  /// response from clobbering the field after a later switch superseded it.
  void _applyCategoryForSku(CategoryEntity? category) {
    if (widget.isEditing || !_autoGenerateSku) return;
    final token = ++_skuPeekToken;
    final code = category?.code;
    if (code == null) {
      setState(() {
        _skuController.text = '';
        _skuHint = category == null
            ? 'Pick a category to generate the SKU.'
            : 'This category has no code — pick another, or turn off '
                'auto-generate and type a SKU.';
      });
      return;
    }
    ref
        .read(categoryRepositoryProvider(CategoryKind.product))
        .peekNextSequence(code)
        .then((sequence) {
      if (!mounted || token != _skuPeekToken || !_autoGenerateSku) return;
      setState(() {
        _skuController.text = SkuGenerator.composeAutoSku(code, sequence);
        _skuHint = null;
      });
    }).catchError((_) {
      if (!mounted || token != _skuPeekToken || !_autoGenerateSku) return;
      setState(() {
        _skuController.text = '';
        _skuHint = 'This category has no code — pick another, or turn off '
            'auto-generate and type a SKU.';
      });
    });
  }
```

- [ ] **Step 6: Update the field and the toggle copy**

In the SKU `TextFormField` (lines 750-765), show the hint while creating with
auto on, and drop the regenerate button:

```dart
                              decoration: InputDecoration(
                                labelText: 'SKU *',
                                prefixIcon: const Icon(LucideIcons.qrCode),
                                helperText: (isCreating && _autoGenerateSku)
                                    ? _skuHint
                                    : (!isCreating &&
                                            userRole == UserRole.admin)
                                        ? 'Changing the SKU keeps past sales & '
                                            'receiving history intact.'
                                        : null,
                                helperMaxLines: 2,
                              ),
```

Update the toggle's subtitle (line 723-728) — it currently claims a random
suffix, which is no longer true:

```dart
                                subtitle: Text(
                                  _autoGenerateSku
                                      ? 'Built from the category code'
                                      : 'Type the SKU manually',
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
```

When the toggle is switched **off**, clear the hint so it does not linger over a
manual field; when switched back **on**, `_applyCategoryForSku` already resets
it. In the `onChanged` at line 730-741, add `_skuHint = null;` inside the
`setState` before the `if (v)` branch.

- [ ] **Step 7: Run the tests to verify they pass**

Run: `flutter test test/presentation/widgets/product_form_auto_sku_test.dart test/presentation/widgets/product_form_screen_test.dart`
Expected: PASS. The pre-existing form test covers edit-mode gating and the SKU-change dialog, both untouched by this task — if it fails, stop and report rather than editing its assertions.

- [ ] **Step 8: Confirm the name-based generator is gone from the form**

Run:

```bash
grep -n "generateForName" lib/presentation/mobile/screens/inventory/product_form_screen.dart
```

Expected: no output. (It must still exist in `receiving_import_resolver.dart` — do not remove it from `SkuGenerator`.)

- [ ] **Step 9: Full mobile gates**

Run: `flutter analyze && flutter test`
Expected: analyze clean, suite passing.

- [ ] **Step 10: Commit**

```bash
git add lib/presentation/mobile/screens/inventory/product_form_screen.dart test/presentation/widgets/product_form_auto_sku_test.dart
git commit -m "fix(inventory): auto-SKU is category-driven or empty on mobile

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>"
```

---

### Task 4: Web auto-SKU — same behavior, same words

**Files:**
- Modify: `web_admin/src/presentation/features/inventory/InventoryFormPage.tsx` — lines 195-235, 417-426, 465-504
- Test: `web_admin/src/presentation/features/inventory/InventoryFormPage.test.tsx`

**Interfaces:**
- Consumes: `composeAutoSku`, `matchesAutoPattern` from `@/domain/products/sku` (unchanged); `categoryRepo.peekNextSequence`.
- Produces: a `skuHint` state string rendered under the SKU field, carrying the same two messages as mobile.

- [ ] **Step 1: Write the failing tests**

In `web_admin/src/presentation/features/inventory/InventoryFormPage.test.tsx`, add to the `create-mode auto-SKU` describe block:

```tsx
  it('opens with an empty SKU and the pick-a-category hint', async () => {
    renderForm();
    expect(screen.getByLabelText('SKU')).toHaveValue('');
    expect(
      await screen.findByText('Pick a category to generate the SKU.'),
    ).toBeInTheDocument();
  });

  it('typing a name generates nothing', async () => {
    renderForm();
    await userEvent.type(screen.getByLabelText('Name'), 'MILK CHOCOLATE');
    await userEvent.tab();
    expect(screen.getByLabelText('SKU')).toHaveValue('');
  });

  it('an uncoded category leaves the SKU empty and says why', async () => {
    renderForm();
    await selectCategory(UNCODED_CATEGORY_NAME);
    expect(screen.getByLabelText('SKU')).toHaveValue('');
    expect(
      screen.getByText(
        'This category has no code — pick another, or turn off auto-generate and type a SKU.',
      ),
    ).toBeInTheDocument();
  });

  it('no regenerate button while auto-generate is on', () => {
    renderForm();
    expect(screen.queryByRole('button', { name: /regenerate/i })).toBeNull();
  });

  it('submitting with an empty SKU raises the required error, not a generated one', async () => {
    renderForm();
    await userEvent.type(screen.getByLabelText('Name'), 'WIDGET');
    await userEvent.click(screen.getByRole('button', { name: /save|create/i }));
    expect(await screen.findByText('SKU is required')).toBeInTheDocument();
    expect(create).not.toHaveBeenCalled();
  });
```

Reuse the file's existing `renderForm` / category-selection helpers and its
existing fixture categories — read the top of the file first and match its
naming. Add an uncoded fixture category if one does not already exist. The
existing test at line 126 uses `getByLabelText('Auto-generate SKU from name')`;
update that string to the new label from Step 3.

- [ ] **Step 2: Run to verify they fail**

Run (from `web_admin/`): `npm run test -- InventoryFormPage`
Expected: FAIL — the SKU field is pre-filled and no hint exists.

- [ ] **Step 3: Remove the name-based fallbacks**

In `InventoryFormPage.tsx`:

Add hint state next to `autoSku` (near line 78):

```tsx
  const [skuHint, setSkuHint] = useState<string | null>(
    'Pick a category to generate the SKU.',
  );
```

Delete `regenerateSku` (lines 195-201) entirely.

Replace `applyCategoryForSku` (lines 216-235):

```tsx
  /** Re-derives the SKU for `category` when auto-generate is on (`autoOn`
   *  passed explicitly rather than read from state, since this can be invoked
   *  in the same handler that just flipped the checkbox). No-op when editing.
   *  A coded category peeks the next sequence and composes `code+sequence`;
   *  anything else — no category, no code, or a failed peek — leaves the
   *  field EMPTY with an explanatory hint. It must never fall back to the old
   *  name-based format. `skuPeekToken` guards a stale response from
   *  clobbering the field after a later switch superseded it. */
  const applyCategoryForSku = (category: Category | undefined, autoOn: boolean) => {
    if (isEditing || !autoOn) return;
    const token = ++skuPeekToken.current;
    const code = category?.code;
    if (code === undefined) {
      setValue('sku', '', { shouldValidate: false });
      setSkuHint(
        category === undefined
          ? 'Pick a category to generate the SKU.'
          : 'This category has no code — pick another, or turn off auto-generate and type a SKU.',
      );
      return;
    }
    categoryRepo
      .peekNextSequence(code)
      .then((sequence) => {
        if (token !== skuPeekToken.current) return;
        if (categoryEntityForName(getValues('category') ?? '')?.code !== code) return;
        setValue('sku', composeAutoSku(code, sequence), { shouldValidate: true });
        setSkuHint(null);
      })
      .catch(() => {
        if (token !== skuPeekToken.current) return;
        setValue('sku', '', { shouldValidate: false });
        setSkuHint(
          'This category has no code — pick another, or turn off auto-generate and type a SKU.',
        );
      });
  };
```

- [ ] **Step 4: Remove the Enter-submit backfill**

The comment at lines 417-420 describes a safety net that only made sense while
the name filled the SKU on blur. With that gone, the backfill would inject an
old-format SKU on an Enter-submit. Replace `onFormSubmit` (lines 421-426):

```tsx
  const onFormSubmit = (e: FormEvent<HTMLFormElement>) => {
    void handleSubmit(onSubmit)(e);
  };
```

An empty SKU now correctly raises the resolver's "SKU is required".

- [ ] **Step 5: Update the label, drop the button, render the hint**

Change the checkbox label (line 480) — it names the wrong source:

```tsx
              Auto-generate SKU from category
```

In the SKU `Field` (lines 484-504), remove the `skuLocked ? <button…Regenerate…> : null` block and its wrapping flex `div` if the input is then its only child, and render the hint underneath:

```tsx
          <Field label="SKU" error={errors.sku?.message}
            input={
              <input
                type="text"
                readOnly={skuLocked}
                className={cn(inputCls(!!errors.sku), skuLocked && 'bg-light-subtle text-light-text-secondary')}
                {...skuField}
                onChange={(e) => { upperizeInput(e); void skuField.onChange(e); }}
              />
            } />
          {skuLocked && skuHint ? (
            <p className="text-[12px] text-light-text-hint">{skuHint}</p>
          ) : null}
```

Remove the now-unused `ArrowPathIcon` import if nothing else in the file uses it, and `generateSku` from the `@/domain/products/sku` import if this file no longer references it.

- [ ] **Step 6: Run the tests to verify they pass**

Run (from `web_admin/`): `npm run test -- InventoryFormPage`
Expected: PASS.

- [ ] **Step 7: Confirm the fallback is gone from this file**

Run (from `web_admin/`):

```bash
grep -n "generateSku" src/presentation/features/inventory/InventoryFormPage.tsx
```

Expected: no output. (It must still exist in `planReceive.ts`, `applyReceivedItems.ts` and `ReceivingEntryPage.tsx` — do not touch Receiving.)

- [ ] **Step 8: Full web gates**

Run (from `web_admin/`): `npm run typecheck && npm run test && npm run build`
Expected: all clean.

- [ ] **Step 9: Commit**

```bash
git add web_admin/src/presentation/features/inventory
git commit -m "fix(web): auto-SKU is category-driven or empty

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>"
```

---

### Task 5: Cross-surface check and final gates

**Files:** none modified.

**Interfaces:**
- Consumes: everything above.
- Produces: a verified branch and an explicit statement of what needs deploying.

- [ ] **Step 1: Confirm the two surfaces use byte-identical copy**

Run:

```bash
grep -rn "Pick a category to generate the SKU." --include="*.dart" --include="*.tsx" lib web_admin/src
grep -rn "This category has no code" --include="*.dart" --include="*.tsx" lib web_admin/src
```

Expected: each string appears on both surfaces. Compare the two no-code strings character by character — mobile's is built from adjacent string literals across a line break, which is where a doubled or missing space creeps in.

- [ ] **Step 2: Confirm Receiving is untouched**

Run:

```bash
git diff --stat main...HEAD -- lib/domain/usecases/receiving web_admin/src/data/receiving web_admin/src/presentation/features/receiving
```

Expected: no output — Receiving still mints old-format SKUs by design, and this branch must not have changed it.

- [ ] **Step 3: Run every mobile gate**

Run: `flutter analyze && flutter test`
Expected: analyze clean, all tests passing. Record the actual counts.

- [ ] **Step 4: Run every web gate**

Run (from `web_admin/`): `npm run typecheck && npm run test && npm run build`
Expected: all clean. Record the actual counts.

- [ ] **Step 5: Report — deploy nothing**

State plainly, with command output: both gate suites and their results; that this branch needs a hosting deploy and an APK bump to reach anyone, and that neither is done here; and that device smoke is the user's step — specifically opening Add Product to confirm the SKU field starts empty, and checking the dashboard's Avg Daily ⓘ.

---

## Self-Review

**Spec coverage:**

| Spec requirement | Task |
|---|---|
| Numerator moves to end-of-yesterday | 1 |
| No query on the 1st | 1 |
| Rename `monthToDateSummaryProvider` | 1 |
| `avgDailySalesProvider` nullable, `—` on the 1st | 1 (provider), 2 (rendering) |
| `avgDailyFromGross` left unchanged | 1 (provider returns early) |
| ⓘ on Avg Daily only, tap-to-open dialog, exact copy | 2 |
| Field empty on open + pick-a-category hint | 3 (mobile), 4 (web) |
| Name never drives the SKU | 3, 4 |
| Coded category fills 8-digit SKU | 3, 4 |
| Uncoded category / failed peek → empty + hint | 3, 4 |
| Blank submit → existing required error | 4 (asserted); 3 relies on the untouched validator |
| Regenerate control removed | 3, 4 |
| Toggle/label copy corrected | 3 (subtitle), 4 (checkbox label) |
| Editing unchanged | 3, 4 (guarded by `isEditing`) |
| `generateForName`/`generateSku` kept for Receiving | 3 Step 8, 4 Step 7, 5 Step 2 |
| Byte-identical cross-surface copy | 5 Step 1 |
| Gates | 1, 2, 3, 4, 5 |

Two spec items are deliberately verified rather than implemented: `avgDailyFromGross` staying unchanged, and Receiving staying untouched. Both have explicit grep/diff checks.

**Placeholder scan:** none — every code step carries literal code. Three steps hand the implementer a judgment call with a stated default (the `avgDailySalesProvider` override form in Task 2 Step 1, `SalesSummary.copyWith` availability in Task 1 Step 1, and whether `_nameFocusNode` survives in Task 3 Step 4); each names both branches and which to prefer, rather than deferring the decision.

**Type consistency:** `monthCompletedDaysSummaryProvider` is named identically in Task 1's provider, both call sites, and both test files. `avgDailySalesProvider` is `AsyncValue<double?>` in Task 1 and consumed as nullable in Task 2. `_skuHint` (mobile) and `skuHint` (web) follow each language's convention and are each declared once. The two hint strings are quoted identically in Tasks 3, 4 and 5.
