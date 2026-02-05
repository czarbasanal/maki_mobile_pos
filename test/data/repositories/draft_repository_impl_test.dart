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
  });
}
