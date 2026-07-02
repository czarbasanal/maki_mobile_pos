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

PriceHistoryEntry _b(DateTime at, double price, double cost) =>
    PriceHistoryEntry(
      id: 'b-${at.millisecondsSinceEpoch}',
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
}
