// Mirror of lib/config/router/route_names.dart's RoutePaths. Keep these
// strings in lock-step with the Dart side — the Flutter web router needs to
// 404 these paths once they're served by the React app.

export const RoutePaths = {
  login: '/login',
  accessDenied: '/access-denied',

  dashboard: '/',
  pos: '/pos',
  checkout: '/pos/checkout',

  drafts: '/drafts',
  draftEdit: '/drafts/:id',

  inventory: '/inventory',
  productAdd: '/inventory/add',
  productEdit: '/inventory/edit/:id',
  productDetail: '/inventory/:id',

  receiving: '/receiving',
  bulkReceiving: '/receiving/bulk',
  bulkReceivingDetail: '/receiving/bulk/:id',

  suppliers: '/suppliers',
  supplierAdd: '/suppliers/add',
  supplierEdit: '/suppliers/edit/:id',

  expenses: '/expenses',
  expenseAdd: '/expenses/add',
  expenseEdit: '/expenses/edit/:id',

  reports: '/reports',
  salesReport: '/reports/sales',
  profitReport: '/reports/profit',
  saleDetail: '/reports/sale/:id',

  users: '/users',
  userAdd: '/users/add',
  userEdit: '/users/edit/:id',

  settings: '/settings',
  costCodeSettings: '/settings/cost-codes',
  about: '/settings/about',

  userLogs: '/logs',

  pettyCash: '/petty-cash',
  pettyCashNew: '/petty-cash/new',
} as const;

export type RoutePath = (typeof RoutePaths)[keyof typeof RoutePaths];
