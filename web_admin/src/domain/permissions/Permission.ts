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
  requestVoidSale: 'requestVoidSale',
  // Job Orders
  saveJobOrder: 'saveJobOrder',
  viewJobOrders: 'viewJobOrders',
  editJobOrder: 'editJobOrder',
  deleteJobOrder: 'deleteJobOrder',
  // Inventory
  viewInventory: 'viewInventory',
  viewProductCost: 'viewProductCost',
  addProduct: 'addProduct',
  editProduct: 'editProduct',
  editProductLimited: 'editProductLimited',
  editProductNameOnly: 'editProductNameOnly',
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
  // End-of-day closing
  viewEndOfDay: 'viewEndOfDay',
  closeDay: 'closeDay',
  // Reports
  viewSalesReports: 'viewSalesReports',
  viewProfitReports: 'viewProfitReports',
  viewDailySalesOnly: 'viewDailySalesOnly',
  viewJobOrderReports: 'viewJobOrderReports',
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
  manageCategories: 'manageCategories',
  editLists: 'editLists',
  editProductCategories: 'editProductCategories',
  // Logs
  viewUserLogs: 'viewUserLogs',
  // HR / Payroll
  manageHr: 'manageHr',
} as const;

export type Permission = (typeof Permission)[keyof typeof Permission];

const cashier: ReadonlySet<Permission> = new Set<Permission>([
  Permission.accessPos,
  Permission.processSale,
  Permission.applyDiscount,
  Permission.requestVoidSale,
  Permission.saveJobOrder,
  Permission.viewJobOrders,
  Permission.editJobOrder,
  Permission.deleteJobOrder,
  Permission.viewInventory,
  Permission.editProductNameOnly,
  Permission.viewSalesReports,
  Permission.viewDailySalesOnly,
  Permission.viewExpenses,
  Permission.addExpense,
  // Expenses (shop policy 2026-07-04: cashiers/staff record, fix, and remove
  // their own entry mistakes; activity log keeps the trail)
  Permission.editExpense,
  Permission.deleteExpense,
  Permission.viewEndOfDay,
  Permission.closeDay,
  Permission.viewSettings,
  Permission.editOwnProfile,
  // Shared lists (2026-07-24): cashiers add and edit entries; deactivate /
  // reactivate stays staff+admin (manageCategories).
  Permission.editLists,
]);

const staff: ReadonlySet<Permission> = new Set<Permission>([
  Permission.accessPos,
  Permission.processSale,
  Permission.applyDiscount,
  Permission.requestVoidSale,
  Permission.saveJobOrder,
  Permission.viewJobOrders,
  Permission.editJobOrder,
  Permission.deleteJobOrder,
  Permission.viewInventory,
  Permission.editProductLimited,
  // Staff add products by entering a cost CODE; the numeric cost is decoded
  // in the create flow and never shown in the staff UI (mobile parity).
  Permission.addProduct,
  Permission.accessReceiving,
  Permission.receiveStock,
  Permission.bulkReceive,
  Permission.viewReceivingHistory,
  Permission.viewSalesReports,
  Permission.viewDailySalesOnly,
  Permission.viewExpenses,
  Permission.addExpense,
  // Expenses (shop policy 2026-07-04: cashiers/staff record, fix, and remove
  // their own entry mistakes; activity log keeps the trail)
  Permission.editExpense,
  Permission.deleteExpense,
  Permission.viewEndOfDay,
  Permission.closeDay,
  Permission.viewSettings,
  Permission.editOwnProfile,
  // Shared lists (2026-07-24): staff fully manage incl. deactivate.
  Permission.editLists,
  Permission.manageCategories,
  Permission.editProductCategories,
]);

const admin: ReadonlySet<Permission> = new Set<Permission>([
  Permission.accessPos,
  Permission.processSale,
  Permission.applyDiscount,
  Permission.voidSale,
  Permission.saveJobOrder,
  Permission.viewJobOrders,
  Permission.editJobOrder,
  Permission.deleteJobOrder,
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
  Permission.viewEndOfDay,
  Permission.closeDay,
  Permission.viewSalesReports,
  Permission.viewProfitReports,
  Permission.viewJobOrderReports,
  Permission.viewUsers,
  Permission.addUser,
  Permission.editUser,
  Permission.deleteUser,
  Permission.editUserPermissions,
  Permission.viewSettings,
  Permission.editOwnProfile,
  Permission.editCostCodeMapping,
  Permission.manageCategories,
  Permission.editLists,
  Permission.editProductCategories,
  Permission.viewUserLogs,
  Permission.manageHr,
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
