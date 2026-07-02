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

  test(
      'getPriceChangesInRange returns in-range changes across products, '
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
}
