import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:maki_mobile_pos/core/constants/firestore_collections.dart';
import 'package:maki_mobile_pos/core/errors/exceptions.dart';
import 'package:maki_mobile_pos/data/models/purchase_order_model.dart';
import 'package:maki_mobile_pos/data/models/receiving_model.dart';
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

  Future<PurchaseOrderEntity> _requireStatus(
    String id,
    Set<PurchaseOrderStatus> allowed,
    String action,
  ) async {
    final po = await getPurchaseOrderById(id);
    if (po == null) {
      throw const DatabaseException(message: 'Purchase order not found');
    }
    if (!allowed.contains(po.status)) {
      throw DatabaseException(
          message: 'Cannot $action a ${po.status.displayName} purchase order');
    }
    return po;
  }

  @override
  Future<void> markOrdered(String id) async {
    try {
      await _requireStatus(id, {PurchaseOrderStatus.draft}, 'order');
      await _ordersRef.doc(id).update({
        'status': PurchaseOrderStatus.ordered.name,
        'orderedAt': FieldValue.serverTimestamp(),
      });
    } on FirebaseException catch (e) {
      throw DatabaseException(
        message: 'Failed to mark purchase order ordered: ${e.message}',
        code: e.code,
        originalError: e,
      );
    }
  }

  /// Applies [poUpdate] to the PO (or deletes it when null) and, in the same
  /// batch, cancels the linked receiving when it is still a draft — an orphan
  /// "From PO-…" draft must never stay completable after the PO leaves the
  /// ordered state.
  Future<void> _writeAndCleanupLinkedReceiving(
    PurchaseOrderEntity po,
    Map<String, dynamic>? poUpdate,
  ) async {
    final batch = _firestore.batch();
    if (poUpdate == null) {
      batch.delete(_ordersRef.doc(po.id));
    } else {
      batch.update(_ordersRef.doc(po.id), poUpdate);
    }
    if (po.receivingId != null) {
      final receivingRef = _firestore
          .collection(FirestoreCollections.receivings)
          .doc(po.receivingId!);
      final snap = await receivingRef.get();
      if (snap.exists &&
          snap.data()?['status'] == ReceivingStatus.draft.name) {
        batch.update(receivingRef, {
          'status': ReceivingStatus.cancelled.name,
          'purchaseOrderId': null,
        });
      }
    }
    await batch.commit();
  }

  @override
  Future<void> revertToDraft(String id) async {
    try {
      final po =
          await _requireStatus(id, {PurchaseOrderStatus.ordered}, 'reopen');
      await _writeAndCleanupLinkedReceiving(po, {
        'status': PurchaseOrderStatus.draft.name,
        'orderedAt': null,
        'receivingId': null,
      });
    } on FirebaseException catch (e) {
      throw DatabaseException(
        message: 'Failed to revert purchase order: ${e.message}',
        code: e.code,
        originalError: e,
      );
    }
  }

  @override
  Future<void> cancelPurchaseOrder(String id) async {
    try {
      final po = await _requireStatus(
        id,
        {PurchaseOrderStatus.draft, PurchaseOrderStatus.ordered},
        'cancel',
      );
      await _writeAndCleanupLinkedReceiving(po, {
        'status': PurchaseOrderStatus.cancelled.name,
        'receivingId': null,
      });
    } on FirebaseException catch (e) {
      throw DatabaseException(
        message: 'Failed to cancel purchase order: ${e.message}',
        code: e.code,
        originalError: e,
      );
    }
  }

  @override
  Future<void> deletePurchaseOrder(String id) async {
    try {
      final po = await getPurchaseOrderById(id);
      if (po == null) return;
      await _writeAndCleanupLinkedReceiving(po, null);
    } on FirebaseException catch (e) {
      throw DatabaseException(
        message: 'Failed to delete purchase order: ${e.message}',
        code: e.code,
        originalError: e,
      );
    }
  }

  @override
  Future<String> startReceiving({
    required String purchaseOrderId,
    required String receivingReferenceNumber,
    required String createdBy,
    required String createdByName,
  }) async {
    try {
      final po = await getPurchaseOrderById(purchaseOrderId);
      if (po == null) {
        throw const DatabaseException(message: 'Purchase order not found');
      }
      if (po.status != PurchaseOrderStatus.ordered) {
        throw const DatabaseException(
            message: 'Only ordered purchase orders can be received');
      }

      final receivingsRef =
          _firestore.collection(FirestoreCollections.receivings);

      // Idempotence: if a linked receiving is still an open draft, resume it
      // instead of creating a duplicate.
      if (po.receivingId != null) {
        final existing = await receivingsRef.doc(po.receivingId!).get();
        if (existing.exists &&
            existing.data()?['status'] == ReceivingStatus.draft.name) {
          return po.receivingId!;
        }
      }

      final receivingRef = receivingsRef.doc();
      final receiving = ReceivingEntity(
        id: receivingRef.id,
        referenceNumber: receivingReferenceNumber,
        supplierId: po.supplierId,
        supplierName: po.supplierName,
        items: po.items
            .map((i) => ReceivingItemEntity(
                  id: i.id,
                  productId: i.productId,
                  sku: i.sku,
                  name: i.name,
                  quantity: i.quantity,
                  unit: i.unit,
                  unitCost: i.unitCost,
                  costCode: i.costCode,
                ))
            .toList(),
        totalCost: po.totalCost,
        totalQuantity: po.totalQuantity,
        status: ReceivingStatus.draft,
        notes: 'From ${po.referenceNumber}',
        createdAt: DateTime.now(),
        createdBy: createdBy,
        createdByName: createdByName,
        purchaseOrderId: po.id,
      );

      final batch = _firestore.batch();
      batch.set(receivingRef,
          ReceivingModel.fromEntity(receiving).toMap(forCreate: true));
      batch.update(_ordersRef.doc(po.id), {'receivingId': receivingRef.id});
      await batch.commit();
      return receivingRef.id;
    } on FirebaseException catch (e) {
      throw DatabaseException(
        message: 'Failed to start receiving: ${e.message}',
        code: e.code,
        originalError: e,
      );
    }
  }
}
