import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
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

  DraftEntity buildDraft({String? model, DateTime? updatedAt}) => DraftEntity(
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
        motorcycleModel: model,
        updatedAt: updatedAt,
        createdBy: 'cashier-1',
        createdByName: 'John Doe',
        createdAt: DateTime(2026, 5, 30),
      );

  Widget harness(DraftEntity draft) => ProviderScope(
        overrides: [
          draftByIdProvider('draft-1').overrideWith((ref) async => draft),
          activeMechanicsProvider.overrideWith((ref) => Stream.value(const [])),
          activeMotorcycleModelsProvider
              .overrideWith((ref) => Stream.value(const [])),
          currentUserProvider.overrideWith((ref) => Stream.value(admin())),
          draftRepositoryProvider.overrideWithValue(
            DraftRepositoryImpl(firestore: FakeFirebaseFirestore()),
          ),
        ],
        child: const MaterialApp(home: DraftEditScreen(draftId: 'draft-1')),
      );

  Future<void> pump(WidgetTester tester, DraftEntity draft) async {
    tester.view.physicalSize = const Size(1200, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpWidget(harness(draft));
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));
  }

  testWidgets('info header shows the motorcycle model in the picker when set',
      (tester) async {
    await pump(tester, buildDraft(model: 'Yamaha Nmax'));
    // The model renders as the picker's selected value (editable in place).
    expect(find.text('Yamaha Nmax'), findsOneWidget);
    expect(find.byIcon(LucideIcons.bike), findsOneWidget);
  });

  testWidgets('info header shows an empty model picker when no model is set',
      (tester) async {
    await pump(tester, buildDraft());
    // Picker is always present (its bike prefix icon), just with no value.
    expect(find.byIcon(LucideIcons.bike), findsOneWidget);
    expect(find.text('Motorcycle model'), findsOneWidget);
  });

  testWidgets('Updated line uses the square-pen glyph', (tester) async {
    await pump(tester, buildDraft(updatedAt: DateTime(2026, 6, 1)));
    expect(find.byIcon(LucideIcons.squarePen), findsOneWidget);
  });
}
