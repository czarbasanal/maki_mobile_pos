// Wires SellingOptionHistoryEvent (16a, lib/core/utils/selling_options.dart)
// into ProductRepositoryImpl.updateProduct — the admin product-save path.
// Every assertion reads the RAW Firestore doc map (not the parsed
// PriceHistoryEntry) so "absent" vs "null" is actually distinguishable: the
// contract is that a base entry has NO optionId/optionLabel/optionPieces
// keys at all, not that they're present-but-null.
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maki_mobile_pos/core/utils/selling_options.dart';
import 'package:maki_mobile_pos/data/models/models.dart';
import 'package:maki_mobile_pos/data/repositories/product_repository_impl.dart';
import 'package:maki_mobile_pos/domain/entities/entities.dart';

void main() {
  late FakeFirebaseFirestore fake;
  late ProductRepositoryImpl repo;

  setUp(() {
    fake = FakeFirebaseFirestore();
    repo = ProductRepositoryImpl(firestore: fake);
  });

  SellingOptionEntity opt(String id, String label, int pieces, double price) =>
      SellingOptionEntity(id: id, label: label, pieces: pieces, price: price);

  Future<String> seedProduct({
    String sku = 'X',
    double cost = 60,
    double price = 100,
    List<SellingOptionEntity> sellingOptions = const [],
  }) async {
    final ref = await fake.collection('products').add({
      'sku': sku,
      'name': 'Test',
      'costCode': '',
      'cost': cost,
      'price': price,
      'quantity': 0,
      'reorderLevel': 10,
      'unit': 'pcs',
      'isActive': true,
      'searchKeywords': <String>[],
      'barcodes': <String>[],
      'sellingOptions': sellingOptionsToList(sellingOptions),
      'createdAt': Timestamp.now(),
    });
    return ref.id;
  }

  Future<List<Map<String, dynamic>>> historyDocs(String productId) async {
    final snap = await fake
        .collection('products')
        .doc(productId)
        .collection('price_history')
        .get();
    return snap.docs.map((d) => d.data()).toList();
  }

  group('ProductRepositoryImpl.updateProduct — selling-option price history',
      () {
    test('adding an option writes one Option added entry with set cost',
        () async {
      final id = await seedProduct(cost: 60);
      final product = await repo.getProductById(id);

      await repo.updateProduct(
        product:
            product!.copyWith(sellingOptions: [opt('o2', 'By 3', 3, 330)]),
        updatedBy: 'admin-1',
        includeSellingOptions: true,
      );

      final docs = await historyDocs(id);
      expect(docs, hasLength(1));
      expect(docs.single['reason'], 'Option added');
      expect(docs.single['price'], 330);
      expect(docs.single['cost'], 180); // 3 * 60
      expect(docs.single['optionId'], 'o2');
      expect(docs.single['optionLabel'], 'By 3');
      expect(docs.single['optionPieces'], 3);
    });

    test('removing an option writes Option removed with its last known price',
        () async {
      final id =
          await seedProduct(cost: 60, sellingOptions: [opt('o2', 'By 3', 3, 330)]);
      final product = await repo.getProductById(id);

      await repo.updateProduct(
        product: product!.copyWith(sellingOptions: const []),
        updatedBy: 'admin-1',
        includeSellingOptions: true,
      );

      final docs = await historyDocs(id);
      expect(docs, hasLength(1));
      expect(docs.single['reason'], 'Option removed');
      expect(docs.single['price'], 330);
      expect(docs.single['optionLabel'], 'By 3');
    });

    test('a pieces change writes Option changed with the new set cost',
        () async {
      final id = await seedProduct(
          cost: 10, sellingOptions: [opt('o1', 'By 6', 6, 600)]);
      final product = await repo.getProductById(id);

      await repo.updateProduct(
        product:
            product!.copyWith(sellingOptions: [opt('o1', 'By 6', 8, 800)]),
        updatedBy: 'admin-1',
        includeSellingOptions: true,
      );

      final docs = await historyDocs(id);
      expect(docs, hasLength(1));
      expect(docs.single['reason'], 'Option changed');
      expect(docs.single['optionPieces'], 8);
      expect(docs.single['cost'], 80); // 8 * 10
    });

    test(
        'a simultaneous base + option price change writes two entries, '
        'distinguishable only by the optionId field (same reason string)',
        () async {
      final id = await seedProduct(
        cost: 60,
        price: 100,
        sellingOptions: [opt('o2', 'By 3', 3, 330)],
      );
      final product = await repo.getProductById(id);

      await repo.updateProduct(
        product: product!.copyWith(
          price: 150, // base price change
          sellingOptions: [opt('o2', 'By 3', 3, 360)], // option price change
        ),
        updatedBy: 'admin-1',
        includeSellingOptions: true,
      );

      final docs = await historyDocs(id);
      expect(docs, hasLength(2));
      final optionDoc = docs.firstWhere((d) => d['optionId'] != null);
      final baseDoc = docs.firstWhere((d) => d['optionId'] == null);

      expect(optionDoc['reason'], 'Price update');
      expect(optionDoc['price'], 360);
      expect(optionDoc['optionLabel'], 'By 3');

      expect(baseDoc['reason'], PriceChangeReason.priceUpdate);
      expect(baseDoc['price'], 150);
      expect(baseDoc.containsKey('optionId'), isFalse,
          reason: 'base entries leave the option fields ABSENT, not null');
      expect(baseDoc.containsKey('optionLabel'), isFalse);
      expect(baseDoc.containsKey('optionPieces'), isFalse);
    });

    test(
        'several simultaneous option changes each produce their own entry',
        () async {
      final id = await seedProduct(
        cost: 10,
        sellingOptions: [
          opt('o1', 'By 6', 6, 600),
          opt('o2', 'By 3', 3, 330),
        ],
      );
      final product = await repo.getProductById(id);

      await repo.updateProduct(
        product: product!.copyWith(
          sellingOptions: [opt('o1', 'By 6', 6, 650)], // o1 price update, o2 removed
        ),
        updatedBy: 'admin-1',
        includeSellingOptions: true,
      );

      final docs = await historyDocs(id);
      expect(docs, hasLength(2));
      expect(
        docs.map((d) => d['reason']).toSet(),
        {'Price update', 'Option removed'},
      );
    });

    test('no change to selling options writes nothing extra', () async {
      final options = [opt('o2', 'By 3', 3, 330)];
      final id = await seedProduct(cost: 60, sellingOptions: options);
      final product = await repo.getProductById(id);

      await repo.updateProduct(
        // sellingOptions untouched — copyWith preserves the fetched value.
        product: product!.copyWith(name: 'Renamed'),
        updatedBy: 'admin-1',
        includeSellingOptions: true,
      );

      final docs = await historyDocs(id);
      expect(docs, isEmpty);
    });

    test(
        'includeSellingOptions:false ignores a differing sellingOptions on '
        'the submitted entity (defense-in-depth — the write map already '
        'strips the field for this tier)', () async {
      final id = await seedProduct(cost: 60, sellingOptions: const []);
      final product = await repo.getProductById(id);

      await repo.updateProduct(
        product:
            product!.copyWith(sellingOptions: [opt('o2', 'By 3', 3, 330)]),
        updatedBy: 'staff-1',
        includeSellingOptions: false,
      );

      final docs = await historyDocs(id);
      expect(docs, isEmpty);
      expect((await repo.getProductById(id))!.sellingOptions, isEmpty,
          reason: 'the field itself must not have been written either');
    });

    test(
        'a product with no selling options produces exactly the same '
        'base-only history it produced before this feature existed',
        () async {
      final id = await seedProduct(cost: 60, price: 100, sellingOptions: const []);
      final product = await repo.getProductById(id);

      await repo.updateProduct(
        product: product!.copyWith(price: 120),
        updatedBy: 'admin-1',
        includeSellingOptions: true,
      );

      final docs = await historyDocs(id);
      expect(docs, hasLength(1),
          reason: 'only the pre-existing base price entry — nothing new');
      expect(docs.single['reason'], PriceChangeReason.priceUpdate);
      expect(docs.single.containsKey('optionId'), isFalse);
    });

    test('getPriceHistory surfaces the option fields back on read', () async {
      final id = await seedProduct(cost: 60, sellingOptions: const []);
      final product = await repo.getProductById(id);

      await repo.updateProduct(
        product:
            product!.copyWith(sellingOptions: [opt('o2', 'By 3', 3, 330)]),
        updatedBy: 'admin-1',
        includeSellingOptions: true,
      );

      final history = await repo.getPriceHistory(productId: id);
      expect(history, hasLength(1));
      expect(history.single.optionId, 'o2');
      expect(history.single.optionLabel, 'By 3');
      expect(history.single.optionPieces, 3);
    });
  });
}
