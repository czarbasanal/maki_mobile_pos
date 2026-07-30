import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:maki_mobile_pos/core/enums/enums.dart';
import 'package:maki_mobile_pos/domain/entities/entities.dart';
import 'package:maki_mobile_pos/presentation/providers/providers.dart';
import 'package:maki_mobile_pos/presentation/mobile/widgets/pos/receipt_widget.dart';

void main() {
  SaleEntity buildSale({
    String? optionLabel,
    int? optionPieces,
    double? optionPrice,
    int quantity = 2,
  }) =>
      SaleEntity(
        id: 'sale-1',
        saleNumber: 'S-0001',
        items: [
          SaleItemEntity(
            id: 'item-1',
            productId: 'prod-1',
            sku: 'ABC-1',
            name: 'Pulley Ball',
            unitPrice: optionPieces == null ? 120 : (optionPrice ?? 0) / optionPieces,
            unitCost: 60.0,
            quantity: quantity,
            optionId: optionLabel == null ? null : 'o2',
            optionLabel: optionLabel,
            optionPieces: optionPieces,
            optionPrice: optionPrice,
          ),
        ],
        paymentMethod: PaymentMethod.cash,
        amountReceived: 1000.0,
        changeGiven: 0.0,
        cashierId: 'cashier-1',
        cashierName: 'John Doe',
        status: SaleStatus.completed,
        createdAt: DateTime(2026, 7, 23, 10, 0),
      );

  Widget harness(SaleEntity sale) => ProviderScope(
        overrides: [
          costCodeMappingProvider
              .overrideWith((ref) async => CostCodeEntity.defaultMapping()),
        ],
        child: MaterialApp(home: Scaffold(body: ReceiptWidget(sale: sale))),
      );

  Future<void> pump(WidgetTester tester, SaleEntity sale) async {
    tester.view.physicalSize = const Size(1200, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpWidget(harness(sale));
    await tester.pump(const Duration(seconds: 1));
  }

  testWidgets('shows the option label beside the name for a single set',
      (tester) async {
    await pump(
      tester,
      buildSale(
        optionLabel: 'By 3',
        optionPieces: 3,
        optionPrice: 330,
        quantity: 3,
      ),
    );
    expect(find.textContaining('By 3'), findsWidgets);
    expect(find.textContaining('× 2'), findsNothing);
  });

  testWidgets('shows the set count and total pieces for more than one set',
      (tester) async {
    await pump(
      tester,
      buildSale(
        optionLabel: 'By 3',
        optionPieces: 3,
        optionPrice: 330,
        quantity: 6,
      ),
    );
    expect(find.textContaining('By 3 × 2'), findsOneWidget);
    expect(find.textContaining('6 pcs'), findsOneWidget);
  });

  testWidgets('a line with no option renders unchanged', (tester) async {
    await pump(tester, buildSale(quantity: 2));
    expect(find.textContaining('By'), findsNothing);
  });
}
