// Completing a receiving maps its supplier onto the products the stock came
// from: a spawned variation records the RECEIVING's supplier (the base's only
// as a fallback), and a matched product with NO supplier is filled with it —
// while a product that already names a supplier is never overwritten. A
// receiving line's unitPrice becomes the spawned variation's selling price
// (null keeps inheriting the base's). Wires the REAL repositories over
// fake_cloud_firestore, mirroring the web planReceive/executeReceivePlan
// behavior shipped alongside this.
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maki_mobile_pos/data/repositories/product_repository_impl.dart';
import 'package:maki_mobile_pos/data/repositories/receiving_repository_impl.dart';
import 'package:maki_mobile_pos/domain/entities/entities.dart';

void main() {
  late FakeFirebaseFirestore fake;
  late ProductRepositoryImpl productRepo;
  late ReceivingRepositoryImpl receivingRepo;

  setUp(() {
    fake = FakeFirebaseFirestore();
    productRepo = ProductRepositoryImpl(firestore: fake);
    receivingRepo = ReceivingRepositoryImpl(
      firestore: fake,
      productRepository: productRepo,
    );
  });

  Future<ProductEntity> seedProduct({
    required String sku,
    String? supplierId,
    String? supplierName,
  }) {
    return productRepo.createProduct(
      product: ProductEntity(
        id: '',
        sku: sku,
        name: 'Part $sku',
        costCode: 'AA',
        cost: 60,
        price: 700,
        quantity: 10,
        reorderLevel: 2,
        unit: 'pcs',
        isActive: true,
        supplierId: supplierId,
        supplierName: supplierName,
        createdAt: DateTime(2026, 1, 1),
      ),
      createdBy: 'u1',
    );
  }

  Future<ReceivingEntity> receive({
    required ProductEntity product,
    required double unitCost,
    double? unitPrice,
    String? supplierId,
    String? supplierName,
  }) async {
    final receiving = await receivingRepo.createReceiving(ReceivingEntity(
      id: '',
      referenceNumber: 'RCV-1',
      supplierId: supplierId,
      supplierName: supplierName,
      items: [
        ReceivingItemEntity(
          id: 'li-1',
          productId: product.id,
          sku: product.sku,
          name: product.name,
          quantity: 5,
          unit: 'pcs',
          unitCost: unitCost,
          unitPrice: unitPrice,
          costCode: 'BB',
        ),
      ],
      totalCost: unitCost * 5,
      totalQuantity: 5,
      status: ReceivingStatus.draft,
      createdAt: DateTime(2026, 1, 2),
      createdBy: 'u1',
      createdByName: 'Admin',
    ));
    return receivingRepo.completeReceiving(
      receivingId: receiving.id,
      completedBy: 'u1',
    );
  }

  Future<Map<String, dynamic>> productDoc(String id) async =>
      (await fake.collection('products').doc(id).get()).data()!;

  group('variation supplier', () {
    test('takes the RECEIVING supplier over the base product having none',
        () async {
      final base = await seedProduct(sku: 'TIRE-1');
      final done = await receive(
        product: base,
        unitCost: 70, // differs -> variation
        supplierId: 's1',
        supplierName: 'Boss Atan Argao',
      );
      final variation = await productDoc(done.items.single.newProductId!);
      expect(variation['supplierId'], 's1');
      expect(variation['supplierName'], 'Boss Atan Argao');
    });

    test('takes the RECEIVING supplier even when the base names another',
        () async {
      final base = await seedProduct(
          sku: 'TIRE-2', supplierId: 's9', supplierName: 'Old Supplier');
      final done = await receive(
        product: base,
        unitCost: 70,
        supplierId: 's1',
        supplierName: 'Boss Atan Argao',
      );
      final variation = await productDoc(done.items.single.newProductId!);
      expect(variation['supplierId'], 's1');
      expect(variation['supplierName'], 'Boss Atan Argao');
    });

    test('falls back to the base supplier when the receiving has none',
        () async {
      final base = await seedProduct(
          sku: 'TIRE-3', supplierId: 's9', supplierName: 'Old Supplier');
      final done = await receive(product: base, unitCost: 70);
      final variation = await productDoc(done.items.single.newProductId!);
      expect(variation['supplierId'], 's9');
      expect(variation['supplierName'], 'Old Supplier');
    });
  });

  group('variation price (unitPrice on the line)', () {
    test('an entered unitPrice becomes the variation price', () async {
      final base = await seedProduct(sku: 'TIRE-4');
      final done =
          await receive(product: base, unitCost: 70, unitPrice: 850);
      final variation = await productDoc(done.items.single.newProductId!);
      expect(variation['price'], 850);
    });

    test('no unitPrice keeps inheriting the base price', () async {
      final base = await seedProduct(sku: 'TIRE-5');
      final done = await receive(product: base, unitCost: 70);
      final variation = await productDoc(done.items.single.newProductId!);
      expect(variation['price'], 700);
    });
  });

  group('matched product fill-when-empty', () {
    test('a matched product with NO supplier is filled from the receiving',
        () async {
      final base = await seedProduct(sku: 'TIRE-6');
      await receive(
        product: base,
        unitCost: 60, // same cost -> match, stock top-up only
        supplierId: 's1',
        supplierName: 'Boss Atan Argao',
      );
      final doc = await productDoc(base.id);
      expect(doc['supplierId'], 's1');
      expect(doc['supplierName'], 'Boss Atan Argao');
      expect(doc['quantity'], 15); // the top-up still applied
    });

    test('a matched product that names a supplier is left alone', () async {
      final base = await seedProduct(
          sku: 'TIRE-7', supplierId: 's9', supplierName: 'Old Supplier');
      await receive(
        product: base,
        unitCost: 60,
        supplierId: 's1',
        supplierName: 'Boss Atan Argao',
      );
      final doc = await productDoc(base.id);
      expect(doc['supplierId'], 's9');
      expect(doc['supplierName'], 'Old Supplier');
    });

    test('no receiving supplier -> the matched product is untouched',
        () async {
      final base = await seedProduct(sku: 'TIRE-8');
      await receive(product: base, unitCost: 60);
      final doc = await productDoc(base.id);
      expect(doc['supplierId'], isNull);
    });
  });

  test('a draft round-trip preserves the line unitPrice', () async {
    final base = await seedProduct(sku: 'TIRE-9');
    final receiving = await receivingRepo.createReceiving(ReceivingEntity(
      id: '',
      referenceNumber: 'RCV-2',
      items: [
        ReceivingItemEntity(
          id: 'li-1',
          productId: base.id,
          sku: base.sku,
          name: base.name,
          quantity: 2,
          unit: 'pcs',
          unitCost: 75,
          unitPrice: 999,
          costCode: 'BB',
        ),
      ],
      totalCost: 150,
      totalQuantity: 2,
      status: ReceivingStatus.draft,
      createdAt: DateTime(2026, 1, 2),
      createdBy: 'u1',
      createdByName: 'Admin',
    ));
    final reloaded = await receivingRepo.getReceivingById(receiving.id);
    expect(reloaded!.items.single.unitPrice, 999);
  });
}
