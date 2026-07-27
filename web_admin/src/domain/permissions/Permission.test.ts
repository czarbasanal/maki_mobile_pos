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
