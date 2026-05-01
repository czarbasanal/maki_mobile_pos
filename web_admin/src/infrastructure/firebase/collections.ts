// Mirror of lib/core/constants/firestore_collections.dart. Keep field names
// identical to the Dart side — the mobile app reads/writes the same docs.

export const FirestoreCollections = {
  users: 'users',
  products: 'products',
  suppliers: 'suppliers',
  sales: 'sales',
  drafts: 'drafts',
  receivings: 'receivings',
  expenses: 'expenses',
  pettyCash: 'petty_cash',
  userLogs: 'user_logs',
  settings: 'settings',
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
