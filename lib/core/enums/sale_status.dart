/// Status of a sale transaction.
enum SaleStatus {
  /// Sale completed successfully
  completed('completed', 'Completed'),

  /// Sale has been voided/cancelled
  voided('voided', 'Voided'),

  /// Sale is saved as draft
  draft('draft', 'Draft');

  const SaleStatus(this.value, this.displayName);

  /// The value stored in Firestore
  final String value;

  /// Human-readable name for UI display
  final String displayName;

  /// Creates a [SaleStatus] from a Firestore string value.
  static SaleStatus fromString(String? value) {
    return SaleStatus.values.firstWhere(
      (status) => status.value == value,
      orElse: () => SaleStatus.completed,
    );
  }
}
