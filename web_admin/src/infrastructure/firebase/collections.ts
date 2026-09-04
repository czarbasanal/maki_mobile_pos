// Mirror of lib/core/constants/firestore_collections.dart. Keep field names
// identical to the Dart side — the mobile app reads/writes the same docs.

export const FirestoreCollections = {
  users: 'users',
  products: 'products',
  productCategories: 'product_categories',
  expenseCategories: 'expense_categories',
  units: 'units',
  voidReasons: 'void_reasons',
  suppliers: 'suppliers',
  mechanics: 'mechanics',
  employees: 'employees',
  payslips: 'payslips',
  sales: 'sales',
  jobOrders: 'job_orders',
  purchaseOrders: 'purchase_orders',
  receivings: 'receivings',
  expenses: 'expenses',
  userLogs: 'user_logs',
  settings: 'settings',
  // SKU-uniqueness claim collection (Slice A). Keyed by normalizeSku(sku).
  productSkus: 'product_skus',
  // Barcode-uniqueness claim collection. Keyed by normalizeBarcode(code).
  productBarcodes: 'product_barcodes',
  // Code128 category-code registry. Non-numeric doc `_counter` {next: int}
  // plus one registry doc per assigned code
  // {categoryId, nameSnapshot, assignedAt, nextSequence}. Assigned only for
  // product categories. Mirrors
  // lib/core/constants/firestore_collections.dart.
  categoryCodes: 'category_codes',
  // Drawer-state collection. Single doc (id 'state') tracking the
  // business-day rollover: lastSaleDay/lastClosedDay (yyyymmdd ints, see
  // core/utils/businessDay.ts), merge-written by sale creation / day
  // closing. Mirrors lib/core/constants/firestore_collections.dart.
  drawerState: 'drawer_state',
  // Admin-managed shop-fee catalog (edited in mobile Settings; web reads it
  // for the POS fee picker). Mirrors lib/core/constants/firestore_collections.dart.
  shopFees: 'shop_fees',
  // Admin-managed + cashier-addable model list for the Job Order picker.
  motorcycleModels: 'motorcycle_models',
  // Custom product tags (spec 2026-09-03) — attached via products.tagIds.
  productTags: 'product_tags',
  // Stock adjustment reasons (spec 2026-09-04) — soft-deletable audit reasons.
  adjustmentReasons: 'adjustment_reasons',
} as const;

export const SettingsDocs = {
  costCodeMapping: 'cost_code_mapping',
  general: 'general',
  hr: 'hr',
} as const;

export const Subcollections = {
  saleItems: 'items',
  priceHistory: 'price_history',
} as const;

export const FieldNames = {
  createdAt: 'createdAt',
  updatedAt: 'updatedAt',
  createdBy: 'createdBy',
  updatedBy: 'updatedBy',
  isActive: 'isActive',
} as const;
