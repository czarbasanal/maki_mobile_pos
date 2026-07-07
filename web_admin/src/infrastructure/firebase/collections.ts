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
  sales: 'sales',
  drafts: 'drafts',
  receivings: 'receivings',
  expenses: 'expenses',
  userLogs: 'user_logs',
  settings: 'settings',
  // SKU-uniqueness claim collection (Slice A). Keyed by normalizeSku(sku).
  productSkus: 'product_skus',
  // Barcode-uniqueness claim collection. Keyed by normalizeBarcode(code).
  productBarcodes: 'product_barcodes',
} as const;

export const SettingsDocs = {
  costCodeMapping: 'cost_code_mapping',
  general: 'general',
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
