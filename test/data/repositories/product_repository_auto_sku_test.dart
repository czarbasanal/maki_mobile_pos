import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maki_mobile_pos/core/errors/exceptions.dart';
import 'package:maki_mobile_pos/data/repositories/product_repository_impl.dart';
import 'package:maki_mobile_pos/domain/entities/entities.dart';

ProductEntity _product({
  required String sku,
  String name = 'Brake Pad',
}) {
  return ProductEntity(
    id: '',
    sku: sku,
    name: name,
    costCode: 'NBF',
    cost: 100,
    price: 150,
    quantity: 10,
    reorderLevel: 2,
    unit: 'pcs',
    isActive: true,
    createdAt: DateTime(2025, 1, 1),
  );
}

Future<void> _seedRegistry(
  FakeFirebaseFirestore firestore,
  String code,
  int nextSequence,
) async {
  await firestore.collection('category_codes').doc(code).set({
    'categoryId': 'cat-1',
    'nameSnapshot': 'Brakes',
    'assignedAt': FieldValue.serverTimestamp(),
    'nextSequence': nextSequence,
  });
}

void main() {
  group('createProduct auto-SKU (peek + claim-in-transaction)', () {
    test('auto path: happy case claims peeked sku and advances registry',
        () async {
      final firestore = FakeFirebaseFirestore();
      final repo = ProductRepositoryImpl(firestore: firestore);
      await _seedRegistry(firestore, '0007', 1);

      final created = await repo.createProduct(
        product: _product(sku: '00070001'),
        createdBy: 'user-1',
        autoSkuCategoryCode: '0007',
      );

      expect(created.sku, '00070001');

      final claim =
          await firestore.collection('product_skus').doc('00070001').get();
      expect(claim.exists, isTrue);
      expect(claim.data()!['productId'], created.id);

      final registry =
          await firestore.collection('category_codes').doc('0007').get();
      expect(registry.data()!['nextSequence'], 2);
    });

    test(
        'auto path: peeked sku pre-claimed (race) skips to the next free '
        'sequence', () async {
      final firestore = FakeFirebaseFirestore();
      final repo = ProductRepositoryImpl(firestore: firestore);
      await _seedRegistry(firestore, '0007', 1);
      // Simulate a concurrent writer that already claimed 00070001.
      await firestore.collection('product_skus').doc('00070001').set({
        'sku': '00070001',
        'productId': 'other-product',
        'claimedBy': 'someone-else',
        'claimedAt': FieldValue.serverTimestamp(),
      });

      final created = await repo.createProduct(
        product: _product(sku: '00070001'),
        createdBy: 'user-1',
        autoSkuCategoryCode: '0007',
      );

      expect(created.sku, '00070002');

      final newClaim =
          await firestore.collection('product_skus').doc('00070002').get();
      expect(newClaim.exists, isTrue);
      expect(newClaim.data()!['productId'], created.id);

      final registry =
          await firestore.collection('category_codes').doc('0007').get();
      expect(registry.data()!['nextSequence'], 3);
    });

    test(
        'manual override: sku that does not match the auto pattern is '
        'saved as-is and leaves the registry untouched', () async {
      final firestore = FakeFirebaseFirestore();
      final repo = ProductRepositoryImpl(firestore: firestore);
      await _seedRegistry(firestore, '0007', 1);

      final created = await repo.createProduct(
        product: _product(sku: 'BRAKE-99'),
        createdBy: 'user-1',
        autoSkuCategoryCode: '0007',
      );

      expect(created.sku, 'BRAKE-99');

      final claim =
          await firestore.collection('product_skus').doc('BRAKE-99').get();
      expect(claim.exists, isTrue);

      final registry =
          await firestore.collection('category_codes').doc('0007').get();
      expect(registry.data()!['nextSequence'], 1);
    });

    test('category-full: registry at 9999 and claimed throws and writes '
        'nothing', () async {
      final firestore = FakeFirebaseFirestore();
      final repo = ProductRepositoryImpl(firestore: firestore);
      await _seedRegistry(firestore, '0007', 9999);
      await firestore.collection('product_skus').doc('00079999').set({
        'sku': '00079999',
        'productId': 'other-product',
        'claimedBy': 'someone-else',
        'claimedAt': FieldValue.serverTimestamp(),
      });

      await expectLater(
        repo.createProduct(
          product: _product(sku: '00079999'),
          createdBy: 'user-1',
          autoSkuCategoryCode: '0007',
        ),
        throwsA(
          isA<ValidationException>().having(
            (e) => e.code,
            'code',
            'category-full',
          ),
        ),
      );

      final products = await firestore.collection('products').get();
      expect(products.docs, isEmpty);

      final registry =
          await firestore.collection('category_codes').doc('0007').get();
      expect(registry.data()!['nextSequence'], 9999);
    });
  });
}
