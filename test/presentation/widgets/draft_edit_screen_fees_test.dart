import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:maki_mobile_pos/core/enums/enums.dart';
import 'package:maki_mobile_pos/data/repositories/draft_repository_impl.dart';
import 'package:maki_mobile_pos/domain/entities/entities.dart';
import 'package:maki_mobile_pos/presentation/providers/providers.dart';
import 'package:maki_mobile_pos/presentation/mobile/screens/drafts/draft_edit_screen.dart';
import 'package:maki_mobile_pos/presentation/mobile/widgets/pos/fee_line_row.dart';

void main() {
  UserEntity admin() => UserEntity(
        id: 'admin-1',
        email: 'a@x.com',
        displayName: 'Admin',
        role: UserRole.admin,
        isActive: true,
        createdAt: DateTime(2026, 7, 1),
      );

  DraftEntity buildDraft({
    List<FeeLineEntity> fees = const [],
    String? motorcycleModel,
  }) =>
      DraftEntity(
        id: 'draft-1',
        name: 'Plate ABC-123',
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
        feeLines: fees,
        motorcycleModel: motorcycleModel,
        createdBy: 'cashier-1',
        createdByName: 'John Doe',
        createdAt: DateTime(2026, 5, 30),
      );

  ShopFeeEntity shopFee({
    required String id,
    required String name,
    double? defaultAmount,
  }) =>
      ShopFeeEntity(
        id: id,
        name: name,
        defaultAmount: defaultAmount,
        isActive: true,
        createdAt: DateTime(2026, 1, 1),
      );

  Future<(ProviderContainer, String)> pump(
    WidgetTester tester,
    DraftEntity draft, {
    List<ShopFeeEntity> activeFees = const [],
  }) async {
    tester.view.physicalSize = const Size(1200, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    // Seed a real doc through the repo so updateDraft persists succeed.
    final repo = DraftRepositoryImpl(firestore: FakeFirebaseFirestore());
    final created = await repo.createDraft(draft);

    final container = ProviderContainer(overrides: [
      draftByIdProvider(created.id).overrideWith((ref) async => created),
      activeMechanicsProvider.overrideWith((ref) => Stream.value(const [])),
      activeShopFeesProvider.overrideWith((ref) => Stream.value(activeFees)),
      currentUserProvider.overrideWith((ref) => Stream.value(admin())),
      draftRepositoryProvider.overrideWithValue(repo),
    ]);
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(home: DraftEditScreen(draftId: created.id)),
      ),
    );
    // Warm the user stream — _persist reads it lazily and a cold first read
    // is loading.
    await container.read(currentUserProvider.future);
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));
    return (container, created.id);
  }

  // After an edit, the notifier invalidates draftByIdProvider (loading flash)
  // before the working copy re-renders — settle across that.
  Future<void> settle(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));
  }

  testWidgets('renders Shop Fees section header and Add Fee button',
      (tester) async {
    await pump(tester, buildDraft());

    expect(find.text('Shop Fees'), findsOneWidget);
    expect(find.text('Add Fee'), findsOneWidget);
  });

  testWidgets('shows fee subtotal and grand total includes fees',
      (tester) async {
    await pump(
      tester,
      buildDraft(fees: const [
        FeeLineEntity(id: 'fee-1', name: 'Electric charge', amount: 20.0),
      ]),
    );

    expect(find.text('Electric charge'), findsOneWidget);
    expect(find.byType(FeeLineRow), findsOneWidget);
    expect(find.text('Shop Fees (1)'), findsOneWidget);
    // Grand total = parts 200 + fee 20 = 220.00.
    expect(find.textContaining('220.00'), findsWidgets);
  });

  testWidgets('adding a fee via the picker persists it onto the draft',
      (tester) async {
    final (container, draftId) = await pump(
      tester,
      buildDraft(),
      activeFees: [shopFee(id: 'f1', name: 'Air', defaultAmount: 15.0)],
    );

    await tester.tap(find.text('Add Fee'));
    await tester.pumpAndSettle();

    expect(find.text('Air'), findsOneWidget);
    await tester.tap(find.text('Air'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Add'));
    await tester.pumpAndSettle();
    await settle(tester);

    expect(find.byType(FeeLineRow), findsOneWidget);
    final stored =
        await container.read(draftRepositoryProvider).getDraftById(draftId);
    expect(stored!.feeLines.single.name, 'Air');
    expect(stored.feeLines.single.amount, 15.0);
  });

  testWidgets('editing a fee amount persists the new amount', (tester) async {
    final (container, draftId) = await pump(
      tester,
      buildDraft(fees: const [
        FeeLineEntity(id: 'fee-1', name: 'Electric charge', amount: 20.0),
      ]),
    );

    await tester.tap(find.byType(FeeLineRow));
    await tester.pumpAndSettle();
    expect(find.text('Edit Fee Amount'), findsOneWidget);

    await tester.enterText(find.byKey(const Key('fee-amount-field')), '35');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    await settle(tester);

    final stored =
        await container.read(draftRepositoryProvider).getDraftById(draftId);
    expect(stored!.feeLines.single.amount, 35.0);
  });

  testWidgets('removing a fee line persists the removal', (tester) async {
    final (container, draftId) = await pump(
      tester,
      buildDraft(fees: const [
        FeeLineEntity(id: 'fee-1', name: 'Electric charge', amount: 20.0),
      ]),
    );

    await tester.tap(find.byWidgetPredicate(
        (w) => w is IconButton && w.tooltip == 'Remove fee line'));
    await tester.pumpAndSettle();
    await settle(tester);

    expect(find.byType(FeeLineRow), findsNothing);
    final stored =
        await container.read(draftRepositoryProvider).getDraftById(draftId);
    expect(stored!.feeLines, isEmpty);
  });

  // Carried review finding: the "register in use" clobber-warning before
  // bill-out used to check cart.isNotEmpty, which excludes fee-only carts —
  // a fee-only live sale in the register would be silently clobbered
  // without warning. It must check cart.hasBillableContent instead.
  testWidgets(
      'bill-out warns about a fee-only register cart before clobbering it',
      (tester) async {
    final (container, _) = await pump(
      tester,
      buildDraft(motorcycleModel: 'Nmax'),
    );

    // Register has NO items but a fee line — hasBillableContent is true,
    // isNotEmpty is false.
    container.read(cartProvider.notifier).addFeeLine(
          const FeeLineEntity(id: 'reg-fee', name: 'Air', amount: 20.0),
        );
    expect(container.read(cartProvider).isNotEmpty, isFalse);
    expect(container.read(cartProvider).hasBillableContent, isTrue);

    await tester.tap(find.text('Bill out'));
    await tester.pumpAndSettle();

    expect(find.text('Register in use'), findsOneWidget);
  });

  // Policy change: items OR labor OR fees — labor alone is now billable.
  // The reported bug was a stale items-only gate on the Bill out button that
  // left a labor+fee ticket (no parts) permanently disabled.
  testWidgets(
      'Bill out is enabled for a labor+fee ticket with no items',
      (tester) async {
    final draft = DraftEntity(
      id: 'draft-1',
      name: 'Plate ABC-123',
      items: const [],
      laborLines: const [
        LaborLineEntity(id: 'lab-1', description: 'Tune-up', fee: 300.0),
      ],
      feeLines: const [
        FeeLineEntity(id: 'fee-1', name: 'Air', amount: 20.0),
      ],
      mechanicId: 'mech-1',
      mechanicName: 'Juan Dela Cruz',
      motorcycleModel: 'Nmax',
      createdBy: 'cashier-1',
      createdByName: 'John Doe',
      createdAt: DateTime(2026, 5, 30),
    );

    await pump(tester, draft);

    final button = tester.widget<FilledButton>(find.ancestor(
      of: find.text('Bill out'),
      matching: find.byWidgetPredicate((w) => w is FilledButton),
    ));
    expect(button.onPressed, isNotNull);
  });

  testWidgets('Bill out is disabled for a truly empty ticket', (tester) async {
    final draft = DraftEntity(
      id: 'draft-1',
      name: 'Plate ABC-123',
      items: const [],
      motorcycleModel: 'Nmax',
      createdBy: 'cashier-1',
      createdByName: 'John Doe',
      createdAt: DateTime(2026, 5, 30),
    );

    await pump(tester, draft);

    final button = tester.widget<FilledButton>(find.ancestor(
      of: find.text('Bill out'),
      matching: find.byWidgetPredicate((w) => w is FilledButton),
    ));
    expect(button.onPressed, isNull);
  });

  // Policy change: items OR labor OR fees — labor alone is now billable.
  // The "register in use" clobber-warning must check hasBillableContent,
  // not isNotEmpty, to catch labor-only carts just as it does fee-only ones.
  testWidgets(
      'labor-only register cart still triggers the clobber warning',
      (tester) async {
    final (container, _) = await pump(
      tester,
      buildDraft(motorcycleModel: 'Nmax'),
    );

    // Register has NO items and NO fees but a labor line — hasBillableContent
    // is true, isNotEmpty is false.
    container.read(cartProvider.notifier).addLaborLine(
          description: 'Tune-up',
          fee: 300.0,
        );
    expect(container.read(cartProvider).isNotEmpty, isFalse);
    expect(container.read(cartProvider).hasBillableContent, isTrue);
    expect(container.read(cartProvider).items, isEmpty);
    expect(container.read(cartProvider).feeLines, isEmpty);

    await tester.tap(find.text('Bill out'));
    await tester.pumpAndSettle();

    expect(find.text('Register in use'), findsOneWidget);
  });
}
