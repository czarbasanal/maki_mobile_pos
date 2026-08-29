import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maki_mobile_pos/data/models/receiving_model.dart';
import 'package:maki_mobile_pos/domain/entities/receiving_entity.dart';

void main() {
  ReceivingEntity receiving({String? poId}) => ReceivingEntity(
        id: 'r1',
        referenceNumber: 'RCV-1',
        items: const [],
        totalCost: 0,
        totalQuantity: 0,
        status: ReceivingStatus.draft,
        createdAt: DateTime(2026, 7, 3),
        createdBy: 'u1',
        createdByName: 'Admin',
        purchaseOrderId: poId,
      );

  test('purchaseOrderId round-trips through the model', () {
    final map = ReceivingModel.fromEntity(receiving(poId: 'po1')).toMap();
    expect(map['purchaseOrderId'], 'po1');
    final back = ReceivingModel.fromMap(map, 'r1').toEntity();
    expect(back.purchaseOrderId, 'po1');
  });

  test('absent purchaseOrderId stays null (old docs unaffected)', () {
    final map = ReceivingModel.fromEntity(receiving()).toMap();
    final back = ReceivingModel.fromMap(map, 'r1').toEntity();
    expect(back.purchaseOrderId, isNull);
  });

  test('copyWith carries and clears the link', () {
    final linked = receiving().copyWith(purchaseOrderId: 'po1');
    expect(linked.purchaseOrderId, 'po1');
    expect(linked.copyWith(clearPurchaseOrderId: true).purchaseOrderId, isNull);
  });

  // Optimistic concurrency: the web admin refuses a save when the draft moved
  // since it was loaded (web_admin/src/domain/receiving/draftConcurrency.ts).
  // That only works if every writer moves the counter — mobile included, or a
  // phone's edit is invisible to the web client about to overwrite it.
  group('version counter', () {
    test('a create starts the counter at 0', () {
      final map =
          ReceivingModel.fromEntity(receiving()).toMap(forCreate: true);
      expect(map['version'], 0);
    });

    test('an update increments it', () {
      final map =
          ReceivingModel.fromEntity(receiving()).toMap(forUpdate: true);
      // A FieldValue, not a literal: an absolute number would need mobile to
      // have read the field first, and mobile never tracks it.
      expect(map['version'], isA<FieldValue>());
    });

    test('a plain toMap does not touch it', () {
      expect(
        ReceivingModel.fromEntity(receiving()).toMap().containsKey('version'),
        isFalse,
      );
    });
  });
}
