// Mirror of lib/config/router/route_guards.dart. The React app is admin-only
// for now, but `canAccess` is implemented faithfully so the same gating logic
// can be reused as more roles get web access in the future.

import type { User } from '@/domain/entities';
import { Permission, hasPermission } from '@/domain/permissions/Permission';
import { RoutePaths } from './routePaths';

const publicRoutes: ReadonlySet<string> = new Set([RoutePaths.login]);

const commonRoutes: ReadonlySet<string> = new Set([
  RoutePaths.dashboard,
  RoutePaths.pos,
  RoutePaths.checkout,
  RoutePaths.drafts,
]);

const protectedRoutes: ReadonlyMap<string, Permission> = new Map<string, Permission>([
  [RoutePaths.inventory, Permission.viewInventory],
  [RoutePaths.productAdd, Permission.addProduct],
  [RoutePaths.receiving, Permission.accessReceiving],
  [RoutePaths.bulkReceiving, Permission.bulkReceive],
  [RoutePaths.suppliers, Permission.viewSuppliers],
  [RoutePaths.supplierAdd, Permission.addSupplier],
  [RoutePaths.expenses, Permission.viewExpenses],
  [RoutePaths.expenseAdd, Permission.addExpense],
  [RoutePaths.reports, Permission.viewSalesReports],
  [RoutePaths.salesReport, Permission.viewSalesReports],
  [RoutePaths.profitReport, Permission.viewProfitReports],
  [RoutePaths.users, Permission.viewUsers],
  [RoutePaths.userAdd, Permission.addUser],
  [RoutePaths.settings, Permission.viewSettings],
  [RoutePaths.costCodeSettings, Permission.editCostCodeMapping],
  [RoutePaths.userLogs, Permission.viewUserLogs],
  [RoutePaths.pettyCash, Permission.managePettyCash],
  [RoutePaths.pettyCashNew, Permission.managePettyCash],
]);

export function isPublicRoute(path: string): boolean {
  return publicRoutes.has(path);
}

export function isCommonRoute(path: string): boolean {
  if (commonRoutes.has(path)) return true;
  if (path.startsWith('/drafts/')) return true;
  return false;
}

export function canAccess(path: string, user: User | null): boolean {
  if (isPublicRoute(path)) return true;
  if (!user) return false;
  if (!user.isActive) return false;
  if (path === RoutePaths.accessDenied) return true;
  if (isCommonRoute(path)) return true;

  const exact = protectedRoutes.get(path);
  if (exact) return hasPermission(user.role, exact);

  return checkDynamicRoute(path, user);
}

function checkDynamicRoute(path: string, user: User): boolean {
  if (path.startsWith('/inventory/edit/')) {
    return (
      hasPermission(user.role, Permission.editProduct) ||
      hasPermission(user.role, Permission.editProductLimited)
    );
  }
  if (/^\/inventory\/[^/]+$/.test(path)) {
    return hasPermission(user.role, Permission.viewInventory);
  }
  if (path.startsWith('/suppliers/edit/')) {
    return hasPermission(user.role, Permission.editSupplier);
  }
  if (path.startsWith('/expenses/edit/')) {
    return hasPermission(user.role, Permission.editExpense);
  }
  if (path.startsWith('/reports/sale/')) {
    return hasPermission(user.role, Permission.viewSalesReports);
  }
  if (path.startsWith('/users/edit/')) {
    return hasPermission(user.role, Permission.editUser);
  }
  if (path.startsWith('/receiving/bulk/')) {
    return hasPermission(user.role, Permission.bulkReceive);
  }
  if (path === RoutePaths.about) {
    return hasPermission(user.role, Permission.viewSettings);
  }
  return false;
}

export function getRedirectPath(user: User | null, _attemptedPath: string): string {
  if (!user) return RoutePaths.login;
  return RoutePaths.dashboard;
}
