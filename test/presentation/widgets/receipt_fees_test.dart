import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maki_mobile_pos/core/enums/enums.dart';
import 'package:maki_mobile_pos/domain/entities/entities.dart';
import 'package:maki_mobile_pos/presentation/mobile/widgets/pos/receipt_widget.dart';

SaleEntity _sale({List<FeeLineEntity> feeLines = const []}) => SaleEntity(
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
      feeLines: feeLines,
      mechanicId: 'm1',
      mechanicName: 'Juan Dela Cruz',
      discountType: DiscountType.amount,
      paymentMethod: PaymentMethod.cash,
      tenders: {PaymentMethod.cash: 550 + feeLines.fold(0.0, (s, f) => s + f.amount)},
      amountReceived: 1000,
      changeGiven: 1000 - 550 - feeLines.fold(0.0, (s, f) => s + f.amount),
      cashierId: 'c1',
      cashierName: 'Cashier',
      createdAt: DateTime(2026, 5, 30, 10, 0),
    );

void main() {
  testWidgets('receipt prints shop-fee lines after labor and a fee-inclusive total',
      (tester) async {
    tester.view.physicalSize = const Size(1200, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: ReceiptWidget(
              sale: _sale(
                feeLines: const [
                  FeeLineEntity(id: 'f1', name: 'Environmental Fee', amount: 50),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('Environmental Fee'), findsOneWidget);
    // Totals recap shows a Shop fees row alongside the fee-inclusive TOTAL.
    expect(find.text('Shop fees'), findsOneWidget);
    // TOTAL = 100 (parts) + 450 (labor) + 50 (fee) = 600.
    expect(find.text('₱600.00'), findsWidgets);
  });

  testWidgets(
      'Charge Item fee prints "Charge Item — description" instead of the bare name',
      (tester) async {
    tester.view.physicalSize = const Size(1200, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: ReceiptWidget(
              sale: _sale(
                feeLines: const [
                  FeeLineEntity(
                    id: 'f1',
                    name: 'Charge Item',
                    amount: 100,
                    description: 'Battery replacement',
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('Charge Item — Battery replacement'), findsOneWidget);
    expect(find.text('Charge Item'), findsNothing);
  });

  testWidgets('legacy sale without fee lines renders no shop-fee section',
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

    expect(find.textContaining('SHOP FEES'), findsNothing);
    expect(find.text('Environmental Fee'), findsNothing);
    expect(find.text('Shop fees'), findsNothing);
    // Grand total stays labor-inclusive only: 100 + 450 = 550.
    expect(find.text('₱550.00'), findsWidgets);
  });
}
