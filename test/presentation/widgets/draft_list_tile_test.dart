import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maki_mobile_pos/core/enums/enums.dart';
import 'package:maki_mobile_pos/domain/entities/entities.dart';
import 'package:maki_mobile_pos/presentation/mobile/widgets/drafts/draft_list_tile.dart';

void main() {
  final testDraft = DraftEntity(
    id: 'draft-1',
    name: 'Table 5',
    items: const [
      SaleItemEntity(
        id: 'item-1',
        productId: 'prod-1',
        sku: 'SKU-001',
        name: 'Test Product 1',
        unitPrice: 100.0,
        unitCost: 60.0,
        quantity: 2,
      ),
      SaleItemEntity(
        id: 'item-2',
        productId: 'prod-2',
        sku: 'SKU-002',
        name: 'Test Product 2',
        unitPrice: 50.0,
        unitCost: 30.0,
        quantity: 3,
      ),
    ],
    discountType: DiscountType.amount,
    createdBy: 'user-1',
    createdByName: 'John Doe',
    createdAt: DateTime(2025, 2, 5, 10, 30),
  );

  group('DraftListTile', () {
    testWidgets('displays draft information correctly', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DraftListTile(
              draft: testDraft,
              onTap: () {},
              onLoadTap: () {},
              onDeleteTap: () {},
            ),
          ),
        ),
      );

      expect(find.text('Table 5'), findsOneWidget);
      expect(find.text('By John Doe'), findsOneWidget);
      expect(find.text('5 items'), findsOneWidget);
    });

    testWidgets('calls onLoadTap when Load button is pressed', (tester) async {
      bool loadTapped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DraftListTile(
              draft: testDraft,
              onTap: () {},
              onLoadTap: () => loadTapped = true,
              onDeleteTap: () {},
            ),
          ),
        ),
      );

      await tester.tap(find.text('Load'));
      await tester.pump();

      expect(loadTapped, true);
    });

    testWidgets('calls onDeleteTap when delete icon is pressed',
        (tester) async {
      bool deleteTapped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DraftListTile(
              draft: testDraft,
              onTap: () {},
              onLoadTap: () {},
              onDeleteTap: () => deleteTapped = true,
            ),
          ),
        ),
      );

      await tester.tap(find.byIcon(LucideIcons.trash2));
      await tester.pump();

      expect(deleteTapped, true);
    });

    testWidgets('shows items preview', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DraftListTile(
              draft: testDraft,
              onTap: () {},
              onLoadTap: () {},
              onDeleteTap: () {},
            ),
          ),
        ),
      );

      expect(find.text('Test Product 1'), findsOneWidget);
      expect(find.text('Test Product 2'), findsOneWidget);
    });

    testWidgets('shows Service job badge when draft has labor lines',
        (tester) async {
      final serviceDraft = DraftEntity(
        id: 'draft-2',
        name: 'Plate XYZ-789',
        items: const [
          SaleItemEntity(
            id: 'item-1',
            productId: 'prod-1',
            sku: 'SKU-001',
            name: 'Brake Pad',
            unitPrice: 100.0,
            unitCost: 60.0,
            quantity: 1,
          ),
        ],
        laborLines: const [
          LaborLineEntity(id: 'l1', description: 'Engine tune-up', fee: 450.0),
        ],
        mechanicId: 'mech-1',
        mechanicName: 'Juan Dela Cruz',
        discountType: DiscountType.amount,
        createdBy: 'user-1',
        createdByName: 'John Doe',
        createdAt: DateTime(2025, 2, 5, 10, 30),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DraftListTile(
              draft: serviceDraft,
              onTap: () {},
              onLoadTap: () {},
              onDeleteTap: () {},
            ),
          ),
        ),
      );

      expect(find.text('Service job'), findsOneWidget);
    });

    testWidgets('hides Service job badge when draft has no labor lines',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DraftListTile(
              draft: testDraft,
              onTap: () {},
              onLoadTap: () {},
              onDeleteTap: () {},
            ),
          ),
        ),
      );

      expect(find.text('Service job'), findsNothing);
    });

    testWidgets('displays labor-inclusive grandTotal in header total',
        (tester) async {
      // parts: 500 × 2 = 1000; labor: 450 → grandTotal = 1450
      final laborDraft = DraftEntity(
        id: 'draft-labor',
        name: 'Labor Job',
        items: const [
          SaleItemEntity(
            id: 'item-1',
            productId: 'prod-1',
            sku: 'SKU-001',
            name: 'Oil Filter',
            unitPrice: 500.0,
            unitCost: 300.0,
            quantity: 2,
          ),
        ],
        laborLines: const [
          LaborLineEntity(id: 'lab-1', description: 'Brake bleed', fee: 450),
        ],
        mechanicId: 'mech-1',
        mechanicName: 'Juan',
        discountType: DiscountType.amount,
        createdBy: 'user-1',
        createdByName: 'Jane Doe',
        createdAt: DateTime(2026, 5, 31, 9, 0),
      );

      // Sanity check: entity math is correct before pumping the widget
      expect(laborDraft.grandTotal, 1450.0);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DraftListTile(
              draft: laborDraft,
              onTap: () {},
              onLoadTap: () {},
              onDeleteTap: () {},
            ),
          ),
        ),
      );

      // The tile renders draft.grandTotal via .toCurrency() (grouped thousands).
      expect(find.text('₱1,450.00'), findsOneWidget);
    });
  });
}
