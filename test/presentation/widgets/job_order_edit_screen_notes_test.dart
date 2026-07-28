import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:maki_mobile_pos/config/router/router.dart';
import 'package:maki_mobile_pos/core/enums/enums.dart';
import 'package:maki_mobile_pos/data/repositories/job_order_repository_impl.dart';
import 'package:maki_mobile_pos/domain/entities/entities.dart';
import 'package:maki_mobile_pos/presentation/providers/providers.dart';
import 'package:maki_mobile_pos/presentation/mobile/screens/job_orders/job_order_edit_screen.dart';

void main() {
  UserEntity admin() => UserEntity(
        id: 'admin-1',
        email: 'a@x.com',
        displayName: 'Admin',
        role: UserRole.admin,
        isActive: true,
        createdAt: DateTime(2026, 7, 1),
      );

  JobOrderEntity buildJobOrder({String? notes, String? motorcycleModel}) =>
      JobOrderEntity(
        id: 'jobOrder-1',
        name: 'JO-072526-001',
        motorcycleModel: motorcycleModel,
        items: const [
          SaleItemEntity(
            id: 'item-1',
            productId: 'prod-1',
            sku: 'SKU-001',
            name: 'Brake Pad',
            unitPrice: 100.0,
            unitCost: 60.0,
            quantity: 2,
          ),
        ],
        notes: notes,
        createdBy: 'cashier-1',
        createdByName: 'John Doe',
        createdAt: DateTime(2026, 5, 30),
      );

  Future<(JobOrderRepositoryImpl, String)> pump(
    WidgetTester tester,
    JobOrderEntity jobOrder,
  ) async {
    tester.view.physicalSize = const Size(1200, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    // Seed a real doc through the repo so updateJobOrder persists succeed.
    final repo = JobOrderRepositoryImpl(firestore: FakeFirebaseFirestore());
    final created = await repo.createJobOrder(jobOrder);

    final container = ProviderContainer(overrides: [
      jobOrderByIdProvider(created.id).overrideWith((ref) async => created),
      activeMechanicsProvider.overrideWith((ref) => Stream.value(const [])),
      activeShopFeesProvider.overrideWith((ref) => Stream.value(const [])),
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
    await container.read(currentUserProvider.future);
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));
    return (repo, created.id);
  }

  Future<void> settle(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));
  }

  testWidgets('shows an editable Notes field with the saved notes',
      (tester) async {
    await pump(tester, buildJobOrder(notes: 'Original note'));

    expect(find.widgetWithText(TextField, 'Original note'), findsOneWidget);
  });

  testWidgets('shows the Notes field even when the ticket has none yet',
      (tester) async {
    await pump(tester, buildJobOrder());

    expect(find.text('Notes'), findsOneWidget);
  });

  testWidgets('editing notes persists through updateJobOrder on focus loss',
      (tester) async {
    final (repo, id) = await pump(tester, buildJobOrder(notes: 'Old note'));

    await tester.enterText(
        find.widgetWithText(TextField, 'Old note'), 'Replace clutch cable');
    FocusManager.instance.primaryFocus?.unfocus();
    await settle(tester);

    final saved = await repo.getJobOrderById(id);
    expect(saved!.notes, 'Replace clutch cable');
  });

  testWidgets('clearing notes persists null, never empty string',
      (tester) async {
    final (repo, id) = await pump(tester, buildJobOrder(notes: 'Old note'));

    await tester.enterText(find.widgetWithText(TextField, 'Old note'), '   ');
    FocusManager.instance.primaryFocus?.unfocus();
    await settle(tester);

    final saved = await repo.getJobOrderById(id);
    expect(saved!.notes, isNull);
  });

  // Buttons don't blur a focused TextField, so Bill out and the back exits
  // must commit explicitly — these pin the two exits the blur commit misses.
  Future<(ProviderContainer, JobOrderRepositoryImpl, String)> pumpWithRouter(
    WidgetTester tester,
    JobOrderEntity jobOrder,
  ) async {
    tester.view.physicalSize = const Size(1200, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    final repo = JobOrderRepositoryImpl(firestore: FakeFirebaseFirestore());
    final created = await repo.createJobOrder(jobOrder);

    final container = ProviderContainer(overrides: [
      jobOrderByIdProvider(created.id).overrideWith((ref) async => created),
      activeMechanicsProvider.overrideWith((ref) => Stream.value(const [])),
      activeShopFeesProvider.overrideWith((ref) => Stream.value(const [])),
      currentUserProvider.overrideWith((ref) => Stream.value(admin())),
      jobOrderRepositoryProvider.overrideWithValue(repo),
      unsettledBusinessDayProvider.overrideWith((ref) async => null),
    ]);
    addTearDown(container.dispose);

    final router = GoRouter(
      initialLocation: '/edit',
      routes: [
        GoRoute(
          path: '/edit',
          builder: (_, __) => JobOrderEditScreen(jobOrderId: created.id),
        ),
        GoRoute(
          path: RoutePaths.checkout,
          builder: (_, __) => const Scaffold(body: Text('CHECKOUT STUB')),
        ),
        GoRoute(
          path: RoutePaths.jobOrders,
          builder: (_, __) => const Scaffold(body: Text('LIST STUB')),
        ),
      ],
    );

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await container.read(currentUserProvider.future);
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));
    return (container, repo, created.id);
  }

  testWidgets(
      'Bill out with a still-focused notes edit carries the fresh notes',
      (tester) async {
    final (container, repo, id) = await pumpWithRouter(
      tester,
      buildJobOrder(notes: 'Old note', motorcycleModel: 'Nmax'),
    );

    // Type but do NOT unfocus — tapping Bill out doesn't blur the field.
    await tester.enterText(
        find.widgetWithText(TextField, 'Old note'), 'Fresh plan');
    await tester.tap(find.text('Bill out'));
    await settle(tester);

    expect(find.text('CHECKOUT STUB'), findsOneWidget);
    expect(container.read(cartProvider).notes, 'Fresh plan');
    final saved = await repo.getJobOrderById(id);
    expect(saved!.notes, 'Fresh plan');
  });

  testWidgets('back exit commits a still-focused notes edit', (tester) async {
    final (_, repo, id) = await pumpWithRouter(
      tester,
      buildJobOrder(notes: 'Old note'),
    );

    await tester.enterText(
        find.widgetWithText(TextField, 'Old note'), 'Remember the gasket');
    await tester.tap(find.byIcon(LucideIcons.chevronLeft));
    await settle(tester);

    final saved = await repo.getJobOrderById(id);
    expect(saved!.notes, 'Remember the gasket');
  });
}
