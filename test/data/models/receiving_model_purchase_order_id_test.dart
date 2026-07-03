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
}
