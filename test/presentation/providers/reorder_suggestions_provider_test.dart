import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maki_mobile_pos/domain/entities/entities.dart';
import 'package:maki_mobile_pos/presentation/providers/product_provider.dart';
import 'package:maki_mobile_pos/presentation/providers/purchase_order_provider.dart';

void main() {
  ProductEntity product(String id, {int qty = 0, int reorder = 2}) =>
      ProductEntity(
        id: id,
        sku: 'SKU-$id',
        name: 'Item $id',
        cost: 55,
        costCode: 'NBF',
        price: 80,
        quantity: qty,
        reorderLevel: reorder,
        unit: 'pcs',
        isActive: true,
        createdAt: DateTime(2026, 1, 1),
      );

  test('derives suggestions and buckets synchronously from movement', () async {
    final sold = product('sold'); // qty 0, 60 units sold → recommended
    final low = product('low', qty: 1, reorder: 5); // no sales → low bucket
    final out = product('out'); // qty 0, no sales → out bucket
    var fetches = 0;

    final container = ProviderContainer(overrides: [
      productsProvider.overrideWith((ref) => Stream.value([sold, low, out])),
      reorderMovementProvider.overrideWith((ref, windowDays) async {
        fetches++;
        return (unitsSold: {'sold': 60}, capped: true);
      }),
    ]);
    addTearDown(container.dispose);

    const params30 = (windowDays: 60, coverDays: 30);
    // Keep the autoDispose graph alive while we read.
    final sub =
        container.listen(reorderSuggestionsProvider(params30), (_, __) {});
    addTearDown(sub.close);
    await container.read(productsProvider.future);
    await container.read(reorderMovementProvider(60).future);

    final result = container.read(reorderSuggestionsProvider(params30)).value!;
    // velocity 60/60 = 1 → target 30 → stock 0 → qty 30.
    expect(result.suggestions.single.product.id, 'sold');
    expect(result.suggestions.single.suggestedQty, 30);
    expect(result.lowStock.single.id, 'low');
    expect(result.outOfStock.single.id, 'out');
    expect(result.capped, true);

    // A different cover recomputes purely — same movement key, no new fetch.
    const params60 = (windowDays: 60, coverDays: 60);
    final sub2 =
        container.listen(reorderSuggestionsProvider(params60), (_, __) {});
    addTearDown(sub2.close);
    final more = container.read(reorderSuggestionsProvider(params60)).value!;
    expect(more.suggestions.single.suggestedQty, 60);
    expect(fetches, 1, reason: 'coverDays must never trigger a sales fetch');
  });
}
