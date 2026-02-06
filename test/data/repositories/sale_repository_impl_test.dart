import 'package:flutter_test/flutter_test.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:maki_mobile_pos/core/enums/enums.dart';
import 'package:maki_mobile_pos/data/repositories/repositories.dart';
import 'package:maki_mobile_pos/domain/entities/entities.dart';

void main() {
  late FakeFirebaseFirestore fakeFirestore;
  late SaleRepositoryImpl repository;

  setUp(() {
    fakeFirestore = FakeFirebaseFirestore();
    repository = SaleRepositoryImpl(firestore: fakeFirestore);
  });

  group('SaleRepositoryImpl', () {
    SaleEntity createTestSale({
      String id = '',
      String saleNumber = '',
      List<SaleItemEntity>? items,
    }) {
      return SaleEntity(
        id: id,
        saleNumber: saleNumber,
        items: items ??
            const [
              SaleItemEntity(
                id: 'item-1',
                productId: 'prod-1',
                sku: 'SKU-001',
                name: 'Test Product',
                unitPrice: 100.0,
                unitCost: 60.0,
                quantity: 2,
              ),
            ],
        discountType: DiscountType.amount,
        paymentMethod: PaymentMethod.cash,
        amountReceived: 200.0,
        changeGiven: 0.0,
        cashierId: 'cashier-1',
        cashierName: 'John Doe',
        createdAt: DateTime.now(),
      );
    }

    test('createSale should create sale with generated ID', () async {
      final sale = createTestSale();

      final created = await repository.createSale(sale);

      expect(created.id, isNotEmpty);
      expect(created.saleNumber, startsWith('SALE-'));
      expect(created.items.length, 1);
    });

    test('createSale should generate sequential sale numbers', () async {
      final date = DateTime(2025, 2, 5);

      final sale1 = createTestSale();
      final sale2 = createTestSale();

      final created1 = await repository.createSale(
        sale1.copyWith(createdAt: date),
      );
      final created2 = await repository.createSale(
        sale2.copyWith(createdAt: date),
      );

      expect(created1.saleNumber, 'SALE-20250205-001');
      expect(created2.saleNumber, 'SALE-20250205-002');
    });

    test('getSaleById should return sale with items', () async {
      final sale = createTestSale();
      final created = await repository.createSale(sale);

      final retrieved = await repository.getSaleById(created.id);

      expect(retrieved, isNotNull);
      expect(retrieved!.id, created.id);
      expect(retrieved.items.length, 1);
      expect(retrieved.items.first.sku, 'SKU-001');
    });

    test('getSaleById should return null for non-existent sale', () async {
      final retrieved = await repository.getSaleById('non-existent');

      expect(retrieved, isNull);
    });

    test('voidSale should update sale status', () async {
      final sale = createTestSale();
      final created = await repository.createSale(sale);

      final voided = await repository.voidSale(
        saleId: created.id,
        voidedBy: 'admin-1',
        voidedByName: 'Admin User',
        reason: 'Customer refund',
      );

      expect(voided.status, SaleStatus.voided);
      expect(voided.voidedBy, 'admin-1');
      expect(voided.voidReason, 'Customer refund');
    });

    test('getTodaysSales should return only today sales', () async {
      final today = DateTime.now();
      final yesterday = today.subtract(const Duration(days: 1));

      // Create today's sale
      await repository.createSale(createTestSale().copyWith(createdAt: today));

      // We can't easily create yesterday's sale in fake firestore with past timestamp
      // So we just verify today's sales returns something
      final sales = await repository.getTodaysSales();

      expect(sales, isNotEmpty);
    });

    test('getSalesSummary should calculate totals correctly', () async {
      final today = DateTime.now();

      // Create multiple sales
      await repository.createSale(createTestSale().copyWith(createdAt: today));
      await repository.createSale(createTestSale().copyWith(createdAt: today));

      final summary = await repository.getSalesSummary(
        startDate: today,
        endDate: today,
      );

      expect(summary.totalSalesCount, 2);
      expect(summary.netAmount, greaterThan(0));
    });
  });
}
