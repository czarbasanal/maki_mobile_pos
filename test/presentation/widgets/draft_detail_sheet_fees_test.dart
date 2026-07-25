import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maki_mobile_pos/domain/entities/entities.dart';
import 'package:maki_mobile_pos/presentation/mobile/widgets/drafts/draft_detail_sheet.dart';

void main() {
  DraftEntity buildDraft({List<FeeLineEntity> fees = const []}) => DraftEntity(
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

  testWidgets('shows fee lines, fees total, and grand total includes fees',
      (tester) async {
    tester.view.physicalSize = const Size(1200, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(harness(buildDraft(fees: const [
      FeeLineEntity(id: 'fee-1', name: 'Electric charge', amount: 20.0),
    ])));
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('Electric charge'), findsOneWidget);
    expect(find.text('Shop Fees'), findsWidgets);
    // Grand total = parts 200 + fee 20 = 220.00.
    expect(find.textContaining('220.00'), findsWidgets);
  });

  testWidgets('hides Shop Fees row when none present', (tester) async {
    tester.view.physicalSize = const Size(1200, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(harness(buildDraft()));
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('Shop Fees'), findsNothing);
    expect(find.text('Electric charge'), findsNothing);
  });
}
