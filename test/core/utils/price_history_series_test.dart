import 'package:flutter_test/flutter_test.dart';
import 'package:maki_mobile_pos/core/utils/price_history_view.dart';
import 'package:maki_mobile_pos/domain/repositories/product_repository.dart';

// PriceHistoryEntry requires `id` — see lib/domain/repositories/product_repository.dart.
PriceHistoryEntry entry({
  required double price,
  double cost = 60,
  String? optionId,
  String? optionLabel,
  int? optionPieces,
  int day = 1,
}) {
  return PriceHistoryEntry(
    id: 'e$day${optionId ?? ''}',
    price: price,
    cost: cost,
    changedAt: DateTime(2026, 7, day),
    changedBy: 'u1',
    reason: 'Price update',
    optionId: optionId,
    optionLabel: optionLabel,
    optionPieces: optionPieces,
  );
}

void main() {
  group('splitPriceHistorySeries', () {
    test('entries with no option fields form a single base series', () {
      final series = splitPriceHistorySeries([
        entry(price: 130, day: 2),
        entry(price: 120, day: 1),
      ]);
      expect(series, hasLength(1));
      expect(series.single.optionId, isNull);
      expect(series.single.label, 'Base price');
      expect(series.single.entries, hasLength(2));
    });

    test('separates base and option entries', () {
      final series = splitPriceHistorySeries([
        entry(price: 360, optionId: 'o2', optionLabel: 'By 3', optionPieces: 3, day: 3),
        entry(price: 130, day: 2),
        entry(price: 330, optionId: 'o2', optionLabel: 'By 3', optionPieces: 3, day: 1),
      ]);
      expect(series.map((s) => s.label), ['Base price', 'By 3']);
      expect(series[0].entries, hasLength(1));
      expect(series[1].entries, hasLength(2));
    });

    test('keeps each series newest-first', () {
      final series = splitPriceHistorySeries([
        entry(price: 360, optionId: 'o2', optionLabel: 'By 3', optionPieces: 3, day: 3),
        entry(price: 330, optionId: 'o2', optionLabel: 'By 3', optionPieces: 3, day: 1),
      ]);
      expect(series.single.entries.first.price, 360);
    });

    test('omits the base series when there are no base entries', () {
      final series = splitPriceHistorySeries([
        entry(price: 330, optionId: 'o2', optionLabel: 'By 3', optionPieces: 3),
      ]);
      expect(series.map((s) => s.label), ['By 3']);
    });

    test('deltas computed per series never mix base and option prices', () {
      final series = splitPriceHistorySeries([
        entry(price: 360, optionId: 'o2', optionLabel: 'By 3', optionPieces: 3, day: 3),
        entry(price: 130, day: 2),
        entry(price: 330, optionId: 'o2', optionLabel: 'By 3', optionPieces: 3, day: 1),
      ]);
      final optionRows =
          buildPriceHistoryRows(series[1].entries, PriceMetric.price);
      expect(optionRows.first.priceDelta, 30);
    });

    test('several options each get their own series', () {
      final series = splitPriceHistorySeries([
        entry(price: 600, optionId: 'o1', optionLabel: 'By 6', optionPieces: 6, day: 2),
        entry(price: 330, optionId: 'o2', optionLabel: 'By 3', optionPieces: 3, day: 1),
      ]);
      expect(series.map((s) => s.label), ['By 6', 'By 3']);
    });
  });
}
