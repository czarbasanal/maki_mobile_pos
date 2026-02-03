/// Supplier transaction/payment terms.
///
/// Defines how payments to suppliers are handled:
/// - [cash]: Immediate payment required
/// - [termsXXd]: Payment due in XX days
/// - [notApplicable]: No specific terms
enum TransactionType {
  /// Immediate cash payment required
  cash('cash', 'Cash'),

  /// Payment due in 30 days
  terms30d('terms_30d', '30 Days'),

  /// Payment due in 45 days
  terms45d('terms_45d', '45 Days'),

  /// Payment due in 60 days
  terms60d('terms_60d', '60 Days'),

  /// Payment due in 90 days
  terms90d('terms_90d', '90 Days'),

  /// No specific payment terms
  notApplicable('na', 'N/A');

  const TransactionType(this.value, this.displayName);

  /// The value stored in Firestore
  final String value;

  /// Human-readable name for UI display
  final String displayName;

  /// Creates a [TransactionType] from a Firestore string value.
  /// Returns [notApplicable] as default if value is invalid.
  static TransactionType fromString(String? value) {
    return TransactionType.values.firstWhere(
      (type) => type.value == value,
      orElse: () => TransactionType.notApplicable,
    );
  }

  /// Returns the number of days for payment terms.
  /// Returns 0 for cash and null for N/A.
  int? get daysUntilDue {
    switch (this) {
      case TransactionType.cash:
        return 0;
      case TransactionType.terms30d:
        return 30;
      case TransactionType.terms45d:
        return 45;
      case TransactionType.terms60d:
        return 60;
      case TransactionType.terms90d:
        return 90;
      case TransactionType.notApplicable:
        return null;
    }
  }
}
