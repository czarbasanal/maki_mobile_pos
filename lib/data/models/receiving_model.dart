import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:maki_mobile_pos/domain/entities/receiving_entity.dart';

/// Data model for Receiving with Firestore serialization.
class ReceivingModel {
  final String id;
  final String referenceNumber;
  final String? supplierId;
  final String? supplierName;
  final List<ReceivingItemModel> items;
  final double totalCost;
  final int totalQuantity;
  final ReceivingStatus status;
  final String? notes;
  final DateTime createdAt;
  final DateTime? completedAt;
  final String createdBy;
  final String createdByName;
  final String? completedBy;

  const ReceivingModel({
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

  /// Creates from Firestore document.
  factory ReceivingModel.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data()!;
    return ReceivingModel.fromMap(data, doc.id);
  }

  /// Creates from a Map.
  factory ReceivingModel.fromMap(Map<String, dynamic> map, String documentId) {
    final itemsList = (map['items'] as List<dynamic>?) ?? [];

    return ReceivingModel(
      id: documentId,
      referenceNumber: map['referenceNumber'] as String? ?? '',
      supplierId: map['supplierId'] as String?,
      supplierName: map['supplierName'] as String?,
      items: itemsList
          .map((item) =>
              ReceivingItemModel.fromMap(item as Map<String, dynamic>))
          .toList(),
      totalCost: (map['totalCost'] as num?)?.toDouble() ?? 0.0,
      totalQuantity: (map['totalQuantity'] as num?)?.toInt() ?? 0,
      status: _parseStatus(map['status'] as String?),
      notes: map['notes'] as String?,
      createdAt: _parseTimestamp(map['createdAt']) ?? DateTime.now(),
      completedAt: _parseTimestamp(map['completedAt']),
      createdBy: map['createdBy'] as String? ?? '',
      createdByName: map['createdByName'] as String? ?? '',
      completedBy: map['completedBy'] as String?,
    );
  }

  /// Converts to Firestore Map.
  Map<String, dynamic> toMap({bool forCreate = false, bool forUpdate = false}) {
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
      'completedBy': completedBy,
    };

    if (forCreate) {
      map['createdAt'] = FieldValue.serverTimestamp();
    }

    if (forUpdate) {
      if (status == ReceivingStatus.completed && completedAt == null) {
        map['completedAt'] = FieldValue.serverTimestamp();
      }
    }

    if (!forCreate && !forUpdate) {
      map['createdAt'] = Timestamp.fromDate(createdAt);
      if (completedAt != null) {
        map['completedAt'] = Timestamp.fromDate(completedAt!);
      }
    }

    return map;
  }

  /// Converts to domain entity.
  ReceivingEntity toEntity() {
    return ReceivingEntity(
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
      completedAt: completedAt,
      createdBy: createdBy,
      createdByName: createdByName,
      completedBy: completedBy,
    );
  }

  /// Creates from domain entity.
  factory ReceivingModel.fromEntity(ReceivingEntity entity) {
    return ReceivingModel(
      id: entity.id,
      referenceNumber: entity.referenceNumber,
      supplierId: entity.supplierId,
      supplierName: entity.supplierName,
      items: entity.items
          .map((item) => ReceivingItemModel.fromEntity(item))
          .toList(),
      totalCost: entity.totalCost,
      totalQuantity: entity.totalQuantity,
      status: entity.status,
      notes: entity.notes,
      createdAt: entity.createdAt,
      completedAt: entity.completedAt,
      createdBy: entity.createdBy,
      createdByName: entity.createdByName,
      completedBy: entity.completedBy,
    );
  }

  static ReceivingStatus _parseStatus(String? value) {
    if (value == null) return ReceivingStatus.draft;
    return ReceivingStatus.values.firstWhere(
      (s) => s.name == value,
      orElse: () => ReceivingStatus.draft,
    );
  }

  static DateTime? _parseTimestamp(dynamic value) {
    if (value == null) return null;
    if (value is Timestamp) return value.toDate();
    if (value is String) return DateTime.tryParse(value);
    return null;
  }
}

/// Data model for ReceivingItem.
class ReceivingItemModel {
  final String id;
  final String? productId;
  final String sku;
  final String name;
  final int quantity;
  final String unit;
  final double unitCost;
  final String costCode;
  final bool isNewVariation;
  final String? newProductId;
  final String? notes;

  const ReceivingItemModel({
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

  factory ReceivingItemModel.fromMap(Map<String, dynamic> map) {
    return ReceivingItemModel(
      id: map['id'] as String? ?? '',
      productId: map['productId'] as String?,
      sku: map['sku'] as String? ?? '',
      name: map['name'] as String? ?? '',
      quantity: (map['quantity'] as num?)?.toInt() ?? 0,
      unit: map['unit'] as String? ?? 'pcs',
      unitCost: (map['unitCost'] as num?)?.toDouble() ?? 0.0,
      costCode: map['costCode'] as String? ?? '',
      isNewVariation: map['isNewVariation'] as bool? ?? false,
      newProductId: map['newProductId'] as String?,
      notes: map['notes'] as String?,
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
      'isNewVariation': isNewVariation,
      'newProductId': newProductId,
      'notes': notes,
    };
  }

  ReceivingItemEntity toEntity() {
    return ReceivingItemEntity(
      id: id,
      productId: productId,
      sku: sku,
      name: name,
      quantity: quantity,
      unit: unit,
      unitCost: unitCost,
      costCode: costCode,
      isNewVariation: isNewVariation,
      newProductId: newProductId,
      notes: notes,
    );
  }

  factory ReceivingItemModel.fromEntity(ReceivingItemEntity entity) {
    return ReceivingItemModel(
      id: entity.id,
      productId: entity.productId,
      sku: entity.sku,
      name: entity.name,
      quantity: entity.quantity,
      unit: entity.unit,
      unitCost: entity.unitCost,
      costCode: entity.costCode,
      isNewVariation: entity.isNewVariation,
      newProductId: entity.newProductId,
      notes: entity.notes,
    );
  }
}
