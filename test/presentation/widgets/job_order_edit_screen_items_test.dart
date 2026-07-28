import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:maki_mobile_pos/core/enums/enums.dart';
import 'package:maki_mobile_pos/data/repositories/job_order_repository_impl.dart';
import 'package:maki_mobile_pos/domain/entities/entities.dart';
import 'package:maki_mobile_pos/presentation/providers/providers.dart';
import 'package:maki_mobile_pos/presentation/mobile/screens/job_orders/job_order_edit_screen.dart';
import 'package:maki_mobile_pos/presentation/mobile/widgets/pos/cart_item_tile.dart';

void main() {
  UserEntity admin() => UserEntity(
        id: 'admin-1',
        email: 'a@x.com',
        displayName: 'Admin',
        role: UserRole.admin,
        isActive: true,
        createdAt: DateTime(2026, 7, 1),
      );

  JobOrderEntity buildJobOrder({int quantity = 2}) => JobOrderEntity(
        id: 'jobOrder-1',
        name: 'Plate ABC-123',
        items: [
          SaleItemEntity(
            id: 'item-1',
            productId: 'prod-1',
            sku: 'SKU-001',
            name: 'Brake Pad',
            unitPrice: 100.0,
            unitCost: 60.0,
            quantity: quantity,
          ),
        ],
        createdBy: 'cashier-1',
        createdByName: 'John Doe',
        createdAt: DateTime(2026, 5, 30),
      );

  Future<void> pump(WidgetTester tester, JobOrderEntity jobOrder) async {
    tester.view.physicalSize = const Size(1200, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    // Seed a real doc through the repo so updateJobOrder persists succeed (a
    // failing write now makes the editor roll the optimistic edit back).
    final repo = JobOrderRepositoryImpl(firestore: FakeFirebaseFirestore());
    final created = await repo.createJobOrder(jobOrder);

    final container = ProviderContainer(overrides: [
      jobOrderByIdProvider(created.id).overrideWith((ref) async => created),
      activeMechanicsProvider.overrideWith((ref) => Stream.value(const [])),
      currentUserProvider.overrideWith((ref) => Stream.value(admin())),
      jobOrderRepositoryProvider.overrideWithValue(repo),
      unsettledBusinessDayProvider.overrideWith((ref) async => null),
    ]);
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(home: JobOrderEditScreen(jobOrderId: created.id)),
      ),
    );
    // Warm the user stream — in the app it is always alive via the auth
    // gate, but _persist reads it lazily and a cold first read is loading.
    await container.read(currentUserProvider.future);
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));
  }

  Finder inTile(Finder matching) =>
      find.descendant(of: find.byType(CartItemTile), matching: matching);

  // After an edit, the notifier invalidates jobOrderByIdProvider (loading flash)
  // before the working copy re-renders — settle across that.
  Future<void> settle(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));
  }

  testWidgets('parts render as POS cart cards and the stepper updates qty',
      (tester) async {
    await pump(tester, buildJobOrder());

    expect(find.byType(CartItemTile), findsOneWidget);
    expect(inTile(find.text('2')), findsOneWidget);

    await tester.tap(inTile(find.byIcon(LucideIcons.plus)));
    await settle(tester);
    expect(inTile(find.text('3')), findsOneWidget);

    await tester.tap(inTile(find.byIcon(LucideIcons.minus)));
    await settle(tester);
    expect(inTile(find.text('2')), findsOneWidget);
  });

  testWidgets('minus is disabled at quantity 1 (removal is via the x)',
      (tester) async {
    await pump(tester, buildJobOrder(quantity: 1));

    final minusButton = tester.widget<IconButton>(
      find.ancestor(
        of: inTile(find.byIcon(LucideIcons.minus)),
        matching: find.byType(IconButton),
      ),
    );
    expect(minusButton.onPressed, isNull);

    await tester.tap(inTile(find.byTooltip('Remove item')));
    await settle(tester);
    expect(find.text('No parts on this job order yet'), findsOneWidget);
  });

  testWidgets('failed persist reverts the optimistic edit', (tester) async {
    // No signed-in user → updateJobOrder can't run; the optimistic qty bump
    // must roll back to the server copy instead of lying on screen.
    tester.view.physicalSize = const Size(1200, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          jobOrderByIdProvider('jobOrder-1')
              .overrideWith((ref) async => buildJobOrder()),
          activeMechanicsProvider.overrideWith((ref) => Stream.value(const [])),
          currentUserProvider.overrideWith((ref) => Stream.value(null)),
          jobOrderRepositoryProvider.overrideWithValue(
            JobOrderRepositoryImpl(firestore: FakeFirebaseFirestore()),
          ),
          unsettledBusinessDayProvider.overrideWith((ref) async => null),
        ],
        child: const MaterialApp(
            home: JobOrderEditScreen(jobOrderId: 'jobOrder-1')),
      ),
    );
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));

    await tester.tap(inTile(find.byIcon(LucideIcons.plus)));
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));

    expect(inTile(find.text('2')), findsOneWidget); // rolled back, not 3
  });

  testWidgets('applying a per-item discount persists and shows in summary',
      (tester) async {
    await pump(tester, buildJobOrder());

    // Discount chip on the card opens the shared POS discount dialog.
    await tester.tap(inTile(find.text('Discount')));
    await tester.pumpAndSettle();
    expect(find.text('Apply Discount'), findsOneWidget);

    await tester.enterText(find.byType(TextField).last, '50');
    await tester.tap(find.text('Apply'));
    await tester.pumpAndSettle();
    await settle(tester);

    // Summary shows the green Discount row; total drops 200 -> 150.
    expect(find.text('Discount'), findsWidgets);
    expect(find.textContaining('150.00'), findsWidgets);
  });
}
