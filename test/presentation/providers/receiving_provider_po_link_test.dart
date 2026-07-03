import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:maki_mobile_pos/core/enums/enums.dart';
import 'package:maki_mobile_pos/data/repositories/purchase_order_repository_impl.dart';
import 'package:maki_mobile_pos/data/repositories/receiving_repository_impl.dart';
import 'package:maki_mobile_pos/domain/entities/entities.dart';
import 'package:maki_mobile_pos/domain/repositories/activity_log_repository.dart';
import 'package:maki_mobile_pos/domain/repositories/product_repository.dart';
import 'package:maki_mobile_pos/services/activity_logger.dart';
import 'package:maki_mobile_pos/presentation/providers/auth_provider.dart';
import 'package:maki_mobile_pos/presentation/providers/product_provider.dart';
import 'package:maki_mobile_pos/presentation/providers/receiving_provider.dart';

class _MockProductRepository extends Mock implements ProductRepository {}

class _MockActivityLogRepository extends Mock
    implements ActivityLogRepository {}

/// The purchase-order Receive flow resumes its prefilled draft in the bulk
/// receiving screen. Editing there must neither sever the PO link (Save
/// Draft) nor complete against stale quantities (Post Receiving without
/// saving first).
void main() {
  late FakeFirebaseFirestore fake;
  late PurchaseOrderRepositoryImpl poRepo;
  late ReceivingRepositoryImpl receivingRepo;
  late _MockProductRepository productRepo;
  late ProviderContainer container;

  final product = ProductEntity(
    id: 'p1',
    sku: 'SKU-1',
    name: 'Brake Pad',
    cost: 55,
    costCode: 'NBF',
    price: 80,
    quantity: 2,
    reorderLevel: 2,
    unit: 'pcs',
    isActive: true,
    createdAt: DateTime(2026, 1, 1),
  );

  final admin = UserEntity(
    id: 'u1',
    email: 'u@x.com',
    displayName: 'Admin',
    role: UserRole.admin,
    isActive: true,
    createdAt: DateTime(2026, 1, 1),
  );

  setUp(() {
    fake = FakeFirebaseFirestore();
    poRepo = PurchaseOrderRepositoryImpl(firestore: fake);
    productRepo = _MockProductRepository();
    receivingRepo = ReceivingRepositoryImpl(
      firestore: fake,
      productRepository: productRepo,
    );
    when(() => productRepo.getProductById('p1'))
        .thenAnswer((_) async => product);
    when(() => productRepo.updateStock(
          productId: any(named: 'productId'),
          quantityChange: any(named: 'quantityChange'),
          updatedBy: any(named: 'updatedBy'),
          updatedByName: any(named: 'updatedByName'),
        )).thenAnswer((_) async => product);

    container = ProviderContainer(overrides: [
      receivingRepositoryProvider.overrideWith((ref) => receivingRepo),
      productRepositoryProvider.overrideWith((ref) => productRepo),
      currentUserProvider.overrideWith((ref) => Stream.value(admin)),
      // Inert list streams so _invalidateProviders doesn't spin up
      // auth-gated Firestore streams that outlive the container.
      recentReceivingsProvider.overrideWith((ref) => Stream.value(const [])),
      productsProvider.overrideWith((ref) => Stream.value([product])),
      // ActivityLogger.log swallows its own errors, so an unstubbed mock
      // repository is enough to keep the audit write off FirebaseService.
      activityLoggerProvider.overrideWith(
          (ref) => ActivityLogger(_MockActivityLogRepository())),
    ]);
    addTearDown(container.dispose);
  });

  Future<void> primeUser() async {
    // complete() reads currentUserProvider synchronously — make sure the
    // overridden stream has emitted before acting.
    await container.read(currentUserProvider.future);
  }

  Future<({String poId, String receivingId})> linkedPair() async {
    final po = await poRepo.createPurchaseOrder(PurchaseOrderEntity(
      id: '',
      referenceNumber: 'PO-20260703-001',
      items: const [
        PurchaseOrderItemEntity(
          id: 'p1',
          productId: 'p1',
          sku: 'SKU-1',
          name: 'Brake Pad',
          quantity: 10,
          unit: 'pcs',
          unitCost: 55,
          costCode: 'NBF',
        ),
      ],
      totalCost: 550,
      totalQuantity: 10,
      status: PurchaseOrderStatus.draft,
      createdAt: DateTime(2026, 7, 3),
      createdBy: 'u1',
      createdByName: 'Admin',
    ));
    await poRepo.markOrdered(po.id);
    final receivingId = await poRepo.startReceiving(
      purchaseOrderId: po.id,
      receivingReferenceNumber: 'RCV-20260703-001',
      createdBy: 'u1',
      createdByName: 'Admin',
    );
    return (poId: po.id, receivingId: receivingId);
  }

  test('Save Draft on a resumed PO receiving keeps the link', () async {
    final pair = await linkedPair();
    await primeUser();
    final notifier = container.read(currentReceivingProvider.notifier);

    await notifier.loadReceiving(pair.receivingId);
    expect(container.read(currentReceivingProvider).purchaseOrderId,
        pair.poId,
        reason: 'the link must survive the round trip through state');

    // Edit a quantity, then Save Draft (updateReceiving path).
    final item = container.read(currentReceivingProvider).items.first;
    notifier.updateItemQuantity(item.id, 6);
    final saved =
        await notifier.saveAsDraft(createdBy: 'u1', createdByName: 'Admin');
    expect(saved, isNotNull);

    final doc = await fake.collection('receivings').doc(pair.receivingId).get();
    expect(doc.data()!['purchaseOrderId'], pair.poId,
        reason: 'Save Draft must not sever the PO link');
  });

  test('completing a resumed draft persists in-session edits first', () async {
    final pair = await linkedPair();
    await primeUser();
    final notifier = container.read(currentReceivingProvider.notifier);

    await notifier.loadReceiving(pair.receivingId);
    // Supplier delivered 6, not 10 — edit in-session and complete WITHOUT
    // tapping Save Draft.
    final item = container.read(currentReceivingProvider).items.first;
    notifier.updateItemQuantity(item.id, 6);

    final done =
        await notifier.complete(createdBy: 'u1', createdByName: 'Admin');
    expect(done, isNotNull,
        reason: container.read(currentReceivingProvider).errorMessage ?? '');

    // Stock must be incremented by the edited quantity, not the stale 10.
    verify(() => productRepo.updateStock(
          productId: 'p1',
          quantityChange: 6,
          updatedBy: 'u1',
          updatedByName: 'Admin',
        )).called(1);

    // And the atomic PO mark still fires (link survived the edit-save).
    final po = await poRepo.getPurchaseOrderById(pair.poId);
    expect(po!.status, PurchaseOrderStatus.received);
  });
}
