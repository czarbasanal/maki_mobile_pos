import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maki_mobile_pos/core/errors/exceptions.dart';
import 'package:maki_mobile_pos/data/repositories/void_request_repository_impl.dart';
import 'package:maki_mobile_pos/domain/entities/entities.dart';

/// R2 — one pending void request per sale, enforced by a
/// `void_request_pending/{saleId}` claim written atomically alongside the
/// `void_requests` doc inside a transaction.
void main() {
  late FakeFirebaseFirestore fake;
  late VoidRequestRepositoryImpl repo;

  VoidRequestEntity request({String saleId = 's-1', String requestedBy = 'u-cashier'}) =>
      VoidRequestEntity(
        id: '',
        saleId: saleId,
        saleNumber: 'SALE-0042',
        saleGrandTotal: 100,
        requestedBy: requestedBy,
        requestedByName: 'cashier user',
        requestedByRole: 'cashier',
        reason: 'wrong item',
        createdAt: DateTime(2025, 1, 1),
      );

  setUp(() {
    fake = FakeFirebaseFirestore();
    repo = VoidRequestRepositoryImpl(firestore: fake);
  });

  group('createRequest', () {
    test('creates both the void_requests doc and the pending claim atomically',
        () async {
      final created = await repo.createRequest(request());

      final requestDoc =
          await fake.collection('void_requests').doc(created.id).get();
      expect(requestDoc.exists, isTrue);
      expect(requestDoc.data()!['saleId'], 's-1');

      final claimDoc =
          await fake.collection('void_request_pending').doc('s-1').get();
      expect(claimDoc.exists, isTrue);
      expect(claimDoc.data()!['requestId'], created.id);
      expect(claimDoc.data()!['requestedBy'], 'u-cashier');
      expect(claimDoc.data()!['createdAt'], isNotNull);
    });

    test('second createRequest for the same saleId throws void-already-pending',
        () async {
      await repo.createRequest(request());

      await expectLater(
        () => repo.createRequest(request()),
        throwsA(isA<DatabaseException>().having(
          (e) => e.code,
          'code',
          'void-already-pending',
        )),
      );

      // Only one void_requests doc was created for the sale.
      final snap = await fake
          .collection('void_requests')
          .where('saleId', isEqualTo: 's-1')
          .get();
      expect(snap.docs, hasLength(1));
    });

    test('a claim for a different saleId does not block creation', () async {
      await repo.createRequest(request(saleId: 's-1'));
      final created2 = await repo.createRequest(request(saleId: 's-2'));

      expect(created2.saleId, 's-2');
      final claimDoc =
          await fake.collection('void_request_pending').doc('s-2').get();
      expect(claimDoc.exists, isTrue);
    });
  });

  group('resolve', () {
    Future<String> seedClaimedRequest(String saleId) async {
      final created = await repo.createRequest(request(saleId: saleId));
      return created.id;
    }

    test('deletes the claim in the same operation as the status update',
        () async {
      final requestId = await seedClaimedRequest('s-1');

      await repo.resolve(
        requestId: requestId,
        saleId: 's-1',
        status: VoidRequestStatus.approved,
        resolvedBy: 'u-admin',
        resolvedByName: 'admin user',
      );

      final requestDoc =
          await fake.collection('void_requests').doc(requestId).get();
      expect(requestDoc.data()!['status'], 'approved');

      final claimDoc =
          await fake.collection('void_request_pending').doc('s-1').get();
      expect(claimDoc.exists, isFalse);
    });

    test('resolving a legacy request with no claim succeeds (idempotent delete)',
        () async {
      // Legacy doc created directly, bypassing the claim path entirely.
      final legacyRef = await fake.collection('void_requests').add({
        'saleId': 'legacy-sale',
        'saleNumber': 'SALE-0001',
        'saleGrandTotal': 10.0,
        'requestedBy': 'u-cashier',
        'requestedByName': 'cashier user',
        'requestedByRole': 'cashier',
        'reason': 'legacy',
        'status': 'pending',
        'read': false,
        'createdAt': Timestamp.now(),
      });

      await repo.resolve(
        requestId: legacyRef.id,
        saleId: 'legacy-sale',
        status: VoidRequestStatus.rejected,
        resolvedBy: 'u-admin',
        resolvedByName: 'admin user',
        rejectionReason: 'not authorized',
      );

      final requestDoc = await legacyRef.get();
      expect(requestDoc.data()!['status'], 'rejected');
    });

    test('after resolve, a new request can be created for the same sale',
        () async {
      final requestId = await seedClaimedRequest('s-1');
      await repo.resolve(
        requestId: requestId,
        saleId: 's-1',
        status: VoidRequestStatus.rejected,
        resolvedBy: 'u-admin',
        resolvedByName: 'admin user',
        rejectionReason: 'nope',
      );

      final created2 = await repo.createRequest(request(saleId: 's-1'));
      expect(created2.saleId, 's-1');
    });
  });
}
