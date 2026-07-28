import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maki_mobile_pos/core/enums/enums.dart';
import 'package:maki_mobile_pos/domain/entities/entities.dart';
import 'package:maki_mobile_pos/presentation/mobile/widgets/job_orders/job_order_list_tile.dart';

void main() {
  final testJobOrder = JobOrderEntity(
    id: 'jobOrder-1',
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

  group('JobOrderListTile', () {
    testWidgets('displays jobOrder information correctly', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: JobOrderListTile(
              jobOrder: testJobOrder,
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

    testWidgets('calls onLoadTap when Open button is pressed', (tester) async {
      bool loadTapped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: JobOrderListTile(
              jobOrder: testJobOrder,
              onTap: () {},
              onLoadTap: () => loadTapped = true,
              onDeleteTap: () {},
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pump();

      expect(loadTapped, true);
    });

    testWidgets('calls onDeleteTap when delete icon is pressed',
        (tester) async {
      bool deleteTapped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: JobOrderListTile(
              jobOrder: testJobOrder,
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
            body: JobOrderListTile(
              jobOrder: testJobOrder,
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

    testWidgets('shows Service job badge when jobOrder has labor lines',
        (tester) async {
      final serviceJobOrder = JobOrderEntity(
        id: 'jobOrder-2',
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
            body: JobOrderListTile(
              jobOrder: serviceJobOrder,
              onTap: () {},
              onLoadTap: () {},
              onDeleteTap: () {},
            ),
          ),
        ),
      );

      expect(find.text('Service job'), findsOneWidget);
    });

    testWidgets('hides Service job badge when jobOrder has no labor lines',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: JobOrderListTile(
              jobOrder: testJobOrder,
              onTap: () {},
              onLoadTap: () {},
              onDeleteTap: () {},
            ),
          ),
        ),
      );

      expect(find.text('Service job'), findsNothing);
    });

    testWidgets('shows a model chip when the jobOrder has a motorcycle model',
        (tester) async {
      final modelJobOrder = JobOrderEntity(
        id: 'jobOrder-3',
        name: 'Juan / ABC-123',
        items: testJobOrder.items,
        motorcycleModel: 'Nmax',
        discountType: DiscountType.amount,
        createdBy: 'user-1',
        createdByName: 'John Doe',
        createdAt: DateTime(2025, 2, 5, 10, 30),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: JobOrderListTile(
              jobOrder: modelJobOrder,
              onTap: () {},
              onLoadTap: () {},
              onDeleteTap: () {},
            ),
          ),
        ),
      );

      expect(find.text('Nmax'), findsOneWidget);
      expect(find.byIcon(LucideIcons.bike), findsOneWidget);
    });

    testWidgets(
        'hides the model chip when the jobOrder has no motorcycle model',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: JobOrderListTile(
              jobOrder: testJobOrder,
              onTap: () {},
              onLoadTap: () {},
              onDeleteTap: () {},
            ),
          ),
        ),
      );

      expect(find.byIcon(LucideIcons.bike), findsNothing);
    });

    testWidgets('JO number renders in RobotoMono', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: JobOrderListTile(
              jobOrder: testJobOrder,
              onTap: () {},
              onLoadTap: () {},
              onDeleteTap: () {},
            ),
          ),
        ),
      );

      final nameText = tester.widget<Text>(find.text('Table 5'));
      expect(nameText.style?.fontFamily, 'RobotoMono');
    });

    testWidgets('preview lines show the discounted net amount', (tester) async {
      // 2 × 100 gross = 200, minus 50 discount → line shows 150 so the
      // preview sums to the tile's (net) total.
      final discounted = JobOrderEntity(
        id: 'jobOrder-d',
        name: 'Discounted',
        items: const [
          SaleItemEntity(
            id: 'item-1',
            productId: 'prod-1',
            sku: 'SKU-001',
            name: 'Brake Pad',
            unitPrice: 100.0,
            unitCost: 60.0,
            quantity: 2,
            discountValue: 50.0,
          ),
        ],
        discountType: DiscountType.amount,
        createdBy: 'user-1',
        createdByName: 'John Doe',
        createdAt: DateTime(2025, 2, 5, 10, 30),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: JobOrderListTile(
              jobOrder: discounted,
              onTap: () {},
              onLoadTap: () {},
              onDeleteTap: () {},
            ),
          ),
        ),
      );

      expect(find.text('₱150.00'), findsWidgets); // line + total agree
      expect(find.text('₱200.00'), findsNothing);
    });

    testWidgets('displays labor-inclusive grandTotal in header total',
        (tester) async {
      // parts: 500 × 2 = 1000; labor: 450 → grandTotal = 1450
      final laborJobOrder = JobOrderEntity(
        id: 'jobOrder-labor',
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
      expect(laborJobOrder.grandTotal, 1450.0);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: JobOrderListTile(
              jobOrder: laborJobOrder,
              onTap: () {},
              onLoadTap: () {},
              onDeleteTap: () {},
            ),
          ),
        ),
      );

      // The tile renders job order.grandTotal via .toCurrency() (grouped thousands).
      expect(find.text('₱1,450.00'), findsOneWidget);
    });
  });
}
