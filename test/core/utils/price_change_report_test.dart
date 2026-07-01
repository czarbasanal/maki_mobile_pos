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
