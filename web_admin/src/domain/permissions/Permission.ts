// Mirror of lib/core/constants/role_permissions.dart. Single source of truth
// for RBAC on the React side. Field names and string values must match the
// Dart enum exactly so audit logs and Firestore rules stay aligned.

import { UserRole } from '../enums';

export const Permission = {
  // POS
  accessPos: 'accessPos',
  processSale: 'processSale',
  applyDiscount: 'applyDiscount',
  voidSale: 'voidSale',
  // Drafts
  saveDraft: 'saveDraft',
  viewDrafts: 'viewDrafts',
  editDraft: 'editDraft',
  deleteDraft: 'deleteDraft',
  // Inventory
  viewInventory: 'viewInventory',
  viewProductCost: 'viewProductCost',
  addProduct: 'addProduct',
  editProduct: 'editProduct',
  editProductLimited: 'editProductLimited',
  deleteProduct: 'deleteProduct',
  // Receiving
  accessReceiving: 'accessReceiving',
  receiveStock: 'receiveStock',
  bulkReceive: 'bulkReceive',
  importCsv: 'importCsv',
  viewReceivingHistory: 'viewReceivingHistory',
  // Suppliers
  viewSuppliers: 'viewSuppliers',
  addSupplier: 'addSupplier',
  editSupplier: 'editSupplier',
  deleteSupplier: 'deleteSupplier',
  // Expenses
  viewExpenses: 'viewExpenses',
  addExpense: 'addExpense',
  editExpense: 'editExpense',
  deleteExpense: 'deleteExpense',
  // Cash
  managePettyCash: 'managePettyCash',
  performCutOff: 'performCutOff',
  // Reports
  viewSalesReports: 'viewSalesReports',
  viewProfitReports: 'viewProfitReports',
  viewDailySalesOnly: 'viewDailySalesOnly',
  // Users
  viewUsers: 'viewUsers',
  addUser: 'addUser',
  editUser: 'editUser',
  deleteUser: 'deleteUser',
  editUserPermissions: 'editUserPermissions',
  // Settings
  viewSettings: 'viewSettings',
  editOwnProfile: 'editOwnProfile',
  editCostCodeMapping: 'editCostCodeMapping',
  // Logs
  viewUserLogs: 'viewUserLogs',
} as const;

export type Permission = (typeof Permission)[keyof typeof Permission];

const cashier: ReadonlySet<Permission> = new Set<Permission>([
  Permission.accessPos,
  Permission.processSale,
  Permission.applyDiscount,
  Permission.saveDraft,
  Permission.viewDrafts,
  Permission.editDraft,
  Permission.deleteDraft,
  Permission.viewInventory,
  Permission.viewSalesReports,
  Permission.viewDailySalesOnly,
  Permission.viewExpenses,
  Permission.addExpense,
  Permission.viewSettings,
  Permission.editOwnProfile,
]);

const staff: ReadonlySet<Permission> = new Set<Permission>([
  Permission.accessPos,
  Permission.processSale,
  Permission.applyDiscount,
  Permission.saveDraft,
  Permission.viewDrafts,
  Permission.editDraft,
  Permission.deleteDraft,
  Permission.viewInventory,
  Permission.editProductLimited,
  Permission.accessReceiving,
  Permission.receiveStock,
  Permission.bulkReceive,
  Permission.viewReceivingHistory,
  Permission.viewSalesReports,
  Permission.viewDailySalesOnly,
  Permission.viewExpenses,
  Permission.addExpense,
  Permission.viewSettings,
  Permission.editOwnProfile,
]);

const admin: ReadonlySet<Permission> = new Set<Permission>([
  Permission.accessPos,
  Permission.processSale,
  Permission.applyDiscount,
  Permission.voidSale,
  Permission.saveDraft,
  Permission.viewDrafts,
  Permission.editDraft,
  Permission.deleteDraft,
  Permission.viewInventory,
  Permission.viewProductCost,
  Permission.addProduct,
  Permission.editProduct,
  Permission.editProductLimited,
  Permission.deleteProduct,
  Permission.accessReceiving,
  Permission.receiveStock,
  Permission.bulkReceive,
  Permission.importCsv,
  Permission.viewReceivingHistory,
  Permission.viewSuppliers,
  Permission.addSupplier,
  Permission.editSupplier,
  Permission.deleteSupplier,
  Permission.viewExpenses,
  Permission.addExpense,
  Permission.editExpense,
  Permission.deleteExpense,
  Permission.managePettyCash,
  Permission.performCutOff,
  Permission.viewSalesReports,
  Permission.viewProfitReports,
  Permission.viewUsers,
  Permission.addUser,
  Permission.editUser,
  Permission.deleteUser,
  Permission.editUserPermissions,
  Permission.viewSettings,
  Permission.editOwnProfile,
  Permission.editCostCodeMapping,
  Permission.viewUserLogs,
]);

const rolePermissions: Record<UserRole, ReadonlySet<Permission>> = {
  cashier,
  staff,
  admin,
};

export function getPermissions(role: UserRole): ReadonlySet<Permission> {
  return rolePermissions[role];
}

export function hasPermission(role: UserRole, permission: Permission): boolean {
  return rolePermissions[role].has(permission);
}

export const passwordProtectedPermissions: ReadonlySet<Permission> = new Set<Permission>([
  Permission.viewProductCost,
  Permission.voidSale,
  Permission.editCostCodeMapping,
]);

export function requiresPassword(permission: Permission): boolean {
  return passwordProtectedPermissions.has(permission);
}
