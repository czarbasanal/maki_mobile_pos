/// Centralized route name constants.
///
/// Using constants prevents typos and makes refactoring easier.
/// Route names should be descriptive and use camelCase.
abstract class RouteNames {
  // ==================== AUTH ROUTES ====================

  /// Login screen route
  static const String login = 'login';

  // ==================== MAIN ROUTES ====================

  /// Dashboard/home route
  static const String dashboard = 'dashboard';

  /// POS screen route
  static const String pos = 'pos';

  /// Checkout screen route
  static const String checkout = 'checkout';

  // ==================== DRAFT ROUTES ====================

  /// Drafts list route
  static const String drafts = 'drafts';

  /// Edit draft route
  static const String draftEdit = 'draftEdit';

  // ==================== INVENTORY ROUTES ====================

  /// Inventory list route
  static const String inventory = 'inventory';

  /// Add product route
  static const String productAdd = 'productAdd';

  /// Edit product route
  static const String productEdit = 'productEdit';

  /// Product detail route
  static const String productDetail = 'productDetail';

  // ==================== RECEIVING ROUTES ====================

  /// Receiving screen route
  static const String receiving = 'receiving';

  /// Bulk receiving route
  static const String bulkReceiving = 'bulkReceiving';

  // ==================== SUPPLIER ROUTES ====================

  /// Suppliers list route
  static const String suppliers = 'suppliers';

  /// Add supplier route
  static const String supplierAdd = 'supplierAdd';

  /// Edit supplier route
  static const String supplierEdit = 'supplierEdit';

  // ==================== EXPENSE ROUTES ====================

  /// Expenses list route
  static const String expenses = 'expenses';

  /// Add expense route
  static const String expenseAdd = 'expenseAdd';

  /// Edit expense route
  static const String expenseEdit = 'expenseEdit';

  // ==================== REPORT ROUTES ====================

  /// Reports dashboard route
  static const String reports = 'reports';

  /// Sales report route
  static const String salesReport = 'salesReport';

  /// Profit report route
  static const String profitReport = 'profitReport';

  /// Sale detail route
  static const String saleDetail = 'saleDetail';

  // ==================== USER MANAGEMENT ROUTES ====================

  /// Users list route
  static const String users = 'users';

  /// Add user route
  static const String userAdd = 'userAdd';

  /// Edit user route
  static const String userEdit = 'userEdit';

  // ==================== SETTINGS ROUTES ====================

  /// Settings screen route
  static const String settings = 'settings';

  /// Cost code settings route
  static const String costCodeSettings = 'costCodeSettings';

  // ==================== LOGS ROUTES ====================

  /// User logs route
  static const String userLogs = 'userLogs';
}

/// Route paths (URL paths).
///
/// Paths define the actual URL structure.
/// Using a separate class keeps paths and names organized.
abstract class RoutePaths {
  // ==================== AUTH PATHS ====================

  static const String login = '/login';

  // ==================== MAIN PATHS ====================

  static const String dashboard = '/';
  static const String pos = '/pos';
  static const String checkout = '/pos/checkout';

  // ==================== DRAFT PATHS ====================

  static const String drafts = '/drafts';
  static const String draftEdit = '/drafts/:id';

  // ==================== INVENTORY PATHS ====================

  static const String inventory = '/inventory';
  static const String productAdd = '/inventory/add';
  static const String productEdit = '/inventory/edit/:id';
  static const String productDetail = '/inventory/:id';

  // ==================== RECEIVING PATHS ====================

  static const String receiving = '/receiving';
  static const String bulkReceiving = '/receiving/bulk';

  // ==================== SUPPLIER PATHS ====================

  static const String suppliers = '/suppliers';
  static const String supplierAdd = '/suppliers/add';
  static const String supplierEdit = '/suppliers/edit/:id';

  // ==================== EXPENSE PATHS ====================

  static const String expenses = '/expenses';
  static const String expenseAdd = '/expenses/add';
  static const String expenseEdit = '/expenses/edit/:id';

  // ==================== REPORT PATHS ====================

  static const String reports = '/reports';
  static const String salesReport = '/reports/sales';
  static const String profitReport = '/reports/profit';
  static const String saleDetail = '/reports/sale/:id';

  // ==================== USER MANAGEMENT PATHS ====================

  static const String users = '/users';
  static const String userAdd = '/users/add';
  static const String userEdit = '/users/edit/:id';

  // ==================== SETTINGS PATHS ====================

  static const String settings = '/settings';
  static const String costCodeSettings = '/settings/cost-codes';

  // ==================== LOGS PATHS ====================

  static const String userLogs = '/logs';
}
