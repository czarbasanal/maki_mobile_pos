// Activity-log wiring for user mutations (task-10): deactivate is the
// representative case the task brief calls out explicitly. create/update/
// reactivate/delete are covered too since they're cheap to assert once the
// harness exists.
import { describe, expect, it, vi } from 'vitest';
import { act, renderHook, waitFor } from '@testing-library/react';
import { QueryClient, QueryClientProvider } from '@tanstack/react-query';
import { DiProvider, type Container } from '@/infrastructure/di/container';
import { useAuthStore } from '@/presentation/stores/authStore';
import {
  useClearOrphanedLogin,
  useCreateUser,
  useDeactivateUser,
  useDeleteUser,
  useReactivateUser,
  useUpdateUser,
} from './useUserMutations';
import { UserRole } from '@/domain/enums';
import type { User } from '@/domain/entities';
import type { ReactNode } from 'react';

function makeUser(overrides: Partial<User> = {}): User {
  return {
    id: 'u1',
    email: 'target@shop.test',
    displayName: 'Target User',
    role: UserRole.cashier,
    isActive: true,
    phoneNumber: null,
    photoUrl: null,
    createdAt: new Date('2026-01-01'),
    updatedAt: null,
    createdBy: null,
    updatedBy: null,
    lastLoginAt: null,
    ...overrides,
  };
}

const sendPasswordResetEmail = vi.fn(async () => {});

function wrap(userRepo: Partial<Container['userRepo']>, activityLog: ReturnType<typeof vi.fn>) {
  const qc = new QueryClient({ defaultOptions: { mutations: { retry: false } } });
  const activityLogRepo = { log: activityLog } as unknown as Container['activityLogRepo'];
  const authRepo = { sendPasswordResetEmail } as unknown as Container['authRepo'];
  return ({ children }: { children: ReactNode }) => (
    <DiProvider override={{ userRepo: userRepo as Container['userRepo'], activityLogRepo, authRepo }}>
      <QueryClientProvider client={qc}>{children}</QueryClientProvider>
    </DiProvider>
  );
}

const actor: User = makeUser({ id: 'admin-1', displayName: 'Admin', role: UserRole.admin });

describe('user mutation activity logging', () => {
  it('useDeactivateUser logs type user_deactivated', async () => {
    useAuthStore.setState({ user: actor, status: 'signedIn' });
    const log = vi.fn().mockResolvedValue(undefined);
    const deactivate = vi.fn().mockResolvedValue(undefined);
    const target = makeUser({ id: 'u2', displayName: 'Cash Ier' });
    const { result } = renderHook(() => useDeactivateUser(), {
      wrapper: wrap({ deactivate }, log),
    });

    act(() => {
      result.current.mutate(target);
    });

    await waitFor(() => expect(result.current.isSuccess).toBe(true));
    expect(log).toHaveBeenCalledWith(
      expect.objectContaining({
        type: 'user_deactivated',
        action: 'Deactivated user: Cash Ier',
        entityId: 'u2',
        entityType: 'user',
        userId: 'admin-1',
      }),
    );
    useAuthStore.setState({ user: null, status: 'signedOut' });
  });

  it('useCreateUser mints with a hidden random password, sends the invite, and logs user_created', async () => {
    useAuthStore.setState({ user: actor, status: 'signedIn' });
    const log = vi.fn().mockResolvedValue(undefined);
    const created = makeUser({ id: 'u3', displayName: 'New Staff', role: UserRole.staff });
    const create = vi.fn().mockResolvedValue(created);
    sendPasswordResetEmail.mockClear();
    const { result } = renderHook(() => useCreateUser(), { wrapper: wrap({ create }, log) });

    act(() => {
      result.current.mutate({ email: created.email, displayName: created.displayName, role: created.role });
    });

    await waitFor(() => expect(result.current.isSuccess).toBe(true));
    const [input] = create.mock.calls[0];
    expect(input.password.length).toBeGreaterThan(20);
    expect(sendPasswordResetEmail).toHaveBeenCalledWith(created.email);
    expect(result.current.data).toEqual({ user: created, inviteSent: true });
    expect(log).toHaveBeenCalledWith(
      expect.objectContaining({ type: 'user_created', entityId: 'u3' }),
    );
    useAuthStore.setState({ user: null, status: 'signedOut' });
  });

  it('useClearOrphanedLogin clears the login by email and logs it', async () => {
    useAuthStore.setState({ user: actor, status: 'signedIn' });
    const log = vi.fn().mockResolvedValue(undefined);
    const deleteOrphanedLogin = vi.fn().mockResolvedValue(undefined);
    const { result } = renderHook(() => useClearOrphanedLogin(), { wrapper: wrap({ deleteOrphanedLogin }, log) });
    act(() => { result.current.mutate('old@shop.test'); });
    await waitFor(() => expect(result.current.isSuccess).toBe(true));
    expect(deleteOrphanedLogin).toHaveBeenCalledWith('old@shop.test');
    expect(log).toHaveBeenCalledWith(expect.objectContaining({ action: 'Cleared orphaned login: old@shop.test' }));
    useAuthStore.setState({ user: null, status: 'signedOut' });
  });

  it('useCreateUser reports inviteSent: false when the account exists but the email failed', async () => {
    useAuthStore.setState({ user: actor, status: 'signedIn' });
    const created = makeUser({ id: 'u3' });
    const create = vi.fn().mockResolvedValue(created);
    sendPasswordResetEmail.mockRejectedValueOnce(new Error('smtp'));
    const { result } = renderHook(() => useCreateUser(), { wrapper: wrap({ create }, vi.fn()) });
    act(() => {
      result.current.mutate({ email: created.email, displayName: created.displayName, role: created.role });
    });
    await waitFor(() => expect(result.current.isSuccess).toBe(true));
    expect(result.current.data?.inviteSent).toBe(false);
    useAuthStore.setState({ user: null, status: 'signedOut' });
  });

  it('useUpdateUser logs user_updated, and role_changed only when the role actually changes', async () => {
    useAuthStore.setState({ user: actor, status: 'signedIn' });
    const log = vi.fn().mockResolvedValue(undefined);
    const target = makeUser({ id: 'u4', displayName: 'Old Name', role: UserRole.cashier });
    const updated = { ...target, displayName: 'New Name', role: UserRole.staff };
    const update = vi.fn().mockResolvedValue(updated);
    const { result } = renderHook(() => useUpdateUser(), { wrapper: wrap({ update }, log) });

    act(() => {
      result.current.mutate({ target, displayName: 'New Name', role: UserRole.staff });
    });

    await waitFor(() => expect(result.current.isSuccess).toBe(true));
    expect(log).toHaveBeenCalledWith(expect.objectContaining({ type: 'user_updated' }));
    expect(log).toHaveBeenCalledWith(expect.objectContaining({ type: 'role_changed' }));
    useAuthStore.setState({ user: null, status: 'signedOut' });
  });

  it('useReactivateUser logs user_updated with a Reactivated detail (no dedicated type exists)', async () => {
    useAuthStore.setState({ user: actor, status: 'signedIn' });
    const log = vi.fn().mockResolvedValue(undefined);
    const reactivate = vi.fn().mockResolvedValue(undefined);
    const target = makeUser({ id: 'u5', displayName: 'Back Again', isActive: false });
    const { result } = renderHook(() => useReactivateUser(), {
      wrapper: wrap({ reactivate }, log),
    });

    act(() => {
      result.current.mutate(target);
    });

    await waitFor(() => expect(result.current.isSuccess).toBe(true));
    expect(log).toHaveBeenCalledWith(
      expect.objectContaining({ type: 'user_updated', details: 'Reactivated' }),
    );
    useAuthStore.setState({ user: null, status: 'signedOut' });
  });

  it('useDeleteUser logs type user_management', async () => {
    useAuthStore.setState({ user: actor, status: 'signedIn' });
    const log = vi.fn().mockResolvedValue(undefined);
    const del = vi.fn().mockResolvedValue(undefined);
    const target = makeUser({ id: 'u6', displayName: 'Gone', isActive: false });
    const { result } = renderHook(() => useDeleteUser(), { wrapper: wrap({ delete: del }, log) });

    act(() => {
      result.current.mutate(target);
    });

    await waitFor(() => expect(result.current.isSuccess).toBe(true));
    expect(log).toHaveBeenCalledWith(
      expect.objectContaining({ type: 'user_management', action: 'Deleted user: Gone' }),
    );
    useAuthStore.setState({ user: null, status: 'signedOut' });
  });
});
