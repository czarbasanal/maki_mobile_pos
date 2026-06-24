import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:maki_mobile_pos/core/enums/enums.dart';
import 'package:maki_mobile_pos/domain/entities/entities.dart';
import 'package:maki_mobile_pos/presentation/providers/providers.dart';
import 'package:maki_mobile_pos/presentation/mobile/screens/sales/sale_detail_screen.dart';

void main() {
  SaleEntity buildSale() => SaleEntity(
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
        mechanicId: 'mech-1',
        mechanicName: 'Juan Dela Cruz',
        paymentMethod: PaymentMethod.cash,
        amountReceived: 650.0,
        changeGiven: 0.0,
        cashierId: 'cashier-1',
        cashierName: 'John Doe',
        status: SaleStatus.completed,
        createdAt: DateTime(2026, 5, 30, 10, 0),
      );

  Widget harness(SaleEntity sale) => ProviderScope(
        overrides: [
          // saleByIdProvider: FutureProvider.family<SaleEntity?, String>
          saleByIdProvider('sale-1').overrideWith((ref) async => sale),
          // costCodeMappingProvider: FutureProvider<CostCodeEntity>
          costCodeMappingProvider
              .overrideWith((ref) async => CostCodeEntity.defaultMapping()),
          // pendingVoidRequestForSaleProvider: StreamProvider.family<List<VoidRequestEntity>, String>
          pendingVoidRequestForSaleProvider('sale-1')
              .overrideWith((ref) => Stream.value(const [])),
          // currentUserProvider: StreamProvider<UserEntity?>
          currentUserProvider.overrideWith((ref) => Stream.value(null)),
        ],
        child: const MaterialApp(home: SaleDetailScreen(saleId: 'sale-1')),
      );

  testWidgets('renders labor line, labor subtotal, and mechanic name',
      (tester) async {
    tester.view.physicalSize = const Size(1200, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(harness(buildSale()));
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('Engine tune-up'), findsOneWidget);
    expect(find.text('Labor'), findsWidgets);
    expect(find.text('Mechanic'), findsOneWidget);
    expect(find.text('Juan Dela Cruz'), findsOneWidget);
    // Payment breakdown folds the mechanic into the labor row label.
    expect(find.textContaining('Labor · Juan Dela Cruz'), findsOneWidget);
    // grandTotal = parts 200 + labor 450 = 650.00.
    expect(find.textContaining('650.00'), findsWidgets);
  });
}
