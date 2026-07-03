import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:maki_mobile_pos/core/constants/firestore_collections.dart';
import 'package:maki_mobile_pos/core/errors/exceptions.dart';
import 'package:maki_mobile_pos/data/models/purchase_order_model.dart';
import 'package:maki_mobile_pos/domain/entities/entities.dart';
import 'package:maki_mobile_pos/domain/repositories/purchase_order_repository.dart';

/// Firestore implementation of [PurchaseOrderRepository].
class PurchaseOrderRepositoryImpl implements PurchaseOrderRepository {
  final FirebaseFirestore _firestore;

  PurchaseOrderRepositoryImpl({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _ordersRef =>
      _firestore.collection(FirestoreCollections.purchaseOrders);

  @override
  Future<PurchaseOrderEntity> createPurchaseOrder(PurchaseOrderEntity po) async {
    try {
      final model = PurchaseOrderModel.fromEntity(po);
      final docRef = await _ordersRef.add(model.toMap(forCreate: true));
      return po.copyWith(id: docRef.id);
    } on FirebaseException catch (e) {
      throw DatabaseException(
        message: 'Failed to create purchase order: ${e.message}',
        code: e.code,
        originalError: e,
      );
    }
  }

  @override
  Future<PurchaseOrderEntity?> getPurchaseOrderById(String id) async {
    try {
      final doc = await _ordersRef.doc(id).get();
      if (!doc.exists) return null;
      return PurchaseOrderModel.fromFirestore(doc).toEntity();
    } on FirebaseException catch (e) {
      throw DatabaseException(
        message: 'Failed to get purchase order: ${e.message}',
        code: e.code,
        originalError: e,
      );
    }
  }

  @override
  Stream<PurchaseOrderEntity?> watchPurchaseOrderById(String id) {
    return _ordersRef.doc(id).snapshots().map((doc) =>
        doc.exists ? PurchaseOrderModel.fromFirestore(doc).toEntity() : null);
  }

  @override
  Stream<List<PurchaseOrderEntity>> watchPurchaseOrders({int limit = 100}) {
    return _ordersRef
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => PurchaseOrderModel.fromFirestore(doc).toEntity())
            .toList());
  }

  @override
  Future<PurchaseOrderEntity> updatePurchaseOrder(PurchaseOrderEntity po) async {
    try {
      final current = await getPurchaseOrderById(po.id);
      if (current == null) {
        throw const DatabaseException(message: 'Purchase order not found');
      }
      if (current.status != PurchaseOrderStatus.draft) {
        throw const DatabaseException(
            message: 'Only draft purchase orders can be edited');
      }
      final model = PurchaseOrderModel.fromEntity(po);
      await _ordersRef.doc(po.id).update(model.toMap());
      final updated = await getPurchaseOrderById(po.id);
      if (updated == null) {
        throw const DatabaseException(
            message: 'Purchase order not found after update');
      }
      return updated;
    } on FirebaseException catch (e) {
      throw DatabaseException(
        message: 'Failed to update purchase order: ${e.message}',
        code: e.code,
        originalError: e,
      );
    }
  }

  @override
  Future<String> generateReferenceNumber() async {
    final now = DateTime.now();
    final dateStr =
        '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}';

    // Same approach as receivings: count today's docs with a plain range
    // query (aggregation queries need an index and have bitten us before).
    final startOfDay = DateTime(now.year, now.month, now.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));

    final snapshot = await _ordersRef
        .where('createdAt',
            isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
        .where('createdAt', isLessThan: Timestamp.fromDate(endOfDay))
        .get();

    final sequence = snapshot.size + 1;
    return 'PO-$dateStr-${sequence.toString().padLeft(3, '0')}';
  }

  // Implemented in Task 4.
  @override
  Future<void> markOrdered(String id) => throw UnimplementedError();
  @override
  Future<void> revertToDraft(String id) => throw UnimplementedError();
  @override
  Future<void> cancelPurchaseOrder(String id) => throw UnimplementedError();
  @override
  Future<void> deletePurchaseOrder(String id) => throw UnimplementedError();

  // Implemented in Task 7.
  @override
  Future<String> startReceiving({
    required String purchaseOrderId,
    required String receivingReferenceNumber,
    required String createdBy,
    required String createdByName,
  }) =>
      throw UnimplementedError();
}
