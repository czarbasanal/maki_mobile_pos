import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maki_mobile_pos/domain/entities/entities.dart';
import 'package:maki_mobile_pos/presentation/providers/cart_provider.dart';
import 'package:maki_mobile_pos/presentation/mobile/widgets/pos/cart_summary.dart';

const _item = SaleItemEntity(
  id: 'i1',
  productId: 'p1',
  sku: 'SKU-1',
  name: 'Spark Plug',
  unitPrice: 100,
  unitCost: 60,
  quantity: 2,
  unit: 'pcs',
);

const _labor = LaborLineEntity(id: 'l1', description: 'Tune-up', fee: 450);

Widget _host(CartState cart) => MaterialApp(
      home: Scaffold(body: SingleChildScrollView(child: CartSummary(cart: cart))),
    );

void main() {
  group('CartSummary labor row', () {
    testWidgets('hides the labor row when there are no labor lines',
        (tester) async {
      await tester.pumpWidget(_host(const CartState(items: [_item])));
      expect(find.text('Labor'), findsNothing);
      // Grand total == parts only (₱200.00); appears in both Subtotal and Total rows.
      expect(find.text('₱200.00'), findsNWidgets(2));
      expect(find.text('₱650.00'), findsNothing);
    });

    testWidgets('shows a labor subtotal row and a labor-inclusive total',
        (tester) async {
      await tester.pumpWidget(
        _host(const CartState(items: [_item], laborLines: [_labor])),
      );
      expect(find.text('Labor'), findsOneWidget);
      expect(find.text('₱450.00'), findsOneWidget); // labor subtotal
      expect(find.text('₱650.00'), findsOneWidget); // grand total (200 + 450)
    });
  });
}
