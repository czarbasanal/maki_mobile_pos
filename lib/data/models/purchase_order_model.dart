import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:maki_mobile_pos/domain/entities/purchase_order_entity.dart';

/// Data model for PurchaseOrder with Firestore serialization.
class PurchaseOrderModel {
  final String id;
  final String referenceNumber;
  final String? supplierId;
  final String? supplierName;
  final List<PurchaseOrderItemModel> items;
  final double totalCost;
  final int totalQuantity;
  final PurchaseOrderStatus status;
  final String? notes;
  final DateTime createdAt;
  final String createdBy;
  final String createdByName;
  final DateTime? orderedAt;
  final DateTime? receivedAt;
  final String? receivingId;

  const PurchaseOrderModel({
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

  /// Creates from Firestore document.
  factory PurchaseOrderModel.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    return PurchaseOrderModel.fromMap(doc.data()!, doc.id);
  }

  /// Creates from a Map.
  factory PurchaseOrderModel.fromMap(
      Map<String, dynamic> map, String documentId) {
    final itemsList = (map['items'] as List<dynamic>?) ?? [];
    return PurchaseOrderModel(
      id: documentId,
      referenceNumber: map['referenceNumber'] as String? ?? '',
      supplierId: map['supplierId'] as String?,
      supplierName: map['supplierName'] as String?,
      items: itemsList
          .map((item) =>
              PurchaseOrderItemModel.fromMap(item as Map<String, dynamic>))
          .toList(),
      totalCost: (map['totalCost'] as num?)?.toDouble() ?? 0.0,
      totalQuantity: (map['totalQuantity'] as num?)?.toInt() ?? 0,
      status: _parseStatus(map['status'] as String?),
      notes: map['notes'] as String?,
      createdAt: _parseTimestamp(map['createdAt']) ?? DateTime.now(),
      createdBy: map['createdBy'] as String? ?? '',
      createdByName: map['createdByName'] as String? ?? '',
      orderedAt: _parseTimestamp(map['orderedAt']),
      receivedAt: _parseTimestamp(map['receivedAt']),
      receivingId: map['receivingId'] as String?,
    );
  }

  /// Converts to Firestore Map.
  Map<String, dynamic> toMap({bool forCreate = false}) {
    final map = <String, dynamic>{
      'referenceNumber': referenceNumber,
      'supplierId': supplierId,
      'supplierName': supplierName,
      'items': items.map((item) => item.toMap()).toList(),
      'totalCost': totalCost,
      'totalQuantity': totalQuantity,
      'status': status.name,
      'notes': notes,
      'createdBy': createdBy,
      'createdByName': createdByName,
      'orderedAt': orderedAt != null ? Timestamp.fromDate(orderedAt!) : null,
      'receivedAt': receivedAt != null ? Timestamp.fromDate(receivedAt!) : null,
      'receivingId': receivingId,
    };
    map['createdAt'] =
        forCreate ? FieldValue.serverTimestamp() : Timestamp.fromDate(createdAt);
    return map;
  }

  /// Converts to domain entity.
  PurchaseOrderEntity toEntity() {
    return PurchaseOrderEntity(
      id: id,
      referenceNumber: referenceNumber,
      supplierId: supplierId,
      supplierName: supplierName,
      items: items.map((item) => item.toEntity()).toList(),
      totalCost: totalCost,
      totalQuantity: totalQuantity,
      status: status,
      notes: notes,
      createdAt: createdAt,
      createdBy: createdBy,
      createdByName: createdByName,
      orderedAt: orderedAt,
      receivedAt: receivedAt,
      receivingId: receivingId,
    );
  }

  /// Creates from domain entity.
  factory PurchaseOrderModel.fromEntity(PurchaseOrderEntity entity) {
    return PurchaseOrderModel(
      id: entity.id,
      referenceNumber: entity.referenceNumber,
      supplierId: entity.supplierId,
      supplierName: entity.supplierName,
      items: entity.items
          .map((item) => PurchaseOrderItemModel.fromEntity(item))
          .toList(),
      totalCost: entity.totalCost,
      totalQuantity: entity.totalQuantity,
      status: entity.status,
      notes: entity.notes,
      createdAt: entity.createdAt,
      createdBy: entity.createdBy,
      createdByName: entity.createdByName,
      orderedAt: entity.orderedAt,
      receivedAt: entity.receivedAt,
      receivingId: entity.receivingId,
    );
  }

  static PurchaseOrderStatus _parseStatus(String? value) {
    if (value == null) return PurchaseOrderStatus.draft;
    return PurchaseOrderStatus.values.firstWhere(
      (s) => s.name == value,
      orElse: () => PurchaseOrderStatus.draft,
    );
  }

  static DateTime? _parseTimestamp(dynamic value) {
    if (value == null) return null;
    if (value is Timestamp) return value.toDate();
    if (value is String) return DateTime.tryParse(value);
    return null;
  }
}

/// Data model for PurchaseOrderItem.
class PurchaseOrderItemModel {
  final String id;
  final String productId;
  final String sku;
  final String name;
  final int quantity;
  final String unit;
  final double unitCost;
  final String costCode;

  const PurchaseOrderItemModel({
    required this.id,
    required this.productId,
    required this.sku,
    required this.name,
    required this.quantity,
    required this.unit,
    required this.unitCost,
    required this.costCode,
  });

  factory PurchaseOrderItemModel.fromMap(Map<String, dynamic> map) {
    return PurchaseOrderItemModel(
      id: map['id'] as String? ?? '',
      productId: map['productId'] as String? ?? '',
      sku: map['sku'] as String? ?? '',
      name: map['name'] as String? ?? '',
      quantity: (map['quantity'] as num?)?.toInt() ?? 0,
      unit: map['unit'] as String? ?? 'pcs',
      unitCost: (map['unitCost'] as num?)?.toDouble() ?? 0.0,
      costCode: map['costCode'] as String? ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'productId': productId,
      'sku': sku,
      'name': name,
      'quantity': quantity,
      'unit': unit,
      'unitCost': unitCost,
      'costCode': costCode,
    };
  }

  PurchaseOrderItemEntity toEntity() {
    return PurchaseOrderItemEntity(
      id: id,
      productId: productId,
      sku: sku,
      name: name,
      quantity: quantity,
      unit: unit,
      unitCost: unitCost,
      costCode: costCode,
    );
  }

  factory PurchaseOrderItemModel.fromEntity(PurchaseOrderItemEntity entity) {
    return PurchaseOrderItemModel(
      id: entity.id,
      productId: entity.productId,
      sku: entity.sku,
      name: entity.name,
      quantity: entity.quantity,
      unit: entity.unit,
      unitCost: entity.unitCost,
      costCode: entity.costCode,
    );
  }
}
