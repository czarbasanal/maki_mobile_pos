import 'package:equatable/equatable.dart';

/// Represents a stock receiving record.
///
/// Tracks when stock was received, from which supplier,
/// and what items were included.
class ReceivingEntity extends Equatable {
  /// Unique identifier
  final String id;

  /// Reference number for this receiving
  final String referenceNumber;

  /// Supplier ID (optional - could be direct purchase)
  final String? supplierId;

  /// Supplier name (denormalized)
  final String? supplierName;

  /// Items received
  final List<ReceivingItemEntity> items;

  /// Total cost of all items received
  final double totalCost;

  /// Total quantity of all items
  final int totalQuantity;

  /// Status of the receiving
  final ReceivingStatus status;

  /// Notes about this receiving
  final String? notes;

  /// When receiving was created
  final DateTime createdAt;

  /// When receiving was completed
  final DateTime? completedAt;

  /// Who created this receiving
  final String createdBy;

  /// Creator's display name
  final String createdByName;

  /// Who completed this receiving
  final String? completedBy;

  const ReceivingEntity({
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
    this.completedAt,
    required this.createdBy,
    required this.createdByName,
    this.completedBy,
  });

  /// Number of unique products in this receiving
  int get uniqueProductCount => items.length;

  /// Whether this receiving is complete
  bool get isComplete => status == ReceivingStatus.completed;

  /// Whether this receiving is still a draft
  bool get isDraft => status == ReceivingStatus.draft;

  ReceivingEntity copyWith({
    String? id,
    String? referenceNumber,
    String? supplierId,
    String? supplierName,
    List<ReceivingItemEntity>? items,
    double? totalCost,
    int? totalQuantity,
    ReceivingStatus? status,
    String? notes,
    DateTime? createdAt,
    DateTime? completedAt,
    String? createdBy,
    String? createdByName,
    String? completedBy,
    bool clearSupplierId = false,
    bool clearSupplierName = false,
    bool clearNotes = false,
    bool clearCompletedAt = false,
    bool clearCompletedBy = false,
  }) {
    return ReceivingEntity(
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
      completedAt: clearCompletedAt ? null : (completedAt ?? this.completedAt),
      createdBy: createdBy ?? this.createdBy,
      createdByName: createdByName ?? this.createdByName,
      completedBy: clearCompletedBy ? null : (completedBy ?? this.completedBy),
    );
  }

  /// Recalculates totals from items.
  ReceivingEntity recalculateTotals() {
    double cost = 0;
    int qty = 0;
    for (final item in items) {
      cost += item.totalCost;
      qty += item.quantity;
    }
    return copyWith(totalCost: cost, totalQuantity: qty);
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
        completedAt,
        createdBy,
        createdByName,
        completedBy,
      ];
}

/// Represents an item in a receiving record.
class ReceivingItemEntity extends Equatable {
  /// Unique identifier for this line item
  final String id;

  /// Product ID (null if new product)
  final String? productId;

  /// SKU
  final String sku;

  /// Product name
  final String name;

  /// Quantity received
  final int quantity;

  /// Unit of measurement
  final String unit;

  /// Cost per unit
  final double unitCost;

  /// Encoded cost code
  final String costCode;

  /// Whether this created a new SKU variation
  final bool isNewVariation;

  /// The new product ID if a variation was created
  final String? newProductId;

  /// Notes for this item
  final String? notes;

  const ReceivingItemEntity({
    required this.id,
    this.productId,
    required this.sku,
    required this.name,
    required this.quantity,
    required this.unit,
    required this.unitCost,
    required this.costCode,
    this.isNewVariation = false,
    this.newProductId,
    this.notes,
  });

  /// Total cost for this line item
  double get totalCost => unitCost * quantity;

  /// Whether this is a new product (not existing)
  bool get isNewProduct => productId == null && !isNewVariation;

  ReceivingItemEntity copyWith({
    String? id,
    String? productId,
    String? sku,
    String? name,
    int? quantity,
    String? unit,
    double? unitCost,
    String? costCode,
    bool? isNewVariation,
    String? newProductId,
    String? notes,
    bool clearProductId = false,
    bool clearNewProductId = false,
    bool clearNotes = false,
  }) {
    return ReceivingItemEntity(
      id: id ?? this.id,
      productId: clearProductId ? null : (productId ?? this.productId),
      sku: sku ?? this.sku,
      name: name ?? this.name,
      quantity: quantity ?? this.quantity,
      unit: unit ?? this.unit,
      unitCost: unitCost ?? this.unitCost,
      costCode: costCode ?? this.costCode,
      isNewVariation: isNewVariation ?? this.isNewVariation,
      newProductId:
          clearNewProductId ? null : (newProductId ?? this.newProductId),
      notes: clearNotes ? null : (notes ?? this.notes),
    );
  }

  @override
  List<Object?> get props => [
        id,
        productId,
        sku,
        name,
        quantity,
        unit,
        unitCost,
        costCode,
        isNewVariation,
        newProductId,
        notes,
      ];
}

/// Status of a receiving record.
enum ReceivingStatus {
  draft('Draft'),
  completed('Completed'),
  cancelled('Cancelled');

  final String displayName;
  const ReceivingStatus(this.displayName);
}
