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

  /// Job orders collection (service tickets; formerly 'drafts')
  static const String jobOrders = 'job_orders';

  /// Receivings collection - stock receiving records
  static const String receivings = 'receivings';

  /// Purchase orders collection - planned stock purchases
  static const String purchaseOrders = 'purchase_orders';

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

  /// Mechanics collection - admin-managed mechanic list for job orders
  static const String mechanics = 'mechanics';

  /// Employees registry (HR payroll) - shared with the web admin
  static const String employees = 'employees';

  /// Generated payslips (HR payroll) - frozen snapshots, shared with web
  static const String payslips = 'payslips';

  /// Shop fees collection - admin-managed shop-fee catalog (e.g. environmental
  /// fee, disposal fee) attachable to a sale/draft
  static const String shopFees = 'shop_fees';

  /// Motorcycle models collection - admin-managed + cashier-addable model list
  /// picked on Job Orders.
  static const String motorcycleModels = 'motorcycle_models';

  /// Custom product tags (spec 2026-09-03) — colored markers attached to
  /// products via `products.tagIds`. Managed in Settings > Product Tags.
  static const String productTags = 'product_tags';

  /// Adjustment reasons collection (spec 2026-09-04) — admin-managed reasons
  /// for stock adjustments (Delivery, Count correction, Damaged, etc.).
  static const String adjustmentReasons = 'adjustment_reasons';

  /// Void requests collection - cashier/staff void requests awaiting admin approval
  static const String voidRequests = 'void_requests';

  /// Void-request pending-claim collection. One doc per sale with an
  /// outstanding void request, keyed by saleId; reserved atomically inside
  /// the same transaction as the `void_requests` doc create, and deleted on
  /// resolve. See docs/superpowers/specs/2026-07-26-race-riders-design.md (R2).
  static const String voidRequestPending = 'void_request_pending';

  /// Product SKU-uniqueness claim collection. One doc per in-use SKU, keyed by
  /// SkuGenerator.normalizeSku(sku); reserved atomically on product create /
  /// SKU rename. See docs/superpowers/specs/2026-06-01-sku-guard-*.
  static const String productSkus = 'product_skus';

  /// Product barcode-uniqueness claim collection. One doc per in-use barcode,
  /// keyed by SkuGenerator.normalizeBarcode(code); reserved atomically on
  /// product create / barcode edit. See docs/superpowers/specs/2026-06-18-barcode-guard-*.
  static const String productBarcodes = 'product_barcodes';

  /// Category-code registry collection for Code128 auto-SKU generation. Holds
  /// a non-numeric `_counter` doc (`{next: int}`) plus one registry doc per
  /// assigned code (`{categoryId, nameSnapshot, assignedAt, nextSequence}`),
  /// keyed by the 4-digit code string. See docs/superpowers/sdd/ Code128
  /// auto-SKU spec.
  static const String categoryCodes = 'category_codes';

  /// Drawer-state collection. Single doc (id `'state'`) tracking the
  /// business-day rollover: `lastSaleDay`/`lastClosedDay` (yyyymmdd ints,
  /// see [businessDayInt]), merge-written by sale creation / day closing.
  /// See docs/superpowers/sdd/ business-day-rollover spec.
  static const String drawerState = 'drawer_state';

  // ==================== SETTINGS DOCUMENTS ====================

  /// Document ID for cost code mapping settings
  static const String costCodeSettings = 'cost_code_mapping';

  /// Document ID for HR settings (week start day + holiday percentages)
  static const String hrSettings = 'hr';

  /// Document ID for general app settings
  static const String generalSettings = 'general';

  // ==================== SUBCOLLECTIONS ====================

  /// Subcollection for sale items within a sale document
  static const String saleItems = 'items';

  /// Subcollection for price history within a product document
  static const String priceHistory = 'price_history';

  /// Subcollection for stock adjustments within a product document
  static const String stockAdjustments = 'stock_adjustments';

  // ==================== FIELD NAMES ====================

  /// Common field names used across collections
  static const String fieldCreatedAt = 'createdAt';
  static const String fieldUpdatedAt = 'updatedAt';
  static const String fieldCreatedBy = 'createdBy';
  static const String fieldUpdatedBy = 'updatedBy';
  static const String fieldIsActive = 'isActive';
}
