import { beforeEach, describe, expect, it, vi } from 'vitest';
import { useAuthStore } from '@/presentation/stores/authStore';
import { logActivity, logActivityAndWait } from './activityLogger';
import type { ActivityLogRepository } from '@/domain/repositories/ActivityLogRepository';
import type { User } from '@/domain/entities';

function actor(overrides: Partial<User> = {}): User {
  return {
    id: 'u1',
    email: 'a@b.co',
    displayName: 'Jane Admin',
    role: 'admin',
    isActive: true,
    phoneNumber: null,
    photoUrl: null,
    createdAt: new Date(),
    updatedAt: null,
    createdBy: null,
    updatedBy: null,
    lastLoginAt: null,
    ...overrides,
  };
}

function fakeRepo(log: ActivityLogRepository['log']): ActivityLogRepository {
  return {
    list: vi.fn(),
    watch: vi.fn(),
    log,
  };
}

describe('logActivity', () => {
  beforeEach(() => {
    useAuthStore.setState({ user: null, status: 'signedOut' });
  });

  it('injects userId/userName/userRole from the auth store', () => {
    useAuthStore.setState({ user: actor({ id: 'u9', displayName: 'Cash Ier', role: 'cashier' }) });
    const log = vi.fn().mockResolvedValue(undefined);
    const repo = fakeRepo(log);

    logActivity(repo, () => ({ type: 'sale', action: 'Completed sale S-1' }));

    expect(log).toHaveBeenCalledWith(
      expect.objectContaining({
        type: 'sale',
        action: 'Completed sale S-1',
        userId: 'u9',
        userName: 'Cash Ier',
        userRole: 'cashier',
        details: null,
        entityId: null,
        entityType: null,
        metadata: null,
        deviceInfo: null,
      }),
    );
  });

  it('passes through optional fields when provided', () => {
    useAuthStore.setState({ user: actor() });
    const log = vi.fn().mockResolvedValue(undefined);
    const repo = fakeRepo(log);

    logActivity(repo, () => ({
      type: 'expense',
      action: 'Created expense: Fuel',
      details: 'Transportation • ₱100.00',
      entityId: 'e1',
      entityType: 'expense',
      metadata: { amount: 100 },
    }));

    expect(log).toHaveBeenCalledWith(
      expect.objectContaining({
        details: 'Transportation • ₱100.00',
        entityId: 'e1',
        entityType: 'expense',
        metadata: { amount: 100 },
      }),
    );
  });

  it('never throws and never rejects when the repo rejects', async () => {
    useAuthStore.setState({ user: actor() });
    const log = vi.fn().mockRejectedValue(new Error('permission-denied'));
    const repo = fakeRepo(log);

    expect(() => logActivity(repo, () => ({ type: 'other', action: 'x' }))).not.toThrow();
    // Let the swallowed rejection's microtask settle before the test ends.
    await Promise.resolve();
    await Promise.resolve();
  });

  it('never throws when the repo itself throws synchronously', () => {
    useAuthStore.setState({ user: actor() });
    const repo = fakeRepo(() => {
      throw new Error('boom');
    });

    expect(() => logActivity(repo, () => ({ type: 'other', action: 'x' }))).not.toThrow();
  });

  it('never throws when build() itself throws (e.g. a sparse test double missing a field the caller reads)', () => {
    useAuthStore.setState({ user: actor() });
    const log = vi.fn().mockResolvedValue(undefined);
    const repo = fakeRepo(log);

    expect(() =>
      logActivity(repo, () => {
        const sale = undefined as unknown as { total: number };
        return { type: 'sale', action: `Total ${sale.total.toFixed(2)}` };
      }),
    ).not.toThrow();
    expect(log).not.toHaveBeenCalled();
  });

  it('is a no-op when no user is signed in (defensive — should not happen at a real call site)', () => {
    const log = vi.fn();
    const repo = fakeRepo(log);

    logActivity(repo, () => ({ type: 'other', action: 'x' }));

    expect(log).not.toHaveBeenCalled();
  });

  it('uses an explicit actorOverride instead of the store (sign-out: the store may already be cleared)', () => {
    // Store is empty (a signed-out session) — without the override this
    // would no-op, same as the "no user signed in" case above.
    useAuthStore.setState({ user: null, status: 'signedOut' });
    const log = vi.fn().mockResolvedValue(undefined);
    const repo = fakeRepo(log);

    logActivity(
      repo,
      () => ({ type: 'logout', action: 'User logged out' }),
      actor({ id: 'u9', displayName: 'Cash Ier', role: 'cashier' }),
    );

    expect(log).toHaveBeenCalledWith(
      expect.objectContaining({ type: 'logout', userId: 'u9', userName: 'Cash Ier' }),
    );
  });
});

describe('logActivityAndWait', () => {
  beforeEach(() => {
    useAuthStore.setState({ user: null, status: 'signedOut' });
  });

  it('awaits the repo write, injecting the same actor fields as logActivity', async () => {
    const log = vi.fn().mockResolvedValue(undefined);
    const repo = fakeRepo(log);

    await logActivityAndWait(
      repo,
      () => ({ type: 'logout', action: 'User logged out' }),
      actor({ id: 'u7', displayName: 'Out Going' }),
    );

    expect(log).toHaveBeenCalledWith(
      expect.objectContaining({
        type: 'logout',
        action: 'User logged out',
        userId: 'u7',
        userName: 'Out Going',
        deviceInfo: null,
      }),
    );
  });

  it('resolves (never rejects) when the repo write fails', async () => {
    const log = vi.fn().mockRejectedValue(new Error('permission-denied'));
    const repo = fakeRepo(log);

    await expect(
      logActivityAndWait(repo, () => ({ type: 'logout', action: 'User logged out' }), actor()),
    ).resolves.toBeUndefined();
  });

  it('no-ops with no signed-in user and no override', async () => {
    const log = vi.fn().mockResolvedValue(undefined);
    const repo = fakeRepo(log);

    await logActivityAndWait(repo, () => ({ type: 'logout', action: 'User logged out' }));

    expect(log).not.toHaveBeenCalled();
  });
});
