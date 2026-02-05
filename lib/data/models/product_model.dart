import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:maki_mobile_pos/core/extensions/extensions.dart';
import 'package:maki_mobile_pos/domain/entities/entities.dart';

/// Data model for Product with Firestore serialization.
class ProductModel {
  final String id;
  final String sku;
  final String name;
  final String costCode;
  final double cost;
  final double price;
  final int quantity;
  final int reorderLevel;
  final String unit;
  final String? supplierId;
  final String? supplierName;
  final bool isActive;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final String? createdBy;
  final String? updatedBy;
  final List<String> searchKeywords;
  final String? baseSku;
  final int? variationNumber;
  final String? barcode;
  final String? category;
  final String? imageUrl;
  final String? notes;

  const ProductModel({
    required this.id,
    required this.sku,
    required this.name,
    required this.costCode,
    required this.cost,
    required this.price,
    required this.quantity,
    required this.reorderLevel,
    required this.unit,
    this.supplierId,
    this.supplierName,
    required this.isActive,
    required this.createdAt,
    this.updatedAt,
    this.createdBy,
    this.updatedBy,
    this.searchKeywords = const [],
    this.baseSku,
    this.variationNumber,
    this.barcode,
    this.category,
    this.imageUrl,
    this.notes,
  });

  // ==================== FIRESTORE SERIALIZATION ====================

  /// Creates from Firestore document.
  factory ProductModel.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data()!;
    return ProductModel.fromMap(data, doc.id);
  }

  /// Creates from a Map.
  factory ProductModel.fromMap(Map<String, dynamic> map, String documentId) {
    return ProductModel(
      id: documentId,
      sku: map['sku'] as String? ?? '',
      name: map['name'] as String? ?? '',
      costCode: map['costCode'] as String? ?? '',
      cost: (map['cost'] as num?)?.toDouble() ?? 0.0,
      price: (map['price'] as num?)?.toDouble() ?? 0.0,
      quantity: (map['quantity'] as num?)?.toInt() ?? 0,
      reorderLevel: (map['reorderLevel'] as num?)?.toInt() ?? 10,
      unit: map['unit'] as String? ?? 'pcs',
      supplierId: map['supplierId'] as String?,
      supplierName: map['supplierName'] as String?,
      isActive: map['isActive'] as bool? ?? true,
      createdAt: _parseTimestamp(map['createdAt']) ?? DateTime.now(),
      updatedAt: _parseTimestamp(map['updatedAt']),
      createdBy: map['createdBy'] as String?,
      updatedBy: map['updatedBy'] as String?,
      searchKeywords: _parseStringList(map['searchKeywords']),
      baseSku: map['baseSku'] as String?,
      variationNumber: (map['variationNumber'] as num?)?.toInt(),
      barcode: map['barcode'] as String?,
      category: map['category'] as String?,
      imageUrl: map['imageUrl'] as String?,
      notes: map['notes'] as String?,
    );
  }

  /// Converts to a Map for Firestore.
  Map<String, dynamic> toMap({
    bool forCreate = false,
    bool forUpdate = false,
  }) {
    final map = <String, dynamic>{
      'sku': sku,
      'name': name,
      'costCode': costCode,
      'cost': cost,
      'price': price,
      'quantity': quantity,
      'reorderLevel': reorderLevel,
      'unit': unit,
      'supplierId': supplierId,
      'supplierName': supplierName,
      'isActive': isActive,
      'searchKeywords': searchKeywords,
      'baseSku': baseSku,
      'variationNumber': variationNumber,
      'barcode': barcode,
      'category': category,
      'imageUrl': imageUrl,
      'notes': notes,
    };

    if (forCreate) {
      map['createdAt'] = FieldValue.serverTimestamp();
      map['updatedAt'] = FieldValue.serverTimestamp();
      map['createdBy'] = createdBy;
      map['updatedBy'] = createdBy;
    } else if (forUpdate) {
      map['updatedAt'] = FieldValue.serverTimestamp();
      map['updatedBy'] = updatedBy;
      // Don't include createdAt and createdBy on updates
    } else {
      if (createdAt != null) {
        map['createdAt'] = Timestamp.fromDate(createdAt);
      }
      if (updatedAt != null) {
        map['updatedAt'] = Timestamp.fromDate(updatedAt!);
      }
      map['createdBy'] = createdBy;
      map['updatedBy'] = updatedBy;
    }

    return map;
  }

  /// Converts to a Map for creating a new product.
  Map<String, dynamic> toCreateMap(String createdByUserId) {
    return copyWith(
      createdBy: createdByUserId,
      searchKeywords: _generateSearchKeywords(),
    ).toMap(forCreate: true);
  }

  /// Converts to a Map for updating a product.
  Map<String, dynamic> toUpdateMap(String updatedByUserId) {
    return copyWith(
      updatedBy: updatedByUserId,
      searchKeywords: _generateSearchKeywords(),
    ).toMap(forUpdate: true);
  }

  // ==================== ENTITY CONVERSION ====================

  /// Converts to domain entity.
  ProductEntity toEntity() {
    return ProductEntity(
      id: id,
      sku: sku,
      name: name,
      costCode: costCode,
      cost: cost,
      price: price,
      quantity: quantity,
      reorderLevel: reorderLevel,
      unit: unit,
      supplierId: supplierId,
      supplierName: supplierName,
      isActive: isActive,
      createdAt: createdAt,
      updatedAt: updatedAt,
      createdBy: createdBy,
      updatedBy: updatedBy,
      searchKeywords: searchKeywords,
      baseSku: baseSku,
      variationNumber: variationNumber,
      barcode: barcode,
      category: category,
      imageUrl: imageUrl,
      notes: notes,
    );
  }

  /// Creates from domain entity.
  factory ProductModel.fromEntity(ProductEntity entity) {
    return ProductModel(
      id: entity.id,
      sku: entity.sku,
      name: entity.name,
      costCode: entity.costCode,
      cost: entity.cost,
      price: entity.price,
      quantity: entity.quantity,
      reorderLevel: entity.reorderLevel,
      unit: entity.unit,
      supplierId: entity.supplierId,
      supplierName: entity.supplierName,
      isActive: entity.isActive,
      createdAt: entity.createdAt,
      updatedAt: entity.updatedAt,
      createdBy: entity.createdBy,
      updatedBy: entity.updatedBy,
      searchKeywords: entity.searchKeywords,
      baseSku: entity.baseSku,
      variationNumber: entity.variationNumber,
      barcode: entity.barcode,
      category: entity.category,
      imageUrl: entity.imageUrl,
      notes: entity.notes,
    );
  }

  // ==================== FACTORY METHODS ====================

  /// Creates an empty product model.
  factory ProductModel.empty() {
    return ProductModel(
      id: '',
      sku: '',
      name: '',
      costCode: '',
      cost: 0,
      price: 0,
      quantity: 0,
      reorderLevel: 10,
      unit: 'pcs',
      isActive: true,
      createdAt: DateTime.now(),
    );
  }

  /// Creates a new product with default values.
  factory ProductModel.create({
    required String sku,
    required String name,
    required String costCode,
    required double cost,
    required double price,
    int quantity = 0,
    int reorderLevel = 10,
    String unit = 'pcs',
    String? supplierId,
    String? supplierName,
    String? barcode,
    String? category,
    String? notes,
  }) {
    final model = ProductModel(
      id: '',
      sku: sku,
      name: name,
      costCode: costCode,
      cost: cost,
      price: price,
      quantity: quantity,
      reorderLevel: reorderLevel,
      unit: unit,
      supplierId: supplierId,
      supplierName: supplierName,
      isActive: true,
      createdAt: DateTime.now(),
      barcode: barcode,
      category: category,
      notes: notes,
    );

    return model.copyWith(
      searchKeywords: model._generateSearchKeywords(),
    );
  }

  /// Creates a variation of this product.
  ProductModel createVariation({
    required String newSku,
    required String newCostCode,
    required double newCost,
    required int variationNum,
  }) {
    return copyWith(
      id: '',
      sku: newSku,
      costCode: newCostCode,
      cost: newCost,
      quantity: 0,
      baseSku: baseSku ?? sku,
      variationNumber: variationNum,
      createdAt: DateTime.now(),
      updatedAt: null,
    );
  }

  // ==================== HELPER METHODS ====================

  /// Generates search keywords from name and SKU.
  List<String> _generateSearchKeywords() {
    final keywords = <String>{};

    // Add SKU keywords
    keywords.addAll(sku.toLowerCase().toSearchKeywords());

    // Add name keywords
    keywords.addAll(name.toLowerCase().toSearchKeywords());

    // Add barcode if present
    if (barcode != null && barcode!.isNotEmpty) {
      keywords.addAll(barcode!.toLowerCase().toSearchKeywords());
    }

    // Add category if present
    if (category != null && category!.isNotEmpty) {
      keywords.addAll(category!.toLowerCase().toSearchKeywords());
    }

    return keywords.toList();
  }

  /// Helper to parse Firestore timestamps.
  static DateTime? _parseTimestamp(dynamic value) {
    if (value == null) return null;
    if (value is Timestamp) return value.toDate();
    if (value is String) return DateTime.tryParse(value);
    return null;
  }

  /// Helper to parse string lists.
  static List<String> _parseStringList(dynamic value) {
    if (value == null) return [];
    if (value is List) {
      return value.map((e) => e.toString()).toList();
    }
    return [];
  }

  // ==================== COPY WITH ====================

  ProductModel copyWith({
    String? id,
    String? sku,
    String? name,
    String? costCode,
    double? cost,
    double? price,
    int? quantity,
    int? reorderLevel,
    String? unit,
    String? supplierId,
    String? supplierName,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? createdBy,
    String? updatedBy,
    List<String>? searchKeywords,
    String? baseSku,
    int? variationNumber,
    String? barcode,
    String? category,
    String? imageUrl,
    String? notes,
  }) {
    return ProductModel(
      id: id ?? this.id,
      sku: sku ?? this.sku,
      name: name ?? this.name,
      costCode: costCode ?? this.costCode,
      cost: cost ?? this.cost,
      price: price ?? this.price,
      quantity: quantity ?? this.quantity,
      reorderLevel: reorderLevel ?? this.reorderLevel,
      unit: unit ?? this.unit,
      supplierId: supplierId ?? this.supplierId,
      supplierName: supplierName ?? this.supplierName,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      createdBy: createdBy ?? this.createdBy,
      updatedBy: updatedBy ?? this.updatedBy,
      searchKeywords: searchKeywords ?? this.searchKeywords,
      baseSku: baseSku ?? this.baseSku,
      variationNumber: variationNumber ?? this.variationNumber,
      barcode: barcode ?? this.barcode,
      category: category ?? this.category,
      imageUrl: imageUrl ?? this.imageUrl,
      notes: notes ?? this.notes,
    );
  }

  @override
  String toString() {
    return 'ProductModel(id: $id, sku: $sku, name: $name, price: $price, qty: $quantity)';
  }
}
