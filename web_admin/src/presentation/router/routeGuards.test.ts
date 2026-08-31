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

  it('lets a cashier into the drawer edit route (name-only editing)', () => {
    expect(canAccess('/inventory/p9/edit', cashier)).toBe(true);
  });

  it('still gates the legacy /inventory/edit/:id URL the same way', () => {
    // The redirect runs inside the router, so the guard sees the old path
    // first — it must gate identically to the new shape.
    expect(canAccess('/inventory/edit/p9', admin)).toBe(true);
    expect(canAccess('/inventory/edit/p9', cashier)).toBe(true);
  });

  it('still lets a view-only role open the product drawer', () => {
    expect(canAccess('/inventory/p9', cashier)).toBe(true);
  });
});

// Pinned when cashiers gained web access (2026-08-24) — the full mobile-parity
// access map for the cashier role.
describe('canAccess — cashier web access map', () => {
  it('reaches the mobile-parity destinations', () => {
    for (const path of [
      '/',
      '/pos',
      '/pos/checkout',
      '/job-orders',
      '/job-orders/j1',
      '/inventory',
      '/inventory/p9',
      '/expenses',
      '/expenses/add',
      '/expenses/edit/e1',
      '/reports',
      '/reports/sales',
      '/reports/labor',
      '/reports/sale/s1',
      '/sales/day',
      '/settings',
      '/settings/about',
      '/settings/lists',
      '/settings/mechanics',
    ]) {
      expect(canAccess(path, cashier)).toBe(true);
    }
  });

  it('stays out of everything cost-, admin-, or stock-facing', () => {
    for (const path of [
      '/reports/profit',
      '/reports/price-changes',
      '/inventory/add',
      '/inventory/price-history',
      // Reorder became the buying list; both views show cost.
      '/purchase-orders',
      '/purchase-orders/new',
      '/users',
      '/logs',
      '/hr',
      '/hr/payroll',
      '/receiving',
      '/receiving/new',
      '/suppliers',
      '/settings/cost-codes',
    ]) {
      expect(canAccess(path, cashier)).toBe(false);
    }
  });
});

describe('/settings/timezone', () => {
  it('is reachable by an admin', () => {
    expect(canAccess(RoutePaths.timezoneSettings, admin)).toBe(true);
  });

  // Gated on viewSettings: everyone who can open Settings can SEE the shop
  // clock (it explains why their reports roll over when they do). Editing is
  // admin-only, enforced on the page itself — same split as the mobile screen.
  it('is readable by a cashier and by staff', () => {
    expect(canAccess(RoutePaths.timezoneSettings, cashier)).toBe(true);
    expect(canAccess(RoutePaths.timezoneSettings, staff)).toBe(true);
  });

  it('is blocked for a deactivated admin', () => {
    expect(canAccess(RoutePaths.timezoneSettings, { ...admin, isActive: false })).toBe(false);
  });
});

describe('canAccess — void requests queue', () => {
  it('admins reach it', () => {
    expect(canAccess(RoutePaths.voidRequests, admin)).toBe(true);
  });

  it('cashiers do not — they file requests, they do not approve them', () => {
    // Approving voids the sale and restores stock, so the queue is gated on
    // voidSale rather than on a weaker view right.
    expect(canAccess(RoutePaths.voidRequests, cashier)).toBe(false);
    expect(canAccess(RoutePaths.voidRequests, staff)).toBe(false);
  });
});
