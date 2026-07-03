import 'package:maki_mobile_pos/domain/entities/purchase_order_entity.dart';

/// Repository contract for purchase orders.
abstract class PurchaseOrderRepository {
  /// Creates a purchase order, returning it with its generated id.
  Future<PurchaseOrderEntity> createPurchaseOrder(PurchaseOrderEntity po);

  Future<PurchaseOrderEntity?> getPurchaseOrderById(String id);

  /// Streams a single purchase order (null once deleted / missing).
  Stream<PurchaseOrderEntity?> watchPurchaseOrderById(String id);

  /// Streams recent purchase orders, newest first.
  Stream<List<PurchaseOrderEntity>> watchPurchaseOrders({int limit = 100});

  /// Rewrites a draft purchase order. Throws for non-draft statuses.
  Future<PurchaseOrderEntity> updatePurchaseOrder(PurchaseOrderEntity po);

  /// draft → ordered (stamps orderedAt).
  Future<void> markOrdered(String id);

  /// ordered → draft (clears orderedAt).
  Future<void> revertToDraft(String id);

  /// draft/ordered → cancelled.
  Future<void> cancelPurchaseOrder(String id);

  /// Deletes the purchase order document (admin-gated in UI and rules).
  Future<void> deletePurchaseOrder(String id);

  /// Next `PO-YYYYMMDD-NNN` reference for today.
  Future<String> generateReferenceNumber();

  /// Creates a draft receiving prefilled from an ordered PO's items and links
  /// it (batch: receiving create + PO.receivingId), returning the receiving id.
  /// Idempotent: a still-draft linked receiving is returned instead of
  /// creating a second one.
  Future<String> startReceiving({
    required String purchaseOrderId,
    required String receivingReferenceNumber,
    required String createdBy,
    required String createdByName,
  });
}
