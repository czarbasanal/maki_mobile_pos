# Price Changes Report v2 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Rework the mobile Price Changes report into per-product summary cards (prev→curr cost/SRP with diffs), tappable to product details, sortable by cost / SRP / combined change magnitude.

**Architecture:** A new pure helper builds `ProductPriceChangeSummary` objects from the existing collection-group entries plus a per-product one-doc "baseline" query (the last change before the range start). A new provider wires repo → helper; the screen swaps its per-change cards for per-product cards with a sort-chips row. The old `priceChangeRowsInRange` path stays untouched for CSV export.

**Tech Stack:** Flutter, Riverpod (`FutureProvider.autoDispose.family`), cloud_firestore, `fake_cloud_firestore` for repo tests, `flutter_test`.

**Spec:** `docs/superpowers/specs/2026-07-02-price-change-report-v2-design.md`

## Global Constraints

- Mobile only; do NOT touch `web_admin/`.
- CSV export behavior unchanged (still the per-change log via `priceChangeRowsInRange` + `priceChangeReportProvider`).
- Verify with `flutter test` and `flutter analyze` from repo root; both must be clean before each commit.
- Currency display via `num_extensions.dart` `toCurrency()` (₱). "SRP" is the user-facing label for the `price` field.
- Follow existing widget idioms: `AppCard` (has `onTap`), Lucide icons, `AppColors.costUp/costDown(isDark)`, theme text styles.
- Work on branch `feat/price-change-report-v2` (already created).

---

### Task 1: Pure summary + sort helpers

**Files:**
- Modify: `lib/core/utils/price_change_report.dart` (append; keep `PriceChangeRow`/`priceChangeRowsInRange` as-is)
- Test: `test/core/utils/price_change_report_test.dart` (append tests)

**Interfaces:**
- Consumes: `PriceChangeEntry`, `PriceHistoryEntry` from `package:maki_mobile_pos/domain/repositories/repositories.dart`.
- Produces (used by Tasks 3):
  - `enum PriceChangeSort { latest, cost, price, both }`
  - `class ProductPriceChangeSummary { String productId; double prevPrice, prevCost, currPrice, currCost; int changeCount; DateTime lastChangedAt; bool isNew; double get priceDiff; double get costDiff; }`
  - `List<ProductPriceChangeSummary> priceChangeProductSummaries(List<PriceChangeEntry> entries, Map<String, PriceHistoryEntry?> baselines)` — returns newest-`lastChangedAt`-first.
  - `List<ProductPriceChangeSummary> sortPriceChangeSummaries(List<ProductPriceChangeSummary> summaries, PriceChangeSort sort)` — returns a new sorted list.

- [ ] **Step 1: Write the failing tests**

Append to `test/core/utils/price_change_report_test.dart` (inside `main()`; the `_e` helper already exists at top of file):

```dart
  PriceHistoryEntry _b(DateTime at, double price, double cost) =>
      PriceHistoryEntry(
        id: 'b-${at.millisecondsSinceEpoch}',
        price: price,
        cost: cost,
        changedAt: at,
        changedBy: 'u1',
      );

  group('priceChangeProductSummaries', () {
    test('prev from baseline, curr from newest in-range entry', () {
      final s = priceChangeProductSummaries(
        [
          _e('p1', DateTime(2026, 6, 10), 120, 70),
          _e('p1', DateTime(2026, 6, 20), 150, 80),
        ],
        {'p1': _b(DateTime(2026, 5, 1), 100, 60)},
      );
      expect(s, hasLength(1));
      expect(s[0].productId, 'p1');
      expect(s[0].prevPrice, 100);
      expect(s[0].prevCost, 60);
      expect(s[0].currPrice, 150);
      expect(s[0].currCost, 80);
      expect(s[0].priceDiff, 50);
      expect(s[0].costDiff, 20);
      expect(s[0].changeCount, 2);
      expect(s[0].lastChangedAt, DateTime(2026, 6, 20));
      expect(s[0].isNew, isFalse);
    });

    test('no baseline -> prev falls back to oldest in-range entry, isNew', () {
      final s = priceChangeProductSummaries(
        [
          _e('p1', DateTime(2026, 6, 1), 100, 60),
          _e('p1', DateTime(2026, 6, 20), 150, 80),
        ],
        {'p1': null},
      );
      expect(s[0].isNew, isTrue);
      expect(s[0].prevPrice, 100);
      expect(s[0].currPrice, 150);
      expect(s[0].priceDiff, 50);
    });

    test('single entry without baseline -> zero diffs, isNew', () {
      final s = priceChangeProductSummaries(
        [_e('p1', DateTime(2026, 6, 1), 100, 60)],
        {'p1': null},
      );
      expect(s[0].priceDiff, 0);
      expect(s[0].costDiff, 0);
      expect(s[0].changeCount, 1);
      expect(s[0].isNew, isTrue);
    });

    test('default order is newest lastChangedAt first', () {
      final s = priceChangeProductSummaries(
        [
          _e('p1', DateTime(2026, 6, 10), 120, 70),
          _e('p2', DateTime(2026, 6, 20), 250, 180),
        ],
        {'p1': null, 'p2': null},
      );
      expect(s.map((x) => x.productId), ['p2', 'p1']);
    });
  });

  group('sortPriceChangeSummaries', () {
    // p1: costDiff +30, priceDiff +5 (sum 35, newer)
    // p2: costDiff -10, priceDiff +40 (sum 50, older)
    List<ProductPriceChangeSummary> two() => priceChangeProductSummaries(
          [
            _e('p1', DateTime(2026, 6, 20), 105, 90),
            _e('p2', DateTime(2026, 6, 10), 140, 50),
          ],
          {
            'p1': _b(DateTime(2026, 5, 1), 100, 60),
            'p2': _b(DateTime(2026, 5, 1), 100, 60),
          },
        );

    test('latest keeps newest-first', () {
      final s = sortPriceChangeSummaries(two(), PriceChangeSort.latest);
      expect(s.map((x) => x.productId), ['p1', 'p2']);
    });

    test('cost sorts by |costDiff| desc', () {
      final s = sortPriceChangeSummaries(two(), PriceChangeSort.cost);
      expect(s.map((x) => x.productId), ['p1', 'p2']); // 30 > 10
    });

    test('price sorts by |priceDiff| desc', () {
      final s = sortPriceChangeSummaries(two(), PriceChangeSort.price);
      expect(s.map((x) => x.productId), ['p2', 'p1']); // 40 > 5
    });

    test('both sorts by |costDiff| + |priceDiff| desc', () {
      final s = sortPriceChangeSummaries(two(), PriceChangeSort.both);
      expect(s.map((x) => x.productId), ['p2', 'p1']); // 50 > 35
    });

    test('ties break by newest lastChangedAt', () {
      final s = sortPriceChangeSummaries(
        priceChangeProductSummaries(
          [
            _e('p1', DateTime(2026, 6, 20), 110, 70),
            _e('p2', DateTime(2026, 6, 10), 110, 70),
          ],
          {
            'p1': _b(DateTime(2026, 5, 1), 100, 60),
            'p2': _b(DateTime(2026, 5, 1), 100, 60),
          },
        ),
        PriceChangeSort.cost,
      );
      expect(s.map((x) => x.productId), ['p1', 'p2']);
    });
  });
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `flutter test test/core/utils/price_change_report_test.dart`
Expected: compile errors — `priceChangeProductSummaries`, `ProductPriceChangeSummary`, `PriceChangeSort`, `sortPriceChangeSummaries` undefined.

- [ ] **Step 3: Implement the helpers**

Append to `lib/core/utils/price_change_report.dart`:

```dart
/// Sort orders for the per-product price-change summary list.
enum PriceChangeSort { latest, cost, price, both }

/// A product's net price/cost movement over the report range: `prev` is the
/// value just before the range's first change (baseline), `curr` the newest
/// in-range value. [isNew] marks products whose history starts inside the
/// range (no baseline) — prev falls back to the oldest in-range entry.
class ProductPriceChangeSummary {
  final String productId;
  final double prevPrice;
  final double prevCost;
  final double currPrice;
  final double currCost;
  final int changeCount;
  final DateTime lastChangedAt;
  final bool isNew;

  const ProductPriceChangeSummary({
    required this.productId,
    required this.prevPrice,
    required this.prevCost,
    required this.currPrice,
    required this.currCost,
    required this.changeCount,
    required this.lastChangedAt,
    required this.isNew,
  });

  double get priceDiff => currPrice - prevPrice;
  double get costDiff => currCost - prevCost;
}

/// Groups in-range [entries] by product and summarizes each product's net
/// movement against its baseline (last change before the range; null when the
/// product has none). Newest [ProductPriceChangeSummary.lastChangedAt] first.
List<ProductPriceChangeSummary> priceChangeProductSummaries(
  List<PriceChangeEntry> entries,
  Map<String, PriceHistoryEntry?> baselines,
) {
  final byProduct = <String, List<PriceChangeEntry>>{};
  for (final e in entries) {
    byProduct.putIfAbsent(e.productId, () => []).add(e);
  }

  final summaries = <ProductPriceChangeSummary>[];
  byProduct.forEach((productId, group) {
    group.sort((a, b) => a.changedAt.compareTo(b.changedAt));
    final baseline = baselines[productId];
    final oldest = group.first;
    final newest = group.last;
    summaries.add(ProductPriceChangeSummary(
      productId: productId,
      prevPrice: baseline?.price ?? oldest.price,
      prevCost: baseline?.cost ?? oldest.cost,
      currPrice: newest.price,
      currCost: newest.cost,
      changeCount: group.length,
      lastChangedAt: newest.changedAt,
      isNew: baseline == null,
    ));
  });

  summaries.sort((a, b) => b.lastChangedAt.compareTo(a.lastChangedAt));
  return summaries;
}

/// Returns a new list sorted by [sort]; change-magnitude sorts are descending
/// with newest [ProductPriceChangeSummary.lastChangedAt] breaking ties.
List<ProductPriceChangeSummary> sortPriceChangeSummaries(
  List<ProductPriceChangeSummary> summaries,
  PriceChangeSort sort,
) {
  double magnitude(ProductPriceChangeSummary s) => switch (sort) {
        PriceChangeSort.cost => s.costDiff.abs(),
        PriceChangeSort.price => s.priceDiff.abs(),
        PriceChangeSort.both => s.costDiff.abs() + s.priceDiff.abs(),
        PriceChangeSort.latest => 0,
      };

  final sorted = List<ProductPriceChangeSummary>.of(summaries);
  sorted.sort((a, b) {
    if (sort != PriceChangeSort.latest) {
      final byMagnitude = magnitude(b).compareTo(magnitude(a));
      if (byMagnitude != 0) return byMagnitude;
    }
    return b.lastChangedAt.compareTo(a.lastChangedAt);
  });
  return sorted;
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/core/utils/price_change_report_test.dart`
Expected: all tests PASS (existing 2 + new 10).

- [ ] **Step 5: Commit**

```bash
git add lib/core/utils/price_change_report.dart test/core/utils/price_change_report_test.dart
git commit -m "feat(reports): per-product price-change summaries + sort helpers"
```

---

### Task 2: Repo baseline query

**Files:**
- Modify: `lib/domain/repositories/product_repository.dart` (add abstract method near `getPriceHistory`)
- Modify: `lib/data/repositories/product_repository_impl.dart` (implement in the PRICE HISTORY section)
- Test: `test/data/repositories/product_price_changes_test.dart` (append)

**Interfaces:**
- Produces (used by Task 3): `Future<PriceHistoryEntry?> getPriceHistoryBaseline({required String productId, required DateTime before})` — newest `price_history` entry with `changedAt < before`, or null.

- [ ] **Step 1: Write the failing tests**

Append inside `main()` of `test/data/repositories/product_price_changes_test.dart` (reuses the existing `seed` helper):

```dart
  group('getPriceHistoryBaseline', () {
    test('returns the newest entry strictly before the date', () async {
      await seed('p1', DateTime(2026, 4, 1), 80, 50);
      await seed('p1', DateTime(2026, 5, 15), 90, 55);
      await seed('p1', DateTime(2026, 6, 10), 100, 60); // in range - excluded

      final baseline = await repo.getPriceHistoryBaseline(
        productId: 'p1',
        before: DateTime(2026, 6, 1),
      );

      expect(baseline, isNotNull);
      expect(baseline!.price, 90);
      expect(baseline.cost, 55);
      expect(baseline.changedAt, DateTime(2026, 5, 15));
    });

    test('returns null when no entry precedes the date', () async {
      await seed('p1', DateTime(2026, 6, 10), 100, 60);

      final baseline = await repo.getPriceHistoryBaseline(
        productId: 'p1',
        before: DateTime(2026, 6, 1),
      );

      expect(baseline, isNull);
    });
  });
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `flutter test test/data/repositories/product_price_changes_test.dart`
Expected: compile error — `getPriceHistoryBaseline` not defined.

- [ ] **Step 3: Implement**

In `lib/domain/repositories/product_repository.dart`, next to the `getPriceHistory` declaration, add:

```dart
  /// Returns the newest price-history entry strictly before [before] — the
  /// "baseline" a report range compares against — or null if none exists.
  Future<PriceHistoryEntry?> getPriceHistoryBaseline({
    required String productId,
    required DateTime before,
  });
```

In `lib/data/repositories/product_repository_impl.dart`, in the PRICE HISTORY section (after `getPriceHistory`), add:

```dart
  @override
  Future<PriceHistoryEntry?> getPriceHistoryBaseline({
    required String productId,
    required DateTime before,
  }) async {
    try {
      final snapshot = await _productsRef
          .doc(productId)
          .collection(FirestoreCollections.priceHistory)
          .where('changedAt', isLessThan: Timestamp.fromDate(before))
          .orderBy('changedAt', descending: true)
          .limit(1)
          .get();

      if (snapshot.docs.isEmpty) return null;
      final doc = snapshot.docs.first;
      final data = doc.data();
      return PriceHistoryEntry(
        id: doc.id,
        price: (data['price'] as num?)?.toDouble() ?? 0,
        cost: (data['cost'] as num?)?.toDouble() ?? 0,
        changedAt:
            (data['changedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
        changedBy: data['changedBy'] as String? ?? '',
        reason: data['reason'] as String?,
        note: data['note'] as String?,
      );
    } on FirebaseException catch (e) {
      throw DatabaseException(
        message: 'Failed to get price-history baseline: ${e.message}',
        code: e.code,
        originalError: e,
      );
    }
  }
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/data/repositories/product_price_changes_test.dart`
Expected: all PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/domain/repositories/product_repository.dart lib/data/repositories/product_repository_impl.dart test/data/repositories/product_price_changes_test.dart
git commit -m "feat(reports): price-history baseline query (last change before range)"
```

---

### Task 3: Provider + screen rework (cards, sorting, navigation)

**Files:**
- Modify: `lib/presentation/providers/product_provider.dart` (add provider after `priceChangeReportProvider`)
- Modify: `lib/presentation/mobile/screens/reports/price_change_report_screen.dart` (rework list; keep DateRangePicker + CSV export as-is)
- Test: `test/presentation/mobile/screens/reports/price_change_report_screen_test.dart` (rewrite)

**Interfaces:**
- Consumes: `priceChangeProductSummaries`, `sortPriceChangeSummaries`, `PriceChangeSort`, `ProductPriceChangeSummary` (Task 1); `getPriceHistoryBaseline` (Task 2); existing `DateRangeParams`, `RoutePaths.inventory`, `AppCard(onTap:)`.
- Produces: `priceChangeSummariesProvider` (`FutureProvider.autoDispose.family<List<ProductPriceChangeSummary>, DateRangeParams>`).

- [ ] **Step 1: Rewrite the widget test (failing first)**

Replace the body of `test/presentation/mobile/screens/reports/price_change_report_screen_test.dart` with:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maki_mobile_pos/core/utils/price_change_report.dart';
import 'package:maki_mobile_pos/domain/repositories/repositories.dart';
import 'package:maki_mobile_pos/presentation/mobile/screens/reports/price_change_report_screen.dart';
import 'package:maki_mobile_pos/presentation/providers/providers.dart';

void main() {
  List<ProductPriceChangeSummary> summaries() => priceChangeProductSummaries(
        [
          PriceChangeEntry(
            id: 'a',
            productId: 'p1',
            price: 150,
            cost: 80,
            changedAt: DateTime(2026, 6, 10),
            changedBy: 'u1',
            reason: 'Price update',
          ),
        ],
        {
          'p1': PriceHistoryEntry(
            id: 'b',
            price: 100,
            cost: 60,
            changedAt: DateTime(2026, 5, 1),
            changedBy: 'u1',
          ),
        },
      );

  Future<void> pumpScreen(WidgetTester tester) async {
    await tester.pumpWidget(ProviderScope(
      overrides: [
        priceChangeSummariesProvider
            .overrideWith((ref, params) async => summaries()),
        productsProvider.overrideWith((ref) => Stream.value(const [])),
      ],
      child: const MaterialApp(home: PriceChangeReportScreen()),
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
  }

  testWidgets('renders prev -> curr with diff for cost and SRP',
      (tester) async {
    await pumpScreen(tester);

    // Card shows both values of each metric plus the diff.
    expect(find.textContaining('₱100.00'), findsOneWidget); // prev SRP
    expect(find.textContaining('₱150.00'), findsOneWidget); // curr SRP
    expect(find.textContaining('₱60.00'), findsOneWidget); // prev cost
    expect(find.textContaining('₱80.00'), findsOneWidget); // curr cost
    expect(find.textContaining('₱50.00'), findsOneWidget); // SRP diff
    expect(find.textContaining('₱20.00'), findsOneWidget); // cost diff
    expect(find.textContaining('1 change'), findsOneWidget);
  });

  testWidgets('shows the sort filter with all four options', (tester) async {
    await pumpScreen(tester);

    expect(find.byKey(const Key('price-change-sort')), findsOneWidget);
    expect(find.text('Latest'), findsOneWidget);
    expect(find.text('Cost'), findsOneWidget);
    expect(find.text('SRP'), findsOneWidget);
    expect(find.text('Both'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `flutter test test/presentation/mobile/screens/reports/price_change_report_screen_test.dart`
Expected: compile error — `priceChangeSummariesProvider` undefined.

- [ ] **Step 3: Add the provider**

In `lib/presentation/providers/product_provider.dart`, directly after `priceChangeReportProvider`, add:

```dart
/// Per-product price-change summaries for the report range: in-range changes
/// (collection-group) + a one-doc baseline per product (last change before the
/// range), newest last-change first. Sorting is applied in the screen.
final priceChangeSummariesProvider = FutureProvider.autoDispose
    .family<List<ProductPriceChangeSummary>, DateRangeParams>(
        (ref, params) async {
  final repo = ref.watch(productRepositoryProvider);
  final changes = await repo.getPriceChangesInRange(
    startDate: params.startDate,
    endDate: params.endDate,
  );
  final ids = changes.map((c) => c.productId).toSet();
  final baselines = <String, PriceHistoryEntry?>{};
  await Future.wait(ids.map((id) async {
    baselines[id] = await repo.getPriceHistoryBaseline(
      productId: id,
      before: params.startDate,
    );
  }));
  return priceChangeProductSummaries(changes, baselines);
});
```

(Imports for `ProductPriceChangeSummary`/`PriceHistoryEntry` come via the existing `price_change_report.dart` / repositories imports in that file; add them if missing.)

- [ ] **Step 4: Rework the screen**

In `lib/presentation/mobile/screens/reports/price_change_report_screen.dart`:

1. Add state to `_PriceChangeReportScreenState`:

```dart
  PriceChangeSort _sort = PriceChangeSort.latest;
```

2. In `build`, watch the new provider instead of the old one for the list (CSV export keeps reading `priceChangeReportProvider`):

```dart
    final reportAsync = ref.watch(priceChangeSummariesProvider(_params));
```

Update `RefreshIndicator.onRefresh` and the error `onRetry` to invalidate `priceChangeSummariesProvider(_params)`, and the `data:` case to `(summaries) => _buildList(theme, summaries, labels)`.

3. Replace `_buildList` and `_PriceChangeRowCard`/`_MoneyDelta` with:

```dart
  Widget _buildList(ThemeData theme, List<ProductPriceChangeSummary> summaries,
      Map<String, String> labels) {
    if (summaries.isEmpty) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 24, 16, 0),
        child: EmptyStateView(
          icon: LucideIcons.tag,
          title: 'No price changes',
          subtitle: 'Price/cost changes in this range will appear here.',
        ),
      );
    }
    final sorted = sortPriceChangeSummaries(summaries, _sort);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          const SizedBox(height: 12),
          _SortFilter(
            selected: _sort,
            onChanged: (s) => setState(() => _sort = s),
          ),
          for (final summary in sorted)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: _ProductChangeCard(
                summary: summary,
                label: labels[summary.productId] ?? summary.productId,
                theme: theme,
                onTap: () =>
                    context.push('${RoutePaths.inventory}/${summary.productId}'),
              ),
            ),
        ],
      ),
    );
  }
```

```dart
/// Segmented Latest / Cost / SRP / Both sort — pill on an [AppCard], selected
/// segment filled, mirroring the price-history metric filter.
class _SortFilter extends StatelessWidget {
  const _SortFilter({required this.selected, required this.onChanged});
  final PriceChangeSort selected;
  final ValueChanged<PriceChangeSort> onChanged;

  static const _labels = {
    PriceChangeSort.latest: 'Latest',
    PriceChangeSort.cost: 'Cost',
    PriceChangeSort.price: 'SRP',
    PriceChangeSort.both: 'Both',
  };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return AppCard(
      key: const Key('price-change-sort'),
      radius: AppRadius.pill,
      padding: const EdgeInsets.all(4),
      child: Row(
        children: [
          for (final s in PriceChangeSort.values)
            Expanded(
              child: GestureDetector(
                onTap: () => onChanged(s),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 7),
                  decoration: BoxDecoration(
                    color: s == selected
                        ? (isDark ? AppColors.goldDark : AppColors.slate)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    _labels[s]!,
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: s == selected
                          ? (isDark ? AppColors.ink : Colors.white)
                          : theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
```

**Note:** before writing `_SortFilter`, read `_MetricFilter`'s `_segment` in `price_history_screen.dart:107-160` and copy its exact selected/unselected colors and paddings — the block above is indicative; the shipped code must match the existing pill idiom (including any helper it uses) rather than invent new color pairings.

```dart
class _ProductChangeCard extends StatelessWidget {
  const _ProductChangeCard({
    required this.summary,
    required this.label,
    required this.theme,
    required this.onTap,
  });
  final ProductPriceChangeSummary summary;
  final String label;
  final ThemeData theme;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final muted = theme.colorScheme.onSurfaceVariant;
    final last = DateFormat('MMM d, y').format(summary.lastChangedAt);
    final n = summary.changeCount;
    return AppCard(
      radius: 12,
      onTap: onTap,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600, fontSize: 13.5)),
              ),
              if (summary.isNew) ...[
                const SizedBox(width: 6),
                Text('New',
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: muted, fontSize: 11)),
              ],
              const SizedBox(width: 4),
              Icon(LucideIcons.chevronRight, size: 15, color: muted),
            ],
          ),
          const SizedBox(height: 6),
          _PrevCurrRow(
              label: 'Cost',
              prev: summary.prevCost,
              curr: summary.currCost,
              diff: summary.costDiff,
              theme: theme),
          const SizedBox(height: 3),
          _PrevCurrRow(
              label: 'SRP',
              prev: summary.prevPrice,
              curr: summary.currPrice,
              diff: summary.priceDiff,
              theme: theme),
          const SizedBox(height: 6),
          Text(
            '$n change${n == 1 ? '' : 's'} · last $last',
            style: theme.textTheme.bodySmall
                ?.copyWith(color: muted, fontSize: 11.5),
          ),
        ],
      ),
    );
  }
}

class _PrevCurrRow extends StatelessWidget {
  const _PrevCurrRow({
    required this.label,
    required this.prev,
    required this.curr,
    required this.diff,
    required this.theme,
  });
  final String label;
  final double prev;
  final double curr;
  final double diff;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    final isDark = theme.brightness == Brightness.dark;
    final muted = theme.colorScheme.onSurfaceVariant;
    final up = diff > 0;
    final deltaColor =
        up ? AppColors.costUp(isDark) : AppColors.costDown(isDark);
    return Row(
      children: [
        SizedBox(
          width: 34,
          child: Text(label,
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: muted, fontSize: 11.5)),
        ),
        Text(prev.toCurrency(),
            style: theme.textTheme.bodySmall
                ?.copyWith(color: muted, fontSize: 12)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Icon(LucideIcons.arrowRight, size: 11, color: muted),
        ),
        Text(curr.toCurrency(),
            style: theme.textTheme.bodyMedium
                ?.copyWith(fontWeight: FontWeight.w600, fontSize: 12.5)),
        const Spacer(),
        if (diff == 0)
          Text('—',
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: muted, fontSize: 11.5))
        else ...[
          Icon(up ? LucideIcons.arrowUpRight : LucideIcons.arrowDownRight,
              size: 12, color: deltaColor),
          const SizedBox(width: 2),
          Text(diff.abs().toCurrency(),
              style: theme.textTheme.bodySmall?.copyWith(
                  color: deltaColor,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600)),
        ],
      ],
    );
  }
}
```

4. Delete the now-unused `_PriceChangeRowCard` and `_MoneyDelta` classes. Keep `_exportCsv` exactly as-is (it reads `priceChangeReportProvider`). Ensure imports cover `context.push` (`go_router` via existing router import) — the file already imports `router.dart` and `num_extensions.dart`.

- [ ] **Step 5: Run the widget test to verify it passes**

Run: `flutter test test/presentation/mobile/screens/reports/price_change_report_screen_test.dart`
Expected: both tests PASS.

- [ ] **Step 6: Full verification**

Run: `flutter analyze` → expected: `No issues found!`
Run: `flutter test` → expected: all tests pass (≈975+).

- [ ] **Step 7: Commit**

```bash
git add lib/presentation/providers/product_provider.dart lib/presentation/mobile/screens/reports/price_change_report_screen.dart test/presentation/mobile/screens/reports/price_change_report_screen_test.dart
git commit -m "feat(reports): per-product price-change cards with prev→curr, sorting, tap-to-product"
```

---

### Task 4: Review + verify + finish

- [ ] **Step 1: Code review** — run `/code-review` on the branch diff; fix real findings, re-run `flutter test` + `flutter analyze` after fixes.
- [ ] **Step 2: `/verify`** — exercise the report flow if a runtime surface is drivable; otherwise state plainly what was and wasn't run (device install is the user's gate per the mobile release process).
- [ ] **Step 3: Finish branch** — use superpowers:finishing-a-development-branch (merge to main; don't push unless asked).
