import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maki_mobile_pos/data/repositories/product_repository_impl.dart';

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
}
