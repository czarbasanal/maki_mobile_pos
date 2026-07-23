import { describe, expect, it } from 'vitest';
import { canAccess } from './routeGuards';
import { RoutePaths } from './routePaths';
import { UserRole } from '@/domain/enums';
import type { User } from '@/domain/entities/User';

const admin: User = {
  id: 'u1',
  email: 'admin@shop.test',
  displayName: 'Admin',
  role: UserRole.admin,
  isActive: true,
  phoneNumber: null,
  photoUrl: null,
  createdAt: new Date('2026-01-01'),
  updatedAt: null,
  createdBy: null,
  updatedBy: null,
  lastLoginAt: null,
};

const cashier: User = { ...admin, id: 'u2', email: 'cashier@shop.test', role: UserRole.cashier };
const staff: User = { ...admin, id: 'u3', email: 'staff@shop.test', role: UserRole.staff };

describe('canAccess — settings routes', () => {
  it('admin can reach the admin-managed list pages', () => {
    // Manage Lists already works; Mechanics is the same manageCategories gate.
    expect(canAccess(RoutePaths.manageLists, admin)).toBe(true);
    expect(canAccess(RoutePaths.mechanics, admin)).toBe(true);
  });
});

describe('canAccess — HR routes', () => {
  const hrPaths = [
    RoutePaths.hrEmployees,
    RoutePaths.hrPayroll,
    RoutePaths.hrPayslips,
    RoutePaths.hrSettings,
  ];

  it('admin can reach all HR pages, including a concrete payslip detail', () => {
    hrPaths.forEach((path) => {
      expect(canAccess(path, admin)).toBe(true);
    });
    expect(canAccess('/hr/payslips/abc123', admin)).toBe(true);
  });

  it('cashier is denied all HR pages, including a concrete payslip detail', () => {
    hrPaths.forEach((path) => {
      expect(canAccess(path, cashier)).toBe(false);
    });
    expect(canAccess('/hr/payslips/abc123', cashier)).toBe(false);
  });

  it('staff is denied all HR pages, including a concrete payslip detail', () => {
    hrPaths.forEach((path) => {
      expect(canAccess(path, staff)).toBe(false);
    });
    expect(canAccess('/hr/payslips/abc123', staff)).toBe(false);
  });
});

describe('canAccess — forgot-password', () => {
  it('is public: reachable signed out and by any role', () => {
    expect(canAccess(RoutePaths.forgotPassword, null)).toBe(true);
    expect(canAccess(RoutePaths.forgotPassword, admin)).toBe(true);
    expect(canAccess(RoutePaths.forgotPassword, cashier)).toBe(true);
  });
});
