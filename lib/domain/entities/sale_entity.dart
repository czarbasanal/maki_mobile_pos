import 'package:equatable/equatable.dart';
import 'package:maki_mobile_pos/core/enums/enums.dart';
import 'package:maki_mobile_pos/domain/entities/sale_item_entity.dart';

/// Represents a completed sale transaction.
///
/// Key features:
/// - Contains snapshot data for historical accuracy
/// - Tracks payment method and amounts
/// - Supports voiding with audit trail
/// - Single discount type across all items (amount OR percentage, never both)
///
/// Discount Rules:
/// - [discountType] determines how ALL item discounts are interpreted
/// - If 'amount': each item's discountValue is a peso amount
/// - If 'percentage': each item's discountValue is a percentage
class SaleEntity extends Equatable {
  /// Unique identifier
  final String id;

  /// Human-readable sale number (e.g., "SALE-20250205-001")
  final String saleNumber;

  /// Line items in this sale
  final List<SaleItemEntity> items;

  /// Type of discount applied (applies to ALL items)
  /// This ensures consistency - you cannot mix amount and percentage discounts
  final DiscountType discountType;

  /// Payment method used
  final PaymentMethod paymentMethod;

  /// Amount received from customer
  final double amountReceived;

  /// Change given to customer
  final double changeGiven;

  /// Current status of the sale
  final SaleStatus status;

  /// ID of cashier who processed this sale
  final String cashierId;

  /// Name of cashier (snapshot for display)
  final String cashierName;

  /// When the sale was completed
  final DateTime createdAt;

  /// When the sale was last updated (e.g., voided)
  final DateTime? updatedAt;

  /// Reference to draft if this sale was converted from a draft
  final String? draftId;

  /// Notes/remarks for this sale
  final String? notes;

  // ==================== VOID INFORMATION ====================

  /// When the sale was voided (null if not voided)
  final DateTime? voidedAt;

  /// ID of user who voided the sale
  final String? voidedBy;

  /// Name of user who voided (snapshot)
  final String? voidedByName;

  /// Reason for voiding
  final String? voidReason;

  const SaleEntity({
    required this.id,
    required this.saleNumber,
    required this.items,
    this.discountType = DiscountType.amount,
    required this.paymentMethod,
    required this.amountReceived,
    required this.changeGiven,
    this.status = SaleStatus.completed,
    required this.cashierId,
    required this.cashierName,
    required this.createdAt,
    this.updatedAt,
    this.draftId,
    this.notes,
    this.voidedAt,
    this.voidedBy,
    this.voidedByName,
    this.voidReason,
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

  /// Subtotal before any discounts (sum of all items' gross amounts)
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

  /// Total cost of all items sold
  double get totalCost {
    return items.fold(0.0, (sum, item) => sum + item.totalCost);
  }

  /// Total profit from this sale
  double get totalProfit => grandTotal - totalCost;

  /// Profit margin percentage
  double get profitMargin {
    if (grandTotal <= 0) return 0;
    return (totalProfit / grandTotal) * 100;
  }

  /// Whether this sale has any discounts
  bool get hasDiscount => totalDiscount > 0;

  /// Whether this sale has been voided
  bool get isVoided => status == SaleStatus.voided;

  /// Whether this sale is completed (not voided)
  bool get isCompleted => status == SaleStatus.completed;

  /// Whether this sale was converted from a draft
  bool get isFromDraft => draftId != null && draftId!.isNotEmpty;

  // ==================== VALIDATION ====================

  /// Validates that the sale data is consistent
  bool get isValid {
    if (items.isEmpty) return false;
    if (amountReceived < grandTotal) return false;
    if (changeGiven < 0) return false;
    return true;
  }

  // ==================== COPY WITH ====================

  SaleEntity copyWith({
    String? id,
    String? saleNumber,
    List<SaleItemEntity>? items,
    DiscountType? discountType,
    PaymentMethod? paymentMethod,
    double? amountReceived,
    double? changeGiven,
    SaleStatus? status,
    String? cashierId,
    String? cashierName,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? draftId,
    String? notes,
    DateTime? voidedAt,
    String? voidedBy,
    String? voidedByName,
    String? voidReason,
    // Clear flags for nullable fields
    bool clearDraftId = false,
    bool clearNotes = false,
    bool clearVoidInfo = false,
  }) {
    return SaleEntity(
      id: id ?? this.id,
      saleNumber: saleNumber ?? this.saleNumber,
      items: items ?? this.items,
      discountType: discountType ?? this.discountType,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      amountReceived: amountReceived ?? this.amountReceived,
      changeGiven: changeGiven ?? this.changeGiven,
      status: status ?? this.status,
      cashierId: cashierId ?? this.cashierId,
      cashierName: cashierName ?? this.cashierName,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      draftId: clearDraftId ? null : (draftId ?? this.draftId),
      notes: clearNotes ? null : (notes ?? this.notes),
      voidedAt: clearVoidInfo ? null : (voidedAt ?? this.voidedAt),
      voidedBy: clearVoidInfo ? null : (voidedBy ?? this.voidedBy),
      voidedByName: clearVoidInfo ? null : (voidedByName ?? this.voidedByName),
      voidReason: clearVoidInfo ? null : (voidReason ?? this.voidReason),
    );
  }

  /// Creates a voided version of this sale
  SaleEntity void_({
    required String voidedById,
    required String voidedByUserName,
    required String reason,
  }) {
    return copyWith(
      status: SaleStatus.voided,
      updatedAt: DateTime.now(),
      voidedAt: DateTime.now(),
      voidedBy: voidedById,
      voidedByName: voidedByUserName,
      voidReason: reason,
    );
  }

  @override
  List<Object?> get props => [
        id,
        saleNumber,
        items,
        discountType,
        paymentMethod,
        amountReceived,
        changeGiven,
        status,
        cashierId,
        cashierName,
        createdAt,
        updatedAt,
        draftId,
        notes,
        voidedAt,
        voidedBy,
        voidedByName,
        voidReason,
      ];

  @override
  String toString() {
    return 'SaleEntity(id: $id, saleNumber: $saleNumber, total: $grandTotal, status: ${status.displayName})';
  }
}
