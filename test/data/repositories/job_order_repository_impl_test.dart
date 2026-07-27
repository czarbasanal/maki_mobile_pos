import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:maki_mobile_pos/core/enums/enums.dart';
import 'package:maki_mobile_pos/data/repositories/job_order_repository_impl.dart';
import 'package:maki_mobile_pos/domain/entities/entities.dart';

void main() {
  late FakeFirebaseFirestore fakeFirestore;
  late JobOrderRepositoryImpl repository;

  setUp(() {
    fakeFirestore = FakeFirebaseFirestore();
    repository = JobOrderRepositoryImpl(firestore: fakeFirestore);
  });

  group('JobOrderRepositoryImpl', () {
    JobOrderEntity createTestJobOrder({
      String id = '',
      String name = 'Test JobOrder',
      List<SaleItemEntity>? items,
    }) {
      return JobOrderEntity(
        id: id,
        name: name,
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
        createdBy: 'cashier-1',
        createdByName: 'John Doe',
        createdAt: DateTime.now(),
      );
    }

    test('createJobOrder should create jobOrder with generated ID', () async {
      final jobOrder = createTestJobOrder();

      final created = await repository.createJobOrder(jobOrder);

      expect(created.id, isNotEmpty);
      expect(created.name, 'Test JobOrder');
      expect(created.items.length, 1);
    });

    test('getJobOrderById should return jobOrder', () async {
      final jobOrder = createTestJobOrder();
      final created = await repository.createJobOrder(jobOrder);

      final retrieved = await repository.getJobOrderById(created.id);

      expect(retrieved, isNotNull);
      expect(retrieved!.id, created.id);
      expect(retrieved.name, 'Test JobOrder');
    });

    test('getActiveJobOrders should return non-converted jobOrders', () async {
      await repository.createJobOrder(createTestJobOrder(name: 'JobOrder 1'));
      await repository.createJobOrder(createTestJobOrder(name: 'JobOrder 2'));

      final jobOrders = await repository.getActiveJobOrders();

      expect(jobOrders.length, 2);
    });

    test('updateJobOrder should update jobOrder', () async {
      final jobOrder = createTestJobOrder();
      final created = await repository.createJobOrder(jobOrder);

      final updated = await repository.updateJobOrder(
        jobOrder: created.copyWith(name: 'Updated Name'),
        updatedBy: 'cashier-1',
      );

      expect(updated.name, 'Updated Name');
    });

    test('markJobOrderAsConverted should set conversion flags', () async {
      final jobOrder = createTestJobOrder();
      final created = await repository.createJobOrder(jobOrder);

      final converted = await repository.markJobOrderAsConverted(
        jobOrderId: created.id,
        saleId: 'sale-123',
      );

      expect(converted.isConverted, true);
      expect(converted.convertedToSaleId, 'sale-123');
    });

    test('deleteJobOrder should remove jobOrder', () async {
      final jobOrder = createTestJobOrder();
      final created = await repository.createJobOrder(jobOrder);

      await repository.deleteJobOrder(created.id);

      final retrieved = await repository.getJobOrderById(created.id);
      expect(retrieved, isNull);
    });

    // ==================== LABOR + MECHANIC ROUND-TRIP ====================

    JobOrderEntity createServiceJobOrder() {
      return JobOrderEntity(
        id: '',
        name: 'Service Job',
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
        createdBy: 'cashier-1',
        createdByName: 'John Doe',
        createdAt: DateTime.now(),
      );
    }

    test('createJobOrder persists labor + mechanic inline on the jobOrder doc',
        () async {
      final created = await repository.createJobOrder(createServiceJobOrder());

      final doc =
          await fakeFirestore.collection('job_orders').doc(created.id).get();
      final data = doc.data()!;
      expect((data['laborLines'] as List).length, 1);
      expect(data['mechanicId'], 'mech-1');
      expect(data['mechanicName'], 'Juan Dela Cruz');
    });

    test('getJobOrderById round-trips labor + mechanic', () async {
      final created = await repository.createJobOrder(createServiceJobOrder());

      final retrieved = await repository.getJobOrderById(created.id);

      expect(retrieved, isNotNull);
      expect(retrieved!.laborLines.length, 1);
      expect(retrieved.laborLines.first.description, 'Engine tune-up');
      expect(retrieved.laborLines.first.fee, 450.0);
      expect(retrieved.mechanicId, 'mech-1');
      expect(retrieved.mechanicName, 'Juan Dela Cruz');
      // grandTotal = 200 parts + 450 labor
      expect(retrieved.grandTotal, 650.0);
    });

    test('updateJobOrder persists changed labor + mechanic', () async {
      final created = await repository.createJobOrder(createServiceJobOrder());

      final updated = await repository.updateJobOrder(
        jobOrder: created.copyWith(
          laborLines: const [
            LaborLineEntity(
              id: 'labor-1',
              description: 'Engine tune-up',
              fee: 450.0,
            ),
            LaborLineEntity(
              id: 'labor-2',
              description: 'Brake bleed',
              fee: 200.0,
            ),
          ],
          mechanicId: 'mech-2',
          mechanicName: 'Pedro Santos',
        ),
        updatedBy: 'cashier-1',
      );

      expect(updated.laborLines.length, 2);
      expect(updated.laborSubtotal, 650.0);
      expect(updated.mechanicId, 'mech-2');
      expect(updated.mechanicName, 'Pedro Santos');
      // 200 parts + 650 labor
      expect(updated.grandTotal, 850.0);
    });

    test('legacy jobOrder doc without laborLines loads as []', () async {
      final ref = await fakeFirestore.collection('job_orders').add({
        'name': 'Legacy JobOrder',
        'items': const [
          {
            'id': 'item-1',
            'productId': 'prod-1',
            'sku': 'SKU-001',
            'name': 'Test Product',
            'unitPrice': 100.0,
            'unitCost': 60.0,
            'quantity': 2,
            'discountValue': 0.0,
            'unit': 'pcs',
          },
        ],
        'discountType': 'amount',
        'createdBy': 'cashier-1',
        'createdByName': 'John Doe',
        'isConverted': false,
        'createdAt': Timestamp.fromDate(DateTime.now()),
      });

      final retrieved = await repository.getJobOrderById(ref.id);

      expect(retrieved, isNotNull);
      expect(retrieved!.laborLines, isEmpty);
      expect(retrieved.mechanicId, isNull);
      expect(retrieved.mechanicName, isNull);
    });
  });
}
