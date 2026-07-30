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

  /// Snapshot of the selling option used for this line, if any. Kept on the
  /// line rather than looked up, so editing or deleting the option later
  /// never rewrites a past receipt.
  final String? optionId;
  final String? optionLabel;
  final int? optionPieces;

  /// Price of one whole set, as typed by the admin. [unitPrice] is this
  /// divided by [optionPieces]; this field is what the receipt shows.
  final double? optionPrice;

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
    this.optionId,
    this.optionLabel,
    this.optionPieces,
    this.optionPrice,
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
      optionId: map['optionId'] as String?,
      optionLabel: map['optionLabel'] as String?,
      optionPieces: (map['optionPieces'] as num?)?.toInt(),
      optionPrice: (map['optionPrice'] as num?)?.toDouble(),
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

    if (optionId != null) {
      map['optionId'] = optionId;
      map['optionLabel'] = optionLabel;
      map['optionPieces'] = optionPieces;
      map['optionPrice'] = optionPrice;
    }

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
      optionId: optionId,
      optionLabel: optionLabel,
      optionPieces: optionPieces,
      optionPrice: optionPrice,
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
      optionId: entity.optionId,
      optionLabel: entity.optionLabel,
      optionPieces: entity.optionPieces,
      optionPrice: entity.optionPrice,
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

  /// Creates a cart line for a product sold through a selling option.
  ///
  /// [sets] is the number of whole sets; the resulting [quantity] is in
  /// PIECES ([sets] x option pieces) so every downstream report, receipt and
  /// stock deduction keeps working unchanged.
  factory SaleItemModel.fromProductOption({
    required String itemId,
    required ProductEntity product,
    required SellingOptionEntity option,
    int sets = 1,
  }) {
    return SaleItemModel(
      id: itemId,
      productId: product.id,
      sku: product.sku,
      name: product.name,
      unitPrice: option.pricePerPiece,
      unitCost: product.cost,
      quantity: option.pieces * sets,
      discountValue: 0,
      unit: product.unit,
      optionId: option.id,
      optionLabel: option.label,
      optionPieces: option.pieces,
      optionPrice: option.price,
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
    String? optionId,
    String? optionLabel,
    int? optionPieces,
    double? optionPrice,
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
      optionId: optionId ?? this.optionId,
      optionLabel: optionLabel ?? this.optionLabel,
      optionPieces: optionPieces ?? this.optionPieces,
      optionPrice: optionPrice ?? this.optionPrice,
    );
  }

  @override
  String toString() {
    return 'SaleItemModel(id: $id, sku: $sku, qty: $quantity, price: $unitPrice)';
  }
}
