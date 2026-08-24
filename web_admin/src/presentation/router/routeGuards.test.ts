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

describe('canAccess — HR routes (top-level /hr/*, grouped under Admin)', () => {
  const hrPaths = [
    RoutePaths.hr,
    RoutePaths.hrEmployees,
    RoutePaths.hrPayroll,
    RoutePaths.hrPayslips,
    RoutePaths.hrSettings,
  ];

  it('paths are rooted at /hr', () => {
    expect(RoutePaths.hr).toBe('/hr');
    expect(RoutePaths.hrEmployees).toBe('/hr/employees');
    expect(RoutePaths.hrPayroll).toBe('/hr/payroll');
    expect(RoutePaths.hrPayslips).toBe('/hr/payslips');
    expect(RoutePaths.hrPayslipDetail).toBe('/hr/payslips/:id');
    expect(RoutePaths.hrSettings).toBe('/hr/settings');
  });

  it('admin can reach all HR pages, including a concrete payslip detail', () => {
    hrPaths.forEach((path) => {
      expect(canAccess(path, admin)).toBe(true);
    });
    expect(canAccess(`${RoutePaths.hrPayslips}/abc123`, admin)).toBe(true);
  });

  it('cashier is denied all HR pages, including a concrete payslip detail', () => {
    hrPaths.forEach((path) => {
      expect(canAccess(path, cashier)).toBe(false);
    });
    expect(canAccess(`${RoutePaths.hrPayslips}/abc123`, cashier)).toBe(false);
  });

  it('staff is denied all HR pages, including a concrete payslip detail', () => {
    hrPaths.forEach((path) => {
      expect(canAccess(path, staff)).toBe(false);
    });
    expect(canAccess(`${RoutePaths.hrPayslips}/abc123`, staff)).toBe(false);
  });

  it('old /settings/hr/* paths are not guarded routes — redirects handle them', () => {
    expect(canAccess('/settings/hr/employees', admin)).toBe(false);
    expect(canAccess('/settings/hr/payroll', admin)).toBe(false);
    expect(canAccess('/settings/hr/payslips', admin)).toBe(false);
    expect(canAccess('/settings/hr/payslips/abc123', admin)).toBe(false);
    expect(canAccess('/settings/hr/config', admin)).toBe(false);
  });
});

describe('canAccess — forgot-password', () => {
  it('is public: reachable signed out and by any role', () => {
    expect(canAccess(RoutePaths.forgotPassword, null)).toBe(true);
    expect(canAccess(RoutePaths.forgotPassword, admin)).toBe(true);
    expect(canAccess(RoutePaths.forgotPassword, cashier)).toBe(true);
  });
});

describe('canAccess — Job Orders (renamed from Drafts)', () => {
  it('paths are rooted at /job-orders', () => {
    expect(RoutePaths.jobOrders).toBe('/job-orders');
    expect(RoutePaths.jobOrderEdit).toBe('/job-orders/:id');
  });

  it('is a common route for every signed-in role, including a concrete job order', () => {
    expect(canAccess(RoutePaths.jobOrders, admin)).toBe(true);
    expect(canAccess(RoutePaths.jobOrders, cashier)).toBe(true);
    expect(canAccess(RoutePaths.jobOrders, staff)).toBe(true);
    expect(canAccess(`${RoutePaths.jobOrders}/abc123`, admin)).toBe(true);
    expect(canAccess(`${RoutePaths.jobOrders}/abc123`, cashier)).toBe(true);
    expect(canAccess(`${RoutePaths.jobOrders}/abc123`, staff)).toBe(true);
  });

  it('old /drafts paths are no longer routed — they moved, they were not aliased', () => {
    expect(canAccess('/drafts', admin)).toBe(false);
    expect(canAccess('/drafts/abc123', admin)).toBe(false);
  });
});

describe('canAccess — product edit moved into the drawer', () => {
  // The edit URL changed from /inventory/edit/:id to /inventory/:id/edit when
  // editing moved into the product drawer. The new shape matches NEITHER the
  // old '/inventory/edit/' prefix nor the single-segment '/inventory/:id'
  // view rule, so without its own rule it falls through and the gate is wrong.
  it('lets a role that may edit products reach the drawer edit route', () => {
    expect(canAccess('/inventory/p9/edit', admin)).toBe(true);
    expect(canAccess('/inventory/p9/edit', staff)).toBe(true);
  });

  it('keeps a cashier out of the drawer edit route', () => {
    expect(canAccess('/inventory/p9/edit', cashier)).toBe(false);
  });

  it('still gates the legacy /inventory/edit/:id URL the same way', () => {
    // The redirect runs inside the router, so the guard sees the old path
    // first — it must not become a hole.
    expect(canAccess('/inventory/edit/p9', admin)).toBe(true);
    expect(canAccess('/inventory/edit/p9', cashier)).toBe(false);
  });

  it('still lets a view-only role open the product drawer', () => {
    expect(canAccess('/inventory/p9', cashier)).toBe(true);
  });
});
