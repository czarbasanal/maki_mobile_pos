import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maki_mobile_pos/core/enums/enums.dart';
import 'package:maki_mobile_pos/data/repositories/sale_repository_impl.dart';
import 'package:maki_mobile_pos/domain/entities/entities.dart';

void main() {
  late FakeFirebaseFirestore fakeFirestore;
  late SaleRepositoryImpl repository;

  setUp(() {
    fakeFirestore = FakeFirebaseFirestore();
    repository = SaleRepositoryImpl(firestore: fakeFirestore);
  });

  SaleEntity saleWithLabor(DateTime when) => SaleEntity(
        id: '',
        saleNumber: '',
        items: const [
          SaleItemEntity(
            id: 'i1',
            productId: 'p1',
            sku: 'SKU-1',
            name: 'Brake Pad',
            unitPrice: 100.0,
            unitCost: 60.0,
            quantity: 2,
          ),
        ],
        laborLines: const [
          LaborLineEntity(id: 'l1', description: 'Brake bleed', fee: 150.0),
        ],
        mechanicId: 'm1',
        mechanicName: 'Juan',
        discountType: DiscountType.amount,
        paymentMethod: PaymentMethod.cash,
        amountReceived: 350.0,
        changeGiven: 0.0,
        cashierId: 'c1',
        cashierName: 'Cashier',
        createdAt: when,
      );

  test('top-line stays parts-only; labor lands in its own track', () async {
    final today = DateTime.now();
    await repository.createSale(saleWithLabor(today));

    final summary = await repository.getSalesSummary(
      startDate: today,
      endDate: today,
    );

    // Parts-only top-line: net = partsRevenue (200), NOT grandTotal (350).
    expect(summary.grossAmount, 200); // partsSubtotal
    expect(summary.netAmount, 200); // partsRevenue
    expect(summary.totalCost, 120); // 60 * 2 — labor adds no cost
    expect(summary.totalProfit, 80); // 200 - 120, parts profit only
    // Labor track.
    expect(summary.laborRevenue, 150);
    expect(summary.laborProfit, 150);
    // Cash bucket is labor-inclusive (drawer holds labor cash).
    expect(summary.byPaymentMethod[PaymentMethod.cash], 350);
    // Reconciliation identity.
    final tenderTotal =
        summary.byPaymentMethod.values.fold<double>(0, (a, b) => a + b);
    expect(tenderTotal, summary.netAmount + summary.laborRevenue);
  });

  test('labor-free sale leaves the labor track at zero', () async {
    final today = DateTime.now();
    await repository.createSale(SaleEntity(
      id: '',
      saleNumber: '',
      items: const [
        SaleItemEntity(
          id: 'i1',
          productId: 'p1',
          sku: 'SKU-1',
          name: 'Oil',
          unitPrice: 100.0,
          unitCost: 60.0,
          quantity: 1,
        ),
      ],
      discountType: DiscountType.amount,
      paymentMethod: PaymentMethod.cash,
      amountReceived: 100.0,
      changeGiven: 0.0,
      cashierId: 'c1',
      cashierName: 'Cashier',
      createdAt: today,
    ));

    final summary = await repository.getSalesSummary(
      startDate: today,
      endDate: today,
    );

    expect(summary.netAmount, 100);
    expect(summary.laborRevenue, 0);
    expect(summary.laborProfit, 0);
  });
}
