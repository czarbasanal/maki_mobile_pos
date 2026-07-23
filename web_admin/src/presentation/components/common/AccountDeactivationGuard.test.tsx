import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';
import { act, render, screen } from '@testing-library/react';
import { MemoryRouter } from 'react-router-dom';
import { DiProvider, type Container } from '@/infrastructure/di/container';
import { useAuthStore } from '@/presentation/stores/authStore';
import { UserRole } from '@/domain/enums';
import type { User } from '@/domain/entities';
import { AccountDeactivationGuard } from './AccountDeactivationGuard';

const user = (o: Partial<User> = {}): User => ({
  id: 'me',
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
  ...o,
});

type SnapshotCb = (u: User | null) => void;
type ErrorCb = (e: { code?: string; message?: string }) => void;

function harness() {
  useAuthStore.setState({ user: user(), status: 'signedIn' });
  let snapshotCb: SnapshotCb | undefined;
  let errorCb: ErrorCb | undefined;
  const unsubscribe = vi.fn();
  const userRepo = {
    watchOne: vi.fn((_id: string, cb: SnapshotCb, onErr?: ErrorCb) => {
      snapshotCb = cb;
      errorCb = onErr;
      return unsubscribe;
    }),
  } as unknown as Container['userRepo'];
  const authRepo = {
    signOut: vi.fn(async () => {}),
  } as unknown as Container['authRepo'];

  const utils = render(
    <DiProvider override={{ userRepo, authRepo }}>
      <MemoryRouter>
        <AccountDeactivationGuard />
      </MemoryRouter>
    </DiProvider>,
  );

  return {
    snapshot: (u: User | null) => act(() => snapshotCb?.(u)),
    error: (e: { code?: string }) => act(() => errorCb?.(e)),
    authRepo,
    unsubscribe,
    ...utils,
  };
}

describe('AccountDeactivationGuard', () => {
  beforeEach(() => {
    vi.useFakeTimers();
  });
  afterEach(() => {
    vi.useRealTimers();
    vi.restoreAllMocks();
  });

  it('renders nothing while the account stays active', () => {
    const h = harness();
    h.snapshot(user());
    expect(screen.queryByText('Account deactivated')).not.toBeInTheDocument();
    expect(h.authRepo.signOut).not.toHaveBeenCalled();
  });

  it('deactivation shows the modal copy and signs out after 10 seconds', async () => {
    const h = harness();
    h.snapshot(user({ isActive: false }));

    expect(screen.getByText('Account deactivated')).toBeInTheDocument();
    expect(
      screen.getByText(
        'Your account has been deactivated by an administrator. You will be signed out.',
      ),
    ).toBeInTheDocument();
    expect(screen.getByText(/10s/)).toBeInTheDocument();

    await act(async () => {
      vi.advanceTimersByTime(3000);
    });
    expect(screen.getByText(/7s/)).toBeInTheDocument();
    expect(h.authRepo.signOut).not.toHaveBeenCalled();

    await act(async () => {
      vi.advanceTimersByTime(7000);
      await Promise.resolve();
    });
    expect(h.authRepo.signOut).toHaveBeenCalledTimes(1);
  });

  // Pre-merge review fix — parity with the mobile twin's onDeleted (no
  // fired-guard): a doc-gone/permission-denied event arriving mid-countdown
  // must escalate to the immediate variant right away, not ride out the
  // remaining seconds.
  it('doc-gone mid-countdown escalates to immediate sign-out instead of waiting out the countdown', async () => {
    const h = harness();
    h.snapshot(user({ isActive: false }));

    await act(async () => {
      vi.advanceTimersByTime(3000);
    });
    expect(screen.getByText(/7s/)).toBeInTheDocument();
    expect(h.authRepo.signOut).not.toHaveBeenCalled();

    h.snapshot(null); // doc-gone arrives mid-countdown

    await act(async () => {
      await Promise.resolve();
    });
    expect(h.authRepo.signOut).toHaveBeenCalledTimes(1);

    // The remaining ~7s of the (now-superseded) countdown must not do
    // anything further — no second sign-out.
    await act(async () => {
      vi.advanceTimersByTime(7000);
    });
    expect(h.authRepo.signOut).toHaveBeenCalledTimes(1);
  });

  it('repeat inactive snapshots do not restart the countdown', async () => {
    const h = harness();
    h.snapshot(user({ isActive: false }));
    await act(async () => {
      vi.advanceTimersByTime(3000);
    });
    h.snapshot(user({ isActive: false })); // snapshot noise
    await act(async () => {
      vi.advanceTimersByTime(1000);
    });
    expect(screen.getByText(/6s/)).toBeInTheDocument();
  });

  it('doc-gone signs out immediately with the modal, no countdown', async () => {
    const h = harness();
    h.snapshot(null);

    expect(screen.getByText('Account deactivated')).toBeInTheDocument();
    await act(async () => {
      await Promise.resolve();
    });
    expect(h.authRepo.signOut).toHaveBeenCalledTimes(1);
  });

  it('permission-denied stream error is treated like doc-gone', async () => {
    const h = harness();
    h.error({ code: 'permission-denied' });

    expect(screen.getByText('Account deactivated')).toBeInTheDocument();
    await act(async () => {
      await Promise.resolve();
    });
    expect(h.authRepo.signOut).toHaveBeenCalledTimes(1);
  });

  it('unmount (normal sign-out path) unsubscribes without showing the modal', () => {
    const h = harness();
    h.unmount();
    expect(h.unsubscribe).toHaveBeenCalledTimes(1);
    expect(h.authRepo.signOut).not.toHaveBeenCalled();
  });

  // Latitude add (brief §"hard-won lesson"): correctness must not depend on
  // the relative ordering of the auth-state transition and the doc
  // subscription's own events. Here the account NEVER actually gets
  // deactivated — the admin just signs out normally elsewhere (e.g. the
  // Sidebar "Sign out" button), which flips the auth store first; the
  // Firestore listener on the now-stale subscription then reports
  // permission-denied as a trailing side effect of the token invalidating.
  // That must be ignored: no modal flash, no (extra) sign-out call.
  it('a permission-denied trailing a normal sign-out does not flash the modal', async () => {
    const h = harness();

    // Normal sign-out already happened elsewhere: the auth store flips to
    // signed-out first.
    act(() => {
      useAuthStore.setState({ user: null, status: 'signedOut' });
    });
    expect(screen.queryByText('Account deactivated')).not.toBeInTheDocument();

    // The trailing stream error arrives afterwards, on the subscription
    // closure captured before that reset.
    h.error({ code: 'permission-denied' });

    expect(screen.queryByText('Account deactivated')).not.toBeInTheDocument();
    await act(async () => {
      await Promise.resolve();
    });
    expect(h.authRepo.signOut).not.toHaveBeenCalled();
  });
});
