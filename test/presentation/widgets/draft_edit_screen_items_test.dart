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

  DraftEntity buildDraft() => DraftEntity(
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
        createdBy: 'cashier-1',
        createdByName: 'John Doe',
        createdAt: DateTime(2026, 5, 30),
      );

  Widget harness(DraftEntity draft) => ProviderScope(
        overrides: [
          draftByIdProvider('draft-1').overrideWith((ref) async => draft),
          activeMechanicsProvider.overrideWith((ref) => Stream.value(const [])),
          currentUserProvider.overrideWith((ref) => Stream.value(admin())),
          draftRepositoryProvider.overrideWithValue(
            DraftRepositoryImpl(firestore: FakeFirebaseFirestore()),
          ),
        ],
        child: const MaterialApp(home: DraftEditScreen(draftId: 'draft-1')),
      );

  testWidgets('increment / decrement / remove update the displayed quantity',
      (tester) async {
    tester.view.physicalSize = const Size(1200, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(harness(buildDraft()));
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));

    // Quantity badge shows "2x".
    expect(find.text('2x'), findsOneWidget);

    await tester.tap(find.byTooltip('Increase quantity'));
    await tester.pump();
    expect(find.text('3x'), findsOneWidget);

    await tester.tap(find.byTooltip('Decrease quantity'));
    await tester.pump();
    expect(find.text('2x'), findsOneWidget);

    await tester.tap(find.byTooltip('Remove part'));
    await tester.pump();
    expect(find.text('No parts on this job order yet'), findsOneWidget);
  });
}
