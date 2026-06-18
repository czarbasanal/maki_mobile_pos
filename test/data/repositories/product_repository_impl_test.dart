import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maki_mobile_pos/core/errors/exceptions.dart';
import 'package:maki_mobile_pos/data/repositories/product_repository_impl.dart';
import 'package:maki_mobile_pos/domain/entities/entities.dart';

void main() {
  late FakeFirebaseFirestore firestore;
  late ProductRepositoryImpl repository;

  setUp(() {
    firestore = FakeFirebaseFirestore();
    repository = ProductRepositoryImpl(firestore: firestore);
  });

  // Seeds a product doc with sensible defaults, overridden by [data].
  // Returns the generated document id.
  Future<String> seedProduct(Map<String, dynamic> data) async {
    final ref = await firestore.collection('products').add({
      'sku': 'X',
      'name': 'X',
      'costCode': '',
      'cost': 1.0,
      'price': 2.0,
      'quantity': 0,
      'reorderLevel': 10,
      'unit': 'pcs',
      'isActive': true,
      'searchKeywords': <String>[],
      'barcodes': <String>[],
      'createdAt': Timestamp.now(),
      ...data,
    });
    return ref.id;
  }

  // Builds a ProductEntity with sensible defaults for create-path tests.
  ProductEntity buildProduct({
    String id = '',
    required String sku,
    String name = 'Test',
    String? baseSku,
    int? variationNumber,
  }) {
    return ProductEntity(
      id: id,
      sku: sku,
      name: name,
      costCode: '',
      cost: 1.0,
      price: 2.0,
      quantity: 0,
      reorderLevel: 10,
      unit: 'pcs',
      isActive: true,
      createdAt: DateTime(2025, 1, 1),
      baseSku: baseSku,
      variationNumber: variationNumber,
    );
  }

  group('ProductRepositoryImpl.updateProduct SKU cascade', () {
    test('re-points variation children when parent SKU changes', () async {
      final parentId = await seedProduct({'sku': 'OLD', 'name': 'Parent'});
      final child1Id = await seedProduct({
        'sku': 'OLD-1',
        'name': 'Child 1',
        'baseSku': 'OLD',
        'variationNumber': 1,
      });
      final child2Id = await seedProduct({
        'sku': 'OLD-2',
        'name': 'Child 2',
        'baseSku': 'OLD',
        'variationNumber': 2,
      });
      final otherId = await seedProduct({
        'sku': 'ZZZ-1',
        'name': 'Unrelated',
        'baseSku': 'ZZZ',
        'variationNumber': 1,
      });

      final parent = await repository.getProductById(parentId);
      await repository.updateProduct(
        product: parent!.copyWith(sku: 'NEW'),
        updatedBy: 'admin-1',
        updatedByName: 'Admin',
      );

      expect((await repository.getProductById(parentId))!.sku, 'NEW');
      expect((await repository.getProductById(child1Id))!.baseSku, 'NEW');
      expect((await repository.getProductById(child2Id))!.baseSku, 'NEW');
      expect((await repository.getProductById(otherId))!.baseSku, 'ZZZ');
    });

    test('does not touch children when SKU is unchanged', () async {
      final parentId = await seedProduct({'sku': 'OLD', 'name': 'Parent'});
      final childId = await seedProduct({
        'sku': 'OLD-1',
        'name': 'Child',
        'baseSku': 'OLD',
        'variationNumber': 1,
      });

      final parent = await repository.getProductById(parentId);
      await repository.updateProduct(
        product: parent!.copyWith(name: 'Parent Renamed'),
        updatedBy: 'admin-1',
        updatedByName: 'Admin',
      );

      expect(
        (await repository.getProductById(parentId))!.name,
        'Parent Renamed',
      );
      expect((await repository.getProductById(childId))!.baseSku, 'OLD');
    });

    test('childless product SKU change succeeds', () async {
      final id = await seedProduct({'sku': 'SOLO', 'name': 'Solo'});
      final product = await repository.getProductById(id);

      final updated = await repository.updateProduct(
        product: product!.copyWith(sku: 'SOLO-2'),
        updatedBy: 'admin-1',
        updatedByName: 'Admin',
      );

      expect(updated.sku, 'SOLO-2');
    });
  });

  group('ProductRepositoryImpl.createProduct SKU claim', () {
    test('writes the product and a normalized SKU claim', () async {
      final created = await repository.createProduct(
        product: buildProduct(sku: 'abc-1'),
        createdBy: 'admin-1',
        createdByName: 'Admin',
      );

      expect((await repository.getProductById(created.id))!.sku, 'abc-1');

      final claim =
          await firestore.collection('product_skus').doc('ABC-1').get();
      expect(claim.exists, true);
      expect(claim.data()!['productId'], created.id);
      expect(claim.data()!['sku'], 'abc-1');
    });

    test('rejects a duplicate SKU case-insensitively', () async {
      await repository.createProduct(
        product: buildProduct(sku: 'ABC-1'),
        createdBy: 'admin-1',
      );

      expect(
        () => repository.createProduct(
          product: buildProduct(sku: 'abc-1'),
          createdBy: 'admin-1',
        ),
        throwsA(isA<DuplicateSkuException>()),
      );
    });

    test('rejects a SKU that cannot form a valid claim doc-id', () async {
      // '/' is a Firestore path separator; '' / whitespace are invalid doc-ids.
      // Real Firestore would throw an opaque path error from _skusRef.doc(...);
      // the guard turns it into a clear ValidationException before the tx.
      expect(
        () => repository.createProduct(
          product: buildProduct(sku: 'PRD/001'),
          createdBy: 'admin-1',
        ),
        throwsA(isA<ValidationException>()),
      );
      expect(
        () => repository.createProduct(
          product: buildProduct(sku: '   '),
          createdBy: 'admin-1',
        ),
        throwsA(isA<ValidationException>()),
      );
    });
  });

  group('ProductRepositoryImpl.skuExists (claim-backed)', () {
    test('true when a claim exists (case-insensitive), false otherwise',
        () async {
      await firestore.collection('product_skus').doc('ABC-1').set({
        'sku': 'abc-1',
        'productId': 'p1',
        'claimedBy': 'x',
      });

      expect(await repository.skuExists(sku: 'abc-1'), true);
      expect(await repository.skuExists(sku: '  ABC-1 '), true);
      expect(await repository.skuExists(sku: 'ZZZ'), false);
    });

    test('excludeProductId lets the owning product reuse its own SKU', () async {
      await firestore.collection('product_skus').doc('ABC-1').set({
        'sku': 'abc-1',
        'productId': 'p1',
        'claimedBy': 'x',
      });

      expect(
        await repository.skuExists(sku: 'abc-1', excludeProductId: 'p1'),
        false,
      );
      expect(
        await repository.skuExists(sku: 'abc-1', excludeProductId: 'p2'),
        true,
      );
    });
  });

  group('ProductRepositoryImpl.barcodeExists (claim-backed)', () {
    test('true when a claim exists, false otherwise', () async {
      await firestore.collection('product_barcodes').doc('ABC123').set({
        'barcode': 'ABC123',
        'productId': 'p1',
      });
      expect(await repository.barcodeExists(barcode: ' ABC123 '), isTrue); // trimmed
      expect(await repository.barcodeExists(barcode: 'NOPE'), isFalse);
    });

    test('excludeProductId lets the owning product reuse its own barcode',
        () async {
      await firestore.collection('product_barcodes').doc('ABC123').set({
        'barcode': 'ABC123',
        'productId': 'p1',
      });
      expect(
        await repository.barcodeExists(barcode: 'ABC123', excludeProductId: 'p1'),
        isFalse,
      );
      expect(
        await repository.barcodeExists(barcode: 'ABC123', excludeProductId: 'p2'),
        isTrue,
      );
    });
  });

  group('ProductRepositoryImpl.updateProduct SKU claim move', () {
    test('moves the claim from old to new on rename', () async {
      final id = await seedProduct({'sku': 'OLD', 'name': 'P'});
      await firestore.collection('product_skus').doc('OLD').set({
        'sku': 'OLD',
        'productId': id,
        'claimedBy': 'x',
      });

      final p = await repository.getProductById(id);
      await repository.updateProduct(
        product: p!.copyWith(sku: 'NEW'),
        updatedBy: 'admin-1',
        updatedByName: 'Admin',
      );

      expect(
        (await firestore.collection('product_skus').doc('OLD').get()).exists,
        false,
      );
      final newClaim =
          await firestore.collection('product_skus').doc('NEW').get();
      expect(newClaim.exists, true);
      expect(newClaim.data()!['productId'], id);
    });

    test('rename onto an existing SKU throws and changes nothing', () async {
      final id = await seedProduct({'sku': 'OLD', 'name': 'P'});
      await firestore.collection('product_skus').doc('OLD').set({
        'sku': 'OLD',
        'productId': id,
        'claimedBy': 'x',
      });
      final takenId = await seedProduct({'sku': 'TAKEN', 'name': 'Other'});
      await firestore.collection('product_skus').doc('TAKEN').set({
        'sku': 'TAKEN',
        'productId': takenId,
        'claimedBy': 'x',
      });

      final p = await repository.getProductById(id);
      expect(
        () => repository.updateProduct(
          product: p!.copyWith(sku: 'TAKEN'),
          updatedBy: 'admin-1',
        ),
        throwsA(isA<DuplicateSkuException>()),
      );

      expect((await repository.getProductById(id))!.sku, 'OLD');
      expect(
        (await firestore.collection('product_skus').doc('OLD').get()).exists,
        true,
      );
      expect(
        (await firestore.collection('product_skus').doc('TAKEN').get())
            .data()!['productId'],
        takenId,
      );
    });
  });

  group('ProductRepositoryImpl.createVariation retry-on-collision', () {
    test('allocates the next free number past existing variations', () async {
      final parentId = await seedProduct({'sku': 'BASE', 'name': 'Parent'});
      // Existing variation #1 (product + claim) → next free number is 2.
      await seedProduct({
        'sku': 'BASE-1',
        'name': 'V1',
        'baseSku': 'BASE',
        'variationNumber': 1,
      });
      await firestore.collection('product_skus').doc('BASE-1').set({
        'sku': 'BASE-1',
        'productId': 'v1',
        'claimedBy': 'x',
      });

      final parent = await repository.getProductById(parentId);
      final v = await repository.createVariation(
        originalProduct: parent!,
        newCost: 5,
        newCostCode: 'X',
        createdBy: 'admin-1',
      );

      expect(v.sku, 'BASE-2');
      expect(v.variationNumber, 2);
      expect(
        (await firestore.collection('product_skus').doc('BASE-2').get()).exists,
        true,
      );
    });

    test('throws DatabaseException after exhausting retries', () async {
      final parentId = await seedProduct({'sku': 'BASE', 'name': 'Parent'});
      // Orphan claim on BASE-1 with NO product → getNextVariationNumber keeps
      // returning 1, so every attempt collides and retries are exhausted.
      await firestore.collection('product_skus').doc('BASE-1').set({
        'sku': 'BASE-1',
        'productId': 'ghost',
        'claimedBy': 'x',
      });

      final parent = await repository.getProductById(parentId);
      expect(
        () => repository.createVariation(
          originalProduct: parent!,
          newCost: 5,
          newCostCode: 'X',
          createdBy: 'admin-1',
        ),
        throwsA(isA<DatabaseException>()),
      );
    });
  });
}
