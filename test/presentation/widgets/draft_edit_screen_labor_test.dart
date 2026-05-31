import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:maki_mobile_pos/domain/entities/entities.dart';
import 'package:maki_mobile_pos/presentation/providers/providers.dart';
import 'package:maki_mobile_pos/presentation/mobile/widgets/pos/mechanic_picker.dart';
import 'package:maki_mobile_pos/presentation/mobile/screens/drafts/draft_edit_screen.dart';

void main() {
  DraftEntity buildDraft({List<LaborLineEntity> labor = const []}) => DraftEntity(
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
        laborLines: labor,
        mechanicName: labor.isEmpty ? null : 'Juan Dela Cruz',
        mechanicId: labor.isEmpty ? null : 'mech-1',
        createdBy: 'cashier-1',
        createdByName: 'John Doe',
        createdAt: DateTime(2026, 5, 30, 10, 0),
      );

  Widget harness(DraftEntity draft) => ProviderScope(
        overrides: [
          draftByIdProvider('draft-1').overrideWith((ref) async => draft),
          activeMechanicsProvider.overrideWith(
            (ref) => Stream.value([
              MechanicEntity(
                id: 'mech-1',
                name: 'Juan Dela Cruz',
                isActive: true,
                createdAt: DateTime(2026, 1, 1),
              ),
            ]),
          ),
        ],
        child: const MaterialApp(home: DraftEditScreen(draftId: 'draft-1')),
      );

  testWidgets('renders Labor & Service section header and mechanic picker',
      (tester) async {
    tester.view.physicalSize = const Size(1200, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(harness(buildDraft()));
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('Labor & Service'), findsOneWidget);
    expect(find.byType(MechanicPicker), findsOneWidget);
    expect(find.text('Add Labor'), findsOneWidget);
  });

  testWidgets('shows labor subtotal and grand total includes labor',
      (tester) async {
    tester.view.physicalSize = const Size(1200, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    final draft = buildDraft(labor: const [
      LaborLineEntity(id: 'l1', description: 'Engine tune-up', fee: 450.0),
    ]);
    await tester.pumpWidget(harness(draft));
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('Engine tune-up'), findsOneWidget);
    expect(find.text('Labor (1 service)'), findsOneWidget);
    // Grand total = parts 200 + labor 450 = 650.00 (appears in summary).
    expect(find.textContaining('650.00'), findsWidgets);
  });
}
