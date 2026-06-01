# Price-History Views — Phase 1 (Mobile) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a dedicated, admin-only, full-screen price-history view per product on the Flutter mobile app — a combined cost+price trend (sparkline) plus a filterable detail table — reachable from a gated tile on `ProductFormScreen`; delete the orphaned `ProductDetailScreen`.

**Architecture:** Pure, widget-free helpers in `lib/core/utils/` (filtering, delta computation, sparkline series, source labels) drive a thin `PriceHistoryScreen`. The screen reuses the existing `priceHistoryProvider(productId)` (reads `products/{id}/price_history`, newest-first, limit 50). A new child route `/inventory/:id/price-history` is guarded by the existing `Permission.viewProductCost` (admin-only). No new dependencies (uses the already-present `fl_chart`), no schema/index changes.

**Tech Stack:** Flutter, Riverpod, go_router, fl_chart, mocktail (tests). Spec: `docs/superpowers/specs/2026-06-01-price-history-views-design.md`.

---

## File Structure

**Create:**
- `lib/core/utils/price_history_view.dart` — `PriceMetric` enum, `PriceHistoryRow` view-model, `buildPriceHistoryRows`, `sparklineSeries`, `derivePriceHistorySource`. Pure, no Flutter/Firestore imports (imports only `PriceHistoryEntry`).
- `lib/presentation/mobile/screens/inventory/price_history_screen.dart` — `PriceHistoryScreen` + private widgets (`_MetricFilter`, `_SparklineSection`, `_Sparkline`, `_HistoryRow`, `_MetricLine`).
- `test/core/utils/price_history_view_test.dart` — unit tests for the helpers.
- `test/presentation/mobile/screens/inventory/price_history_screen_test.dart` — widget tests.

**Modify:**
- `lib/config/router/route_names.dart` — add `productPriceHistory` name.
- `lib/config/router/app_routes.dart` — add the child route + import.
- `lib/config/router/route_guards.dart` — add a dynamic-route branch for the new path.
- `lib/presentation/mobile/screens/inventory/product_form_screen.dart` — add the gated entry tile + go_router import.

**Delete:**
- `lib/presentation/mobile/screens/inventory/product_detail_screen.dart` (dead code).
- The `export 'product_detail_screen.dart';` line in `lib/presentation/mobile/screens/inventory/inventory.dart`.

**Reference (do not modify):**
- `lib/data/models/price_history_model.dart` — `PriceChangeReason` constants (`Initial price`, `Price update`, `Cost update`, `Stock receiving`, `Promotion`, `Supplier change`, `Market adjustment`, `Correction`).
- `lib/domain/repositories/product_repository.dart` — `PriceHistoryEntry` (`id, price, cost, changedAt, changedBy, reason?, note?`).
- `lib/presentation/providers/product_provider.dart:106` — `priceHistoryProvider` (FutureProvider.family).

---

## Task 1: Pure helpers (filtering, deltas, sparkline series, source labels)

**Files:**
- Create: `lib/core/utils/price_history_view.dart`
- Test: `test/core/utils/price_history_view_test.dart`

- [ ] **Step 1: Write the failing test**

Create `test/core/utils/price_history_view_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:maki_mobile_pos/core/utils/price_history_view.dart';
import 'package:maki_mobile_pos/domain/repositories/product_repository.dart'
    show PriceHistoryEntry;

PriceHistoryEntry _e({
  String id = 'e',
  double price = 100,
  double cost = 60,
  DateTime? at,
  String changedBy = 'u1',
  String? reason,
  String? note,
}) {
  return PriceHistoryEntry(
    id: id,
    price: price,
    cost: cost,
    changedAt: at ?? DateTime(2026, 1, 1),
    changedBy: changedBy,
    reason: reason,
    note: note,
  );
}

void main() {
  // newest-first, as getPriceHistory returns.
  final entries = [
    _e(id: 'e3', price: 120, cost: 70, at: DateTime(2026, 3, 1), reason: 'Price update'),
    _e(id: 'e2', price: 110, cost: 70, at: DateTime(2026, 2, 1), reason: 'Stock receiving', note: 'RCV-20260201-003'),
    _e(id: 'e1', price: 110, cost: 60, at: DateTime(2026, 1, 1), reason: 'Initial price'),
  ];

  group('buildPriceHistoryRows', () {
    test('all metric keeps every entry with deltas vs the older entry', () {
      final rows = buildPriceHistoryRows(entries, PriceMetric.all);
      expect(rows.length, 3);
      expect(rows[0].entry.id, 'e3');
      expect(rows[0].priceDelta, closeTo(10, 1e-9));
      expect(rows[0].costDelta, closeTo(0, 1e-9));
      expect(rows[0].hasPrior, isTrue);
      expect(rows[2].entry.id, 'e1');
      expect(rows[2].hasPrior, isFalse);
      expect(rows[2].priceDelta, 0);
    });

    test('price filter keeps origin + entries where price moved', () {
      final rows = buildPriceHistoryRows(entries, PriceMetric.price);
      expect(rows.map((r) => r.entry.id).toList(), ['e3', 'e1']);
    });

    test('cost filter keeps origin + entries where cost moved', () {
      final rows = buildPriceHistoryRows(entries, PriceMetric.cost);
      expect(rows.map((r) => r.entry.id).toList(), ['e2', 'e1']);
    });

    test('empty input yields no rows', () {
      expect(buildPriceHistoryRows(const [], PriceMetric.all), isEmpty);
    });
  });

  group('sparklineSeries', () {
    test('returns price values oldest-first', () {
      expect(sparklineSeries(entries, forCost: false), [110, 110, 120]);
    });
    test('returns cost values oldest-first', () {
      expect(sparklineSeries(entries, forCost: true), [60, 70, 70]);
    });
  });

  group('derivePriceHistorySource', () {
    test('maps known reasons to friendly labels', () {
      expect(derivePriceHistorySource('Initial price', null), 'Created');
      expect(derivePriceHistorySource('Price update', null), 'Manual edit');
      expect(derivePriceHistorySource('Cost update', null), 'Manual edit');
    });
    test('receiving appends the RCV id from note when present', () {
      expect(derivePriceHistorySource('Stock receiving', 'RCV-20260201-003'),
          'Receiving (RCV-20260201-003)');
      expect(derivePriceHistorySource('Stock receiving', null), 'Receiving');
    });
    test('null/empty reason -> Edit; unknown reason shown as-is', () {
      expect(derivePriceHistorySource(null, null), 'Edit');
      expect(derivePriceHistorySource('', null), 'Edit');
      expect(derivePriceHistorySource('Promotion', null), 'Promotion');
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/core/utils/price_history_view_test.dart`
Expected: FAIL — `Error: Couldn't resolve the package 'price_history_view.dart'` / target of URI doesn't exist (the file doesn't exist yet).

- [ ] **Step 3: Write the implementation**

Create `lib/core/utils/price_history_view.dart`:

```dart
import 'package:maki_mobile_pos/domain/repositories/product_repository.dart'
    show PriceHistoryEntry;

/// Which metric the dedicated price-history view is filtered to.
enum PriceMetric { all, price, cost }

/// A price-history entry paired with its change vs. the chronologically
/// previous (older) entry. For the oldest entry there is no prior, so the
/// deltas are 0 and [hasPrior] is false — it is the origin of every series.
class PriceHistoryRow {
  const PriceHistoryRow({
    required this.entry,
    required this.priceDelta,
    required this.costDelta,
    required this.hasPrior,
  });

  final PriceHistoryEntry entry;
  final double priceDelta;
  final double costDelta;
  final bool hasPrior;
}

/// Smallest change treated as a real move (guards against float noise).
const double _eps = 0.005;

/// Builds display rows from [entriesNewestFirst] (as returned by
/// `getPriceHistory`), filtered to [metric].
///
/// Deltas are computed against the chronologically previous entry — the NEXT
/// element in the newest-first list. The oldest entry has no prior, so its
/// deltas are 0 and it is always kept (origin point of every series). For
/// [PriceMetric.price] / [PriceMetric.cost], an entry is kept when it has no
/// prior OR that metric moved by more than [_eps].
List<PriceHistoryRow> buildPriceHistoryRows(
  List<PriceHistoryEntry> entriesNewestFirst,
  PriceMetric metric,
) {
  final rows = <PriceHistoryRow>[];
  for (var i = 0; i < entriesNewestFirst.length; i++) {
    final entry = entriesNewestFirst[i];
    final prior =
        i + 1 < entriesNewestFirst.length ? entriesNewestFirst[i + 1] : null;
    final hasPrior = prior != null;
    final priceDelta = hasPrior ? entry.price - prior.price : 0.0;
    final costDelta = hasPrior ? entry.cost - prior.cost : 0.0;

    final keep = switch (metric) {
      PriceMetric.all => true,
      PriceMetric.price => !hasPrior || priceDelta.abs() > _eps,
      PriceMetric.cost => !hasPrior || costDelta.abs() > _eps,
    };
    if (keep) {
      rows.add(PriceHistoryRow(
        entry: entry,
        priceDelta: priceDelta,
        costDelta: costDelta,
        hasPrior: hasPrior,
      ));
    }
  }
  return rows;
}

/// Returns the metric values in chronological order (oldest -> newest) for the
/// sparkline. Pass [forCost] true for the cost series, false for the price
/// series. Always reflects the full history regardless of the active filter.
List<double> sparklineSeries(
  List<PriceHistoryEntry> entriesNewestFirst, {
  required bool forCost,
}) {
  final values = [
    for (final e in entriesNewestFirst) forCost ? e.cost : e.price,
  ];
  return values.reversed.toList();
}

/// Maps a price-history [reason] (a `PriceChangeReason` constant) plus optional
/// [note] to a human label for the "Source" column.
String derivePriceHistorySource(String? reason, String? note) {
  switch (reason) {
    case 'Initial price':
      return 'Created';
    case 'Price update':
    case 'Cost update':
      return 'Manual edit';
    case 'Stock receiving':
      final rcv = _receivingId(note);
      return rcv == null ? 'Receiving' : 'Receiving ($rcv)';
    case null:
    case '':
      return 'Edit';
    default:
      return reason;
  }
}

/// Extracts an `RCV-YYYYMMDD-N` id from a free-text [note], if present.
String? _receivingId(String? note) {
  if (note == null) return null;
  final match = RegExp(r'RCV-\d{8}-\d+').firstMatch(note);
  return match?.group(0);
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/core/utils/price_history_view_test.dart`
Expected: PASS (all 9 tests green).

- [ ] **Step 5: Commit**

```bash
git add lib/core/utils/price_history_view.dart test/core/utils/price_history_view_test.dart
git commit -m "feat(price-history): pure helpers for filtering, deltas, sparkline, source labels"
```

---

## Task 2: PriceHistoryScreen widget

**Files:**
- Create: `lib/presentation/mobile/screens/inventory/price_history_screen.dart`
- Test: `test/presentation/mobile/screens/inventory/price_history_screen_test.dart`

- [ ] **Step 1: Write the failing widget test**

Create `test/presentation/mobile/screens/inventory/price_history_screen_test.dart`:

```dart
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:maki_mobile_pos/domain/entities/user_entity.dart';
import 'package:maki_mobile_pos/core/enums/enums.dart';
import 'package:maki_mobile_pos/domain/repositories/product_repository.dart'
    show PriceHistoryEntry;
import 'package:maki_mobile_pos/presentation/mobile/screens/inventory/price_history_screen.dart';
import 'package:maki_mobile_pos/presentation/providers/product_provider.dart';
import 'package:maki_mobile_pos/presentation/providers/user_provider.dart';

PriceHistoryEntry _e(String id, double price, double cost, DateTime at,
        {String? reason}) =>
    PriceHistoryEntry(
      id: id,
      price: price,
      cost: cost,
      changedAt: at,
      changedBy: 'u1',
      reason: reason,
    );

final _actor = UserEntity(
  id: 'u1',
  email: 'a@test',
  displayName: 'Alice Admin',
  role: UserRole.admin,
  isActive: true,
  createdAt: DateTime(2024, 1, 1),
);

Future<void> _pump(
  WidgetTester tester,
  List<PriceHistoryEntry> entries,
) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        priceHistoryProvider('p-1').overrideWith((ref) async => entries),
        userByIdProvider('u1').overrideWith((ref) async => _actor),
      ],
      child: const MaterialApp(
        home: PriceHistoryScreen(productId: 'p-1'),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('shows empty state when there is no history', (tester) async {
    await _pump(tester, const []);
    expect(find.text('No price changes yet.'), findsOneWidget);
    expect(find.byType(LineChart), findsNothing);
  });

  testWidgets('single entry hides the sparkline with a caption', (tester) async {
    await _pump(tester, [_e('e1', 100, 60, DateTime(2026, 1, 1), reason: 'Initial price')]);
    expect(find.text('Not enough changes to chart'), findsOneWidget);
    expect(find.byType(LineChart), findsNothing);
    expect(find.text('Created'), findsOneWidget); // source label
  });

  testWidgets('multiple entries render sparkline, filter, and rows',
      (tester) async {
    await _pump(tester, [
      _e('e2', 120, 70, DateTime(2026, 2, 1), reason: 'Price update'),
      _e('e1', 100, 60, DateTime(2026, 1, 1), reason: 'Initial price'),
    ]);
    expect(find.byType(LineChart), findsWidgets);
    expect(find.byType(SegmentedButton<PriceMetric>), findsOneWidget);
    expect(find.text('Alice Admin'), findsWidgets);

    // Switch to the Cost filter — should not throw and still render a chart.
    await tester.tap(find.text('Cost'));
    await tester.pumpAndSettle();
    expect(find.byType(LineChart), findsWidgets);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/presentation/mobile/screens/inventory/price_history_screen_test.dart`
Expected: FAIL — target of URI doesn't exist (`price_history_screen.dart` not created yet).

- [ ] **Step 3: Write the implementation**

Create `lib/presentation/mobile/screens/inventory/price_history_screen.dart`:

```dart
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:maki_mobile_pos/core/constants/app_constants.dart';
import 'package:maki_mobile_pos/core/theme/theme.dart';
import 'package:maki_mobile_pos/core/utils/price_history_view.dart';
import 'package:maki_mobile_pos/domain/repositories/product_repository.dart'
    show PriceHistoryEntry;
import 'package:maki_mobile_pos/presentation/providers/providers.dart';

/// Full-screen, admin-only price-history view for a single product. Combined
/// cost + selling-price, with an All / Price / Cost filter, a sparkline trend,
/// and a detailed table. Reuses [priceHistoryProvider] (newest-first, limit 50).
class PriceHistoryScreen extends ConsumerStatefulWidget {
  const PriceHistoryScreen({super.key, required this.productId});
  final String productId;

  @override
  ConsumerState<PriceHistoryScreen> createState() =>
      _PriceHistoryScreenState();
}

class _PriceHistoryScreenState extends ConsumerState<PriceHistoryScreen> {
  PriceMetric _metric = PriceMetric.all;

  @override
  Widget build(BuildContext context) {
    final historyAsync = ref.watch(priceHistoryProvider(widget.productId));
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(CupertinoIcons.back),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: const Text('Price History'),
      ),
      body: historyAsync.when(
        data: (entries) => _buildBody(context, entries),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => const Center(
          child: Padding(
            padding: EdgeInsets.all(AppSpacing.lg),
            child: Text('Could not load price history'),
          ),
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context, List<PriceHistoryEntry> entries) {
    if (entries.isEmpty) {
      return const Center(child: Text('No price changes yet.'));
    }
    final rows = buildPriceHistoryRows(entries, _metric);
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        _MetricFilter(
          selected: _metric,
          onChanged: (m) => setState(() => _metric = m),
        ),
        const SizedBox(height: AppSpacing.lg),
        _SparklineSection(entries: entries, metric: _metric),
        const SizedBox(height: AppSpacing.lg),
        for (var i = 0; i < rows.length; i++)
          _HistoryRow(row: rows[i], metric: _metric, isFirst: i == 0),
      ],
    );
  }
}

/// Segmented All / Price / Cost filter.
class _MetricFilter extends StatelessWidget {
  const _MetricFilter({required this.selected, required this.onChanged});
  final PriceMetric selected;
  final ValueChanged<PriceMetric> onChanged;

  @override
  Widget build(BuildContext context) {
    return SegmentedButton<PriceMetric>(
      showSelectedIcon: false,
      segments: const [
        ButtonSegment(value: PriceMetric.all, label: Text('All')),
        ButtonSegment(value: PriceMetric.price, label: Text('Price')),
        ButtonSegment(value: PriceMetric.cost, label: Text('Cost')),
      ],
      selected: {selected},
      onSelectionChanged: (s) => onChanged(s.first),
    );
  }
}

/// Stacked, separately-scaled sparklines for the active metric(s). Hidden with
/// a caption when there are fewer than two data points.
class _SparklineSection extends StatelessWidget {
  const _SparklineSection({required this.entries, required this.metric});
  final List<PriceHistoryEntry> entries;
  final PriceMetric metric;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (entries.length < 2) {
      return Text(
        'Not enough changes to chart',
        style: theme.textTheme.bodySmall
            ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
      );
    }
    final showPrice = metric != PriceMetric.cost;
    final showCost = metric != PriceMetric.price;
    final lineColor = theme.colorScheme.primary;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (showPrice) ...[
          _SparklineLabel('Price'),
          _Sparkline(
            values: sparklineSeries(entries, forCost: false),
            color: lineColor,
          ),
          if (showCost) const SizedBox(height: AppSpacing.md),
        ],
        if (showCost) ...[
          _SparklineLabel('Cost'),
          _Sparkline(
            values: sparklineSeries(entries, forCost: true),
            color: lineColor,
          ),
        ],
      ],
    );
  }
}

class _SparklineLabel extends StatelessWidget {
  const _SparklineLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Text(
        text,
        style: theme.textTheme.labelSmall
            ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
      ),
    );
  }
}

/// Minimal axis-less, touch-less fl_chart line — a sparkline. [values] are
/// chronological and length >= 2.
class _Sparkline extends StatelessWidget {
  const _Sparkline({required this.values, required this.color});
  final List<double> values;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final spots = <FlSpot>[
      for (var i = 0; i < values.length; i++) FlSpot(i.toDouble(), values[i]),
    ];
    return SizedBox(
      height: 44,
      child: LineChart(
        LineChartData(
          lineTouchData: const LineTouchData(enabled: false),
          gridData: const FlGridData(show: false),
          titlesData: const FlTitlesData(show: false),
          borderData: FlBorderData(show: false),
          minX: 0,
          maxX: (values.length - 1).toDouble(),
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              isCurved: false,
              color: color,
              barWidth: 2,
              dotData: const FlDotData(show: false),
            ),
          ],
        ),
      ),
    );
  }
}

/// One table row: metric value(s) with old->new arrows, then date / actor /
/// source. Mirrors the layout previously used by the inline card.
class _HistoryRow extends ConsumerWidget {
  const _HistoryRow({
    required this.row,
    required this.metric,
    required this.isFirst,
  });
  final PriceHistoryRow row;
  final PriceMetric metric;
  final bool isFirst;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    final isDark = theme.brightness == Brightness.dark;
    final hairline =
        isDark ? AppColors.darkHairline : AppColors.lightHairline;
    final dateFormat = DateFormat('MMM d, y • h:mm a');

    final entry = row.entry;
    final showPrice = metric != PriceMetric.cost;
    final showCost = metric != PriceMetric.price;
    final source = derivePriceHistorySource(entry.reason, entry.note);

    final userAsync = ref.watch(userByIdProvider(entry.changedBy));
    final who = userAsync.whenOrNull(data: (u) => u?.displayName) ?? '—';

    return Container(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm + 2),
      decoration: isFirst
          ? null
          : BoxDecoration(border: Border(top: BorderSide(color: hairline))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (showPrice)
                Expanded(
                  child: _MetricLine(
                    label: 'Price',
                    value: entry.price,
                    delta: row.hasPrior ? row.priceDelta : 0,
                  ),
                ),
              if (showPrice && showCost) const SizedBox(width: AppSpacing.md),
              if (showCost)
                Expanded(
                  child: _MetricLine(
                    label: 'Cost',
                    value: entry.cost,
                    delta: row.hasPrior ? row.costDelta : 0,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(dateFormat.format(entry.changedAt),
                  style: theme.textTheme.bodySmall?.copyWith(color: muted)),
              Text('•',
                  style: theme.textTheme.bodySmall?.copyWith(color: muted)),
              Text(who,
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: muted, fontWeight: FontWeight.w500)),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm, vertical: 2),
                decoration: BoxDecoration(
                  border: Border.all(color: hairline),
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                child: Text(source,
                    style: theme.textTheme.labelSmall?.copyWith(color: muted)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// One labelled value with an up/down arrow + delta when it changed.
class _MetricLine extends StatelessWidget {
  const _MetricLine({
    required this.label,
    required this.value,
    required this.delta,
  });
  final String label;
  final double value;
  final double delta;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    final changed = delta.abs() > 0.01;
    final up = delta > 0;
    final arrowColor =
        !changed ? muted : (up ? AppColors.successDark : AppColors.errorDark);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('$label ',
            style: theme.textTheme.bodySmall?.copyWith(color: muted)),
        Text('${AppConstants.currencySymbol}${value.toStringAsFixed(2)}',
            style: theme.textTheme.bodyMedium
                ?.copyWith(fontWeight: FontWeight.w600)),
        if (changed) ...[
          const SizedBox(width: 4),
          Icon(up ? CupertinoIcons.arrow_up : CupertinoIcons.arrow_down,
              size: 12, color: arrowColor),
          Text('${AppConstants.currencySymbol}${delta.abs().toStringAsFixed(2)}',
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: arrowColor, fontWeight: FontWeight.w500)),
        ],
      ],
    );
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/presentation/mobile/screens/inventory/price_history_screen_test.dart`
Expected: PASS (3 widget tests green).

> If `fl_chart` 1.1.x flags an API mismatch (e.g. a renamed const), adjust only the `_Sparkline` `LineChartData` fields to match the installed version — the surrounding logic is unaffected. Re-run the test.

- [ ] **Step 5: Run analyze**

Run: `flutter analyze lib/presentation/mobile/screens/inventory/price_history_screen.dart lib/core/utils/price_history_view.dart`
Expected: "No issues found!"

- [ ] **Step 6: Commit**

```bash
git add lib/presentation/mobile/screens/inventory/price_history_screen.dart test/presentation/mobile/screens/inventory/price_history_screen_test.dart
git commit -m "feat(price-history): full-screen PriceHistoryScreen (sparkline + filterable table)"
```

---

## Task 3: Route + guard wiring

**Files:**
- Modify: `lib/config/router/route_names.dart:46`
- Modify: `lib/config/router/app_routes.dart:16` (import) and `:209-216` (child route)
- Modify: `lib/config/router/route_guards.dart:139` (new dynamic-route branch)

- [ ] **Step 1: Add the route name**

In `lib/config/router/route_names.dart`, after the `productDetail` constant (line 46), add:

```dart

  /// Product price-history view route
  static const String productPriceHistory = 'productPriceHistory';
```

- [ ] **Step 2: Add the screen import to app_routes.dart**

In `lib/config/router/app_routes.dart`, immediately after the existing
`import '.../inventory/product_form_screen.dart';` line (line 16), add:

```dart
import 'package:maki_mobile_pos/presentation/mobile/screens/inventory/price_history_screen.dart';
```

- [ ] **Step 3: Add the child route**

In `lib/config/router/app_routes.dart`, replace the `:id` `GoRoute` (currently lines 209-216):

```dart
          GoRoute(
            path: ':id',
            name: RouteNames.productDetail,
            builder: (context, state) {
              final id = state.pathParameters['id']!;
              return ProductFormScreen(productId: id);
            },
          ),
```

with:

```dart
          GoRoute(
            path: ':id',
            name: RouteNames.productDetail,
            builder: (context, state) {
              final id = state.pathParameters['id']!;
              return ProductFormScreen(productId: id);
            },
            routes: [
              GoRoute(
                path: 'price-history',
                name: RouteNames.productPriceHistory,
                builder: (context, state) {
                  final id = state.pathParameters['id']!;
                  return PriceHistoryScreen(productId: id);
                },
              ),
            ],
          ),
```

- [ ] **Step 4: Guard the new route**

In `lib/config/router/route_guards.dart`, inside `_checkDynamicRoute`, immediately
after the inventory-edit branch (the `if (path.startsWith('/inventory/edit/'))`
block ending at line 139) and before the `/inventory/[^/]+$` detail branch, add:

```dart
    // Price-history view lives under /inventory/<id>/price-history — it exposes
    // cost, so it is admin-only via viewProductCost (defense in depth; the UI
    // tile is also gated). Must precede the generic /inventory/<id> branch.
    if (RegExp(r'^/inventory/[^/]+/price-history$').hasMatch(path)) {
      return user.hasPermission(Permission.viewProductCost);
    }
```

- [ ] **Step 5: Verify analyze + existing router behaviour**

Run: `flutter analyze lib/config/router/`
Expected: "No issues found!"

Run: `flutter test test/` (full suite — ensures no route/guard regressions)
Expected: all tests pass (existing count + the new Task 1/2 tests).

- [ ] **Step 6: Commit**

```bash
git add lib/config/router/route_names.dart lib/config/router/app_routes.dart lib/config/router/route_guards.dart
git commit -m "feat(price-history): route /inventory/:id/price-history guarded by viewProductCost"
```

---

## Task 4: Entry-point tile on ProductFormScreen

**Files:**
- Modify: `lib/presentation/mobile/screens/inventory/product_form_screen.dart` (import + tile)

- [ ] **Step 1: Add the go_router import**

In `lib/presentation/mobile/screens/inventory/product_form_screen.dart`, after the
existing `import 'package:maki_mobile_pos/config/router/router.dart';` line (line 5),
add:

```dart
import 'package:go_router/go_router.dart';
```

- [ ] **Step 2: Add the gated tile**

In the build method's children list, replace the audit-card block (currently
lines 622-625):

```dart
                    if (widget.isEditing && _existingProduct != null) ...[
                      const SizedBox(height: 24),
                      _AuditInfoCard(product: _existingProduct!),
                    ],
```

with (appends the price-history tile, gated to admin + cost-toggle on, only for
an existing product):

```dart
                    if (widget.isEditing && _existingProduct != null) ...[
                      const SizedBox(height: 24),
                      _AuditInfoCard(product: _existingProduct!),
                    ],
                    if (canViewCost &&
                        widget.isEditing &&
                        inventoryState.showCost) ...[
                      const SizedBox(height: 16),
                      OutlinedButton.icon(
                        onPressed: () => context.push(
                          '/inventory/${widget.productId}/price-history',
                        ),
                        icon: const Icon(CupertinoIcons.clock),
                        label: const Text('View price history'),
                      ),
                    ],
```

- [ ] **Step 3: Verify analyze**

Run: `flutter analyze lib/presentation/mobile/screens/inventory/product_form_screen.dart`
Expected: "No issues found!" (no unused-import warning — `context.push` now uses go_router).

- [ ] **Step 4: Run the form widget test (no regression)**

Run: `flutter test test/presentation/widgets/product_form_screen_test.dart`
Expected: PASS (the tile is gated behind `inventoryState.showCost`, off by default, so existing SKU/dialog tests are unaffected).

- [ ] **Step 5: Commit**

```bash
git add lib/presentation/mobile/screens/inventory/product_form_screen.dart
git commit -m "feat(price-history): gated 'View price history' tile on product form"
```

---

## Task 5: Delete the dead ProductDetailScreen

**Files:**
- Delete: `lib/presentation/mobile/screens/inventory/product_detail_screen.dart`
- Modify: `lib/presentation/mobile/screens/inventory/inventory.dart` (drop export)

- [ ] **Step 1: Confirm it is unreferenced (safety re-check)**

Run: `grep -rn "ProductDetailScreen\|product_detail_screen" lib/ test/`
Expected: matches ONLY in `product_detail_screen.dart` itself and the `inventory.dart`
export line. If anything else references it, STOP and report — do not delete.

- [ ] **Step 2: Delete the file**

```bash
git rm lib/presentation/mobile/screens/inventory/product_detail_screen.dart
```

- [ ] **Step 3: Drop the barrel export**

In `lib/presentation/mobile/screens/inventory/inventory.dart`, remove the line:

```dart
export 'product_detail_screen.dart';
```

(Leaving the `inventory_screen.dart` and `product_form_screen.dart` exports.)

- [ ] **Step 4: Verify analyze + full test suite**

Run: `flutter analyze`
Expected: "No issues found!"

Run: `flutter test`
Expected: all tests pass.

- [ ] **Step 5: Commit**

```bash
git add lib/presentation/mobile/screens/inventory/inventory.dart
git commit -m "chore(inventory): delete orphaned ProductDetailScreen (dead code)"
```

---

## Task 6: Final verification

- [ ] **Step 1: Full analyze**

Run: `flutter analyze`
Expected: "No issues found!"

- [ ] **Step 2: Full test suite**

Run: `flutter test`
Expected: all green (baseline 690+ plus the new helper + screen tests).

- [ ] **Step 3: Manual smoke (optional, via /verify or /run)**

As an admin: open a product with recorded price changes → toggle cost on → tap
"View price history" → confirm the sparkline + table render, the All/Price/Cost
filter works, and source/actor labels look right. As a staff user: confirm the
tile is absent and a deep link to `/inventory/<id>/price-history` is denied.

---

## Self-Review notes (author)

- **Spec coverage:** §5 contract → Task 1 (filter/delta/source) + Task 2 (sparkline, table, empty/single-entry caption). §6 gating → Task 3 guard (`viewProductCost`) + Task 4 tile gate (`canViewCost && showCost`). §6.1 cleanup → Task 5. §7.1 route → Task 3. §8 testing → Tasks 1, 2, plus full-suite runs in 3/5/6.
- **Out of scope here (Phase 2 / spec §7):** web admin view + host page — separate plan.
- **Type consistency:** `PriceMetric`, `PriceHistoryRow{entry,priceDelta,costDelta,hasPrior}`, `buildPriceHistoryRows`, `sparklineSeries(...,{required bool forCost})`, `derivePriceHistorySource(reason,note)` are used identically across helper, screen, and tests.
- **Assumption to verify at runtime:** receiving entries use `reason == 'Stock receiving'` (PriceChangeReason.receiving). If a different string is used, `derivePriceHistorySource` shows it verbatim — acceptable, not a failure.
