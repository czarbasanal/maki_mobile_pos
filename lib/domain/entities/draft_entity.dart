import 'package:equatable/equatable.dart';
import 'package:maki_mobile_pos/core/enums/enums.dart';
import 'package:maki_mobile_pos/domain/entities/sale_item_entity.dart';

/// Represents a saved incomplete sale (draft).
///
/// Drafts allow cashiers to:
/// - Save a sale in progress when a customer steps away
/// - Retrieve and continue the sale later
/// - Convert to a completed sale at checkout
///
/// Key features:
/// - Identified by a user-provided name/description
/// - Can be edited, deleted, or converted to sale
/// - Marked as converted after checkout (then can be deleted)
/// - Single discount type across all items (amount OR percentage)
class DraftEntity extends Equatable {
  /// Unique identifier
  final String id;

  /// User-provided name/description for this draft
  /// e.g., "Customer waiting outside", "Table 5", "John's order"
  final String name;

  /// Line items in this draft
  final List<SaleItemEntity> items;

  /// Type of discount applied (applies to ALL items)
  final DiscountType discountType;

  /// ID of cashier who created this draft
  final String createdBy;

  /// Name of cashier (snapshot for display)
  final String createdByName;

  /// When the draft was created
  final DateTime createdAt;

  /// When the draft was last updated
  final DateTime? updatedAt;

  /// ID of user who last updated this draft
  final String? updatedBy;

  /// Whether this draft has been converted to a sale
  /// Once converted, the draft can be deleted
  final bool isConverted;

  /// Reference to the sale if converted
  final String? convertedToSaleId;

  /// When the draft was converted to a sale
  final DateTime? convertedAt;

  /// Optional notes
  final String? notes;

  const DraftEntity({
    required this.id,
    required this.name,
    required this.items,
    this.discountType = DiscountType.amount,
    required this.createdBy,
    required this.createdByName,
    required this.createdAt,
    this.updatedAt,
    this.updatedBy,
    this.isConverted = false,
    this.convertedToSaleId,
    this.convertedAt,
    this.notes,
  });

  // ==================== COMPUTED PROPERTIES ====================

  /// Whether discount type is percentage
  bool get isPercentageDiscount => discountType == DiscountType.percentage;

  /// Total number of items (sum of quantities)
  int get totalItemCount {
    return items.fold(0, (sum, item) => sum + item.quantity);
  }

  /// Number of unique products (line items)
  int get uniqueProductCount => items.length;

  /// Subtotal before any discounts
  double get subtotal {
    return items.fold(0.0, (sum, item) => sum + item.grossAmount);
  }

  /// Total discount amount across all items
  double get totalDiscount {
    return items.fold(
      0.0,
      (sum, item) =>
          sum +
          item.calculateDiscountAmount(isPercentage: isPercentageDiscount),
    );
  }

  /// Grand total after all discounts
  double get grandTotal => subtotal - totalDiscount;

  /// Total cost of all items
  double get totalCost {
    return items.fold(0.0, (sum, item) => sum + item.totalCost);
  }

  /// Whether this draft has any discounts
  bool get hasDiscount => totalDiscount > 0;

  /// Whether this draft is empty
  bool get isEmpty => items.isEmpty;

  /// Whether this draft can be checked out
  bool get canCheckout => items.isNotEmpty && !isConverted;

  /// Whether this draft can be deleted
  /// Drafts can always be deleted, but UI may warn if not converted
  bool get canDelete => true;

  /// Display label showing item count
  String get itemCountLabel {
    final count = totalItemCount;
    return count == 1 ? '1 item' : '$count items';
  }

  // ==================== ITEM MANAGEMENT ====================

  /// Adds an item to the draft (returns new instance)
  DraftEntity addItem(SaleItemEntity item) {
    final existingIndex =
        items.indexWhere((i) => i.productId == item.productId);

    if (existingIndex >= 0) {
      // Update existing item quantity
      final existingItem = items[existingIndex];
      final updatedItem = existingItem.copyWith(
        quantity: existingItem.quantity + item.quantity,
      );
      final updatedItems = List<SaleItemEntity>.from(items);
      updatedItems[existingIndex] = updatedItem;
      return copyWith(items: updatedItems, updatedAt: DateTime.now());
    } else {
      // Add new item
      return copyWith(
        items: [...items, item],
        updatedAt: DateTime.now(),
      );
    }
  }

  /// Updates an item in the draft (returns new instance)
  DraftEntity updateItem(SaleItemEntity updatedItem) {
    final index = items.indexWhere((i) => i.id == updatedItem.id);
    if (index < 0) return this;

    final updatedItems = List<SaleItemEntity>.from(items);
    updatedItems[index] = updatedItem;
    return copyWith(items: updatedItems, updatedAt: DateTime.now());
  }

  /// Removes an item from the draft (returns new instance)
  DraftEntity removeItem(String itemId) {
    return copyWith(
      items: items.where((i) => i.id != itemId).toList(),
      updatedAt: DateTime.now(),
    );
  }

  /// Updates item quantity (returns new instance)
  DraftEntity updateItemQuantity(String itemId, int newQuantity) {
    if (newQuantity <= 0) {
      return removeItem(itemId);
    }

    final index = items.indexWhere((i) => i.id == itemId);
    if (index < 0) return this;

    final updatedItems = List<SaleItemEntity>.from(items);
    updatedItems[index] = items[index].copyWith(quantity: newQuantity);
    return copyWith(items: updatedItems, updatedAt: DateTime.now());
  }

  /// Applies discount to an item (returns new instance)
  DraftEntity applyItemDiscount(String itemId, double discountValue) {
    final index = items.indexWhere((i) => i.id == itemId);
    if (index < 0) return this;

    final updatedItems = List<SaleItemEntity>.from(items);
    updatedItems[index] = items[index].copyWith(discountValue: discountValue);
    return copyWith(items: updatedItems, updatedAt: DateTime.now());
  }

  /// Changes the discount type for all items
  DraftEntity changeDiscountType(DiscountType newType) {
    // When changing type, reset all item discounts to 0 to avoid confusion
    final resetItems =
        items.map((item) => item.copyWith(discountValue: 0)).toList();
    return copyWith(
      discountType: newType,
      items: resetItems,
      updatedAt: DateTime.now(),
    );
  }

  /// Clears all items from the draft
  DraftEntity clearItems() {
    return copyWith(items: [], updatedAt: DateTime.now());
  }

  // ==================== COPY WITH ====================

  DraftEntity copyWith({
    String? id,
    String? name,
    List<SaleItemEntity>? items,
    DiscountType? discountType,
    String? createdBy,
    String? createdByName,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? updatedBy,
    bool? isConverted,
    String? convertedToSaleId,
    DateTime? convertedAt,
    String? notes,
    // Clear flags
    bool clearNotes = false,
    bool clearConversionInfo = false,
  }) {
    return DraftEntity(
      id: id ?? this.id,
      name: name ?? this.name,
      items: items ?? this.items,
      discountType: discountType ?? this.discountType,
      createdBy: createdBy ?? this.createdBy,
      createdByName: createdByName ?? this.createdByName,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      updatedBy: updatedBy ?? this.updatedBy,
      isConverted: isConverted ?? this.isConverted,
      convertedToSaleId: clearConversionInfo
          ? null
          : (convertedToSaleId ?? this.convertedToSaleId),
      convertedAt:
          clearConversionInfo ? null : (convertedAt ?? this.convertedAt),
      notes: clearNotes ? null : (notes ?? this.notes),
    );
  }

  /// Marks this draft as converted to a sale
  DraftEntity markAsConverted(String saleId) {
    return copyWith(
      isConverted: true,
      convertedToSaleId: saleId,
      convertedAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }

  @override
  List<Object?> get props => [
        id,
        name,
        items,
        discountType,
        createdBy,
        createdByName,
        createdAt,
        updatedAt,
        updatedBy,
        isConverted,
        convertedToSaleId,
        convertedAt,
        notes,
      ];

  @override
  String toString() {
    return 'DraftEntity(id: $id, name: $name, items: ${items.length}, total: $grandTotal)';
  }
}
