import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maki_mobile_pos/data/repositories/sale_repository_impl.dart';

/// Behavior-preservation pin for the parallelized item loading: sales come
/// back in query order (createdAt desc) with each sale's own items attached,
/// exactly as the previous sequential loader returned them.
void main() {
  test(
      'getSalesByDateRange keeps order and per-sale items with parallel loads',
      () async {
    final fake = FakeFirebaseFirestore();
    final repo = SaleRepositoryImpl(firestore: fake);

    for (var i = 1; i <= 5; i++) {
      final sale = await fake.collection('sales').add({
        'saleNumber': 'S-$i',
        'status': 'completed',
        'paymentMethod': 'cash',
        'amountReceived': 100,
        'changeGiven': 0,
        'cashierId': 'u1',
        'cashierName': 'Admin',
        'createdAt': DateTime(2026, 7, i),
      });
      await sale.collection('items').add({
        'id': 'i$i',
        'productId': 'p$i',
        'sku': 'SKU-$i',
        'name': 'Item $i',
        'unitPrice': 10,
        'unitCost': 5,
        'quantity': i,
      });
    }

    final sales = await repo.getSalesByDateRange(
      startDate: DateTime(2026, 7, 1),
      endDate: DateTime(2026, 7, 31),
    );

    expect(sales, hasLength(5));
    expect(sales.map((s) => s.saleNumber).toList(),
        ['S-5', 'S-4', 'S-3', 'S-2', 'S-1'],
        reason: 'query order (createdAt desc) must survive parallel loading');
    for (final sale in sales) {
      expect(sale.items, hasLength(1));
      final n = sale.saleNumber.split('-').last;
      expect(sale.items.first.productId, 'p$n',
          reason: 'each sale must keep its OWN items');
    }
  });
}
