// Guard test for Task 16b's deliberate omission: a receiving that changes
// unit cost must still write BASE price_history entries only — never one
// per selling option (option cost is always reconstructible as
// pieces x unitCost, so a per-option write would be pure duplication: a
// four-option product would get five history docs per receiving instead of
// one). This test wires the REAL ProductRepositoryImpl (not a mock) so it
// actually exercises Firestore writes, over the same fake instance as the
// receiving repository — proving the receiving path was left untouched by
// the 16b wiring in ProductRepositoryImpl.updateProduct.
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

  Future<String?> receiveAtDifferentCost({
    required String sku,
    required List<SellingOptionEntity> sellingOptions,
  }) async {
    final created = await productRepo.createProduct(
      product: ProductEntity(
        id: '',
        sku: sku,
        name: 'Pulley ball',
        costCode: 'AA',
        cost: 60,
        price: 700,
        quantity: 10,
        reorderLevel: 2,
        unit: 'pcs',
        isActive: true,
        createdAt: DateTime(2026, 1, 1),
        sellingOptions: sellingOptions,
      ),
      createdBy: 'u1',
    );

    final receiving = await receivingRepo.createReceiving(ReceivingEntity(
      id: '',
      referenceNumber: 'RCV-1',
      items: [
        ReceivingItemEntity(
          id: 'li-1',
          productId: created.id,
          sku: created.sku,
          name: created.name,
          quantity: 5,
          unit: 'pcs',
          unitCost: 70, // different from the seeded 60 -> variation path
          costCode: 'BB',
        ),
      ],
      totalCost: 350,
      totalQuantity: 5,
      status: ReceivingStatus.draft,
      createdAt: DateTime(2026, 1, 2),
      createdBy: 'u1',
      createdByName: 'Admin',
    ));

    final completed = await receivingRepo.completeReceiving(
      receivingId: receiving.id,
      completedBy: 'u1',
    );

    return completed.items.single.newProductId;
  }

  test(
      'receiving a product WITH selling options at a different cost writes '
      'the SAME price_history entry count as a product with none — no '
      'per-option multiplication, and no entry carries an option field',
      () async {
    // Baseline: a product with NO selling options, same cost-changing receive.
    final plainVariationId = await receiveAtDifferentCost(
      sku: 'PULLEY-PLAIN',
      sellingOptions: const [],
    );
    final plainHistory = await fake
        .collection('products')
        .doc(plainVariationId)
        .collection('price_history')
        .get();

    // The product under test: FOUR selling options — if the receiving path
    // ever started writing one entry per option, this would jump to 4+2
    // instead of staying equal to the baseline above.
    final optionedVariationId = await receiveAtDifferentCost(
      sku: 'PULLEY-OPTIONED',
      sellingOptions: const [
        SellingOptionEntity(id: 'o1', label: 'By 6', pieces: 6, price: 600),
        SellingOptionEntity(id: 'o2', label: 'By 3', pieces: 3, price: 330),
        SellingOptionEntity(id: 'o3', label: 'By 2', pieces: 2, price: 220),
        SellingOptionEntity(id: 'o4', label: 'Single', pieces: 1, price: 120),
      ],
    );
    final optionedHistory = await fake
        .collection('products')
        .doc(optionedVariationId)
        .collection('price_history')
        .get();

    // Pin the LITERAL count too, not just "matches the baseline" — this is
    // 2 (not 1) on Dart today: createVariation's own createProduct writes an
    // "Initial price" entry, and _processReceivingItem then adds a second
    // "Stock receiving" entry. That duplication is pre-existing and NOT this
    // feature's concern (web's equivalent path writes exactly one) — the
    // guarantee this test exists to protect is that it stays exactly 2, not
    // 2 + (one per option) = 6.
    expect(plainHistory.docs, hasLength(2));
    expect(optionedHistory.docs, hasLength(2),
        reason:
            'a product with 4 selling options must not write extra price_history '
            'docs on receiving — option cost is reconstructible from pieces x '
            'unitCost, so per-option entries would be pure duplication (this '
            'would be 6 docs, not 2, if a future change wired option-diffing '
            'into the receiving path)');
    expect(optionedHistory.docs.length, plainHistory.docs.length);

    for (final doc in optionedHistory.docs) {
      final data = doc.data();
      expect(data.containsKey('optionId'), isFalse,
          reason: 'every receiving-path entry is a base entry');
      expect(data.containsKey('optionLabel'), isFalse);
      expect(data.containsKey('optionPieces'), isFalse);
    }
  });

  test(
      'receiving at the SAME cost writes no price_history at all, '
      'options or not (stock-only path, unaffected by this feature)',
      () async {
    final created = await productRepo.createProduct(
      product: ProductEntity(
        id: '',
        sku: 'PULLEY2',
        name: 'Pulley ball',
        costCode: 'AA',
        cost: 60,
        price: 700,
        quantity: 10,
        reorderLevel: 2,
        unit: 'pcs',
        isActive: true,
        createdAt: DateTime(2026, 1, 1),
        sellingOptions: const [
          SellingOptionEntity(id: 'o1', label: 'By 6', pieces: 6, price: 600),
        ],
      ),
      createdBy: 'u1',
    );
    // Clear the "Initial price" entry createProduct wrote, so we can observe
    // cleanly whether completeReceiving adds anything at the SAME cost.
    final initial = await fake
        .collection('products')
        .doc(created.id)
        .collection('price_history')
        .get();
    for (final doc in initial.docs) {
      await doc.reference.delete();
    }

    final receiving = await receivingRepo.createReceiving(ReceivingEntity(
      id: '',
      referenceNumber: 'RCV-2',
      items: [
        ReceivingItemEntity(
          id: 'li-1',
          productId: created.id,
          sku: created.sku,
          name: created.name,
          quantity: 5,
          unit: 'pcs',
          unitCost: 60, // same cost -> stock-only path, no history write
          costCode: 'AA',
        ),
      ],
      totalCost: 300,
      totalQuantity: 5,
      status: ReceivingStatus.draft,
      createdAt: DateTime(2026, 1, 2),
      createdBy: 'u1',
      createdByName: 'Admin',
    ));
    await receivingRepo.completeReceiving(
      receivingId: receiving.id,
      completedBy: 'u1',
    );

    final history = await fake
        .collection('products')
        .doc(created.id)
        .collection('price_history')
        .get();
    expect(history.docs, isEmpty);
  });
}
