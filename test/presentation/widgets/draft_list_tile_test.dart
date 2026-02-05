import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maki_mobile_pos/core/enums/enums.dart';
import 'package:maki_mobile_pos/domain/entities/entities.dart';
import 'package:maki_mobile_pos/presentation/widgets/drafts/draft_list_tile.dart';

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

      await tester.tap(find.byIcon(Icons.delete_outline));
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
  });
}
