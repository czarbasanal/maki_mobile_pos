/// Application-wide constants.
///
/// This class cannot be instantiated; all members are static.
abstract class AppConstants {
  // ==================== CURRENCY ====================

  /// Currency symbol for Philippine Peso
  static const String currencySymbol = '₱';

  /// Currency code
  static const String currencyCode = 'PHP';

  /// Number of decimal places for currency
  static const int currencyDecimalPlaces = 2;

  // ==================== APP INFO ====================

  /// Application name
  static const String appName = 'POS System';

  /// Application version
  static const String appVersion = '1.0.0';

  // ==================== DEFAULTS ====================

  /// Default reorder level for new products
  static const int defaultReorderLevel = 10;

  /// Default GCash fee percentage (if applicable)
  static const double gcashFeePercentage = 0.0; // Adjust if fees apply

  // ==================== SKU GENERATION ====================

  /// Prefix for auto-generated SKUs
  static const String skuPrefix = 'SKU';

  /// Length of random portion in auto-generated SKUs
  static const int skuRandomLength = 8;

  /// Separator for SKU variations (e.g., ABC-1, ABC-2)
  static const String skuVariationSeparator = '-';

  // ==================== VALIDATION ====================

  /// Minimum password length
  static const int minPasswordLength = 6;

  /// Maximum product name length
  static const int maxProductNameLength = 100;

  /// Maximum description length for drafts
  static const int maxDraftDescriptionLength = 200;

  // ==================== PAGINATION ====================

  /// Default page size for list queries
  static const int defaultPageSize = 20;

  /// Maximum items to load at once
  static const int maxPageSize = 100;
}
