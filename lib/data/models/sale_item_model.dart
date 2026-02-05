import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:maki_mobile_pos/domain/entities/entities.dart';

/// Data model for SaleItem with Firestore serialization.
///
/// This model handles:
/// - JSON/Map serialization for Firestore
/// - Conversion to/from domain entity
/// - Creation from ProductEntity (for adding to cart)
class SaleItemModel {
  final String id;
  final String productId;
  final String sku;
  final String name;
  final double unitPrice;
  final double unitCost;
  final int quantity;
  final double discountValue;
  final String unit;

  const SaleItemModel({
    required this.id,
    required this.productId,
    required this.sku,
    required this.name,
    required this.unitPrice,
    required this.unitCost,
    required this.quantity,
    this.discountValue = 0,
    this.unit = 'pcs',
  });

  // ==================== FIRESTORE SERIALIZATION ====================

  /// Creates from a Map (Firestore data).
  factory SaleItemModel.fromMap(Map<String, dynamic> map, String documentId) {
    return SaleItemModel(
      id: documentId,
      productId: map['productId'] as String? ?? '',
      sku: map['sku'] as String? ?? '',
      name: map['name'] as String? ?? '',
      unitPrice: (map['unitPrice'] as num?)?.toDouble() ?? 0.0,
      unitCost: (map['unitCost'] as num?)?.toDouble() ?? 0.0,
      quantity: (map['quantity'] as num?)?.toInt() ?? 0,
      discountValue: (map['discountValue'] as num?)?.toDouble() ?? 0.0,
      unit: map['unit'] as String? ?? 'pcs',
    );
  }

  /// Creates from Firestore document.
  factory SaleItemModel.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    return SaleItemModel.fromMap(doc.data()!, doc.id);
  }

  /// Converts to a Map for Firestore.
  Map<String, dynamic> toMap({bool includeId = false}) {
    final map = <String, dynamic>{
      'productId': productId,
      'sku': sku,
      'name': name,
      'unitPrice': unitPrice,
      'unitCost': unitCost,
      'quantity': quantity,
      'discountValue': discountValue,
      'unit': unit,
    };

    if (includeId) {
      map['id'] = id;
    }

    return map;
  }

  // ==================== ENTITY CONVERSION ====================

  /// Converts to domain entity.
  SaleItemEntity toEntity() {
    return SaleItemEntity(
      id: id,
      productId: productId,
      sku: sku,
      name: name,
      unitPrice: unitPrice,
      unitCost: unitCost,
      quantity: quantity,
      discountValue: discountValue,
      unit: unit,
    );
  }

  /// Creates from domain entity.
  factory SaleItemModel.fromEntity(SaleItemEntity entity) {
    return SaleItemModel(
      id: entity.id,
      productId: entity.productId,
      sku: entity.sku,
      name: entity.name,
      unitPrice: entity.unitPrice,
      unitCost: entity.unitCost,
      quantity: entity.quantity,
      discountValue: entity.discountValue,
      unit: entity.unit,
    );
  }

  // ==================== FACTORY METHODS ====================

  /// Creates a SaleItemModel from a ProductEntity.
  ///
  /// Use this when adding a product to the cart.
  /// [itemId] - Unique identifier for this cart item
  /// [product] - The product being added
  /// [quantity] - Initial quantity (default: 1)
  factory SaleItemModel.fromProduct({
    required String itemId,
    required ProductEntity product,
    int quantity = 1,
  }) {
    return SaleItemModel(
      id: itemId,
      productId: product.id,
      sku: product.sku,
      name: product.name,
      unitPrice: product.price,
      unitCost: product.cost,
      quantity: quantity,
      discountValue: 0,
      unit: product.unit,
    );
  }

  /// Creates an empty item (for initial states).
  factory SaleItemModel.empty() {
    return const SaleItemModel(
      id: '',
      productId: '',
      sku: '',
      name: '',
      unitPrice: 0,
      unitCost: 0,
      quantity: 0,
    );
  }

  // ==================== COPY WITH ====================

  SaleItemModel copyWith({
    String? id,
    String? productId,
    String? sku,
    String? name,
    double? unitPrice,
    double? unitCost,
    int? quantity,
    double? discountValue,
    String? unit,
  }) {
    return SaleItemModel(
      id: id ?? this.id,
      productId: productId ?? this.productId,
      sku: sku ?? this.sku,
      name: name ?? this.name,
      unitPrice: unitPrice ?? this.unitPrice,
      unitCost: unitCost ?? this.unitCost,
      quantity: quantity ?? this.quantity,
      discountValue: discountValue ?? this.discountValue,
      unit: unit ?? this.unit,
    );
  }

  @override
  String toString() {
    return 'SaleItemModel(id: $id, sku: $sku, qty: $quantity, price: $unitPrice)';
  }
}
