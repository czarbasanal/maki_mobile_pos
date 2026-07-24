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

const _fee = FeeLineEntity(id: 'f1', name: 'Environmental Fee', amount: 75);

Widget _host(CartState cart) => MaterialApp(
      home: Scaffold(body: SingleChildScrollView(child: CartSummary(cart: cart))),
    );

void main() {
  group('CartSummary shop fees row', () {
    testWidgets('hides the shop fees row when there are no fee lines',
        (tester) async {
      await tester.pumpWidget(_host(const CartState(items: [_item])));
      expect(find.text('Shop fees'), findsNothing);
    });

    testWidgets('shows a shop-fees row and a fee-inclusive total',
        (tester) async {
      await tester.pumpWidget(
        _host(const CartState(items: [_item], feeLines: [_fee])),
      );
      expect(find.text('Shop fees'), findsOneWidget);
      expect(find.text('₱75.00'), findsOneWidget); // fees subtotal
      expect(find.text('₱275.00'), findsOneWidget); // grand total (200 + 75)
    });
  });
}
