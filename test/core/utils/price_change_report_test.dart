import 'package:flutter_test/flutter_test.dart';
import 'package:maki_mobile_pos/core/utils/price_change_report.dart';
import 'package:maki_mobile_pos/domain/repositories/repositories.dart';

PriceChangeEntry _e(String product, DateTime at, double price, double cost,
        {String? reason}) =>
    PriceChangeEntry(
      id: '$product-${at.millisecondsSinceEpoch}',
      productId: product,
      price: price,
      cost: cost,
      changedAt: at,
      changedBy: 'u1',
      reason: reason,
    );

PriceHistoryEntry _b(DateTime at, double price, double cost,
        {String? optionId, String? optionLabel, int? optionPieces}) =>
    PriceHistoryEntry(
      id: 'b-${at.millisecondsSinceEpoch}',
      price: price,
      cost: cost,
      changedAt: at,
      changedBy: 'u1',
      optionId: optionId,
      optionLabel: optionLabel,
      optionPieces: optionPieces,
    );

/// Explicit-id entry for the selling-option grouping tests, where individual
/// rows need to be looked back up by id after the fact.
PriceChangeEntry _entry(
  String id,
  String product,
  double price,
  double cost,
  DateTime at, {
  String? optionId,
  String? optionLabel,
  int? optionPieces,
}) =>
    PriceChangeEntry(
      id: id,
      productId: product,
      price: price,
      cost: cost,
      changedAt: at,
      changedBy: 'u1',
      reason: 'Price update',
      optionId: optionId,
      optionLabel: optionLabel,
      optionPieces: optionPieces,
    );

const _by3Id = 'o2';
const _by3Label = 'By 3';
const _by3Pieces = 3;
const _by6Id = 'o1';
const _by6Label = 'By 6';
const _by6Pieces = 6;

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

  group('priceChangeRowsInRange with selling options', () {
    test('computes an option delta against the same option only, '
        'not a base entry that sits between them chronologically', () {
      final rows = priceChangeRowsInRange([
        _entry('e1', 'p1', 330, 150, DateTime(2026, 7, 1),
            optionId: _by3Id, optionLabel: _by3Label, optionPieces: _by3Pieces),
        _entry('e2', 'p1', 130, 60, DateTime(2026, 7, 2)),
        _entry('e3', 'p1', 360, 160, DateTime(2026, 7, 3),
            optionId: _by3Id, optionLabel: _by3Label, optionPieces: _by3Pieces),
      ]);
      final optionRow = rows.firstWhere((r) => r.entry.id == 'e3');
      // Wrong (flat-grouped by product only) would compute 360 - 130 = 230.
      expect(optionRow.priceDelta, 30);
      expect(optionRow.hasPrior, isTrue);
    });

    test('never subtracts an option price from a base price', () {
      final rows = priceChangeRowsInRange([
        _entry('e1', 'p1', 120, 70, DateTime(2026, 7, 1)),
        _entry('e2', 'p1', 330, 150, DateTime(2026, 7, 2),
            optionId: _by3Id, optionLabel: _by3Label, optionPieces: _by3Pieces),
      ]);
      final optionRow = rows.firstWhere((r) => r.entry.id == 'e2');
      // Wrong (flat-grouped) would compute 330 - 120 = 210.
      expect(optionRow.priceDelta, 0);
      expect(optionRow.hasPrior, isFalse);
    });

    test('a base delta ignores option entries interleaved between base '
        'entries', () {
      final rows = priceChangeRowsInRange([
        _entry('e1', 'p1', 120, 70, DateTime(2026, 7, 1)),
        _entry('e2', 'p1', 330, 150, DateTime(2026, 7, 2),
            optionId: _by3Id, optionLabel: _by3Label, optionPieces: _by3Pieces),
        _entry('e3', 'p1', 130, 75, DateTime(2026, 7, 3)),
      ]);
      final baseRow = rows.firstWhere((r) => r.entry.id == 'e3');
      // Wrong (flat-grouped, prior = e2) would compute 130 - 330 = -200.
      expect(baseRow.priceDelta, 10);
    });

    test('keeps two different options of one product in separate groups', () {
      final rows = priceChangeRowsInRange([
        _entry('e1', 'p1', 600, 300, DateTime(2026, 7, 1),
            optionId: _by6Id, optionLabel: _by6Label, optionPieces: _by6Pieces),
        _entry('e2', 'p1', 330, 150, DateTime(2026, 7, 2),
            optionId: _by3Id, optionLabel: _by3Label, optionPieces: _by3Pieces),
        _entry('e3', 'p1', 650, 300, DateTime(2026, 7, 3),
            optionId: _by6Id, optionLabel: _by6Label, optionPieces: _by6Pieces),
      ]);
      final by6Latest = rows.firstWhere((r) => r.entry.id == 'e3');
      // Wrong (all three in one group sorted by date) would compute
      // 650 - 330 = 320 for e3, and would give e2 a false prior (delta
      // 330 - 600 = -270, hasPrior true) instead of being the lone by3 entry.
      expect(by6Latest.priceDelta, 50);
      expect(by6Latest.hasPrior, isTrue);
      final by3Only = rows.firstWhere((r) => r.entry.id == 'e2');
      expect(by3Only.hasPrior, isFalse);
      expect(by3Only.priceDelta, 0);
    });

    test('a product with no options is unchanged: newest-first, delta vs '
        'immediate prior', () {
      final rows = priceChangeRowsInRange([
        _entry('e1', 'p1', 120, 70, DateTime(2026, 7, 1)),
        _entry('e2', 'p1', 130, 75, DateTime(2026, 7, 2)),
      ]);
      expect(rows.map((r) => r.entry.id), ['e2', 'e1']);
      expect(rows[0].priceDelta, 10);
      expect(rows[0].hasPrior, isTrue);
      expect(rows[1].priceDelta, 0);
      expect(rows[1].hasPrior, isFalse);
    });

    test('still returns rows newest-first across groups regardless of input '
        'order', () {
      final rows = priceChangeRowsInRange([
        _entry('e1', 'p1', 120, 70, DateTime(2026, 7, 1)),
        _entry('e3', 'p1', 360, 160, DateTime(2026, 7, 3),
            optionId: _by3Id, optionLabel: _by3Label, optionPieces: _by3Pieces),
        _entry('e2', 'p1', 330, 150, DateTime(2026, 7, 2),
            optionId: _by3Id, optionLabel: _by3Label, optionPieces: _by3Pieces),
      ]);
      expect(rows.map((r) => r.entry.id), ['e3', 'e2', 'e1']);
    });
  });

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
      expect(s[0].hasPrev, isTrue);
    });

    test(
        'no baseline, multiple entries -> prev falls back to oldest in-range '
        'entry; NOT marked new (unknown history, not a new product)', () {
      final s = priceChangeProductSummaries(
        [
          _e('p1', DateTime(2026, 6, 1), 100, 60),
          _e('p1', DateTime(2026, 6, 20), 150, 80),
        ],
        {'p1': null},
      );
      expect(s[0].isNew, isFalse);
      expect(s[0].hasPrev, isTrue);
      expect(s[0].prevPrice, 100);
      expect(s[0].currPrice, 150);
      expect(s[0].priceDiff, 50);
    });

    test(
        'single non-initial entry without baseline -> hasPrev false '
        '(prior value unknown; must not render as "no change")', () {
      final s = priceChangeProductSummaries(
        [_e('p1', DateTime(2026, 6, 1), 150, 80)],
        {'p1': null},
      );
      expect(s[0].hasPrev, isFalse);
      expect(s[0].isNew, isFalse);
      expect(s[0].priceDiff, 0);
      expect(s[0].costDiff, 0);
      expect(s[0].changeCount, 1);
    });

    test('created in range (oldest is Initial price) -> isNew', () {
      final s = priceChangeProductSummaries(
        [
          _e('p1', DateTime(2026, 6, 1), 100, 60, reason: 'Initial price'),
          _e('p1', DateTime(2026, 6, 20), 150, 80),
        ],
        {'p1': null},
      );
      expect(s[0].isNew, isTrue);
      expect(s[0].hasPrev, isTrue); // initial values are a real starting point
      expect(s[0].prevPrice, 100);
      expect(s[0].priceDiff, 50);
    });

    test('lone Initial price entry -> isNew, hasPrev false', () {
      final s = priceChangeProductSummaries(
        [_e('p1', DateTime(2026, 6, 1), 100, 60, reason: 'Initial price')],
        {'p1': null},
      );
      expect(s[0].isNew, isTrue);
      expect(s[0].hasPrev, isFalse);
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

  group('priceChangeProductSummaries with selling options', () {
    test('two options of one product produce two separate summaries, not '
        'one merged summary', () {
      final s = priceChangeProductSummaries(
        [
          _entry('e1', 'p1', 600, 300, DateTime(2026, 7, 1),
              optionId: _by6Id,
              optionLabel: _by6Label,
              optionPieces: _by6Pieces),
          _entry('e2', 'p1', 330, 150, DateTime(2026, 7, 2),
              optionId: _by3Id,
              optionLabel: _by3Label,
              optionPieces: _by3Pieces),
        ],
        {'p1': null},
      );
      // Wrong (flat-grouped) would merge both into ONE summary: prevPrice
      // 600 (oldest), currPrice 330 (newest), changeCount 2, hasPrev true
      // (group.length > 1) — a swing that never happened.
      expect(s, hasLength(2));
      final by6 = s.firstWhere((x) => x.currPrice == 600);
      expect(by6.hasPrev, isFalse);
      expect(by6.changeCount, 1);
      final by3 = s.firstWhere((x) => x.currPrice == 330);
      expect(by3.hasPrev, isFalse);
      expect(by3.changeCount, 1);
    });

    test('a baseline for the base series is not applied to an option '
        'series of the same product', () {
      final s = priceChangeProductSummaries(
        [
          _entry('e1', 'p1', 150, 90, DateTime(2026, 6, 10)), // base, in range
          _entry('e2', 'p1', 330, 150, DateTime(2026, 6, 15),
              optionId: _by3Id,
              optionLabel: _by3Label,
              optionPieces: _by3Pieces), // by3, in range, lone entry
        ],
        // Baseline is a BASE-price entry (optionId null).
        {'p1': _b(DateTime(2026, 5, 1), 100, 60)},
      );
      expect(s, hasLength(2));

      final base = s.firstWhere((x) => x.currPrice == 150);
      expect(base.prevPrice, 100); // baseline applies: matching series
      expect(base.hasPrev, isTrue);

      final by3 = s.firstWhere((x) => x.currPrice == 330);
      // Wrong (option-blind) would apply the base baseline here too:
      // prevPrice 100, hasPrev true, priceDiff 230 — a change that never
      // happened for the by3 series (which has no known baseline at all).
      expect(by3.prevPrice, 330); // falls back to oldest-in-range (itself)
      expect(by3.hasPrev, isFalse); // lone entry, no matching baseline
    });

    test('a baseline recorded against an option only applies to that '
        "option's series, not the base series", () {
      final s = priceChangeProductSummaries(
        [
          _entry('e1', 'p1', 150, 90, DateTime(2026, 6, 10)), // base, lone
          _entry('e2', 'p1', 360, 160, DateTime(2026, 6, 15),
              optionId: _by3Id, optionLabel: _by3Label, optionPieces: _by3Pieces),
        ],
        // Baseline is a BY-3 entry.
        {
          'p1': _b(DateTime(2026, 5, 1), 300, 140,
              optionId: _by3Id, optionLabel: _by3Label, optionPieces: _by3Pieces)
        },
      );
      expect(s, hasLength(2));

      final by3 = s.firstWhere((x) => x.currPrice == 360);
      expect(by3.prevPrice, 300); // baseline applies: matching series
      expect(by3.hasPrev, isTrue);
      expect(by3.priceDiff, 60);

      final base = s.firstWhere((x) => x.currPrice == 150);
      // Wrong (option-blind) would apply the by3 baseline here: prevPrice
      // 300, hasPrev true, priceDiff -150 — a change that never happened.
      expect(base.prevPrice, 150); // falls back to oldest-in-range (itself)
      expect(base.hasPrev, isFalse);
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

  // Same fixture as web_admin/src/domain/products/priceChangeReport.test.ts's
  // "parity fixture (matches Dart price_change_report_test.dart)" — this is
  // the side-by-side parity demonstration for Task 19a, not just an assertion
  // that the two happen to agree. Keep the numbers identical on both sides.
  group('parity fixture (matches web priceChangeReport.test.ts)', () {
    test('base and two options of one product, interleaved input order', () {
      final rows = priceChangeRowsInRange([
        _entry('e1', 'p1', 100, 60, DateTime(2026, 7, 1)), // base
        _entry('e2', 'p1', 300, 150, DateTime(2026, 7, 2),
            optionId: _by3Id, optionLabel: _by3Label, optionPieces: _by3Pieces),
        _entry('e3', 'p1', 140, 65, DateTime(2026, 7, 3)), // base
        _entry('e4', 'p1', 345, 160, DateTime(2026, 7, 4),
            optionId: _by3Id, optionLabel: _by3Label, optionPieces: _by3Pieces),
        _entry('e5', 'p1', 600, 300, DateTime(2026, 7, 5),
            optionId: _by6Id, optionLabel: _by6Label, optionPieces: _by6Pieces),
      ]);

      expect(rows.map((r) => r.entry.id), ['e5', 'e4', 'e3', 'e2', 'e1']);

      final byId = {for (final r in rows) r.entry.id: r};
      expect(byId['e5']!.priceDelta, 0);
      expect(byId['e5']!.hasPrior, isFalse);
      expect(byId['e4']!.priceDelta, 45); // 345 - 300, by3 series only
      expect(byId['e4']!.hasPrior, isTrue);
      expect(byId['e4']!.costDelta, 10); // 160 - 150
      expect(byId['e3']!.priceDelta, 40); // 140 - 100, base series only
      expect(byId['e3']!.hasPrior, isTrue);
      expect(byId['e3']!.costDelta, 5); // 65 - 60
      expect(byId['e2']!.priceDelta, 0);
      expect(byId['e2']!.hasPrior, isFalse);
      expect(byId['e1']!.priceDelta, 0);
      expect(byId['e1']!.hasPrior, isFalse);
    });
  });
}
