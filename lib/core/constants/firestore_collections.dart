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

  /// Daily closings collection - end-of-day sales-drawer reconciliations
  static const String dailyClosings = 'daily_closings';

  /// User activity logs collection
  static const String userLogs = 'user_logs';

  /// Settings collection - app configuration
  static const String settings = 'settings';

  /// Product categories collection - admin-managed product category list
  static const String productCategories = 'product_categories';

  /// Expense categories collection - admin-managed expense category list
  static const String expenseCategories = 'expense_categories';

  /// Units collection - admin-managed product unit list (pcs, kg, box, ...)
  static const String units = 'units';

  /// Void reasons collection - admin-managed reasons shown in the void-sale dialog
  static const String voidReasons = 'void_reasons';

  /// Mechanics collection - admin-managed mechanic list for service drafts
  static const String mechanics = 'mechanics';

  /// Motorcycle models collection - admin-managed + cashier-addable model list
  /// picked on Job Orders.
  static const String motorcycleModels = 'motorcycle_models';

  /// Void requests collection - cashier/staff void requests awaiting admin approval
  static const String voidRequests = 'void_requests';

  /// Product SKU-uniqueness claim collection. One doc per in-use SKU, keyed by
  /// SkuGenerator.normalizeSku(sku); reserved atomically on product create /
  /// SKU rename. See docs/superpowers/specs/2026-06-01-sku-guard-*.
  static const String productSkus = 'product_skus';

  /// Product barcode-uniqueness claim collection. One doc per in-use barcode,
  /// keyed by SkuGenerator.normalizeBarcode(code); reserved atomically on
  /// product create / barcode edit. See docs/superpowers/specs/2026-06-18-barcode-guard-*.
  static const String productBarcodes = 'product_barcodes';

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
