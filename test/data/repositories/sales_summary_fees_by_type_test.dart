import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maki_mobile_pos/core/enums/enums.dart';
import 'package:maki_mobile_pos/data/repositories/sale_repository_impl.dart';
import 'package:maki_mobile_pos/domain/entities/entities.dart';
import 'package:maki_mobile_pos/domain/repositories/sale_repository.dart';

/// Per-fee-type breakdown for the closing document.
///
/// A closing is immutable once written (`allow update, delete: if false`), so
/// this breakdown can only ever exist on days closed AFTER it ships — every
/// existing closing stays total-only, permanently. Worth getting right once.
void main() {
  late FakeFirebaseFirestore fakeFirestore;
  late SaleRepositoryImpl repository;

  setUp(() {
    fakeFirestore = FakeFirebaseFirestore();
    repository = SaleRepositoryImpl(firestore: fakeFirestore);
  });

  SaleEntity sale(
    DateTime when, {
    List<FeeLineEntity> fees = const [],
    SaleStatus status = SaleStatus.completed,
  }) =>
      SaleEntity(
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
            quantity: 1,
          ),
        ],
        feeLines: fees,
        discountType: DiscountType.amount,
        paymentMethod: PaymentMethod.cash,
        amountReceived: 100.0,
        changeGiven: 0.0,
        cashierId: 'c1',
        cashierName: 'Cashier',
        createdAt: when,
        status: status,
      );

  Future<SalesSummary> summaryAround(DateTime day) => repository.getSalesSummary(
        startDate: day.subtract(const Duration(days: 1)),
        endDate: day.add(const Duration(days: 1)),
      );

  test('sums each fee type separately, and they reconcile with the total',
      () async {
    final today = DateTime.now();
    await repository.createSale(sale(today, fees: const [
      FeeLineEntity(id: 'f1', name: 'Electric charge', amount: 150.0),
      FeeLineEntity(id: 'f2', name: 'Air', amount: 20.0),
    ]));
    await repository.createSale(sale(today, fees: const [
      FeeLineEntity(id: 'f3', name: 'Electric charge', amount: 100.0),
    ]));

    final summary = await summaryAround(today);

    expect(summary.feesByType, {'Electric charge': 250.0, 'Air': 20.0});
    // The breakdown must add up to the total that was already being written,
    // or the zone would contradict its own result line.
    expect(
      summary.feesByType.values.fold<double>(0, (a, b) => a + b),
      summary.feesRevenue,
    );
  });

  test('a voided sale contributes nothing to the breakdown', () async {
    final today = DateTime.now();
    await repository.createSale(sale(today,
        status: SaleStatus.voided,
        fees: const [
          FeeLineEntity(id: 'f1', name: 'Electric charge', amount: 150.0),
        ]));

    expect((await summaryAround(today)).feesByType, isEmpty);
  });

  test('a fee-free day yields an empty map, not a zero row', () async {
    final today = DateTime.now();
    await repository.createSale(sale(today));

    final summary = await summaryAround(today);
    expect(summary.feesByType, isEmpty);
    expect(summary.feesRevenue, 0);
  });
}
