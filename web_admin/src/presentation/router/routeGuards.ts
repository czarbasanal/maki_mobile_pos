// Mirror of lib/config/router/route_guards.dart. Admins and cashiers have web
// access (cashiers since 2026-08-24, with mobile-parity privileges enforced
// here); the role allowlist itself lives in ProtectedRoute/LoginPage.

import type { User } from '@/domain/entities';
import { Permission, hasPermission } from '@/domain/permissions/Permission';
import { RoutePaths } from './routePaths';

const publicRoutes: ReadonlySet<string> = new Set([RoutePaths.login, RoutePaths.forgotPassword]);

const commonRoutes: ReadonlySet<string> = new Set([
  RoutePaths.dashboard,
  RoutePaths.pos,
  RoutePaths.checkout,
  RoutePaths.jobOrders,
]);

const protectedRoutes: ReadonlyMap<string, Permission> = new Map<string, Permission>([
  [RoutePaths.inventory, Permission.viewInventory],
  [RoutePaths.productAdd, Permission.addProduct],
  // Price history exposes cost → admin-only. Exact match wins over the generic
  // /^\/inventory\/[^/]+$/ dynamic rule below (which would grant viewInventory).
  [RoutePaths.priceHistory, Permission.viewProductCost],
  // Buying. Gated on cost, not on receiving access: every view here shows
  // what parts cost, and a cashier who may receive stock still may not see
  // that. Creating one additionally means committing to spend.
  [RoutePaths.purchaseOrders, Permission.viewProductCost],
  [RoutePaths.purchaseOrderNew, Permission.receiveStock],
  [RoutePaths.receiving, Permission.accessReceiving],
  [RoutePaths.receivingNew, Permission.receiveStock],
  [RoutePaths.receivingHistory, Permission.viewReceivingHistory],
  [RoutePaths.bulkReceiving, Permission.bulkReceive],
  [RoutePaths.suppliers, Permission.viewSuppliers],
  [RoutePaths.supplierAdd, Permission.addSupplier],
  [RoutePaths.expenses, Permission.viewExpenses],
  [RoutePaths.expenseAdd, Permission.addExpense],
  [RoutePaths.reports, Permission.viewSalesReports],
  [RoutePaths.salesReport, Permission.viewSalesReports],
  [RoutePaths.daySales, Permission.viewSalesReports],
  [RoutePaths.profitReport, Permission.viewProfitReports],
  [RoutePaths.laborReport, Permission.viewSalesReports],
  [RoutePaths.priceChangeReport, Permission.viewProductCost],
  // Approving a request voids the sale, so the queue is gated on the same
  // permission as the void itself rather than on a weaker "view" right.
  [RoutePaths.voidRequests, Permission.voidSale],
  [RoutePaths.users, Permission.viewUsers],
  [RoutePaths.userAdd, Permission.addUser],
  [RoutePaths.settings, Permission.viewSettings],
  [RoutePaths.costCodeSettings, Permission.editCostCodeMapping],
  [RoutePaths.timezoneSettings, Permission.viewSettings],
  // Route-level gate is editLists (mobile parity) — deactivate/reactivate and
  // delete are gated in-page by manageCategories.
  [RoutePaths.manageLists, Permission.editLists],
  [RoutePaths.mechanics, Permission.editLists],
  [RoutePaths.productTags, Permission.editLists],
  [RoutePaths.userLogs, Permission.viewUserLogs],
  [RoutePaths.hr, Permission.manageHr],
  [RoutePaths.hrEmployees, Permission.manageHr],
  [RoutePaths.hrPayroll, Permission.manageHr],
  [RoutePaths.hrPayslips, Permission.manageHr],
  [RoutePaths.hrSettings, Permission.manageHr],
]);

export function isPublicRoute(path: string): boolean {
  return publicRoutes.has(path);
}

export function isCommonRoute(path: string): boolean {
  if (commonRoutes.has(path)) return true;
  if (path.startsWith('/job-orders/')) return true;
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
  // Editing lives at /inventory/:id/edit (inside the product drawer). The
  // legacy /inventory/edit/:id still redirects there, and the guard runs before
  // the redirect, so BOTH shapes must gate identically — otherwise the old URL
  // becomes a hole or the new one locks everyone out. Must come before the
  // single-segment view rule below, which this path would never match anyway.
  if (path.startsWith('/inventory/edit/') || /^\/inventory\/[^/]+\/edit$/.test(path)) {
    return (
      hasPermission(user.role, Permission.editProduct) ||
      hasPermission(user.role, Permission.editProductLimited) ||
      hasPermission(user.role, Permission.editProductNameOnly)
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
  if (path.startsWith('/receiving/new/')) {
    return hasPermission(user.role, Permission.receiveStock);
  }
  // /receiving/:id — the read-only receiving detail (static /receiving/new,
  // /receiving/history, /receiving/bulk are matched as exact routes first).
  if (path.startsWith('/receiving/')) {
    return hasPermission(user.role, Permission.viewReceivingHistory);
  }
  if (path === RoutePaths.about) {
    return hasPermission(user.role, Permission.viewSettings);
  }
  // /hr/payslips/:id — the concrete payslip detail (the static
  // /hr/payslips list is matched as an exact route first).
  if (path.startsWith('/hr/payslips/')) {
    return hasPermission(user.role, Permission.manageHr);
  }
  return false;
}

export function getRedirectPath(user: User | null, _attemptedPath: string): string {
  if (!user) return RoutePaths.login;
  return RoutePaths.dashboard;
}
