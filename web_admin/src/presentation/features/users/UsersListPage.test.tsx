import { describe, expect, it, vi } from 'vitest';
import { render, screen, waitFor } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { QueryClient, QueryClientProvider } from '@tanstack/react-query';
import { MemoryRouter } from 'react-router-dom';
import { DiProvider, type Container } from '@/infrastructure/di/container';
import { useAuthStore } from '@/presentation/stores/authStore';
import { UserRole } from '@/domain/enums';
import type { User } from '@/domain/entities';
import { UsersListPage } from './UsersListPage';

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

const me = user({ id: 'me', displayName: 'Admin', role: UserRole.admin });

function harness(opts?: { users?: User[]; del?: ReturnType<typeof vi.fn> }) {
  useAuthStore.setState({ user: me, status: 'signedIn' });
  const qc = new QueryClient({
    defaultOptions: { mutations: { retry: false } },
  });
  const userRepo = {
    watchAll: vi.fn((cb: (users: User[]) => void) => {
      cb(opts?.users ?? []);
      return () => {};
    }),
    delete: opts?.del ?? vi.fn(async () => {}),
    deactivate: vi.fn(async () => {}),
    reactivate: vi.fn(async () => {}),
    listByRole: vi.fn(async () => []),
  } as unknown as Container['userRepo'];
  render(
    <DiProvider override={{ userRepo }}>
      <QueryClientProvider client={qc}>
        <MemoryRouter>
          <UsersListPage />
        </MemoryRouter>
      </QueryClientProvider>
    </DiProvider>,
  );
  return { userRepo };
}

describe('UsersListPage — delete action', () => {
  it('shows Delete in the row menu only for inactive users, never for me', async () => {
    harness({
      users: [
        me,
        user({ id: 'u2', displayName: 'Active Cashier' }),
        user({ id: 'u3', displayName: 'Gone Staff', role: UserRole.staff, isActive: false }),
      ],
    });

    // Self row never gets a menu at all → 2 menus for 3 rows.
    const menus = screen.getAllByRole('button', { name: /more actions/i });
    expect(menus).toHaveLength(2);

    // Active row (sorted active-first: Active Cashier, Admin/me, Gone Staff).
    await userEvent.click(menus[0]);
    expect(screen.getByRole('button', { name: /deactivate/i })).toBeInTheDocument();
    expect(screen.queryByRole('button', { name: /^delete$/i })).not.toBeInTheDocument();
    await userEvent.click(document.body); // close the menu

    // Inactive row.
    await userEvent.click(screen.getAllByRole('button', { name: /more actions/i })[1]);
    expect(screen.getByRole('button', { name: /reactivate/i })).toBeInTheDocument();
    expect(screen.getByRole('button', { name: /^delete$/i })).toBeInTheDocument();
  });

  it('confirming Delete calls the repo with the user id', async () => {
    const del = vi.fn(async () => {});
    harness({
      users: [me, user({ id: 'u3', displayName: 'Gone Staff', isActive: false })],
      del,
    });

    await userEvent.click(screen.getByRole('button', { name: /more actions/i }));
    await userEvent.click(screen.getByRole('button', { name: /^delete$/i }));

    // Destructive confirm dialog names the user.
    const dialog = screen.getByRole('dialog');
    expect(dialog).toHaveTextContent('Delete user');
    expect(dialog).toHaveTextContent('Gone Staff');

    // Menu is closed now, so the only Delete button is the confirm action.
    await userEvent.click(screen.getByRole('button', { name: /^delete$/i }));
    await waitFor(() => expect(del).toHaveBeenCalledWith('u3'));
  });
});
