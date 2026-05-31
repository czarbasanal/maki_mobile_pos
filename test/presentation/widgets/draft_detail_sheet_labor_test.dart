import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maki_mobile_pos/domain/entities/entities.dart';
import 'package:maki_mobile_pos/presentation/mobile/widgets/drafts/draft_detail_sheet.dart';

void main() {
  DraftEntity buildDraft({List<LaborLineEntity> labor = const [], String? mechanic}) =>
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
        laborLines: labor,
        mechanicName: mechanic,
        mechanicId: mechanic == null ? null : 'mech-1',
        createdBy: 'cashier-1',
        createdByName: 'John Doe',
        createdAt: DateTime(2026, 5, 30, 10, 0),
      );

  Widget harness(DraftEntity draft) => MaterialApp(
        home: Scaffold(
          body: DraftDetailSheet(
            draft: draft,
            onLoad: () {},
            onDelete: () {},
          ),
        ),
      );

  testWidgets('shows labor lines, labor subtotal, and mechanic row',
      (tester) async {
    tester.view.physicalSize = const Size(1200, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(harness(buildDraft(
      labor: const [
        LaborLineEntity(id: 'l1', description: 'Engine tune-up', fee: 450.0),
      ],
      mechanic: 'Juan Dela Cruz',
    )));
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('Engine tune-up'), findsOneWidget);
    expect(find.text('Labor'), findsWidgets);
    expect(find.text('Mechanic'), findsOneWidget);
    expect(find.text('Juan Dela Cruz'), findsOneWidget);
    // Grand total = parts 200 + labor 450 = 650.00.
    expect(find.textContaining('650.00'), findsWidgets);
  });

  testWidgets('hides labor and mechanic rows when none present',
      (tester) async {
    tester.view.physicalSize = const Size(1200, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(harness(buildDraft()));
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('Mechanic'), findsNothing);
    expect(find.text('Engine tune-up'), findsNothing);
  });
}
