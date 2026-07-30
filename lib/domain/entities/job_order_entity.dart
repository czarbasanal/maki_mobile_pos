import 'package:equatable/equatable.dart';
import 'package:maki_mobile_pos/core/enums/enums.dart';
import 'package:maki_mobile_pos/domain/entities/fee_line_entity.dart';
import 'package:maki_mobile_pos/domain/entities/labor_line_entity.dart';
import 'package:maki_mobile_pos/domain/entities/sale_item_entity.dart';

/// Represents a saved incomplete sale (job order).
///
/// Job Orders allow cashiers to:
/// - Save a sale in progress when a customer steps away
/// - Retrieve and continue the sale later
/// - Convert to a completed sale at checkout
///
/// Key features:
/// - Identified by a user-provided name/description
/// - Can be edited, deleted, or converted to sale
/// - Marked as converted after checkout (then can be deleted)
/// - Single discount type across all items (amount OR percentage)
class JobOrderEntity extends Equatable {
  /// Unique identifier
  final String id;

  /// User-provided name/description for this job order
  /// e.g., "Customer waiting outside", "Table 5", "John's order"
  final String name;

  /// Line items in this job order
  final List<SaleItemEntity> items;

  /// Free-form labor/service lines (full price, never discounted)
  final List<LaborLineEntity> laborLines;

  /// Shop-fee lines on this ticket (outside-item charges: electric charge,
  /// tire changer, air, ...). Belongs to the shop, never discounted, zero
  /// cost.
  final List<FeeLineEntity> feeLines;

  /// Mechanic assigned to this job (one per ticket); null until assigned
  final String? mechanicId;

  /// Mechanic display name (snapshot, like createdByName)
  final String? mechanicName;

  /// Motorcycle model serviced (canonical name snapshot); null until set.
  final String? motorcycleModel;

  /// Type of discount applied (applies to ALL items)
  final DiscountType discountType;

  /// ID of cashier who created this job order
  final String createdBy;

  /// Name of cashier (snapshot for display)
  final String createdByName;

  /// When the job order was created
  final DateTime createdAt;

  /// When the job order was last updated
  final DateTime? updatedAt;

  /// ID of user who last updated this job order
  final String? updatedBy;

  /// Whether this job order has been converted to a sale
  /// Once converted, the job order can be deleted
  final bool isConverted;

  /// Reference to the sale if converted
  final String? convertedToSaleId;

  /// When the job order was converted to a sale
  final DateTime? convertedAt;

  /// Optional notes
  final String? notes;

  const JobOrderEntity({
    required this.id,
    required this.name,
    required this.items,
    this.laborLines = const [],
    this.feeLines = const [],
    this.mechanicId,
    this.mechanicName,
    this.motorcycleModel,
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

  // ==================== MONEY MATH ====================

  /// Parts gross before discount (items only). Alias of [subtotal].
  double get partsSubtotal => subtotal;

  /// Sum of all labor fees (full price, never discounted).
  double get laborSubtotal => laborLines.fold(0.0, (s, l) => s + l.fee);

  /// Net merchandise revenue (parts gross minus item discounts).
  double get partsRevenue => partsSubtotal - totalDiscount;

  /// Labor revenue (pure margin — zero cost).
  double get laborRevenue => laborSubtotal;

  /// Total of all shop-fee lines. Belongs to the shop; never discounted;
  /// zero cost (pure margin, like labor).
  double get feesTotal => feeLines.fold(0.0, (s, f) => s + f.amount);

  /// Grand total after discounts, including labor and shop fees.
  double get grandTotal => partsRevenue + laborRevenue + feesTotal;

  /// Merchandise profit (parts revenue minus parts cost).
  double get partsProfit => partsRevenue - totalCost;

  /// Labor profit (labor has zero cost).
  double get laborProfit => laborRevenue;

  /// True per-transaction profit (parts + labor).
  double get totalProfit => partsProfit + laborProfit;

  /// Total cost of all items
  double get totalCost {
    return items.fold(0.0, (sum, item) => sum + item.totalCost);
  }

  /// Whether this job order has any discounts
  bool get hasDiscount => totalDiscount > 0;

  /// Whether this job order is empty
  bool get isEmpty => items.isEmpty;

  /// Whether this job order has any billable content — items, labor, or shop
  /// fees. Only a truly empty ticket (nothing at all) has none.
  bool get hasBillableContent =>
      items.isNotEmpty || laborLines.isNotEmpty || feeLines.isNotEmpty;

  /// Whether this job order can be checked out. Any billable content (items,
  /// labor, or shop fees) is enough — labor alone can bill out.
  bool get canCheckout => hasBillableContent && !isConverted;

  /// Whether this job order can be deleted
  /// Job Orders can always be deleted, but UI may warn if not converted
  bool get canDelete => true;

  /// Display label showing item count
  String get itemCountLabel {
    final count = totalItemCount;
    return count == 1 ? '1 item' : '$count items';
  }

  // ==================== ITEM MANAGEMENT ====================

  /// Adds an item to the job order (returns new instance).
  ///
  /// Merges on (productId, optionId), not productId alone — a By 6 and a
  /// By 3 of the same product carry different prices, so folding them would
  /// silently lose one. Mirrors CartNotifier.addItem's fix for the same bug.
  JobOrderEntity addItem(SaleItemEntity item) {
    final existingIndex = items.indexWhere(
      (i) => i.productId == item.productId && i.optionId == item.optionId,
    );

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

  /// Updates an item in the job order (returns new instance)
  JobOrderEntity updateItem(SaleItemEntity updatedItem) {
    final index = items.indexWhere((i) => i.id == updatedItem.id);
    if (index < 0) return this;

    final updatedItems = List<SaleItemEntity>.from(items);
    updatedItems[index] = updatedItem;
    return copyWith(items: updatedItems, updatedAt: DateTime.now());
  }

  /// Removes an item from the job order (returns new instance)
  JobOrderEntity removeItem(String itemId) {
    return copyWith(
      items: items.where((i) => i.id != itemId).toList(),
      updatedAt: DateTime.now(),
    );
  }

  /// Updates item quantity (returns new instance)
  JobOrderEntity updateItemQuantity(String itemId, int newQuantity) {
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
  JobOrderEntity applyItemDiscount(String itemId, double discountValue) {
    final index = items.indexWhere((i) => i.id == itemId);
    if (index < 0) return this;

    final updatedItems = List<SaleItemEntity>.from(items);
    updatedItems[index] = items[index].copyWith(discountValue: discountValue);
    return copyWith(items: updatedItems, updatedAt: DateTime.now());
  }

  /// Changes the discount type for all items
  JobOrderEntity changeDiscountType(DiscountType newType) {
    // When changing type, reset all item discounts to 0 to avoid confusion
    final resetItems =
        items.map((item) => item.copyWith(discountValue: 0)).toList();
    return copyWith(
      discountType: newType,
      items: resetItems,
      updatedAt: DateTime.now(),
    );
  }

  /// Clears all items from the job order
  JobOrderEntity clearItems() {
    return copyWith(items: [], updatedAt: DateTime.now());
  }

  // ==================== LABOR MANAGEMENT ====================

  /// Adds a labor line to the job order (returns new instance)
  JobOrderEntity addLaborLine(LaborLineEntity line) {
    return copyWith(
      laborLines: [...laborLines, line],
      updatedAt: DateTime.now(),
    );
  }

  /// Updates a labor line by id (returns new instance; no-op if not found)
  JobOrderEntity updateLaborLine(LaborLineEntity line) {
    final index = laborLines.indexWhere((l) => l.id == line.id);
    if (index < 0) return this;

    final updated = List<LaborLineEntity>.from(laborLines);
    updated[index] = line;
    return copyWith(laborLines: updated, updatedAt: DateTime.now());
  }

  /// Removes a labor line by id (returns new instance)
  JobOrderEntity removeLaborLine(String lineId) {
    return copyWith(
      laborLines: laborLines.where((l) => l.id != lineId).toList(),
      updatedAt: DateTime.now(),
    );
  }

  // ==================== FEE MANAGEMENT ====================

  /// Adds a shop-fee line to the job order (returns new instance)
  JobOrderEntity addFeeLine(FeeLineEntity line) {
    return copyWith(
      feeLines: [...feeLines, line],
      updatedAt: DateTime.now(),
    );
  }

  /// Updates a shop-fee line by id (returns new instance; no-op if not found)
  JobOrderEntity updateFeeLine(FeeLineEntity line) {
    final index = feeLines.indexWhere((f) => f.id == line.id);
    if (index < 0) return this;

    final updated = List<FeeLineEntity>.from(feeLines);
    updated[index] = line;
    return copyWith(feeLines: updated, updatedAt: DateTime.now());
  }

  /// Removes a shop-fee line by id (returns new instance)
  JobOrderEntity removeFeeLine(String lineId) {
    return copyWith(
      feeLines: feeLines.where((f) => f.id != lineId).toList(),
      updatedAt: DateTime.now(),
    );
  }

  // ==================== COPY WITH ====================

  JobOrderEntity copyWith({
    String? id,
    String? name,
    List<SaleItemEntity>? items,
    List<LaborLineEntity>? laborLines,
    List<FeeLineEntity>? feeLines,
    String? mechanicId,
    String? mechanicName,
    String? motorcycleModel,
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
    bool clearMechanic = false,
    bool clearMotorcycleModel = false,
  }) {
    return JobOrderEntity(
      id: id ?? this.id,
      name: name ?? this.name,
      items: items ?? this.items,
      laborLines: laborLines ?? this.laborLines,
      feeLines: feeLines ?? this.feeLines,
      mechanicId: clearMechanic ? null : (mechanicId ?? this.mechanicId),
      mechanicName: clearMechanic ? null : (mechanicName ?? this.mechanicName),
      motorcycleModel: clearMotorcycleModel
          ? null
          : (motorcycleModel ?? this.motorcycleModel),
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

  /// Marks this job order as converted to a sale
  JobOrderEntity markAsConverted(String saleId) {
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
        laborLines,
        feeLines,
        mechanicId,
        mechanicName,
        motorcycleModel,
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
    return 'JobOrderEntity(id: $id, name: $name, items: ${items.length}, total: $grandTotal)';
  }
}
