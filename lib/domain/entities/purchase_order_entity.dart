import 'package:equatable/equatable.dart';

/// Status of a purchase order.
///
/// draft ⇄ ordered → received; cancelled allowed from draft/ordered.
/// received and cancelled are terminal.
enum PurchaseOrderStatus {
  draft('Draft'),
  ordered('Ordered'),
  received('Received'),
  cancelled('Cancelled');

  final String displayName;
  const PurchaseOrderStatus(this.displayName);
}

/// A planned stock purchase, drafted from reorder suggestions or manual picks.
///
/// One supplier and one delivery per PO: receiving it creates a single linked
/// receiving draft ([receivingId]); completing that receiving marks this PO
/// received. Ordered-vs-received audit = diff of this PO's items against the
/// linked receiving's items.
class PurchaseOrderEntity extends Equatable {
  final String id;
  final String referenceNumber;
  final String? supplierId;
  final String? supplierName;
  final List<PurchaseOrderItemEntity> items;
  final double totalCost;
  final int totalQuantity;
  final PurchaseOrderStatus status;
  final String? notes;
  final DateTime createdAt;
  final String createdBy;
  final String createdByName;
  final DateTime? orderedAt;
  final DateTime? receivedAt;

  /// The receiving draft/record fulfilling this PO, once Receive was tapped.
  final String? receivingId;

  const PurchaseOrderEntity({
    required this.id,
    required this.referenceNumber,
    this.supplierId,
    this.supplierName,
    required this.items,
    required this.totalCost,
    required this.totalQuantity,
    required this.status,
    this.notes,
    required this.createdAt,
    required this.createdBy,
    required this.createdByName,
    this.orderedAt,
    this.receivedAt,
    this.receivingId,
  });

  bool get isDraft => status == PurchaseOrderStatus.draft;
  bool get canEdit => status == PurchaseOrderStatus.draft;
  bool get canReceive => status == PurchaseOrderStatus.ordered;
  bool get canCancel =>
      status == PurchaseOrderStatus.draft ||
      status == PurchaseOrderStatus.ordered;
  int get uniqueProductCount => items.length;

  PurchaseOrderEntity copyWith({
    String? id,
    String? referenceNumber,
    String? supplierId,
    String? supplierName,
    List<PurchaseOrderItemEntity>? items,
    double? totalCost,
    int? totalQuantity,
    PurchaseOrderStatus? status,
    String? notes,
    DateTime? createdAt,
    String? createdBy,
    String? createdByName,
    DateTime? orderedAt,
    DateTime? receivedAt,
    String? receivingId,
    bool clearSupplierId = false,
    bool clearSupplierName = false,
    bool clearNotes = false,
    bool clearOrderedAt = false,
    bool clearReceivedAt = false,
    bool clearReceivingId = false,
  }) {
    return PurchaseOrderEntity(
      id: id ?? this.id,
      referenceNumber: referenceNumber ?? this.referenceNumber,
      supplierId: clearSupplierId ? null : (supplierId ?? this.supplierId),
      supplierName:
          clearSupplierName ? null : (supplierName ?? this.supplierName),
      items: items ?? this.items,
      totalCost: totalCost ?? this.totalCost,
      totalQuantity: totalQuantity ?? this.totalQuantity,
      status: status ?? this.status,
      notes: clearNotes ? null : (notes ?? this.notes),
      createdAt: createdAt ?? this.createdAt,
      createdBy: createdBy ?? this.createdBy,
      createdByName: createdByName ?? this.createdByName,
      orderedAt: clearOrderedAt ? null : (orderedAt ?? this.orderedAt),
      receivedAt: clearReceivedAt ? null : (receivedAt ?? this.receivedAt),
      receivingId: clearReceivingId ? null : (receivingId ?? this.receivingId),
    );
  }

  /// Recalculates totals from items.
  PurchaseOrderEntity recalculateTotals() {
    return copyWith(
        totalCost: items.totalCost, totalQuantity: items.totalQuantity);
  }

  @override
  List<Object?> get props => [
        id,
        referenceNumber,
        supplierId,
        supplierName,
        items,
        totalCost,
        totalQuantity,
        status,
        notes,
        createdAt,
        createdBy,
        createdByName,
        orderedAt,
        receivedAt,
        receivingId,
      ];
}

/// A line on a purchase order. Always references an existing product
/// (suggestions and search-to-add both pick from inventory).
class PurchaseOrderItemEntity extends Equatable {
  final String id;
  final String productId;
  final String sku;
  final String name;

  /// Quantity ordered.
  final int quantity;
  final String unit;

  /// Expected cost, prefilled from the product; the real cost is set on the
  /// receiving at delivery time.
  final double unitCost;
  final String costCode;

  const PurchaseOrderItemEntity({
    required this.id,
    required this.productId,
    required this.sku,
    required this.name,
    required this.quantity,
    required this.unit,
    required this.unitCost,
    required this.costCode,
  });

  double get totalCost => unitCost * quantity;

  PurchaseOrderItemEntity copyWith({
    String? id,
    String? productId,
    String? sku,
    String? name,
    int? quantity,
    String? unit,
    double? unitCost,
    String? costCode,
  }) {
    return PurchaseOrderItemEntity(
      id: id ?? this.id,
      productId: productId ?? this.productId,
      sku: sku ?? this.sku,
      name: name ?? this.name,
      quantity: quantity ?? this.quantity,
      unit: unit ?? this.unit,
      unitCost: unitCost ?? this.unitCost,
      costCode: costCode ?? this.costCode,
    );
  }

  @override
  List<Object?> get props =>
      [id, productId, sku, name, quantity, unit, unitCost, costCode];
}

/// The one summation rule for PO item lists — used by [recalculateTotals]
/// and every UI surface that previews totals (detail footer, staged edits),
/// so persisted and displayed totals can never drift apart.
extension PurchaseOrderItemsTotals on List<PurchaseOrderItemEntity> {
  int get totalQuantity => fold(0, (sum, item) => sum + item.quantity);
  double get totalCost => fold(0.0, (sum, item) => sum + item.totalCost);
}
