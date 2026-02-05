import 'package:equatable/equatable.dart';
import 'package:maki_mobile_pos/domain/entities/entities.dart';

/// Represents a product in the inventory.
///
/// This is a domain entity containing all product-related
/// business logic and data.
class ProductEntity extends Equatable {
  /// Unique identifier
  final String id;

  /// Stock Keeping Unit - unique product code
  /// Can be auto-generated or manually entered
  /// Format: Code128 compatible (alphanumeric + hyphen)
  final String sku;

  /// Product name/description
  final String name;

  /// Cost code (letter representation of cost)
  /// Example: "NBF" for cost of 125
  final String costCode;

  /// Actual unit cost (hidden from non-admin users)
  final double cost;

  /// Selling price
  final double price;

  /// Current stock quantity
  final int quantity;

  /// Minimum quantity before reorder alert
  final int reorderLevel;

  /// Unit of measurement (pcs, kg, box, etc.)
  final String unit;

  /// Reference to supplier
  final String? supplierId;

  /// Supplier name (denormalized for display)
  final String? supplierName;

  /// Whether this product is active
  final bool isActive;

  /// When product was created
  final DateTime createdAt;

  /// When product was last updated
  final DateTime? updatedAt;

  /// Who created this product
  final String? createdBy;

  /// Who last updated this product
  final String? updatedBy;

  /// Search keywords for quick lookup
  final List<String> searchKeywords;

  /// Base SKU (for variations)
  /// If this is ABC-1, baseSku would be ABC
  final String? baseSku;

  /// Variation number (null if not a variation)
  final int? variationNumber;

  /// Optional barcode (if different from SKU)
  final String? barcode;

  /// Optional product category
  final String? category;

  /// Optional product image URL
  final String? imageUrl;

  /// Optional notes
  final String? notes;

  const ProductEntity({
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

  // ==================== COMPUTED PROPERTIES ====================

  /// Calculates profit per unit.
  double get profit => price - cost;

  /// Calculates profit margin percentage.
  double get profitMargin {
    if (price == 0) return 0;
    return (profit / price) * 100;
  }

  /// Calculates markup percentage (from cost).
  double get markup {
    if (cost == 0) return 0;
    return (profit / cost) * 100;
  }

  /// Total inventory value at cost.
  double get inventoryValueAtCost => cost * quantity;

  /// Total inventory value at price.
  double get inventoryValueAtPrice => price * quantity;

  /// Potential profit for current stock.
  double get potentialProfit => profit * quantity;

  /// Whether stock is low (at or below reorder level).
  bool get isLowStock => quantity <= reorderLevel;

  /// Whether product is out of stock.
  bool get isOutOfStock => quantity <= 0;

  /// Stock status for display.
  StockStatus get stockStatus {
    if (quantity <= 0) return StockStatus.outOfStock;
    if (quantity <= reorderLevel) return StockStatus.lowStock;
    return StockStatus.inStock;
  }

  /// Whether this is a variation of another product.
  bool get isVariation => variationNumber != null && variationNumber! > 0;

  /// Display SKU (shows variation if applicable).
  String get displaySku => sku;

  // ==================== COST CODE METHODS ====================

  /// Gets the encoded cost code.
  /// If costCode is already set, returns it.
  /// Otherwise, encodes the cost using the provided mapping.
  String getEncodedCost(CostCodeEntity? costCodeMapping) {
    if (costCode.isNotEmpty) return costCode;
    final mapping = costCodeMapping ?? CostCodeEntity.defaultMapping();
    return mapping.encode(cost);
  }

  /// Decodes the cost code to actual value.
  /// Returns the stored cost if decoding fails.
  double getDecodedCost(CostCodeEntity? costCodeMapping) {
    if (costCode.isEmpty) return cost;
    final mapping = costCodeMapping ?? CostCodeEntity.defaultMapping();
    return mapping.decode(costCode) ?? cost;
  }

  // ==================== STOCK METHODS ====================

  /// Checks if the requested quantity is available.
  bool hasAvailableStock(int requestedQty) {
    return quantity >= requestedQty;
  }

  /// Creates a copy with adjusted quantity.
  ProductEntity adjustQuantity(int adjustment) {
    return copyWith(quantity: quantity + adjustment);
  }

  // ==================== COPY WITH ====================

  ProductEntity copyWith({
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
    return ProductEntity(
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
  List<Object?> get props => [
        id,
        sku,
        name,
        costCode,
        cost,
        price,
        quantity,
        reorderLevel,
        unit,
        supplierId,
        supplierName,
        isActive,
        createdAt,
        updatedAt,
        createdBy,
        updatedBy,
        searchKeywords,
        baseSku,
        variationNumber,
        barcode,
        category,
        imageUrl,
        notes,
      ];

  @override
  String toString() {
    return 'ProductEntity(id: $id, sku: $sku, name: $name, price: $price, qty: $quantity)';
  }
}

/// Stock status enumeration.
enum StockStatus {
  inStock('In Stock'),
  lowStock('Low Stock'),
  outOfStock('Out of Stock');

  final String displayName;
  const StockStatus(this.displayName);
}
