/// Firestore collection and document path constants.
///
/// Centralized location for all Firestore paths to ensure consistency
/// and make refactoring easier.
///
/// This class cannot be instantiated; all members are static.
abstract class FirestoreCollections {
  // ==================== ROOT COLLECTIONS ====================

  /// Users collection - stores user profiles and roles
  static const String users = 'users';

  /// Products collection - inventory items
  static const String products = 'products';

  /// Suppliers collection - vendor information
  static const String suppliers = 'suppliers';

  /// Sales collection - completed transactions
  static const String sales = 'sales';

  /// Drafts collection - saved incomplete sales
  static const String drafts = 'drafts';

  /// Receivings collection - stock receiving records
  static const String receivings = 'receivings';

  /// Expenses collection - business expenses
  static const String expenses = 'expenses';

  /// Petty cash collection - cash fund records
  static const String pettyCash = 'petty_cash';

  /// User activity logs collection
  static const String userLogs = 'user_logs';

  /// Settings collection - app configuration
  static const String settings = 'settings';

  // ==================== SETTINGS DOCUMENTS ====================

  /// Document ID for cost code mapping settings
  static const String costCodeSettings = 'cost_code_mapping';

  /// Document ID for general app settings
  static const String generalSettings = 'general';

  // ==================== SUBCOLLECTIONS ====================

  /// Subcollection for sale items within a sale document
  static const String saleItems = 'items';

  /// Subcollection for price history within a product document
  static const String priceHistory = 'price_history';

  // ==================== FIELD NAMES ====================

  /// Common field names used across collections
  static const String fieldCreatedAt = 'createdAt';
  static const String fieldUpdatedAt = 'updatedAt';
  static const String fieldCreatedBy = 'createdBy';
  static const String fieldUpdatedBy = 'updatedBy';
  static const String fieldIsActive = 'isActive';
}
