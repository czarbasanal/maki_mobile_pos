import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:maki_mobile_pos/core/enums/enums.dart';
import 'package:maki_mobile_pos/domain/entities/entities.dart';
import 'package:maki_mobile_pos/presentation/providers/providers.dart';
import 'package:maki_mobile_pos/presentation/mobile/screens/sales/sale_detail_screen.dart';
import 'package:maki_mobile_pos/presentation/mobile/widgets/inventory/cost_code_pill.dart';

void main() {
  SaleEntity buildSale({double discountValue = 0}) => SaleEntity(
        id: 'sale-1',
        saleNumber: 'S-0001',
        items: [
          SaleItemEntity(
            id: 'item-1',
            productId: 'prod-1',
            sku: 'SKU-001',
            name: 'Brake Pad',
            unitPrice: 100.0,
            unitCost: 60.0,
            quantity: 2,
            discountValue: discountValue,
          ),
        ],
        paymentMethod: PaymentMethod.cash,
        amountReceived: 200.0,
        changeGiven: 0.0,
        cashierId: 'cashier-1',
        cashierName: 'John Doe',
        status: SaleStatus.completed,
        createdAt: DateTime(2026, 7, 23, 10, 0),
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

  Finder struckThroughText() => find.byWidgetPredicate(
        (w) =>
            w is Text &&
            w.style?.decoration == TextDecoration.lineThrough &&
            (w.data ?? '').contains('200.00'),
      );

  testWidgets('item card shows the POS cost-code pill, not the Code text',
      (tester) async {
    await pump(tester, buildSale());
    expect(find.byType(CostCodePill), findsOneWidget);
    expect(find.textContaining('Code:'), findsNothing);
  });

  testWidgets(
      'discounted item shows the original line total struck through '
      'below the final amount', (tester) async {
    await pump(tester, buildSale(discountValue: 20));
    // Net: 100×2 − 20 = 180; original 200 struck through beneath it.
    expect(find.textContaining('180.00'), findsWidgets);
    expect(struckThroughText(), findsOneWidget);
  });

  testWidgets('undiscounted item shows no struck-through price',
      (tester) async {
    await pump(tester, buildSale());
    expect(struckThroughText(), findsNothing);
  });
}
