/// Payment methods accepted by the POS system.
///
/// Note: e-wallet payments (Maya, GCash) may have associated merchant
/// fees that are deducted from total sales during reporting.
enum PaymentMethod {
  /// Maya e-wallet (formerly PayMaya). Fees may apply.
  maya('maya', 'Maya'),

  /// Physical cash payment
  cash('cash', 'Cash'),

  /// GCash mobile payment (fees may apply)
  gcash('gcash', 'GCash');

  const PaymentMethod(this.value, this.displayName);

  /// The value stored in Firestore
  final String value;

  /// Human-readable name for UI display
  final String displayName;

  /// Creates a [PaymentMethod] from a Firestore string value.
  /// Returns [cash] as default if value is invalid.
  static PaymentMethod fromString(String? value) {
    return PaymentMethod.values.firstWhere(
      (method) => method.value == value,
      orElse: () => PaymentMethod.cash,
    );
  }

  /// Whether this payment method has transaction fees.
  bool get hasFees =>
      this == PaymentMethod.gcash || this == PaymentMethod.maya;
}
