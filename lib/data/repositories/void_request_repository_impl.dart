import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:maki_mobile_pos/core/constants/firestore_collections.dart';
import 'package:maki_mobile_pos/core/errors/exceptions.dart';
import 'package:maki_mobile_pos/data/models/models.dart';
import 'package:maki_mobile_pos/domain/entities/entities.dart';
import 'package:maki_mobile_pos/domain/repositories/void_request_repository.dart';

class VoidRequestRepositoryImpl implements VoidRequestRepository {
  final FirebaseFirestore _firestore;

  VoidRequestRepositoryImpl({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  CollectionReference get _ref =>
      _firestore.collection(FirestoreCollections.voidRequests);

  @override
  Future<VoidRequestEntity> createRequest(VoidRequestEntity request) async {
    try {
      final docRef = await _ref.add(VoidRequestModel.toCreateMap(request));
      final doc = await docRef.get();
      return VoidRequestModel.fromFirestore(doc);
    } on FirebaseException catch (e) {
      throw DatabaseException(
        message: 'Failed to create void request: ${e.message}',
        code: e.code,
        originalError: e,
      );
    }
  }

  @override
  Stream<List<VoidRequestEntity>> watchRequests({int limit = 50}) {
    return _ref
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .map((s) => s.docs.map(VoidRequestModel.fromFirestore).toList());
  }

  @override
  Stream<List<VoidRequestEntity>> watchPendingForSale(String saleId) {
    return _ref
        .where('saleId', isEqualTo: saleId)
        .where('status', isEqualTo: VoidRequestStatus.pending.value)
        .snapshots()
        .map((s) => s.docs.map(VoidRequestModel.fromFirestore).toList());
  }

  @override
  Future<bool> hasPendingForSale(String saleId) async {
    final snap = await _ref
        .where('saleId', isEqualTo: saleId)
        .where('status', isEqualTo: VoidRequestStatus.pending.value)
        .limit(1)
        .get();
    return snap.docs.isNotEmpty;
  }

  @override
  Future<void> resolve({
    required String requestId,
    required VoidRequestStatus status,
    required String resolvedBy,
    required String resolvedByName,
    String? rejectionReason,
  }) async {
    try {
      await _ref.doc(requestId).update({
        'status': status.value,
        'read': true,
        'resolvedBy': resolvedBy,
        'resolvedByName': resolvedByName,
        'resolvedAt': FieldValue.serverTimestamp(),
        if (rejectionReason != null) 'rejectionReason': rejectionReason,
      });
    } on FirebaseException catch (e) {
      throw DatabaseException(
        message: 'Failed to resolve void request: ${e.message}',
        code: e.code,
        originalError: e,
      );
    }
  }

  @override
  Future<void> markRead(String requestId) async {
    await _ref.doc(requestId).update({'read': true});
  }

  @override
  Future<void> markAllRead() async {
    final snap = await _ref.where('read', isEqualTo: false).get();
    if (snap.docs.isEmpty) return;
    final batch = _firestore.batch();
    for (final doc in snap.docs) {
      batch.update(doc.reference, {'read': true});
    }
    await batch.commit();
  }

  Query _pageQuery({
    VoidRequestStatus? status,
    required DateTime start,
    required DateTime end,
  }) {
    Query q = _ref
        .where('createdAt',
            isGreaterThanOrEqualTo: Timestamp.fromDate(start))
        .where('createdAt', isLessThanOrEqualTo: Timestamp.fromDate(end));
    if (status != null) q = q.where('status', isEqualTo: status.value);
    return q.orderBy('createdAt', descending: true);
  }

  @override
  Future<List<VoidRequestEntity>> getRequestsPage({
    VoidRequestStatus? status,
    required DateTime start,
    required DateTime end,
    int limit = 20,
    String? startAfterId,
  }) async {
    try {
      var q = _pageQuery(status: status, start: start, end: end);
      if (startAfterId != null) {
        final cursor = await _ref.doc(startAfterId).get();
        if (cursor.exists) q = q.startAfterDocument(cursor);
      }
      final snap = await q.limit(limit).get();
      return snap.docs.map(VoidRequestModel.fromFirestore).toList();
    } on FirebaseException catch (e) {
      throw DatabaseException(
        message: 'Failed to get void requests page: ${e.message}',
        code: e.code,
        originalError: e,
      );
    }
  }

  @override
  Future<int> countByStatus({
    required VoidRequestStatus status,
    required DateTime start,
    required DateTime end,
  }) async {
    try {
      final agg = await _pageQuery(status: status, start: start, end: end)
          .count()
          .get();
      return agg.count ?? 0;
    } on FirebaseException catch (e) {
      throw DatabaseException(
        message: 'Failed to count void requests: ${e.message}',
        code: e.code,
        originalError: e,
      );
    }
  }
}
