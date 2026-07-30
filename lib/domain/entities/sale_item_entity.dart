import 'package:equatable/equatable.dart';

/// Represents a single line item in a sale or job order.
///
/// Each item tracks:
/// - Product reference and snapshot data (for historical accuracy)
/// - Quantity and pricing
/// - Item-level discount (value only; type inherited from parent Sale/Job Order)
///
/// Note: The discount TYPE (amount vs percentage) is determined at the
/// Sale/Job Order level to ensure consistency across all items.
class SaleItemEntity extends Equatable {
  /// Unique identifier for this line item
  final String id;

  /// Reference to the product
  final String productId;

  /// Product SKU (snapshot at time of sale)
  final String sku;

  /// Product name (snapshot at time of sale)
  final String name;

  /// Unit price at time of sale (snapshot)
  final double unitPrice;

  /// Cost at time of sale (snapshot for profit calculation)
  /// Hidden from non-admin users in UI
  final double unitCost;

  /// Quantity sold
  final int quantity;

  /// Discount value for this item
  /// - If parent's discountType is 'amount': this is the peso amount off
  /// - If parent's discountType is 'percentage': this is the percentage off (e.g., 10 for 10%)
  final double discountValue;

  /// Unit of measurement (snapshot)
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

  const SaleItemEntity({
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

  // ==================== COMPUTED PROPERTIES ====================

  /// Gross amount before discount (unitPrice × quantity)
  double get grossAmount => unitPrice * quantity;

  /// Total cost for this line item (unitCost × quantity)
  double get totalCost => unitCost * quantity;

  /// Calculates the discount amount based on discount type.
  ///
  /// [isPercentage] - true if parent Sale/Job Order uses percentage discount
  double calculateDiscountAmount({required bool isPercentage}) {
    if (discountValue <= 0) return 0;

    if (isPercentage) {
      // Percentage: discountValue is the percentage (e.g., 10 for 10%)
      return grossAmount * (discountValue / 100);
    } else {
      // Amount: discountValue is the peso amount
      // Cap at gross amount to prevent negative
      return discountValue > grossAmount ? grossAmount : discountValue;
    }
  }

  /// Net amount after discount.
  ///
  /// [isPercentage] - true if parent Sale/Job Order uses percentage discount
  double calculateNetAmount({required bool isPercentage}) {
    return grossAmount - calculateDiscountAmount(isPercentage: isPercentage);
  }

  /// Profit for this line item.
  ///
  /// [isPercentage] - true if parent Sale/Job Order uses percentage discount
  double calculateProfit({required bool isPercentage}) {
    return calculateNetAmount(isPercentage: isPercentage) - totalCost;
  }

  /// Profit margin percentage for this item.
  ///
  /// [isPercentage] - true if parent Sale/Job Order uses percentage discount
  double calculateProfitMargin({required bool isPercentage}) {
    final netAmount = calculateNetAmount(isPercentage: isPercentage);
    if (netAmount <= 0) return 0;
    return (calculateProfit(isPercentage: isPercentage) / netAmount) * 100;
  }

  /// Whether this item has a discount applied
  bool get hasDiscount => discountValue > 0;

  /// Whether this line was rung up through a selling option.
  bool get hasOption => optionId != null && optionPieces != null && optionPieces! > 0;

  /// Number of whole sets on this line, or null when there's no option.
  /// [quantity] is always pieces, so sets is quantity / pieces.
  int? get optionSets => hasOption ? quantity ~/ optionPieces! : null;

  /// How much the +/- buttons move this line. A "By 3" line steps 3 -> 6.
  int get quantityStep => hasOption ? optionPieces! : 1;

  /// Name for display, with the option label appended when there is one —
  /// e.g. "Pulley Ball · By 3". Falls back to the bare [name] with no
  /// option. Centralised here so every render site (cart tile, receipts,
  /// sale detail, checkout, void-request receipt, job-order previews)
  /// constructs this string identically.
  String get displayName => hasOption ? '$name · $optionLabel' : name;

  /// Sets + total pieces caption for display, e.g. "By 3 × 2 (6 pcs)" — null
  /// when there's no option or there's only one set (a single set is fully
  /// said by [displayName] alone, so no extra caption is shown).
  String? get optionSetsCaption {
    final sets = optionSets;
    if (sets == null || sets <= 1) return null;
    return '$optionLabel × $sets ($quantity pcs)';
  }

  // ==================== COPY WITH ====================

  SaleItemEntity copyWith({
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
    return SaleItemEntity(
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
  List<Object?> get props => [
        id,
        productId,
        sku,
        name,
        unitPrice,
        unitCost,
        quantity,
        discountValue,
        unit,
        optionId,
        optionLabel,
        optionPieces,
        optionPrice,
      ];

  @override
  String toString() {
    return 'SaleItemEntity(sku: $sku, name: $name, qty: $quantity, price: $unitPrice, discount: $discountValue)';
  }
}
