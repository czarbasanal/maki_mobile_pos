import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maki_mobile_pos/data/models/void_request_model.dart';
import 'package:maki_mobile_pos/domain/entities/entities.dart';

void main() {
  VoidRequestEntity entity({String? itemsSummary}) => VoidRequestEntity(
        id: '',
        saleId: 's-1',
        saleNumber: 'SALE-0042',
        saleGrandTotal: 550.0,
        requestedBy: 'u-cashier',
        requestedByName: 'cashier user',
        requestedByRole: 'cashier',
        reason: 'wrong item rung up',
        createdAt: DateTime(2026, 7, 25),
        itemsSummary: itemsSummary,
      );

  group('VoidRequestModel.toCreateMap', () {
    test('includes itemsSummary when non-null', () {
      final map =
          VoidRequestModel.toCreateMap(entity(itemsSummary: '2× Brake Shoe, 1× Bulb'));
      expect(map['itemsSummary'], '2× Brake Shoe, 1× Bulb');
    });

    test('omits itemsSummary when null', () {
      final map = VoidRequestModel.toCreateMap(entity());
      expect(map.containsKey('itemsSummary'), isFalse);
    });
  });

  group('VoidRequestModel.fromFirestore', () {
    late FakeFirebaseFirestore fake;

    setUp(() {
      fake = FakeFirebaseFirestore();
    });

    // Written directly (not via toCreateMap) because fake_cloud_firestore
    // can't materialize FieldValue.serverTimestamp() outside a full Flutter
    // test binding; createdAt is stubbed with a concrete Timestamp instead.
    Map<String, dynamic> storedMap({String? itemsSummary}) => {
          'saleId': 's-1',
          'saleNumber': 'SALE-0042',
          'saleGrandTotal': 550.0,
          'requestedBy': 'u-cashier',
          'requestedByName': 'cashier user',
          'requestedByRole': 'cashier',
          'reason': 'wrong item rung up',
          'status': 'pending',
          'read': false,
          'createdAt': Timestamp.fromDate(DateTime(2026, 7, 25)),
          if (itemsSummary != null) 'itemsSummary': itemsSummary,
        };

    test('reads itemsSummary when present', () async {
      final docRef = await fake
          .collection('void_requests')
          .add(storedMap(itemsSummary: '2× Brake Shoe, 1× Bulb'));
      final doc = await docRef.get();

      final loaded = VoidRequestModel.fromFirestore(doc);

      expect(loaded.itemsSummary, '2× Brake Shoe, 1× Bulb');
    });

    test('defaults itemsSummary to null when absent', () async {
      final docRef = await fake.collection('void_requests').add(storedMap());
      final doc = await docRef.get();

      final loaded = VoidRequestModel.fromFirestore(doc);

      expect(loaded.itemsSummary, isNull);
    });
  });
}
