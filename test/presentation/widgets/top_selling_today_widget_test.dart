import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maki_mobile_pos/core/enums/enums.dart';
import 'package:maki_mobile_pos/domain/entities/entities.dart';
import 'package:maki_mobile_pos/presentation/providers/sale_provider.dart';
import 'package:maki_mobile_pos/presentation/shared/widgets/dashboard/top_selling_today_widget.dart';

SaleEntity _saleWithItems(List<SaleItemEntity> items) {
  return SaleEntity(
    id: 's',
    saleNumber: 'S',
    items: items,
    paymentMethod: PaymentMethod.cash,
    amountReceived: 0,
    changeGiven: 0,
    cashierId: 'u',
    cashierName: 'Cashier',
    createdAt: DateTime(2026, 5, 4, 10),
  );
}

SaleItemEntity _item({
  required String productId,
  required String name,
  required int quantity,
  double unitPrice = 100,
}) {
  return SaleItemEntity(
    id: '$productId-line',
    productId: productId,
    sku: 'SKU-$productId',
    name: name,
    quantity: quantity,
    unitPrice: unitPrice,
    unitCost: 60,
  );
}

/// Build a `todaysSalesProvider` override that emits a single sale with
/// [count] distinct products, each at descending quantity (10, 9, 8, ...).
List<SaleEntity> _salesWithProducts(int count) {
  return [
    _saleWithItems([
      for (var i = 0; i < count; i++)
        _item(
          productId: 'p${i + 1}',
          name: 'Item ${i + 1}',
          quantity: count - i,
        ),
    ]),
  ];
}

Future<void> _pump(WidgetTester tester, List<SaleEntity> sales) {
  return tester.pumpWidget(
    ProviderScope(
      overrides: [
        todaysSalesProvider.overrideWith((ref) => Stream.value(sales)),
      ],
      child: const MaterialApp(
        home: Scaffold(
          body: TopSellingTodayWidget(),
        ),
      ),
    ),
  );
}

void main() {
  group('TopSellingTodayWidget', () {
    testWidgets('shows the empty state when no sales today', (tester) async {
      await _pump(tester, const []);
      await tester.pumpAndSettle();

      expect(find.text('No products sold yet today'), findsOneWidget);
      expect(find.text('See more'), findsNothing);
    });

    testWidgets('shows top 5 by default and hides See more when ≤5 products',
        (tester) async {
      await _pump(tester, _salesWithProducts(3));
      await tester.pumpAndSettle();

      expect(find.text('Item 1'), findsOneWidget);
      expect(find.text('Item 2'), findsOneWidget);
      expect(find.text('Item 3'), findsOneWidget);
      // Nothing to expand to.
      expect(find.text('See more'), findsNothing);
      expect(find.text('See less'), findsNothing);
    });

    testWidgets('shows See more when there are more than 5 products',
        (tester) async {
      await _pump(tester, _salesWithProducts(8));
      await tester.pumpAndSettle();

      // Top 5 visible.
      for (var i = 1; i <= 5; i++) {
        expect(find.text('Item $i'), findsOneWidget);
      }
      // 6–8 hidden until expanded.
      expect(find.text('Item 6'), findsNothing);
      expect(find.text('Item 7'), findsNothing);
      expect(find.text('Item 8'), findsNothing);

      expect(find.text('See more'), findsOneWidget);
    });

    testWidgets('See more reveals ranks 6–10 inline; See less collapses back',
        (tester) async {
      await _pump(tester, _salesWithProducts(10));
      await tester.pumpAndSettle();

      // Tap See more.
      await tester.tap(find.text('See more'));
      await tester.pumpAndSettle();

      // All 10 visible now.
      for (var i = 1; i <= 10; i++) {
        expect(find.text('Item $i'), findsOneWidget);
      }
      expect(find.text('See less'), findsOneWidget);

      // Tap See less.
      await tester.tap(find.text('See less'));
      await tester.pumpAndSettle();

      // Back to top 5.
      for (var i = 1; i <= 5; i++) {
        expect(find.text('Item $i'), findsOneWidget);
      }
      expect(find.text('Item 6'), findsNothing);
      expect(find.text('See more'), findsOneWidget);
    });

    testWidgets('caps at expandedLimit even if more products exist',
        (tester) async {
      // 12 products — only 10 should ever render.
      await _pump(tester, _salesWithProducts(12));
      await tester.pumpAndSettle();

      await tester.tap(find.text('See more'));
      await tester.pumpAndSettle();

      expect(find.text('Item 10'), findsOneWidget);
      expect(find.text('Item 11'), findsNothing);
      expect(find.text('Item 12'), findsNothing);
    });

    testWidgets('rank numbers and qty-sold render correctly',
        (tester) async {
      await _pump(tester, _salesWithProducts(2));
      await tester.pumpAndSettle();

      // First product had quantity 2, second had quantity 1.
      expect(find.text('1'), findsOneWidget); // rank
      expect(find.text('2'), findsOneWidget); // rank
      expect(find.text('2 sold'), findsOneWidget);
      expect(find.text('1 sold'), findsOneWidget);
    });
  });
}
