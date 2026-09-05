// Users screen derivations (users guide §1/§2): last-sign-in staleness with
// the escalating bands, and ONE summary that feeds the role card, the KPIs
// and the last-admin guard.
import { describe, expect, it } from 'vitest';
import type { User } from '@/domain/entities';
import { UserRole } from '@/domain/enums';
import { roleScope, signInStaleness, summarizeUsers } from './userSignIn';

const NOW = new Date('2026-09-05T06:00:00Z');
const daysAgo = (n: number) => new Date(NOW.getTime() - n * 86_400_000);

function u(o: Partial<User> = {}): User {
  return {
    id: 'u', email: 'a@b.c', displayName: 'A', role: UserRole.cashier, isActive: true,
    phoneNumber: null, photoUrl: null, createdAt: daysAgo(60), updatedAt: null,
    createdBy: null, updatedBy: null, lastLoginAt: daysAgo(1), ...o,
  };
}

describe('signInStaleness', () => {
  it('counts whole SHOP days: today / yesterday / N days ago; quiet to a week, amber to 29, red from 30', () => {
    expect(signInStaleness(daysAgo(0), NOW)).toEqual({ label: 'today', tone: 'ink-3', days: 0 });
    // 20 hours ago but across the shop midnight — yesterday, not "today".
    expect(signInStaleness(new Date(NOW.getTime() - 20 * 3_600_000), NOW).label).toBe('yesterday');
    expect(signInStaleness(daysAgo(1), NOW)).toEqual({ label: 'yesterday', tone: 'ink-3', days: 1 });
    expect(signInStaleness(daysAgo(7), NOW)).toEqual({ label: '7 days ago', tone: 'ink-3', days: 7 });
    expect(signInStaleness(daysAgo(8), NOW)).toEqual({ label: '8 days ago', tone: 'accent-text', days: 8 });
    expect(signInStaleness(daysAgo(29), NOW).tone).toBe('accent-text');
    expect(signInStaleness(daysAgo(30), NOW)).toEqual({ label: '30 days ago', tone: 'neg', days: 30 });
  });
  it('never signed in is red with the invite line', () => {
    expect(signInStaleness(null, NOW)).toEqual({ label: 'invite not accepted', tone: 'neg', days: null });
  });
});

describe('summarizeUsers', () => {
  const users = [
    u({ id: 'me', role: UserRole.admin, lastLoginAt: daysAgo(1) }),
    u({ id: 'a2', role: UserRole.admin, lastLoginAt: daysAgo(43) }),
    u({ id: 's1', role: UserRole.staff, lastLoginAt: daysAgo(65) }),
    u({ id: 'c1', role: UserRole.cashier, lastLoginAt: daysAgo(1) }),
    u({ id: 'c2', role: UserRole.cashier, lastLoginAt: daysAgo(41) }),
    u({ id: 'x', role: UserRole.staff, isActive: false, lastLoginAt: null }),
    u({ id: 'y', role: UserRole.admin, isActive: false, lastLoginAt: daysAgo(2) }),
  ];
  const s = summarizeUsers(users, NOW);

  it('counts active accounts by role and the active admins for the last-admin guard', () => {
    expect(s.active).toBe(5);
    expect(s.byRole).toEqual({ admin: 2, staff: 1, cashier: 2 });
    expect(s.activeAdminCount).toBe(2);
  });
  it('sign-in KPIs read the active set; never-signed-in counts every account', () => {
    expect(s.signedInThisWeek).toBe(2);
    expect(s.dormant30).toBe(3);
    expect(s.neverSignedIn).toBe(1);
  });
  it('the zero case is all zeros', () => {
    expect(summarizeUsers([], NOW)).toEqual({
      active: 0, byRole: { admin: 0, staff: 0, cashier: 0 },
      signedInThisWeek: 0, dormant30: 0, neverSignedIn: 0, activeAdminCount: 0,
    });
  });
});

describe('roleScope', () => {
  it('names each role in three words and a sentence', () => {
    expect(roleScope.admin.can).toBe('full access');
    expect(roleScope.staff.can).toBe('stock & jobs');
    expect(roleScope.cashier.can).toBe('register only');
    expect(roleScope.cashier.desc).toMatch(/Voids need approval/);
  });
});
