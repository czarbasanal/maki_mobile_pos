import { describe, expect, it } from 'vitest';
import { UserRole } from '@/domain/enums';
import type { User } from '@/domain/entities';
import { assertDeleteAllowed, UserGuardError } from './userGuards';

const user = (o: Partial<User> = {}): User => ({
  id: 'u1',
  email: 'a@shop.test',
  displayName: 'A',
  role: UserRole.cashier,
  isActive: true,
  phoneNumber: null,
  photoUrl: null,
  createdAt: new Date('2026-01-01'),
  updatedAt: null,
  createdBy: null,
  updatedBy: null,
  lastLoginAt: null,
  ...o,
});

describe('assertDeleteAllowed', () => {
  it('throws self-delete when the target is the actor', () => {
    const actor = user({ id: 'me', role: UserRole.admin });
    expect(() => assertDeleteAllowed(actor, user({ id: 'me', isActive: false })))
      .toThrowError(UserGuardError);
    try {
      assertDeleteAllowed(actor, user({ id: 'me', isActive: false }));
    } catch (e) {
      expect((e as UserGuardError).code).toBe('self-delete');
    }
  });

  it('throws active-target for an active user (deactivate-first)', () => {
    const actor = user({ id: 'me', role: UserRole.admin });
    try {
      assertDeleteAllowed(actor, user({ id: 'u2', isActive: true }));
      expect.unreachable('should have thrown');
    } catch (e) {
      expect(e).toBeInstanceOf(UserGuardError);
      expect((e as UserGuardError).code).toBe('active-target');
    }
  });

  it('passes for an inactive other user', () => {
    const actor = user({ id: 'me', role: UserRole.admin });
    expect(() =>
      assertDeleteAllowed(actor, user({ id: 'u2', isActive: false })),
    ).not.toThrow();
  });
});
