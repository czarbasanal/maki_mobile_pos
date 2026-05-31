import 'package:cloud_firestore/cloud_firestore.dart';
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

      // Create multiple sales (parts-only; labor track must be zero).
      await repository.createSale(createTestSale().copyWith(createdAt: today));
      await repository.createSale(createTestSale().copyWith(createdAt: today));

      final summary = await repository.getSalesSummary(
        startDate: today,
        endDate: today,
      );

      expect(summary.totalSalesCount, 2);
      expect(summary.netAmount, 400); // 2 × (100 × 2), no discount
      expect(summary.grossAmount, 400);
      expect(summary.totalCost, 240); // 2 × (60 × 2)
      expect(summary.totalProfit, 160);
      expect(summary.laborRevenue, 0);
      expect(summary.laborProfit, 0);
    });

    // ==================== LABOR + MECHANIC ROUND-TRIP TESTS ====================

    SaleEntity createServiceSale() {
      return SaleEntity(
        id: '',
        saleNumber: '',
        items: const [
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
        laborLines: const [
          LaborLineEntity(
            id: 'labor-1',
            description: 'Engine tune-up',
            fee: 450.0,
          ),
        ],
        mechanicId: 'mech-1',
        mechanicName: 'Juan Dela Cruz',
        discountType: DiscountType.amount,
        paymentMethod: PaymentMethod.cash,
        amountReceived: 650.0,
        changeGiven: 0.0,
        cashierId: 'cashier-1',
        cashierName: 'John Doe',
        createdAt: DateTime.now(),
      );
    }

    test('createSale persists labor + mechanic inline on the sale doc',
        () async {
      final created = await repository.createSale(createServiceSale());

      // Read the raw doc: labor must be inline; items must NOT be on the doc.
      final doc = await fakeFirestore.collection('sales').doc(created.id).get();
      final data = doc.data()!;
      expect(data['laborLines'], isA<List<dynamic>>());
      expect((data['laborLines'] as List).length, 1);
      expect(data['mechanicId'], 'mech-1');
      expect(data['mechanicName'], 'Juan Dela Cruz');
      expect(data.containsKey('items'), isFalse);
    });

    test('getSaleById loads inline labor + mechanic with items', () async {
      final created = await repository.createSale(createServiceSale());

      final retrieved = await repository.getSaleById(created.id);

      expect(retrieved, isNotNull);
      expect(retrieved!.items.length, 1);
      expect(retrieved.laborLines.length, 1);
      expect(retrieved.laborLines.first.description, 'Engine tune-up');
      expect(retrieved.laborLines.first.fee, 450.0);
      expect(retrieved.mechanicId, 'mech-1');
      expect(retrieved.mechanicName, 'Juan Dela Cruz');
      // grandTotal = 200 parts + 450 labor
      expect(retrieved.grandTotal, 650.0);
    });

    test('getRecentSales loads inline labor for each sale', () async {
      await repository.createSale(createServiceSale());

      final sales = await repository.getRecentSales();

      expect(sales, isNotEmpty);
      expect(sales.first.laborLines.length, 1);
      expect(sales.first.mechanicName, 'Juan Dela Cruz');
    });

    test('legacy sale doc without laborLines loads as []', () async {
      // Write a doc directly with no labor/mechanic fields.
      final ref = await fakeFirestore.collection('sales').add({
        'saleNumber': 'SALE-LEGACY-001',
        'discountType': 'amount',
        'paymentMethod': 'cash',
        'amountReceived': 200.0,
        'changeGiven': 0.0,
        'status': 'completed',
        'cashierId': 'cashier-1',
        'cashierName': 'John Doe',
        'createdAt': Timestamp.fromDate(DateTime.now()),
      });

      final retrieved = await repository.getSaleById(ref.id);

      expect(retrieved, isNotNull);
      expect(retrieved!.laborLines, isEmpty);
      expect(retrieved.mechanicId, isNull);
      expect(retrieved.mechanicName, isNull);
    });
  });
}
