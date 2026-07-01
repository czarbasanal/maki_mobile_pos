import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:maki_mobile_pos/core/enums/enums.dart';
import 'package:maki_mobile_pos/data/repositories/receiving_repository_impl.dart';
import 'package:maki_mobile_pos/domain/entities/entities.dart';
import 'package:maki_mobile_pos/domain/repositories/product_repository.dart';
import 'package:maki_mobile_pos/presentation/mobile/screens/receiving/bulk_receiving_screen.dart';
import 'package:maki_mobile_pos/presentation/providers/providers.dart';

class _MockProductRepository extends Mock implements ProductRepository {}

/// Regression for the "receiving details stuck on skeleton / not showing data"
/// bug: BulkReceivingScreen.initState used to call loadReceiving synchronously,
/// which mutates currentReceivingProvider DURING the widget build phase. Riverpod
/// throws "Tried to modify a provider while the widget tree was building"; the
/// uncaught exception left isLoading pinned true, so the detail hung on the
/// skeleton forever and getReceivingById was never reached.
///
/// With the load deferred to a post-frame callback, mounting the screen no
/// longer throws and the receiving's items render.
void main() {
  late FakeFirebaseFirestore fake;
  late ReceivingRepositoryImpl repo;

  UserEntity admin() => UserEntity(
        id: 'u1',
        email: 'a@x.com',
        displayName: 'Admin',
        role: UserRole.admin,
        isActive: true,
        createdAt: DateTime(2026, 6, 1),
      );

  setUp(() {
    fake = FakeFirebaseFirestore();
    repo = ReceivingRepositoryImpl(
      firestore: fake,
      productRepository: _MockProductRepository(),
    );
  });

  testWidgets('opening an existing receiving loads and renders its items '
      '(no modify-provider-during-build hang)', (tester) async {
    final created = await repo.createReceiving(ReceivingEntity(
      id: '',
      referenceNumber: 'RCV-1',
      items: const [
        ReceivingItemEntity(
          id: 'li-1',
          productId: 'p1',
          sku: 'SKU-1',
          name: 'Brake Pad',
          quantity: 2,
          unit: 'pcs',
          unitCost: 50,
          costCode: 'NBF',
        ),
      ],
      totalCost: 100,
      totalQuantity: 2,
      status: ReceivingStatus.completed,
      completedAt: DateTime(2026, 6, 2),
      createdAt: DateTime(2026, 6, 1),
      createdBy: 'u1',
      createdByName: 'Admin',
      completedBy: 'u1',
    ));

    await tester.pumpWidget(ProviderScope(
      overrides: [
        receivingRepositoryProvider.overrideWith((ref) => repo),
        productRepositoryProvider
            .overrideWith((ref) => _MockProductRepository()),
        currentUserProvider.overrideWith((ref) => Stream.value(admin())),
        suppliersProvider
            .overrideWith((ref) => Stream.value(const <SupplierEntity>[])),
      ],
      child: MaterialApp(home: BulkReceivingScreen(receivingId: created.id)),
    ));

    // First frame (skeleton), then the post-frame callback runs loadReceiving
    // and the async Firestore read resolves.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pump(const Duration(milliseconds: 200));

    // The item is rendered — the detail is no longer stuck on the skeleton.
    expect(find.text('Brake Pad'), findsOneWidget);
    // And it is shown as a completed, read-only receiving.
    expect(find.textContaining('Read-only'), findsOneWidget);
  });
}
