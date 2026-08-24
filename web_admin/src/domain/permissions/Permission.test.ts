import { describe, expect, it } from 'vitest';
import { Permission, getPermissions, hasPermission } from './Permission';
import { UserRole } from '../enums';

describe('Permission — role permissions', () => {
  it('cashier has editExpense and deleteExpense (shop policy 2026-07-04)', () => {
    const perms = getPermissions(UserRole.cashier);
    expect(perms.has(Permission.editExpense)).toBe(true);
    expect(perms.has(Permission.deleteExpense)).toBe(true);
  });

  it('staff has editExpense and deleteExpense (shop policy 2026-07-04)', () => {
    const perms = getPermissions(UserRole.staff);
    expect(perms.has(Permission.editExpense)).toBe(true);
    expect(perms.has(Permission.deleteExpense)).toBe(true);
  });

  it('admin has editExpense and deleteExpense', () => {
    const perms = getPermissions(UserRole.admin);
    expect(perms.has(Permission.editExpense)).toBe(true);
    expect(perms.has(Permission.deleteExpense)).toBe(true);
  });

  it('hasPermission() returns true for cashier editExpense', () => {
    expect(hasPermission(UserRole.cashier, Permission.editExpense)).toBe(true);
  });

  it('hasPermission() returns true for staff deleteExpense', () => {
    expect(hasPermission(UserRole.staff, Permission.deleteExpense)).toBe(true);
  });
});

// Mirror parity with lib/core/constants/role_permissions.dart — pinned when
// cashier gained web access (2026-08-24). The web sets must match mobile
// EXACTLY; these vectors are the tripwire.
describe('Permission — mobile-parity vectors (cashier web access)', () => {
  it('cashier holds the full mobile cashier set', () => {
    const expected: Permission[] = [
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
      Permission.editExpense,
      Permission.deleteExpense,
      Permission.viewEndOfDay,
      Permission.closeDay,
      Permission.viewSettings,
      Permission.editOwnProfile,
      Permission.editLists,
    ];
    const actual = getPermissions(UserRole.cashier);
    expect([...actual].sort()).toEqual([...expected].sort());
  });

  it('cashier lacks the sensitive grants', () => {
    for (const p of [
      Permission.voidSale,
      Permission.viewProductCost,
      Permission.manageCategories,
      Permission.editProductCategories,
      Permission.addProduct,
      Permission.editProduct,
      Permission.editProductLimited,
      Permission.deleteProduct,
      Permission.accessReceiving,
      Permission.viewProfitReports,
      Permission.viewJobOrderReports,
      Permission.viewUsers,
      Permission.viewUserLogs,
      Permission.manageHr,
      Permission.editCostCodeMapping,
    ]) {
      expect(hasPermission(UserRole.cashier, p)).toBe(false);
    }
  });

  it('staff mirrors mobile (requestVoidSale, lists management, EOD, addProduct)', () => {
    for (const p of [
      Permission.requestVoidSale,
      Permission.editLists,
      Permission.manageCategories,
      Permission.editProductCategories,
      Permission.viewEndOfDay,
      Permission.closeDay,
      Permission.addProduct,
    ]) {
      expect(hasPermission(UserRole.staff, p)).toBe(true);
    }
    expect(hasPermission(UserRole.staff, Permission.voidSale)).toBe(false);
    expect(hasPermission(UserRole.staff, Permission.importCsv)).toBe(false);
  });

  it('admin mirrors mobile (voids directly — no requestVoidSale; full lists + EOD + JO analytics)', () => {
    for (const p of [
      Permission.voidSale,
      Permission.editLists,
      Permission.editProductCategories,
      Permission.viewEndOfDay,
      Permission.closeDay,
      Permission.viewJobOrderReports,
    ]) {
      expect(hasPermission(UserRole.admin, p)).toBe(true);
    }
    expect(hasPermission(UserRole.admin, Permission.requestVoidSale)).toBe(false);
    expect(hasPermission(UserRole.admin, Permission.viewDailySalesOnly)).toBe(false);
  });
});
