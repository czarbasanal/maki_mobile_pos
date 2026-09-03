// Mirror of lib/config/router/route_names.dart's RoutePaths. Keep these
// strings in lock-step with the Dart side — the Flutter web router needs to
// 404 these paths once they're served by the React app.

export const RoutePaths = {
  login: '/login',
  forgotPassword: '/forgot-password',
  accessDenied: '/access-denied',

  dashboard: '/',
  pos: '/pos',
  checkout: '/pos/checkout',

  jobOrders: '/job-orders',
  voidRequests: '/void-requests',
  purchaseOrders: '/purchase-orders',
  purchaseOrderNew: '/purchase-orders/new',
  purchaseOrderDetail: '/purchase-orders/:id',
  jobOrderEdit: '/job-orders/:id',

  inventory: '/inventory',
  productAdd: '/inventory/add',
  // Editing lives inside the product drawer; /inventory/edit/:id redirects here.
  productEdit: '/inventory/:id/edit',
  // Top level, not under /inventory: the sidebar marks a parent active for
  // any path beneath it, so a nested URL lit Inventory up while Price History
  // was the page you were on.
  priceHistory: '/price-history',

  receiving: '/receiving',
  receivingNew: '/receiving/new',
  receivingNewDraft: '/receiving/new/:id',
  receivingHistory: '/receiving/history',
  bulkReceiving: '/receiving/bulk',
  receivingDetail: '/receiving/:id',

  suppliers: '/suppliers',
  supplierAdd: '/suppliers/add',
  supplierEdit: '/suppliers/edit/:id',

  expenses: '/expenses',
  expenseAdd: '/expenses/add',
  expenseEdit: '/expenses/edit/:id',

  reports: '/reports',
  salesReport: '/reports/sales',
  // Web-only (no Flutter mirror) — the dashboard's "View all" destination.
  daySales: '/sales/day',
  profitReport: '/reports/profit',
  laborReport: '/reports/labor',
  priceChangeReport: '/reports/price-changes',
  saleDetail: '/reports/sale/:id',

  users: '/users',
  userAdd: '/users/add',
  userEdit: '/users/edit/:id',

  settings: '/settings',
  costCodeSettings: '/settings/cost-codes',
  timezoneSettings: '/settings/timezone',
  manageLists: '/settings/lists',
  mechanics: '/settings/mechanics',
  productTags: '/settings/tags',
  about: '/settings/about',

  userLogs: '/logs',

  hr: '/hr',
  hrEmployees: '/hr/employees',
  hrPayroll: '/hr/payroll',
  hrPayslips: '/hr/payslips',
  hrPayslipDetail: '/hr/payslips/:id',
  hrSettings: '/hr/settings',
} as const;

export type RoutePath = (typeof RoutePaths)[keyof typeof RoutePaths];
