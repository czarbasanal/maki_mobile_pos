import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:maki_mobile_pos/core/enums/enums.dart';
import 'package:maki_mobile_pos/data/repositories/draft_repository_impl.dart';
import 'package:maki_mobile_pos/domain/entities/entities.dart';
import 'package:maki_mobile_pos/presentation/providers/providers.dart';
import 'package:maki_mobile_pos/presentation/mobile/screens/drafts/draft_edit_screen.dart';

void main() {
  UserEntity admin() => UserEntity(
        id: 'admin-1',
        email: 'a@x.com',
        displayName: 'Admin',
        role: UserRole.admin,
        isActive: true,
        createdAt: DateTime(2026, 7, 1),
      );

  DraftEntity buildDraft({String? notes}) => DraftEntity(
        id: 'draft-1',
        name: 'JO-072526-001',
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

  Future<(DraftRepositoryImpl, String)> pump(
    WidgetTester tester,
    DraftEntity draft,
  ) async {
    tester.view.physicalSize = const Size(1200, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    // Seed a real doc through the repo so updateDraft persists succeed.
    final repo = DraftRepositoryImpl(firestore: FakeFirebaseFirestore());
    final created = await repo.createDraft(draft);

    final container = ProviderContainer(overrides: [
      draftByIdProvider(created.id).overrideWith((ref) async => created),
      activeMechanicsProvider.overrideWith((ref) => Stream.value(const [])),
      activeShopFeesProvider.overrideWith((ref) => Stream.value(const [])),
      currentUserProvider.overrideWith((ref) => Stream.value(admin())),
      draftRepositoryProvider.overrideWithValue(repo),
      unsettledBusinessDayProvider.overrideWith((ref) async => null),
    ]);
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(home: DraftEditScreen(draftId: created.id)),
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
    await pump(tester, buildDraft(notes: 'Original note'));

    expect(find.widgetWithText(TextField, 'Original note'), findsOneWidget);
  });

  testWidgets('shows the Notes field even when the ticket has none yet',
      (tester) async {
    await pump(tester, buildDraft());

    expect(find.text('Notes'), findsOneWidget);
  });

  testWidgets('editing notes persists through updateDraft on focus loss',
      (tester) async {
    final (repo, id) = await pump(tester, buildDraft(notes: 'Old note'));

    await tester.enterText(
        find.widgetWithText(TextField, 'Old note'), 'Replace clutch cable');
    FocusManager.instance.primaryFocus?.unfocus();
    await settle(tester);

    final saved = await repo.getDraftById(id);
    expect(saved!.notes, 'Replace clutch cable');
  });

  testWidgets('clearing notes persists null, never empty string',
      (tester) async {
    final (repo, id) = await pump(tester, buildDraft(notes: 'Old note'));

    await tester.enterText(find.widgetWithText(TextField, 'Old note'), '   ');
    FocusManager.instance.primaryFocus?.unfocus();
    await settle(tester);

    final saved = await repo.getDraftById(id);
    expect(saved!.notes, isNull);
  });
}
