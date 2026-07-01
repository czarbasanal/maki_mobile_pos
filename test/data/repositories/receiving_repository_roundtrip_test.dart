import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:maki_mobile_pos/data/repositories/receiving_repository_impl.dart';
import 'package:maki_mobile_pos/domain/entities/entities.dart';
import 'package:maki_mobile_pos/domain/repositories/product_repository.dart';
import 'package:maki_mobile_pos/presentation/providers/product_provider.dart';
import 'package:maki_mobile_pos/presentation/providers/receiving_provider.dart';

class _MockProductRepository extends Mock implements ProductRepository {}

/// Evidence test: does an existing receiving (draft + completed) round-trip its
/// items through the real Firestore serialization path
/// (createReceiving/updateReceiving -> getReceivingById -> ReceivingModel)?
/// The detail screen shows "No items" when state.items is empty, so if this
/// drops items it reproduces "receiving details not showing the data".
void main() {
  late FakeFirebaseFirestore fake;
  late ReceivingRepositoryImpl repo;

  setUp(() {
    fake = FakeFirebaseFirestore();
    repo = ReceivingRepositoryImpl(
      firestore: fake,
      productRepository: _MockProductRepository(),
    );
  });

  ReceivingItemEntity item() => const ReceivingItemEntity(
        id: 'li-1',
        productId: 'p1',
        sku: 'SKU-1',
        name: 'Brake Pad',
        quantity: 3,
        unit: 'pcs',
        unitCost: 50,
        costCode: 'NBF',
      );

  ReceivingEntity draft() => ReceivingEntity(
        id: '',
        referenceNumber: 'RCV-1',
        items: [item()],
        totalCost: 150,
        totalQuantity: 3,
        status: ReceivingStatus.draft,
        createdAt: DateTime(2026, 6, 1),
        createdBy: 'u1',
        createdByName: 'Admin',
      );

  test('createReceiving -> getReceivingById round-trips items', () async {
    final created = await repo.createReceiving(draft());

    final loaded = await repo.getReceivingById(created.id);

    expect(loaded, isNotNull);
    expect(loaded!.referenceNumber, 'RCV-1');
    expect(loaded.items, hasLength(1),
        reason: 'a saved draft must keep its items when reopened');
    expect(loaded.items.first.name, 'Brake Pad');
    expect(loaded.items.first.quantity, 3);
  });

  test('updateReceiving (mark completed) -> getReceivingById keeps items',
      () async {
    final created = await repo.createReceiving(draft());

    // Mirror completeReceiving's final write: same items, completed status.
    await repo.updateReceiving(created.copyWith(
      status: ReceivingStatus.completed,
      completedAt: DateTime(2026, 6, 2),
      completedBy: 'u1',
    ));

    final loaded = await repo.getReceivingById(created.id);

    expect(loaded, isNotNull);
    expect(loaded!.status, ReceivingStatus.completed);
    expect(loaded.items, hasLength(1),
        reason: 'a completed receiving viewed from history must show items');
    expect(loaded.items.first.name, 'Brake Pad');
    expect(loaded.completedAt, isNotNull,
        reason: 'completedAt should persist so the read-only banner shows it');
  });

  test(
      'END-TO-END: CurrentReceivingNotifier.loadReceiving shows the items the '
      'detail screen renders', () async {
    // Seed a receiving the way the app does, then drive the exact provider the
    // detail screen watches — with the REAL repo over fake Firestore.
    final created = await repo.createReceiving(draft());

    final container = ProviderContainer(overrides: [
      receivingRepositoryProvider.overrideWith((ref) => repo),
      productRepositoryProvider.overrideWith((ref) => _MockProductRepository()),
    ]);
    addTearDown(container.dispose);

    await container
        .read(currentReceivingProvider.notifier)
        .loadReceiving(created.id);

    final state = container.read(currentReceivingProvider);
    expect(state.isLoading, isFalse, reason: 'skeleton must clear');
    expect(state.id, created.id);
    expect(state.items, hasLength(1),
        reason: 'the detail screen renders state.items — empty = "no data"');
    expect(state.items.first.name, 'Brake Pad');
    expect(state.errorMessage, isNull);
  });
}
