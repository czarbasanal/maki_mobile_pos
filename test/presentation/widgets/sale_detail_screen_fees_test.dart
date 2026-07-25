import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:maki_mobile_pos/core/enums/enums.dart';
import 'package:maki_mobile_pos/domain/entities/entities.dart';
import 'package:maki_mobile_pos/presentation/providers/providers.dart';
import 'package:maki_mobile_pos/presentation/mobile/screens/sales/sale_detail_screen.dart';

void main() {
  SaleEntity buildSale({List<FeeLineEntity> feeLines = const []}) => SaleEntity(
        id: 'sale-1',
        saleNumber: 'S-0001',
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
        laborLines: const [
          LaborLineEntity(id: 'l1', description: 'Engine tune-up', fee: 450.0),
        ],
        feeLines: feeLines,
        mechanicId: 'mech-1',
        mechanicName: 'Juan Dela Cruz',
        paymentMethod: PaymentMethod.cash,
        amountReceived: 700.0,
        changeGiven: 0.0,
        cashierId: 'cashier-1',
        cashierName: 'John Doe',
        status: SaleStatus.completed,
        createdAt: DateTime(2026, 5, 30, 10, 0),
      );

  Widget harness(SaleEntity sale) => ProviderScope(
        overrides: [
          saleByIdProvider('sale-1').overrideWith((ref) async => sale),
          costCodeMappingProvider
              .overrideWith((ref) async => CostCodeEntity.defaultMapping()),
          pendingVoidRequestForSaleProvider('sale-1')
              .overrideWith((ref) => Stream.value(const [])),
          currentUserProvider.overrideWith((ref) => Stream.value(null)),
        ],
        child: const MaterialApp(home: SaleDetailScreen(saleId: 'sale-1')),
      );

  Future<void> pump(WidgetTester tester, SaleEntity sale) async {
    tester.view.physicalSize = const Size(1200, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpWidget(harness(sale));
    await tester.pump(const Duration(seconds: 1));
  }

  testWidgets(
      'renders a shop-fee row between items and labor with name and amount',
      (tester) async {
    await pump(
      tester,
      buildSale(
        feeLines: const [
          FeeLineEntity(id: 'f1', name: 'Environmental Fee', amount: 50),
        ],
      ),
    );

    expect(find.text('Environmental Fee'), findsOneWidget);
    expect(find.text('Shop Fee'), findsOneWidget);
    // grandTotal = parts 200 + labor 450 + fee 50 = 700.
    expect(find.textContaining('700.00'), findsWidgets);
  });

  testWidgets(
      'Charge Item fee row shows "Charge Item — description" instead of the bare name',
      (tester) async {
    await pump(
      tester,
      buildSale(
        feeLines: const [
          FeeLineEntity(
            id: 'f1',
            name: 'Charge Item',
            amount: 100,
            description: 'Battery replacement',
          ),
        ],
      ),
    );

    expect(find.text('Charge Item — Battery replacement'), findsOneWidget);
    expect(find.text('Charge Item'), findsNothing);
  });

  testWidgets('legacy sale without fee lines renders no shop-fee row',
      (tester) async {
    await pump(tester, buildSale());

    expect(find.text('Shop Fee'), findsNothing);
  });
}
