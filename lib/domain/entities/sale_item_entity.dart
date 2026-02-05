import 'package:equatable/equatable.dart';

/// Represents a single line item in a sale or draft.
///
/// Each item tracks:
/// - Product reference and snapshot data (for historical accuracy)
/// - Quantity and pricing
/// - Item-level discount (value only; type inherited from parent Sale/Draft)
///
/// Note: The discount TYPE (amount vs percentage) is determined at the
/// Sale/Draft level to ensure consistency across all items.
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
  });

  // ==================== COMPUTED PROPERTIES ====================

  /// Gross amount before discount (unitPrice × quantity)
  double get grossAmount => unitPrice * quantity;

  /// Total cost for this line item (unitCost × quantity)
  double get totalCost => unitCost * quantity;

  /// Calculates the discount amount based on discount type.
  ///
  /// [isPercentage] - true if parent Sale/Draft uses percentage discount
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
  /// [isPercentage] - true if parent Sale/Draft uses percentage discount
  double calculateNetAmount({required bool isPercentage}) {
    return grossAmount - calculateDiscountAmount(isPercentage: isPercentage);
  }

  /// Profit for this line item.
  ///
  /// [isPercentage] - true if parent Sale/Draft uses percentage discount
  double calculateProfit({required bool isPercentage}) {
    return calculateNetAmount(isPercentage: isPercentage) - totalCost;
  }

  /// Profit margin percentage for this item.
  ///
  /// [isPercentage] - true if parent Sale/Draft uses percentage discount
  double calculateProfitMargin({required bool isPercentage}) {
    final netAmount = calculateNetAmount(isPercentage: isPercentage);
    if (netAmount <= 0) return 0;
    return (calculateProfit(isPercentage: isPercentage) / netAmount) * 100;
  }

  /// Whether this item has a discount applied
  bool get hasDiscount => discountValue > 0;

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
      ];

  @override
  String toString() {
    return 'SaleItemEntity(sku: $sku, name: $name, qty: $quantity, price: $unitPrice, discount: $discountValue)';
  }
}
