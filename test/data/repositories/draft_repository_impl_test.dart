import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:maki_mobile_pos/core/enums/enums.dart';
import 'package:maki_mobile_pos/data/repositories/draft_repository_impl.dart';
import 'package:maki_mobile_pos/domain/entities/entities.dart';

void main() {
  late FakeFirebaseFirestore fakeFirestore;
  late DraftRepositoryImpl repository;

  setUp(() {
    fakeFirestore = FakeFirebaseFirestore();
    repository = DraftRepositoryImpl(firestore: fakeFirestore);
  });

  group('DraftRepositoryImpl', () {
    DraftEntity createTestDraft({
      String id = '',
      String name = 'Test Draft',
      List<SaleItemEntity>? items,
    }) {
      return DraftEntity(
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

    test('createDraft should create draft with generated ID', () async {
      final draft = createTestDraft();

      final created = await repository.createDraft(draft);

      expect(created.id, isNotEmpty);
      expect(created.name, 'Test Draft');
      expect(created.items.length, 1);
    });

    test('getDraftById should return draft', () async {
      final draft = createTestDraft();
      final created = await repository.createDraft(draft);

      final retrieved = await repository.getDraftById(created.id);

      expect(retrieved, isNotNull);
      expect(retrieved!.id, created.id);
      expect(retrieved.name, 'Test Draft');
    });

    test('getActiveDrafts should return non-converted drafts', () async {
      await repository.createDraft(createTestDraft(name: 'Draft 1'));
      await repository.createDraft(createTestDraft(name: 'Draft 2'));

      final drafts = await repository.getActiveDrafts();

      expect(drafts.length, 2);
    });

    test('updateDraft should update draft', () async {
      final draft = createTestDraft();
      final created = await repository.createDraft(draft);

      final updated = await repository.updateDraft(
        draft: created.copyWith(name: 'Updated Name'),
        updatedBy: 'cashier-1',
      );

      expect(updated.name, 'Updated Name');
    });

    test('markDraftAsConverted should set conversion flags', () async {
      final draft = createTestDraft();
      final created = await repository.createDraft(draft);

      final converted = await repository.markDraftAsConverted(
        draftId: created.id,
        saleId: 'sale-123',
      );

      expect(converted.isConverted, true);
      expect(converted.convertedToSaleId, 'sale-123');
    });

    test('deleteDraft should remove draft', () async {
      final draft = createTestDraft();
      final created = await repository.createDraft(draft);

      await repository.deleteDraft(created.id);

      final retrieved = await repository.getDraftById(created.id);
      expect(retrieved, isNull);
    });

    test('draftNameExists should check for duplicates', () async {
      await repository.createDraft(createTestDraft(name: 'Unique Name'));

      final exists = await repository.draftNameExists(name: 'Unique Name');
      final notExists = await repository.draftNameExists(name: 'Other Name');

      expect(exists, true);
      expect(notExists, false);
    });

    test('getActiveDraftCount should return correct count', () async {
      await repository.createDraft(createTestDraft(name: 'Draft 1'));
      await repository.createDraft(createTestDraft(name: 'Draft 2'));

      final count = await repository.getActiveDraftCount();

      expect(count, 2);
    });

    // ==================== LABOR + MECHANIC ROUND-TRIP ====================

    DraftEntity createServiceDraft() {
      return DraftEntity(
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

    test('createDraft persists labor + mechanic inline on the draft doc',
        () async {
      final created = await repository.createDraft(createServiceDraft());

      final doc =
          await fakeFirestore.collection('drafts').doc(created.id).get();
      final data = doc.data()!;
      expect((data['laborLines'] as List).length, 1);
      expect(data['mechanicId'], 'mech-1');
      expect(data['mechanicName'], 'Juan Dela Cruz');
    });

    test('getDraftById round-trips labor + mechanic', () async {
      final created = await repository.createDraft(createServiceDraft());

      final retrieved = await repository.getDraftById(created.id);

      expect(retrieved, isNotNull);
      expect(retrieved!.laborLines.length, 1);
      expect(retrieved.laborLines.first.description, 'Engine tune-up');
      expect(retrieved.laborLines.first.fee, 450.0);
      expect(retrieved.mechanicId, 'mech-1');
      expect(retrieved.mechanicName, 'Juan Dela Cruz');
      // grandTotal = 200 parts + 450 labor
      expect(retrieved.grandTotal, 650.0);
    });

    test('updateDraft persists changed labor + mechanic', () async {
      final created = await repository.createDraft(createServiceDraft());

      final updated = await repository.updateDraft(
        draft: created.copyWith(
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

    test('legacy draft doc without laborLines loads as []', () async {
      final ref = await fakeFirestore.collection('drafts').add({
        'name': 'Legacy Draft',
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

      final retrieved = await repository.getDraftById(ref.id);

      expect(retrieved, isNotNull);
      expect(retrieved!.laborLines, isEmpty);
      expect(retrieved.mechanicId, isNull);
      expect(retrieved.mechanicName, isNull);
    });
  });
}
