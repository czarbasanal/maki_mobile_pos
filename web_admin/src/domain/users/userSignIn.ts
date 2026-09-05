// Users screen derivations (users guide §1/§2). Last sign-in is the column
// that answers "is this account still in use", and its staleness escalates:
// ≤7 days quiet, 8–29 amber, ≥30 red, never red with the invite line.
import type { User } from '../entities';
import { UserRole } from '../enums';

export type StalenessTone = 'ink-3' | 'accent-text' | 'neg';

export interface SignInStaleness {
  label: string;
  tone: StalenessTone;
  /** Whole days since the last sign-in; null when never. */
  days: number | null;
}

export function signInStaleness(lastLoginAt: Date | null, now: Date): SignInStaleness {
  if (!lastLoginAt) return { label: 'invite not accepted', tone: 'neg', days: null };
  const days = Math.max(0, Math.floor((now.getTime() - lastLoginAt.getTime()) / 86_400_000));
  const label = days <= 1 ? 'today' : `${days} days ago`;
  const tone: StalenessTone = days >= 30 ? 'neg' : days > 7 ? 'accent-text' : 'ink-3';
  return { label, tone, days };
}

export interface UsersSummary {
  active: number;
  byRole: Record<UserRole, number>;
  signedInThisWeek: number;
  dormant30: number;
  neverSignedIn: number;
  /** Drives the last-admin guard in the modal. From the FULL subscription, never a page. */
  activeAdminCount: number;
}

export function summarizeUsers(users: User[], now: Date): UsersSummary {
  const active = users.filter((x) => x.isActive);
  const days = (x: User) => signInStaleness(x.lastLoginAt, now).days;
  return {
    active: active.length,
    byRole: {
      admin: active.filter((x) => x.role === UserRole.admin).length,
      staff: active.filter((x) => x.role === UserRole.staff).length,
      cashier: active.filter((x) => x.role === UserRole.cashier).length,
    },
    signedInThisWeek: active.filter((x) => { const d = days(x); return d !== null && d <= 7; }).length,
    dormant30: active.filter((x) => { const d = days(x); return d !== null && d >= 30; }).length,
    neverSignedIn: users.filter((x) => x.lastLoginAt === null).length,
    activeAdminCount: active.filter((x) => x.role === UserRole.admin).length,
  };
}

/** What each role can do — three words for the card, a sentence for the picker. */
export const roleScope: Record<UserRole, { can: string; desc: string }> = {
  admin: { can: 'full access', desc: 'Everything, including users, voids, pricing and reports.' },
  staff: { can: 'stock & jobs', desc: 'Job orders, inventory and receiving. No money screens or users.' },
  cashier: { can: 'register only', desc: 'The register and their own sales. Voids need approval.' },
};
