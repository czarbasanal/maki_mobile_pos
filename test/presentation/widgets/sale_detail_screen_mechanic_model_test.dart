import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:maki_mobile_pos/core/enums/enums.dart';
import 'package:maki_mobile_pos/domain/entities/entities.dart';
import 'package:maki_mobile_pos/presentation/providers/providers.dart';
import 'package:maki_mobile_pos/presentation/mobile/screens/sales/sale_detail_screen.dart';

void main() {
  SaleEntity buildSale({
    String? mechanicName,
    String? motorcycleModel,
  }) =>
      SaleEntity(
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
            discountValue: 0,
          ),
        ],
        paymentMethod: PaymentMethod.cash,
        amountReceived: 200.0,
        changeGiven: 0.0,
        cashierId: 'cashier-1',
        cashierName: 'John Doe',
        mechanicName: mechanicName,
        motorcycleModel: motorcycleModel,
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

  testWidgets(
      'sale header shows mechanic and motorcycle model when both present',
      (tester) async {
    await pump(
      tester,
      buildSale(mechanicName: 'Jeric', motorcycleModel: 'Rusi'),
    );
    expect(find.textContaining('Jeric · Rusi'), findsOneWidget);
  });

  testWidgets(
      'sale header shows only mechanic name when only mechanic is present',
      (tester) async {
    await pump(
      tester,
      buildSale(mechanicName: 'Jeric', motorcycleModel: null),
    );
    expect(find.textContaining('Jeric'), findsWidgets);
    expect(find.textContaining('Jeric · '), findsNothing);
  });

  testWidgets(
      'sale header shows only motorcycle model when only model is present',
      (tester) async {
    await pump(
      tester,
      buildSale(mechanicName: null, motorcycleModel: 'Rusi'),
    );
    expect(find.textContaining('Rusi'), findsWidgets);
    expect(find.textContaining('· Rusi'), findsNothing);
  });

  testWidgets('sale header shows no mechanic/model row when both are absent',
      (tester) async {
    await pump(
      tester,
      buildSale(mechanicName: null, motorcycleModel: null),
    );
    expect(find.textContaining('·'), findsNothing);
  });

  testWidgets(
      'sale header shows no mechanic/model row when both are empty strings',
      (tester) async {
    await pump(
      tester,
      buildSale(mechanicName: '', motorcycleModel: ''),
    );
    expect(find.textContaining('·'), findsNothing);
  });
}
