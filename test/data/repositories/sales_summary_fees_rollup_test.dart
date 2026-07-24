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

  SaleEntity saleWithFees(DateTime when) => SaleEntity(
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
        feeLines: const [
          FeeLineEntity(id: 'f1', name: 'Electric charge', amount: 50.0),
        ],
        discountType: DiscountType.amount,
        paymentMethod: PaymentMethod.cash,
        amountReceived: 250.0,
        changeGiven: 0.0,
        cashierId: 'c1',
        cashierName: 'Cashier',
        createdAt: when,
      );

  test('top-line stays parts-only; fees land in their own track', () async {
    final today = DateTime.now();
    await repository.createSale(saleWithFees(today));

    final summary = await repository.getSalesSummary(
      startDate: today,
      endDate: today,
    );

    // Parts-only top-line: net = partsRevenue (200), NOT grandTotal (250).
    expect(summary.grossAmount, 200); // partsSubtotal
    expect(summary.netAmount, 200); // partsRevenue
    expect(summary.totalCost, 120); // 60 * 2 — fees add no cost
    expect(summary.totalProfit, 80); // 200 - 120, parts profit only
    // Fees track.
    expect(summary.feesRevenue, 50);
    // Cash bucket is fees-inclusive (drawer holds fee cash).
    expect(summary.byPaymentMethod[PaymentMethod.cash], 250);
    // Reconciliation identity.
    final tenderTotal =
        summary.byPaymentMethod.values.fold<double>(0, (a, b) => a + b);
    expect(tenderTotal, summary.netAmount + summary.feesRevenue);
  });

  test('fee-free sale leaves the fees track at zero', () async {
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
    expect(summary.feesRevenue, 0);
  });
}
