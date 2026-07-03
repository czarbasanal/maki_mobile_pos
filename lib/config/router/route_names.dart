/// Centralized route name constants.
///
/// Using constants prevents typos and makes refactoring easier.
/// Route names should be descriptive and use camelCase.
abstract class RouteNames {
  // ==================== AUTH ROUTES ====================

  /// Login screen route
  static const String login = 'login';

  /// Access denied route — landing for authenticated users hitting a route
  /// they don't have permission to view.
  static const String accessDenied = 'accessDenied';

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

  /// Product price-history view route
  static const String productPriceHistory = 'productPriceHistory';

  // ==================== RECEIVING ROUTES ====================

  /// Receiving screen route
  static const String receiving = 'receiving';

  /// Bulk receiving route
  static const String bulkReceiving = 'bulkReceiving';

  /// Bulk receiving detail (resume a draft) — `/receiving/bulk/:id`.
  static const String bulkReceivingDetail = 'bulkReceivingDetail';

  /// Full receiving history — `/receiving/history`.
  static const String receivingHistory = 'receivingHistory';

  /// All draft receivings — `/receiving/drafts`.
  static const String receivingDrafts = 'receivingDrafts';

  /// CSV batch-import — `/receiving/import`.
  static const String batchImport = 'batchImport';

  /// Purchase orders list — `/receiving/purchase-orders`.
  static const String purchaseOrders = 'purchaseOrders';

  /// New purchase order (reorder suggestions) — `/receiving/purchase-orders/new`.
  static const String purchaseOrderNew = 'purchaseOrderNew';

  /// Purchase order detail — `/receiving/purchase-orders/:id`.
  static const String purchaseOrderDetail = 'purchaseOrderDetail';

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

  /// Expenses history route — `/expenses/history`.
  static const String expenseHistory = 'expenseHistory';

  // ==================== REPORT ROUTES ====================

  /// Reports dashboard route
  static const String reports = 'reports';

  /// Sales report route
  static const String salesReport = 'salesReport';

  /// Profit report route
  static const String profitReport = 'profitReport';

  /// Labor report route
  static const String laborReport = 'laborReport';

  /// Job Orders reports route (Motorcycle Models + Top Mechanics)
  static const String jobOrderReports = 'jobOrderReports';

  /// Sales transaction history list route
  static const String salesHistory = 'salesHistory';

  /// Price-change report route
  static const String priceChangeReport = 'priceChangeReport';

  /// Top selling drill-down route
  static const String topSelling = 'topSelling';

  /// Sale detail route
  static const String saleDetail = 'saleDetail';

  /// End-of-day closing route
  static const String endOfDay = 'endOfDay';

  /// End-of-day closing history route
  static const String endOfDayHistory = 'endOfDayHistory';

  /// Void requests (admin approval queue) route
  static const String voidRequests = 'voidRequests';

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

  /// Category management hub — `/settings/categories`.
  static const String categorySettings = 'categorySettings';

  /// Per-kind category editor — `/settings/categories/:kind`.
  static const String categoryEditor = 'categoryEditor';

  /// Mechanics admin editor — `/settings/mechanics`.
  static const String mechanics = 'mechanics';

  /// Motorcycle models admin editor — `/settings/motorcycle-models`.
  static const String motorcycleModels = 'motorcycleModels';

  /// About screen route — `/settings/about`.
  static const String about = 'about';

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
  static const String accessDenied = '/access-denied';

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
  static const String receivingHistory = '/receiving/history';
  static const String receivingDrafts = '/receiving/drafts';
  static const String batchImport = '/receiving/import';
  static const String purchaseOrders = '/receiving/purchase-orders';
  static const String purchaseOrderNew = '/receiving/purchase-orders/new';

  // ==================== SUPPLIER PATHS ====================

  static const String suppliers = '/suppliers';
  static const String supplierAdd = '/suppliers/add';
  static const String supplierEdit = '/suppliers/edit/:id';

  // ==================== EXPENSE PATHS ====================

  static const String expenses = '/expenses';
  static const String expenseAdd = '/expenses/add';
  static const String expenseEdit = '/expenses/edit/:id';
  static const String expenseHistory = '/expenses/history';

  // ==================== REPORT PATHS ====================

  static const String reports = '/reports';
  static const String salesReport = '/reports/sales';
  static const String profitReport = '/reports/profit';
  static const String laborReport = '/reports/labor';
  static const String jobOrderReports = '/reports/job-orders';
  static const String salesHistory = '/reports/history';
  static const String priceChangeReport = '/reports/price-changes';
  static const String topSelling = '/reports/top-selling';
  static const String saleDetail = '/reports/sale/:id';
  static const String endOfDay = '/reports/end-of-day';
  static const String endOfDayHistory = '/reports/end-of-day/history';
  static const String voidRequests = '/void-requests';

  // ==================== USER MANAGEMENT PATHS ====================

  static const String users = '/users';
  static const String userAdd = '/users/add';
  static const String userEdit = '/users/edit/:id';

  // ==================== SETTINGS PATHS ====================

  static const String settings = '/settings';
  static const String costCodeSettings = '/settings/cost-codes';
  static const String categorySettings = '/settings/categories';
  static const String categoryEditor = '/settings/categories/:kind';
  static const String mechanics = '/settings/mechanics';
  static const String motorcycleModels = '/settings/motorcycle-models';
  static const String about = '/settings/about';

  // ==================== LOGS PATHS ====================

  static const String userLogs = '/logs';
}
