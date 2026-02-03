/// Type of discount applied to a sale.
enum DiscountType {
  /// Fixed amount discount (e.g., ₱100 off)
  amount('amount', 'Amount'),

  /// Percentage discount (e.g., 10% off)
  percentage('percentage', 'Percentage');

  const DiscountType(this.value, this.displayName);

  /// The value stored in Firestore
  final String value;

  /// Human-readable name for UI display
  final String displayName;

  /// Creates a [DiscountType] from a Firestore string value.
  static DiscountType fromString(String? value) {
    return DiscountType.values.firstWhere(
      (type) => type.value == value,
      orElse: () => DiscountType.amount,
    );
  }
}
