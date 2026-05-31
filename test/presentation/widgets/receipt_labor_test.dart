import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maki_mobile_pos/core/enums/enums.dart';
import 'package:maki_mobile_pos/domain/entities/entities.dart';
import 'package:maki_mobile_pos/presentation/mobile/widgets/pos/receipt_widget.dart';

SaleEntity _sale() => SaleEntity(
      id: 's1',
      saleNumber: 'OR-0001',
      items: const [
        SaleItemEntity(
          id: 'i1',
          productId: 'p1',
          sku: 'SKU-1',
          name: 'Spark Plug',
          unitPrice: 100,
          unitCost: 60,
          quantity: 1,
          unit: 'pcs',
        ),
      ],
      laborLines: const [
        LaborLineEntity(id: 'l1', description: 'Engine tune-up', fee: 450),
      ],
      mechanicId: 'm1',
      mechanicName: 'Juan Dela Cruz',
      discountType: DiscountType.amount,
      paymentMethod: PaymentMethod.cash,
      tenders: const {PaymentMethod.cash: 550},
      amountReceived: 1000,
      changeGiven: 450,
      cashierId: 'c1',
      cashierName: 'Cashier',
      createdAt: DateTime(2026, 5, 30, 10, 0),
    );

void main() {
  testWidgets('receipt prints labor section, subtotal and mechanic',
      (tester) async {
    tester.view.physicalSize = const Size(1200, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Scaffold(body: ReceiptWidget(sale: _sale())),
        ),
      ),
    );
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('Engine tune-up'), findsOneWidget);
    expect(find.textContaining('Mechanic'), findsWidgets);
    expect(find.textContaining('Juan Dela Cruz'), findsOneWidget);
    // Labor subtotal in totals section + labor-inclusive grand total.
    expect(find.text('₱450.00'), findsWidgets); // labor subtotal
    expect(find.text('₱550.00'), findsWidgets); // TOTAL = 100 + 450
  });
}
