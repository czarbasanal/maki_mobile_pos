// Final-review fix: the logout log must be WRITTEN (awaited) while the user
// is still signed in. Firing it after signOut() sends the addDoc
// unauthenticated → firestore.rules denies it → logActivity swallows the
// denial, so web logout entries would silently never exist. Mobile's
// sign_out_usecase logs first for the same reason; these tests pin the order.
import { describe, expect, it, vi } from 'vitest';
import { act, renderHook, waitFor } from '@testing-library/react';
import { QueryClient, QueryClientProvider } from '@tanstack/react-query';
import { DiProvider, type Container } from '@/infrastructure/di/container';
import { useAuthStore } from '@/presentation/stores/authStore';
import { useSignOut } from './useSignOut';
import { UserRole } from '@/domain/enums';
import type { User } from '@/domain/entities';
import type { ReactNode } from 'react';

const actor: User = {
  id: 'u1',
  email: 'a@shop.test',
  displayName: 'Jane Admin',
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

function wrap(signOut: ReturnType<typeof vi.fn>, log: ReturnType<typeof vi.fn>) {
  const qc = new QueryClient({ defaultOptions: { mutations: { retry: false } } });
  const authRepo = { signOut } as unknown as Container['authRepo'];
  const activityLogRepo = { log } as unknown as Container['activityLogRepo'];
  return ({ children }: { children: ReactNode }) => (
    <DiProvider override={{ authRepo, activityLogRepo }}>
      <QueryClientProvider client={qc}>{children}</QueryClientProvider>
    </DiProvider>
  );
}

describe('useSignOut', () => {
  it('writes the logout log BEFORE signing out, attributed to the outgoing user', async () => {
    useAuthStore.setState({ user: actor, status: 'signedIn' });
    const calls: string[] = [];
    const log = vi.fn(async () => {
      calls.push('log');
    });
    const signOut = vi.fn(async () => {
      calls.push('signOut');
    });
    const { result } = renderHook(() => useSignOut(), { wrapper: wrap(signOut, log) });

    act(() => {
      result.current.mutate();
    });

    await waitFor(() => expect(result.current.isSuccess).toBe(true));
    expect(calls).toEqual(['log', 'signOut']);
    expect(log).toHaveBeenCalledWith(
      expect.objectContaining({
        type: 'logout',
        action: 'User logged out',
        userId: 'u1',
        userName: 'Jane Admin',
      }),
    );
    useAuthStore.setState({ user: null, status: 'signedOut' });
  });

  it('still signs out when the log write is rejected', async () => {
    useAuthStore.setState({ user: actor, status: 'signedIn' });
    const log = vi.fn().mockRejectedValue(new Error('permission-denied'));
    const signOut = vi.fn().mockResolvedValue(undefined);
    const { result } = renderHook(() => useSignOut(), { wrapper: wrap(signOut, log) });

    act(() => {
      result.current.mutate();
    });

    await waitFor(() => expect(result.current.isSuccess).toBe(true));
    expect(signOut).toHaveBeenCalledTimes(1);
    useAuthStore.setState({ user: null, status: 'signedOut' });
  });

  it('skips logging (but still signs out) with no signed-in user', async () => {
    useAuthStore.setState({ user: null, status: 'signedOut' });
    const log = vi.fn().mockResolvedValue(undefined);
    const signOut = vi.fn().mockResolvedValue(undefined);
    const { result } = renderHook(() => useSignOut(), { wrapper: wrap(signOut, log) });

    act(() => {
      result.current.mutate();
    });

    await waitFor(() => expect(result.current.isSuccess).toBe(true));
    expect(log).not.toHaveBeenCalled();
    expect(signOut).toHaveBeenCalledTimes(1);
  });
});
