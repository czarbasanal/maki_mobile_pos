// The one add/manage modal (users guide §3/§4): invite flow without a
// password field, the two permission rules made visible, and the
// deactivate-before-delete Danger zone with a typed confirmation.
import { describe, expect, it, vi } from 'vitest';
import { render, screen, waitFor, within } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { QueryClient, QueryClientProvider } from '@tanstack/react-query';
import { MemoryRouter, Route, Routes } from 'react-router-dom';
import { DiProvider, type Container } from '@/infrastructure/di/container';
import { useAuthStore } from '@/presentation/stores/authStore';
import { UserRole } from '@/domain/enums';
import type { User } from '@/domain/entities';
import { UserModal } from './UserModal';

const user = (o: Partial<User> = {}): User => ({
  id: 'u1', email: 'a@shop.test', displayName: 'A', role: UserRole.cashier, isActive: true,
  phoneNumber: null, photoUrl: null, createdAt: new Date('2026-07-02T00:00:00Z'), updatedAt: null,
  createdBy: 'me', updatedBy: null, lastLoginAt: new Date('2026-09-04T00:00:00Z'), ...o,
});
const me = user({ id: 'me', displayName: 'Czar', email: 'czar@shop.test', role: UserRole.admin, createdBy: null });

function harness(path: string, users: User[], repo: Partial<Container['userRepo']> = {}, viewer: User = me) {
  useAuthStore.setState({ user: viewer, status: 'signedIn' });
  const qc = new QueryClient({ defaultOptions: { mutations: { retry: false } } });
  const userRepo = {
    watchAll: vi.fn((cb: (users: User[]) => void) => { cb(users); return () => {}; }),
    listByRole: vi.fn(async (role: UserRole) => users.filter((u) => u.role === role)),
    create: vi.fn(async (input: { email: string; displayName: string; role: UserRole }) =>
      user({ id: 'new', email: input.email, displayName: input.displayName, role: input.role, lastLoginAt: null })),
    update: vi.fn(async () => users[0]),
    deactivate: vi.fn(async () => {}),
    reactivate: vi.fn(async () => {}),
    delete: vi.fn(async () => {}),
    ...repo,
  } as unknown as Container['userRepo'];
  const authRepo = { sendPasswordResetEmail: vi.fn(async () => {}) } as unknown as Container['authRepo'];
  render(
    <DiProvider override={{ userRepo, authRepo, activityLogRepo: { log: vi.fn() } as unknown as Container['activityLogRepo'] }}>
      <QueryClientProvider client={qc}>
        <MemoryRouter initialEntries={[path]}>
          <Routes>
            <Route path="/users" element={<div>list</div>} />
            <Route path="/users/add" element={<UserModal />} />
            <Route path="/users/edit/:id" element={<UserModal />} />
          </Routes>
        </MemoryRouter>
      </QueryClientProvider>
    </DiProvider>,
  );
  return { userRepo, authRepo };
}

describe('UserModal — add', () => {
  it('has no password field; Send invite mints the account with a hidden password, then emails the invite', async () => {
    const { userRepo, authRepo } = harness('/users/add', [me]);
    const dialog = screen.getByRole('dialog', { name: 'Add user' });
    expect(within(dialog).queryByLabelText(/password/i)).not.toBeInTheDocument();
    expect(within(dialog).getByText(/They will get an email to set their own password/)).toBeInTheDocument();
    const send = within(dialog).getByRole('button', { name: 'Send invite' });
    expect(send).toBeDisabled();

    await userEvent.type(within(dialog).getByLabelText('Name'), 'Jeric');
    await userEvent.type(within(dialog).getByLabelText('Email'), 'jeric@shop.test');
    await userEvent.click(within(dialog).getByRole('radio', { name: /Staff/ }));
    await userEvent.click(send);

    await waitFor(() => expect(userRepo.create).toHaveBeenCalled());
    const [input] = (userRepo.create as ReturnType<typeof vi.fn>).mock.calls[0];
    expect(input).toMatchObject({ email: 'jeric@shop.test', displayName: 'Jeric', role: 'staff' });
    expect(input.password.length).toBeGreaterThan(20);
    await waitFor(() => expect(authRepo.sendPasswordResetEmail).toHaveBeenCalledWith('jeric@shop.test'));
    expect(await screen.findByText('list')).toBeInTheDocument();
  });

  it('a duplicate email lands on the Email field', async () => {
    harness('/users/add', [me], { create: vi.fn(async () => { throw new Error('A user with this email already exists'); }) });
    const dialog = screen.getByRole('dialog', { name: 'Add user' });
    await userEvent.type(within(dialog).getByLabelText('Name'), 'Dup');
    await userEvent.type(within(dialog).getByLabelText('Email'), 'a@shop.test');
    await userEvent.click(within(dialog).getByRole('button', { name: 'Send invite' }));
    expect(await within(dialog).findByText('This email already has an account')).toBeInTheDocument();
  });
});

describe('UserModal — manage', () => {
  const belle = user({ id: 'c1', displayName: 'Belle', email: 'belle@shop.test', updatedBy: 'me', updatedAt: new Date('2026-08-12T06:15:00Z') });

  it('shows Account history with people and timestamps as one entry each', async () => {
    harness('/users/edit/c1', [me, belle]);
    const dialog = await screen.findByRole('dialog', { name: 'Manage user' });
    const added = within(dialog).getByText('Added by').parentElement as HTMLElement;
    expect(within(added).getByText('Czar')).toBeInTheDocument();
    const updated = within(dialog).getByText('Last updated by').parentElement as HTMLElement;
    expect(within(updated).getByText('Czar')).toBeInTheDocument();
    expect(within(dialog).getByRole('link', { name: 'View activity for this user →' })).toHaveAttribute('href', '/logs');
  });

  it('Save changes updates name and role', async () => {
    const { userRepo } = harness('/users/edit/c1', [me, belle]);
    const dialog = await screen.findByRole('dialog', { name: 'Manage user' });
    await waitFor(() => expect(within(dialog).getByLabelText('Name')).toHaveValue('Belle'));
    expect(within(dialog).getByLabelText('Email')).toBeDisabled();
    await userEvent.click(within(dialog).getByRole('radio', { name: /Staff/ }));
    await userEvent.click(within(dialog).getByRole('button', { name: 'Save changes' }));
    await waitFor(() => expect(userRepo.update).toHaveBeenCalledWith(expect.objectContaining({ id: 'c1', role: 'staff' }), 'me'));
  });

  it('on my own account the role picker is a read-only summary and the Danger zone defers to another admin', async () => {
    harness('/users/edit/me', [me, belle]);
    const dialog = await screen.findByRole('dialog', { name: 'Manage user' });
    expect(within(dialog).queryByRole('radiogroup')).not.toBeInTheDocument();
    expect(within(dialog).getByText('This is your own account. Ask another admin to change your role.')).toBeInTheDocument();
    expect(within(dialog).getByText('This is your own account. Ask another admin to deactivate it.')).toBeInTheDocument();
    expect(within(dialog).queryByRole('button', { name: /Deactivate account/ })).not.toBeInTheDocument();
  });

  it('the only active admin cannot be moved off Admin: other options grey out with the reason', async () => {
    // Viewer is a staff account for the test's sake; the target is the sole active admin.
    const viewer = user({ id: 'v', displayName: 'Viewer', role: UserRole.staff });
    harness('/users/edit/me', [me, viewer], {}, viewer);
    const dialog = await screen.findByRole('dialog', { name: 'Manage user' });
    const cashier = within(dialog).getByRole('radio', { name: /Cashier/ });
    expect(cashier).toHaveAttribute('aria-disabled', 'true');
    expect(within(dialog).getAllByText('Unavailable while this is the only admin.')).toHaveLength(2);
    expect(within(dialog).getByText(/This is the only active admin/)).toBeInTheDocument();
    await userEvent.click(cashier);
    expect(within(dialog).getByRole('radio', { name: /Admin/ })).toHaveAttribute('aria-checked', 'true');
  });

  it('Delete is inert while the account is active; Deactivate is the way in', async () => {
    const { userRepo } = harness('/users/edit/c1', [me, belle]);
    const dialog = await screen.findByRole('dialog', { name: 'Manage user' });
    expect(within(dialog).getByRole('button', { name: 'Delete account' })).toBeDisabled();
    expect(within(dialog).getByText(/Deactivate first/)).toBeInTheDocument();
    await userEvent.click(within(dialog).getByRole('button', { name: 'Deactivate account' }));
    await waitFor(() => expect(userRepo.deactivate).toHaveBeenCalledWith('c1', 'me'));
  });

  it('an inactive account can be reactivated, or deleted after typing the email', async () => {
    const gone = user({ ...belle, isActive: false });
    const { userRepo } = harness('/users/edit/c1', [me, gone]);
    const dialog = await screen.findByRole('dialog', { name: 'Manage user' });
    expect(within(dialog).getByRole('button', { name: 'Reactivate account' })).toBeInTheDocument();
    await userEvent.click(within(dialog).getByRole('button', { name: 'Delete account' }));
    const confirm = screen.getByRole('dialog', { name: 'Delete account?' });
    const commit = within(confirm).getByRole('button', { name: 'Delete account' });
    expect(commit).toBeDisabled();
    await userEvent.type(within(confirm).getByLabelText(/Type belle@shop.test to confirm/), 'belle@shop.test');
    await userEvent.click(commit);
    await waitFor(() => expect(userRepo.delete).toHaveBeenCalledWith('c1'));
    expect(await screen.findByText('list')).toBeInTheDocument();
  });
});
