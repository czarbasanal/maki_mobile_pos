# Price-Change Report Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** An admin-only reports-hub entry (mobile + web) showing a cross-product change log of price/cost changes over a date range, with ▲/▼ deltas and CSV export.

**Architecture:** A `collectionGroup('price_history')` range query returns every change with its `productId`; a pure helper groups by product and computes within-range deltas newest-first; report screens on both surfaces render the rows + export CSV. New admin-only routes; an additive rules rule + a collection-group index deploy on the user's go-ahead.

**Tech Stack:** Flutter, Riverpod, go_router, cloud_firestore, `csv`/`file_picker`; React + Vite + TanStack Query + Firestore web SDK; `flutter_test`/`fake_cloud_firestore`, vitest.

## Global Constraints

- Admin-only (gate: `Permission.viewProductCost` — same as the per-product price-history view).
- Default preset `thisMonth` (price changes are infrequent).
- Deltas are within-range only (oldest-per-product change shows no delta).
- CSV via the shared `saveReportCsv` (mobile); no TOTAL row (change log).
- `firestore.rules` + `firestore.indexes.json` changes deploy ONLY on explicit user go-ahead.
- Run `flutter analyze` + `flutter test` (mobile) / `npm run typecheck` + `npm run test` (web) after each task; clean before commit.

---

### Task 1: Mobile — `PriceChangeEntry` + `getPriceChangesInRange` (collection-group query)

**Files:**
- Modify: `lib/domain/repositories/product_repository.dart` (add `PriceChangeEntry` class + method sig on the abstract `ProductRepository`)
- Modify: `lib/data/repositories/product_repository_impl.dart` (implement the method)
- Test: `test/data/repositories/product_price_changes_test.dart`

**Interfaces:**
- Produces: `class PriceChangeEntry { String id; String productId; double price; double cost; DateTime changedAt; String changedBy; String? reason; String? note; }`; `Future<List<PriceChangeEntry>> ProductRepository.getPriceChangesInRange({required DateTime startDate, required DateTime endDate, int limit})`.

- [ ] **Step 1: Write the failing test**

```dart
// test/data/repositories/product_price_changes_test.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maki_mobile_pos/data/repositories/product_repository_impl.dart';

void main() {
  late FakeFirebaseFirestore fake;
  late ProductRepositoryImpl repo;

  setUp(() {
    fake = FakeFirebaseFirestore();
    repo = ProductRepositoryImpl(firestore: fake);
  });

  Future<void> seed(String productId, DateTime at, double price, double cost) {
    return fake
        .collection('products')
        .doc(productId)
        .collection('price_history')
        .add({
      'price': price,
      'cost': cost,
      'changedAt': Timestamp.fromDate(at),
      'changedBy': 'u1',
      'reason': 'receiving',
    });
  }

  test('getPriceChangesInRange returns in-range changes across products, '
      'newest-first, each tagged with its productId', () async {
    await seed('p1', DateTime(2026, 6, 10), 100, 60);
    await seed('p2', DateTime(2026, 6, 20), 250, 180);
    await seed('p1', DateTime(2026, 5, 1), 90, 55); // before range - excluded

    final changes = await repo.getPriceChangesInRange(
      startDate: DateTime(2026, 6, 1),
      endDate: DateTime(2026, 6, 30, 23, 59, 59),
    );

    expect(changes, hasLength(2));
    expect(changes.first.changedAt.isAfter(changes.last.changedAt), isTrue);
    expect(changes.map((c) => c.productId).toSet(), {'p1', 'p2'});
    expect(changes.first.productId, 'p2'); // Jun 20 newest
    expect(changes.first.price, 250);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/data/repositories/product_price_changes_test.dart`
Expected: FAIL — `PriceChangeEntry` / `getPriceChangesInRange` undefined.

- [ ] **Step 3: Add the type + abstract method**

In `lib/domain/repositories/product_repository.dart`, after the existing `PriceHistoryEntry` class add:

```dart
/// A price/cost change plus the product it belongs to — the cross-product
/// form of [PriceHistoryEntry] used by the price-change report.
class PriceChangeEntry {
  final String id;
  final String productId;
  final double price;
  final double cost;
  final DateTime changedAt;
  final String changedBy;
  final String? reason;
  final String? note;

  const PriceChangeEntry({
    required this.id,
    required this.productId,
    required this.price,
    required this.cost,
    required this.changedAt,
    required this.changedBy,
    this.reason,
    this.note,
  });
}
```

In the `abstract class ProductRepository`, add (near `getPriceHistory`):

```dart
  /// All price/cost changes across every product in the range, newest-first.
  /// Admin-only (price_history is admin-only). Requires the collection-group
  /// index on price_history.changedAt.
  Future<List<PriceChangeEntry>> getPriceChangesInRange({
    required DateTime startDate,
    required DateTime endDate,
    int limit = 500,
  });
```

- [ ] **Step 4: Implement in the Firestore repo**

In `lib/data/repositories/product_repository_impl.dart`, add (near `getPriceHistory`):

```dart
  @override
  Future<List<PriceChangeEntry>> getPriceChangesInRange({
    required DateTime startDate,
    required DateTime endDate,
    int limit = 500,
  }) async {
    try {
      final snapshot = await _firestore
          .collectionGroup(FirestoreCollections.priceHistory)
          .where('changedAt',
              isGreaterThanOrEqualTo: Timestamp.fromDate(startDate))
          .where('changedAt', isLessThanOrEqualTo: Timestamp.fromDate(endDate))
          .orderBy('changedAt', descending: true)
          .limit(limit)
          .get();

      return snapshot.docs.map((doc) {
        final data = doc.data();
        return PriceChangeEntry(
          id: doc.id,
          productId: doc.reference.parent.parent!.id,
          price: (data['price'] as num?)?.toDouble() ?? 0,
          cost: (data['cost'] as num?)?.toDouble() ?? 0,
          changedAt:
              (data['changedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
          changedBy: data['changedBy'] as String? ?? '',
          reason: data['reason'] as String?,
          note: data['note'] as String?,
        );
      }).toList();
    } on FirebaseException catch (e) {
      throw DatabaseException(
        message: 'Failed to load price changes: ${e.message}',
        code: e.code,
        originalError: e,
      );
    }
  }
```

`PriceChangeEntry` is exported via the same file as `PriceHistoryEntry`; if the impl file doesn't already import the repository interface, it does (it implements it). `DatabaseException` and `FirestoreCollections` are already imported in the impl.

- [ ] **Step 5: Run test to verify it passes**

Run: `flutter test test/data/repositories/product_price_changes_test.dart`
Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add lib/domain/repositories/product_repository.dart lib/data/repositories/product_repository_impl.dart test/data/repositories/product_price_changes_test.dart
git commit -m "feat(reports): cross-product price-change query (collectionGroup)"
```

---

### Task 2: Mobile — `priceChangeRowsInRange` delta helper

**Files:**
- Create: `lib/core/utils/price_change_report.dart`
- Test: `test/core/utils/price_change_report_test.dart`

**Interfaces:**
- Consumes: `PriceChangeEntry` (Task 1).
- Produces: `class PriceChangeRow { PriceChangeEntry entry; double priceDelta; double costDelta; bool hasPrior; }`; `List<PriceChangeRow> priceChangeRowsInRange(List<PriceChangeEntry> entries)`.

- [ ] **Step 1: Write the failing test**

```dart
// test/core/utils/price_change_report_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:maki_mobile_pos/core/utils/price_change_report.dart';
import 'package:maki_mobile_pos/domain/repositories/repositories.dart';

PriceChangeEntry _e(String product, DateTime at, double price, double cost) =>
    PriceChangeEntry(
      id: '$product-${at.millisecondsSinceEpoch}',
      productId: product,
      price: price,
      cost: cost,
      changedAt: at,
      changedBy: 'u1',
    );

void main() {
  test('groups by product, deltas vs prior in-range entry, newest-first', () {
    // p1: 100 (Jun 1) -> 120 (Jun 10). p2: 250 (Jun 20).
    final rows = priceChangeRowsInRange([
      _e('p1', DateTime(2026, 6, 10), 120, 70),
      _e('p2', DateTime(2026, 6, 20), 250, 180),
      _e('p1', DateTime(2026, 6, 1), 100, 60),
    ]);

    // Overall newest-first: p2 Jun20, p1 Jun10, p1 Jun1.
    expect(rows.map((r) => r.entry.changedAt), [
      DateTime(2026, 6, 20),
      DateTime(2026, 6, 10),
      DateTime(2026, 6, 1),
    ]);

    final p1Jun10 = rows[1];
    expect(p1Jun10.hasPrior, isTrue);
    expect(p1Jun10.priceDelta, 20); // 120 - 100
    expect(p1Jun10.costDelta, 10); // 70 - 60

    final p1Jun1 = rows[2]; // oldest for p1 -> no prior
    expect(p1Jun1.hasPrior, isFalse);
    expect(p1Jun1.priceDelta, 0);

    final p2 = rows[0]; // only entry for p2 -> no prior
    expect(p2.hasPrior, isFalse);
  });

  test('empty input -> empty rows', () {
    expect(priceChangeRowsInRange(const []), isEmpty);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/core/utils/price_change_report_test.dart`
Expected: FAIL — file/function undefined.

- [ ] **Step 3: Implement**

```dart
// lib/core/utils/price_change_report.dart
import 'package:maki_mobile_pos/domain/repositories/repositories.dart';

/// A price-change entry with its ▲/▼ deltas vs the prior in-range change for
/// the same product.
class PriceChangeRow {
  final PriceChangeEntry entry;
  final double priceDelta;
  final double costDelta;
  final bool hasPrior;

  const PriceChangeRow({
    required this.entry,
    required this.priceDelta,
    required this.costDelta,
    required this.hasPrior,
  });
}

/// Groups [entries] by product, computes each change's delta against the prior
/// (older) in-range change for that product — the oldest change per product has
/// no prior (deltas 0) — then returns all rows newest-first by changedAt.
List<PriceChangeRow> priceChangeRowsInRange(List<PriceChangeEntry> entries) {
  final byProduct = <String, List<PriceChangeEntry>>{};
  for (final e in entries) {
    byProduct.putIfAbsent(e.productId, () => []).add(e);
  }

  final rows = <PriceChangeRow>[];
  for (final group in byProduct.values) {
    // Oldest -> newest so each entry can look back at the previous one.
    group.sort((a, b) => a.changedAt.compareTo(b.changedAt));
    PriceChangeEntry? prior;
    for (final e in group) {
      rows.add(PriceChangeRow(
        entry: e,
        priceDelta: prior == null ? 0 : e.price - prior.price,
        costDelta: prior == null ? 0 : e.cost - prior.cost,
        hasPrior: prior != null,
      ));
      prior = e;
    }
  }

  rows.sort((a, b) => b.entry.changedAt.compareTo(a.entry.changedAt));
  return rows;
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/core/utils/price_change_report_test.dart`
Expected: PASS (2 tests).

- [ ] **Step 5: Commit**

```bash
git add lib/core/utils/price_change_report.dart test/core/utils/price_change_report_test.dart
git commit -m "feat(reports): cross-product price-change delta helper"
```

---

### Task 3: Mobile — `buildPriceChangeReportCsv`

**Files:**
- Modify: `lib/core/utils/report_csv.dart`
- Test: `test/core/utils/report_csv_test.dart` (add a group)

**Interfaces:**
- Consumes: `PriceChangeRow` (Task 2).
- Produces: `String buildPriceChangeReportCsv(List<PriceChangeRow> rows, Map<String, String> productLabelById)`.

- [ ] **Step 1: Add the failing test** (append inside `main()` of `report_csv_test.dart`)

```dart
  group('buildPriceChangeReportCsv', () {
    test('header + one row per change with signed deltas + product label', () {
      final rows = priceChangeRowsInRange([
        PriceChangeEntry(
            id: 'a', productId: 'p1', price: 120, cost: 70,
            changedAt: DateTime(2026, 6, 10, 9), changedBy: 'u1',
            reason: 'receiving'),
        PriceChangeEntry(
            id: 'b', productId: 'p1', price: 100, cost: 60,
            changedAt: DateTime(2026, 6, 1, 9), changedBy: 'u1'),
      ]);
      final csv = buildPriceChangeReportCsv(rows, {'p1': 'Widget (SKU-1)'});
      final lines = csv.trim().split('\n');
      expect(lines.first,
          'Date,Product,SKU,New Price,Price Delta,New Cost,Cost Delta,Reason,Changed By');
      expect(lines.length, 3); // header + 2 changes
      expect(lines[1], contains('Widget (SKU-1)'));
      expect(lines[1], contains('+20.00')); // newest row's price delta
    });
  });
```

Add these imports at the top of `report_csv_test.dart` if missing:
`import 'package:maki_mobile_pos/core/utils/price_change_report.dart';`
`import 'package:maki_mobile_pos/domain/repositories/repositories.dart';`

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/core/utils/report_csv_test.dart`
Expected: FAIL — `buildPriceChangeReportCsv` undefined.

- [ ] **Step 3: Implement** — append to `lib/core/utils/report_csv.dart`:

```dart
String _signed(double v) => (v >= 0 ? '+' : '') + v.toStringAsFixed(2);

/// Change log: one row per price/cost change, newest-first (as [rows] arrive).
/// [productLabelById] maps productId -> "Name (SKU)"; a missing product falls
/// back to the id.
String buildPriceChangeReportCsv(
  List<PriceChangeRow> rows,
  Map<String, String> productLabelById,
) {
  final fmt = DateFormat('yyyy-MM-dd HH:mm');
  final out = <List<dynamic>>[
    ['Date', 'Product', 'SKU', 'New Price', 'Price Delta', 'New Cost',
        'Cost Delta', 'Reason', 'Changed By'],
  ];
  for (final r in rows) {
    final e = r.entry;
    out.add([
      fmt.format(e.changedAt),
      productLabelById[e.productId] ?? e.productId,
      '',
      e.price.toStringAsFixed(2),
      r.hasPrior ? _signed(r.priceDelta) : '',
      e.cost.toStringAsFixed(2),
      r.hasPrior ? _signed(r.costDelta) : '',
      e.reason ?? '',
      e.changedBy,
    ]);
  }
  return _converter.convert(out);
}
```

Add imports to `report_csv.dart` if missing: `PriceChangeRow` via
`import 'package:maki_mobile_pos/core/utils/price_change_report.dart';`.
(`_converter` and `DateFormat` already exist in the file.)

> Note: the SKU column is filled by the caller only when it splits the label;
> here the "Name (SKU)" label already carries the SKU, so the SKU column stays
> blank to avoid duplication. Keep it for column stability.

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/core/utils/report_csv_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/core/utils/report_csv.dart test/core/utils/report_csv_test.dart
git commit -m "feat(reports): price-change CSV builder"
```

---

### Task 4: Mobile — provider + `PriceChangeReportScreen`

**Files:**
- Modify: `lib/presentation/providers/product_provider.dart` (add `priceChangeReportProvider`)
- Create: `lib/presentation/mobile/screens/reports/price_change_report_screen.dart`
- Test: `test/presentation/mobile/screens/reports/price_change_report_screen_test.dart`

**Interfaces:**
- Consumes: `getPriceChangesInRange` (Task 1), `priceChangeRowsInRange` (Task 2), `DateRangeParams`, `productsProvider`, `DateRangePicker`, `dateRangeForPreset`, `saveReportCsv`, `buildPriceChangeReportCsv`.
- Produces: `priceChangeReportProvider` (`FutureProvider.autoDispose.family<List<PriceChangeRow>, DateRangeParams>`), `PriceChangeReportScreen`.

- [ ] **Step 1: Add the provider** — in `product_provider.dart`:

```dart
final priceChangeReportProvider = FutureProvider.autoDispose
    .family<List<PriceChangeRow>, DateRangeParams>((ref, params) async {
  final repo = ref.watch(productRepositoryProvider);
  final changes = await repo.getPriceChangesInRange(
    startDate: params.startDate,
    endDate: params.endDate,
  );
  return priceChangeRowsInRange(changes);
});
```

Add imports to `product_provider.dart`: `report/price_change_report.dart`
(`priceChangeRowsInRange`, `PriceChangeRow`) and, for `DateRangeParams`, it is
in `sale_provider.dart` — import
`package:maki_mobile_pos/presentation/providers/sale_provider.dart` if not
already visible (product_provider may need it; if `DateRangeParams` isn't
resolvable, import sale_provider).

- [ ] **Step 2: Write the failing widget test**

```dart
// test/presentation/mobile/screens/reports/price_change_report_screen_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maki_mobile_pos/core/utils/price_change_report.dart';
import 'package:maki_mobile_pos/domain/repositories/repositories.dart';
import 'package:maki_mobile_pos/presentation/mobile/screens/reports/price_change_report_screen.dart';
import 'package:maki_mobile_pos/presentation/providers/providers.dart';

void main() {
  testWidgets('renders price-change rows from the provider', (tester) async {
    final rows = priceChangeRowsInRange([
      PriceChangeEntry(
          id: 'a', productId: 'p1', price: 120, cost: 70,
          changedAt: DateTime(2026, 6, 10), changedBy: 'u1',
          reason: 'receiving'),
    ]);
    await tester.pumpWidget(ProviderScope(
      overrides: [
        priceChangeReportProvider.overrideWith((ref, params) async => rows),
        productsProvider.overrideWith((ref) => Stream.value(const [])),
      ],
      child: const MaterialApp(home: PriceChangeReportScreen()),
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.textContaining('receiving'), findsWidgets);
  });
}
```

- [ ] **Step 3: Run test to verify it fails**

Run: `flutter test test/presentation/mobile/screens/reports/price_change_report_screen_test.dart`
Expected: FAIL — `PriceChangeReportScreen` undefined.

- [ ] **Step 4: Implement the screen** (mirror `labor_report_screen.dart` structure — app bar with Export action, `DateRangePicker` default `thisMonth`, `reportAsync.when` skeleton/error/data list). Full file:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:maki_mobile_pos/config/router/router.dart';
import 'package:maki_mobile_pos/core/extensions/navigation_extensions.dart';
import 'package:maki_mobile_pos/core/extensions/num_extensions.dart';
import 'package:maki_mobile_pos/core/theme/theme.dart';
import 'package:maki_mobile_pos/core/utils/price_change_report.dart';
import 'package:maki_mobile_pos/core/utils/report_csv.dart';
import 'package:maki_mobile_pos/core/utils/report_date_range.dart';
import 'package:maki_mobile_pos/core/utils/report_export.dart';
import 'package:maki_mobile_pos/domain/entities/entities.dart';
import 'package:maki_mobile_pos/presentation/providers/providers.dart';
import 'package:maki_mobile_pos/presentation/mobile/widgets/reports/reports_widgets.dart';
import 'package:maki_mobile_pos/presentation/shared/widgets/common/common_widgets.dart';
import 'package:intl/intl.dart';

/// Admin-only report: price/cost changes across all products in a date range.
class PriceChangeReportScreen extends ConsumerStatefulWidget {
  const PriceChangeReportScreen({super.key});
  @override
  ConsumerState<PriceChangeReportScreen> createState() =>
      _PriceChangeReportScreenState();
}

class _PriceChangeReportScreenState
    extends ConsumerState<PriceChangeReportScreen> {
  late DateTime _startDate;
  late DateTime _endDate;
  DateRangePreset _selectedPreset = DateRangePreset.thisMonth;

  @override
  void initState() {
    super.initState();
    final r = dateRangeForPreset(DateRangePreset.thisMonth, DateTime.now());
    _startDate = r.start;
    _endDate = r.end;
  }

  DateRangeParams get _params =>
      DateRangeParams(startDate: _startDate, endDate: _endDate);

  Map<String, String> _labels(List<ProductEntity> products) => {
        for (final p in products) p.id: '${p.name} (${p.sku})',
      };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final reportAsync = ref.watch(priceChangeReportProvider(_params));
    final products = ref.watch(productsProvider).valueOrNull ?? const [];
    final labels = _labels(products);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Price Changes'),
        leading: IconButton(
          icon: const Icon(LucideIcons.chevronLeft),
          onPressed: () => context.goBackOr(RoutePaths.reports),
        ),
        actions: [
          IconButton(
            icon: const Icon(LucideIcons.download),
            tooltip: 'Export CSV',
            onPressed: () => _exportCsv(labels),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(priceChangeReportProvider(_params)),
        child: ListView(
          children: [
            DateRangePicker(
              startDate: _startDate,
              endDate: _endDate,
              selectedPreset: _selectedPreset,
              onPresetChanged: (preset) {
                if (preset == DateRangePreset.custom) return;
                final r = dateRangeForPreset(preset, DateTime.now());
                setState(() {
                  _startDate = r.start;
                  _endDate = r.end;
                  _selectedPreset = preset;
                });
              },
              onCustomRangeSelected: (start, end) {
                setState(() {
                  _startDate = start;
                  _endDate = DateTime(end.year, end.month, end.day, 23, 59, 59);
                  _selectedPreset = DateRangePreset.custom;
                });
              },
            ),
            reportAsync.when(
              loading: () => const Padding(
                padding: EdgeInsets.fromLTRB(16, 16, 16, 0),
                child: SizedBox(height: 300, child: ListSkeleton()),
              ),
              error: (e, _) => Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                child: ErrorStateView(
                  message: 'Failed to load price changes: $e',
                  onRetry: () =>
                      ref.invalidate(priceChangeReportProvider(_params)),
                ),
              ),
              data: (rows) => _buildList(theme, rows, labels),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildList(
      ThemeData theme, List<PriceChangeRow> rows, Map<String, String> labels) {
    if (rows.isEmpty) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 24, 16, 0),
        child: EmptyStateView(
          icon: LucideIcons.tag,
          title: 'No price changes',
          subtitle: 'Price/cost changes in this range will appear here.',
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          for (final row in rows)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: _PriceChangeRowCard(
                row: row,
                label: labels[row.entry.productId] ?? row.entry.productId,
                theme: theme,
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _exportCsv(Map<String, String> labels) async {
    final rows = await ref.read(priceChangeReportProvider(_params).future);
    if (!mounted) return;
    if (rows.isEmpty) {
      context.showSnackBar('No price changes to export in this range');
      return;
    }
    final d = DateFormat('yyyy-MM-dd');
    final name =
        'price-changes_${d.format(_startDate)}_to_${d.format(_endDate)}.csv';
    if (!mounted) return;
    await saveReportCsv(context, buildPriceChangeReportCsv(rows, labels), name);
  }
}

class _PriceChangeRowCard extends StatelessWidget {
  const _PriceChangeRowCard(
      {required this.row, required this.label, required this.theme});
  final PriceChangeRow row;
  final String label;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    final muted = theme.colorScheme.onSurfaceVariant;
    final e = row.entry;
    final when = DateFormat('MMM d, y • h:mm a').format(e.changedAt);
    return AppCard(
      radius: 12,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodyMedium
                  ?.copyWith(fontWeight: FontWeight.w600, fontSize: 13.5)),
          const SizedBox(height: 4),
          Row(
            children: [
              _MoneyDelta(label: 'Price', value: e.price, delta: row.priceDelta,
                  hasPrior: row.hasPrior, theme: theme),
              const SizedBox(width: 16),
              _MoneyDelta(label: 'Cost', value: e.cost, delta: row.costDelta,
                  hasPrior: row.hasPrior, theme: theme),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '${e.reason ?? 'change'} · $when',
            style: theme.textTheme.bodySmall?.copyWith(color: muted, fontSize: 11.5),
          ),
        ],
      ),
    );
  }
}

class _MoneyDelta extends StatelessWidget {
  const _MoneyDelta(
      {required this.label,
      required this.value,
      required this.delta,
      required this.hasPrior,
      required this.theme});
  final String label;
  final double value;
  final double delta;
  final bool hasPrior;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    final isDark = theme.brightness == Brightness.dark;
    final muted = theme.colorScheme.onSurfaceVariant;
    final up = delta > 0;
    final deltaColor = up ? AppColors.costUp(isDark) : AppColors.costDown(isDark);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('$label ', style: theme.textTheme.bodySmall?.copyWith(color: muted, fontSize: 11.5)),
        Text(value.toCurrency(),
            style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600, fontSize: 12.5)),
        if (hasPrior && delta != 0) ...[
          const SizedBox(width: 4),
          Icon(up ? LucideIcons.arrowUpRight : LucideIcons.arrowDownRight,
              size: 12, color: deltaColor),
          Text(delta.abs().toCurrency(),
              style: theme.textTheme.bodySmall?.copyWith(color: deltaColor, fontSize: 11)),
        ],
      ],
    );
  }
}
```

> If `AppColors.costUp`/`costDown` don't exist, use `AppColors.error` (up) and
> `AppColors.successText(isDark)` (down) — check `app_colors.dart` and use the
> existing up/down cost colors (the receiving screen's variance display uses
> them).

- [ ] **Step 5: Run test + analyze**

Run: `flutter analyze lib/presentation/mobile/screens/reports/price_change_report_screen.dart lib/presentation/providers/product_provider.dart`
Expected: No issues (fix any unused imports / missing color helpers).
Run: `flutter test test/presentation/mobile/screens/reports/price_change_report_screen_test.dart`
Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add lib/presentation/providers/product_provider.dart lib/presentation/mobile/screens/reports/price_change_report_screen.dart test/presentation/mobile/screens/reports/price_change_report_screen_test.dart
git commit -m "feat(reports): price-change report screen + provider"
```

---

### Task 5: Mobile — hub card + route

**Files:**
- Modify: `lib/config/router/route_names.dart`, `app_routes.dart`, `route_guards.dart`
- Modify: `lib/presentation/mobile/screens/reports/reports_hub_screen.dart`
- Test: `test/presentation/mobile/screens/reports/reports_hub_screen_test.dart` (extend)

**Interfaces:**
- Consumes: `PriceChangeReportScreen` (Task 4), `Permission.viewProductCost`.

- [ ] **Step 1: Add route name + path**

In `route_names.dart` after the labor report name: `static const String priceChangeReport = 'priceChangeReport';` and after the labor path: `static const String priceChangeReport = '/reports/price-changes';`.

- [ ] **Step 2: Add the route + import** in `app_routes.dart`

Import: `import 'package:maki_mobile_pos/presentation/mobile/screens/reports/price_change_report_screen.dart';`
Add child under `/reports` (next to `labor`):
```dart
          GoRoute(
            path: 'price-changes',
            name: RouteNames.priceChangeReport,
            builder: (context, state) => const PriceChangeReportScreen(),
          ),
```

- [ ] **Step 3: Guard it** in `route_guards.dart`, in the reports map:
```dart
    '/reports/price-changes': Permission.viewProductCost,
```

- [ ] **Step 4: Add the hub card** — in `reports_hub_screen.dart`, compute `canCost` and add a card:
```dart
    final canCost = user != null &&
        RolePermissions.hasPermission(user.role, Permission.viewProductCost);
```
Add after the Labor card:
```dart
          if (canCost) ...[
            const SizedBox(height: 10),
            _ReportCard(
              icon: LucideIcons.tag,
              title: 'Price Changes',
              subtitle: 'Price/cost changes across products',
              onTap: () => context.pushNamed(RouteNames.priceChangeReport),
            ),
          ],
```

- [ ] **Step 5: Extend the hub test** — in `reports_hub_screen_test.dart`, in the admin test add `expect(find.text('Price Changes'), findsOneWidget);` and in the non-admin (cashier) test add `expect(find.text('Price Changes'), findsNothing);`.

- [ ] **Step 6: Analyze + test + commit**

Run: `flutter analyze lib/config/router lib/presentation/mobile/screens/reports/reports_hub_screen.dart`
Run: `flutter test test/presentation/mobile/screens/reports/reports_hub_screen_test.dart test/config/router/`
Expected: PASS.
```bash
git add lib/config/router/route_names.dart lib/config/router/app_routes.dart lib/config/router/route_guards.dart lib/presentation/mobile/screens/reports/reports_hub_screen.dart test/presentation/mobile/screens/reports/reports_hub_screen_test.dart
git commit -m "feat(reports): price-change report route + hub card (admin)"
```

---

### Task 6: Web — `priceChangeReport.ts` domain helper

**Files:**
- Create: `web_admin/src/domain/products/priceChangeReport.ts`
- Test: `web_admin/src/domain/products/priceChangeReport.test.ts`

**Interfaces:**
- Produces: `interface PriceChangeEntry extends PriceHistoryEntry { id: string; productId: string }`; `interface PriceChangeRow { entry: PriceChangeEntry; priceDelta: number; costDelta: number; hasPrior: boolean }`; `function priceChangeRowsInRange(entries: PriceChangeEntry[]): PriceChangeRow[]`.

- [ ] **Step 1: Write the failing test**

```ts
// web_admin/src/domain/products/priceChangeReport.test.ts
import { describe, expect, it } from 'vitest';
import { priceChangeRowsInRange, type PriceChangeEntry } from './priceChangeReport';

const e = (
  productId: string, at: string, price: number, cost: number,
): PriceChangeEntry => ({
  id: `${productId}-${at}`, productId, price, cost,
  changedAt: new Date(at), changedBy: 'u1', reason: 'receiving', note: null,
});

describe('priceChangeRowsInRange', () => {
  it('groups by product, deltas vs prior, newest-first', () => {
    const rows = priceChangeRowsInRange([
      e('p1', '2026-06-10T09:00:00Z', 120, 70),
      e('p2', '2026-06-20T09:00:00Z', 250, 180),
      e('p1', '2026-06-01T09:00:00Z', 100, 60),
    ]);
    expect(rows.map((r) => r.entry.productId)).toEqual(['p2', 'p1', 'p1']);
    const p1Jun10 = rows[1];
    expect(p1Jun10.hasPrior).toBe(true);
    expect(p1Jun10.priceDelta).toBe(20);
    expect(rows[2].hasPrior).toBe(false); // oldest p1
  });

  it('empty -> empty', () => {
    expect(priceChangeRowsInRange([])).toEqual([]);
  });
});
```

- [ ] **Step 2: Run to verify it fails**

Run: `cd web_admin && npx vitest run src/domain/products/priceChangeReport.test.ts`
Expected: FAIL — module not found.

- [ ] **Step 3: Implement**

```ts
// web_admin/src/domain/products/priceChangeReport.ts
import type { PriceHistoryEntry } from '../repositories/ProductRepository';

export interface PriceChangeEntry extends PriceHistoryEntry {
  id: string;
  productId: string;
}

export interface PriceChangeRow {
  entry: PriceChangeEntry;
  priceDelta: number;
  costDelta: number;
  hasPrior: boolean;
}

/** Groups by product, computes deltas vs the prior in-range change per product
 *  (oldest-per-product has no prior), returns rows newest-first. */
export function priceChangeRowsInRange(entries: PriceChangeEntry[]): PriceChangeRow[] {
  const byProduct = new Map<string, PriceChangeEntry[]>();
  for (const e of entries) {
    const list = byProduct.get(e.productId) ?? [];
    list.push(e);
    byProduct.set(e.productId, list);
  }

  const rows: PriceChangeRow[] = [];
  for (const group of byProduct.values()) {
    group.sort((a, b) => a.changedAt.getTime() - b.changedAt.getTime());
    let prior: PriceChangeEntry | null = null;
    for (const e of group) {
      rows.push({
        entry: e,
        priceDelta: prior ? e.price - prior.price : 0,
        costDelta: prior ? e.cost - prior.cost : 0,
        hasPrior: prior !== null,
      });
      prior = e;
    }
  }
  rows.sort((a, b) => b.entry.changedAt.getTime() - a.entry.changedAt.getTime());
  return rows;
}
```

- [ ] **Step 4: Run to verify it passes**

Run: `cd web_admin && npx vitest run src/domain/products/priceChangeReport.test.ts`
Expected: PASS (2 tests).

- [ ] **Step 5: Commit**

```bash
git add web_admin/src/domain/products/priceChangeReport.ts web_admin/src/domain/products/priceChangeReport.test.ts
git commit -m "feat(web-reports): cross-product price-change delta helper"
```

---

### Task 7: Web — repo method + hook + page

**Files:**
- Modify: `web_admin/src/domain/repositories/ProductRepository.ts` (add method sig)
- Modify: `web_admin/src/data/repositories/FirestoreProductRepository.ts` (impl)
- Create: `web_admin/src/presentation/hooks/usePriceChangeReport.ts`
- Create: `web_admin/src/presentation/features/reports/PriceChangeReportPage.tsx`

**Interfaces:**
- Consumes: `priceChangeRowsInRange`, `PriceChangeEntry` (Task 6), `DateRange`/`resolvePreset`, `DateRangePicker`, `formatMoney`.
- Produces: `ProductRepository.listPriceChangesInRange(start, end, limit?): Promise<PriceChangeEntry[]>`; `usePriceChangeReport(range)`; `PriceChangeReportPage`.

- [ ] **Step 1: Add the repo method sig** — in `ProductRepository.ts`, add near `listPriceHistory`:
```ts
  listPriceChangesInRange(start: Date, end: Date, limit?: number): Promise<PriceChangeEntry[]>;
```
and `import type { PriceChangeEntry } from '@/domain/products/priceChangeReport';` at the top.

- [ ] **Step 2: Implement in `FirestoreProductRepository.ts`** (add `collectionGroup`, `where`, `orderBy`, `limit`, `Timestamp` to the firestore imports if missing):
```ts
  async listPriceChangesInRange(start: Date, end: Date, max = 500): Promise<PriceChangeEntry[]> {
    const q = query(
      collectionGroup(this.db, FirestoreCollections.priceHistory),
      where('changedAt', '>=', Timestamp.fromDate(start)),
      where('changedAt', '<=', Timestamp.fromDate(end)),
      orderBy('changedAt', 'desc'),
      limit(max),
    );
    const snap = await getDocs(q);
    return snap.docs.map((d) => {
      const data = d.data() as Record<string, unknown>;
      return {
        id: d.id,
        productId: d.ref.parent.parent!.id,
        price: Number(data.price ?? 0),
        cost: Number(data.cost ?? 0),
        changedAt: (data.changedAt as Timestamp).toDate(),
        changedBy: (data.changedBy as string) ?? '',
        reason: (data.reason as string | null) ?? null,
        note: (data.note as string | null) ?? null,
      } satisfies PriceChangeEntry;
    });
  }
```
Add `import type { PriceChangeEntry } from '@/domain/products/priceChangeReport';`.

- [ ] **Step 3: Add the hook**

```ts
// web_admin/src/presentation/hooks/usePriceChangeReport.ts
import { useQuery } from '@tanstack/react-query';
import { useProductRepo } from '@/infrastructure/di/container';
import {
  priceChangeRowsInRange,
  type PriceChangeRow,
} from '@/domain/products/priceChangeReport';
import type { DateRange } from '@/domain/reports/dateRange';

export function usePriceChangeReport(range: DateRange): {
  rows: PriceChangeRow[];
  isLoading: boolean;
  error: Error | null;
} {
  const repo = useProductRepo();
  const q = useQuery({
    queryKey: ['reports', 'price-changes', range.start.getTime(), range.end.getTime()],
    queryFn: () => repo.listPriceChangesInRange(range.start, range.end),
  });
  return {
    rows: q.data ? priceChangeRowsInRange(q.data) : [],
    isLoading: q.isLoading,
    error: (q.error as Error) ?? null,
  };
}
```

- [ ] **Step 4: Add the page** (mirror `LaborReportPage.tsx`: header + `DateRangePicker` + table + CSV download; join product names from `useProducts`; `formatMoney`; signed deltas). Table columns: Product, SKU, New Price, Δ, New Cost, Δ, Reason, By, When. CSV via the existing web download helper used by the other report pages (follow `SalesReportPage`/`LaborReportPage` for the download pattern). Default preset `resolvePreset('thisMonth')` if available, else the web's month preset. Admin-only (route guard covers it).

- [ ] **Step 5: Typecheck + commit**

Run: `cd web_admin && npm run typecheck`
Expected: clean.
```bash
git add web_admin/src/domain/repositories/ProductRepository.ts web_admin/src/data/repositories/FirestoreProductRepository.ts web_admin/src/presentation/hooks/usePriceChangeReport.ts web_admin/src/presentation/features/reports/PriceChangeReportPage.tsx
git commit -m "feat(web-reports): price-change repo query + hook + page"
```

---

### Task 8: Web — hub card + route trio

**Files:**
- Modify: `web_admin/src/presentation/router/routePaths.ts`, `routes.tsx`, `routeGuards.ts`
- Modify: `web_admin/src/presentation/features/reports/ReportsHubPage.tsx`

- [ ] **Step 1: routePaths** — add `priceChangeReport: '/reports/price-changes',` after `profitReport`.

- [ ] **Step 2: routes.tsx** — import `PriceChangeReportPage` and add `{ path: RoutePaths.priceChangeReport, element: <PriceChangeReportPage /> },`.

- [ ] **Step 3: routeGuards.ts** — add `[RoutePaths.priceChangeReport, Permission.viewProductCost],` (confirm the web `Permission` enum has `viewProductCost`; if it is named differently, use the admin-only cost permission the per-product price-history route uses).

- [ ] **Step 4: ReportsHubPage.tsx** — add a card (with an appropriate heroicon, e.g. `TagIcon`) linking to `RoutePaths.priceChangeReport`, titled "Price changes", description "Price/cost changes across products". If the hub gates cards by permission, gate this one on `viewProductCost`; otherwise the route guard is the gate.

- [ ] **Step 5: Typecheck + build + commit**

Run: `cd web_admin && npm run typecheck && npm run build`
Expected: clean; build succeeds.
```bash
git add web_admin/src/presentation/router/routePaths.ts web_admin/src/presentation/router/routes.tsx web_admin/src/presentation/router/routeGuards.ts web_admin/src/presentation/features/reports/ReportsHubPage.tsx
git commit -m "feat(web-reports): price-change route + hub card"
```

---

### Task 9: Firestore rules + index (write; deploy on user go-ahead)

**Files:**
- Modify: `firestore.rules`
- Modify: `firestore.indexes.json`

- [ ] **Step 1: Add the collection-group read rule** — in `firestore.rules`, inside `match /databases/{database}/documents {`, at the top level (a sibling of the collection matches), add:
```
    // Cross-product price-change report reads price_history via a collection
    // group query. The nested products/*/price_history rule governs writes and
    // per-product reads; this recursive-wildcard rule authorizes the group
    // query. Admin-only, same as the nested rule.
    match /{path=**}/price_history/{historyId} {
      allow read: if isAdmin() && isActiveUser();
    }
```

- [ ] **Step 2: Add the collection-group index** — in `firestore.indexes.json`, add a top-level `"fieldOverrides"` array (sibling of `"indexes"`):
```json
  "fieldOverrides": [
    {
      "collectionGroup": "price_history",
      "fieldPath": "changedAt",
      "indexes": [
        { "queryScope": "COLLECTION_GROUP", "order": "ASCENDING" },
        { "queryScope": "COLLECTION_GROUP", "order": "DESCENDING" }
      ]
    }
  ]
```

- [ ] **Step 3: Commit (do NOT deploy yet)**

```bash
git add firestore.rules firestore.indexes.json
git commit -m "chore(firestore): collection-group read rule + index for price_history (deploy-gated)"
```

- [ ] **Step 4: Hand the diffs to the user for deploy**

Report: "Rules + index are committed. To make the report work against production, deploy: `firebase deploy --only firestore:rules,firestore:indexes`. This is production-affecting — say the word and I'll run it, or you can. Until deployed, the report shows a permission/failed-precondition error."

Do NOT run the deploy without explicit confirmation.

---

### Task 10: Full verification

- [ ] **Step 1: Mobile** — `flutter analyze` (No issues) and `flutter test` (all pass, incl. the new price-change tests).
- [ ] **Step 2: Web** — `cd web_admin && npm run typecheck && npm run test && npm run build` (all clean/pass).
- [ ] **Step 3: Note the deploy gate** — remind that rules + index must be deployed (Task 9 Step 4) before the report returns data, and mobile changes need a rebuild + `adb install`.

---

## Self-Review

**Spec coverage:** cross-product query (T1); deltas (T2); mobile screen/provider/hub/route/CSV (T3–T5); web helper/repo/hook/page/hub/route (T6–T8); rules+index (T9); testing throughout; verification (T10). ✓

**Placeholder scan:** logic tasks (T1–T3, T6) carry full code + tests; UI/wiring tasks (T4, T5, T7, T8) give full screen code (T4) or exact edits mirroring the just-built report screens/pages (T7 page references LaborReportPage as the concrete pattern — acceptable since that file exists in-repo). No TBD/TODO. ✓

**Type consistency:** `PriceChangeEntry`/`PriceChangeRow`/`priceChangeRowsInRange`/`getPriceChangesInRange`/`buildPriceChangeReportCsv`/`priceChangeReportProvider` (mobile) and `PriceChangeEntry`/`PriceChangeRow`/`priceChangeRowsInRange`/`listPriceChangesInRange`/`usePriceChangeReport` (web) are used consistently across tasks; route names `priceChangeReport` / `/reports/price-changes` and gate `Permission.viewProductCost` consistent. ✓
