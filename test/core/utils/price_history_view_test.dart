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
