// Users list (users guide §2): one subscription feeds the role card, the
// sign-in KPIs, the chip counts and the table; Active is the default view;
// a row or Manage opens the modal route.
import { describe, expect, it, vi } from 'vitest';
import { render, screen, within } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { QueryClient, QueryClientProvider } from '@tanstack/react-query';
import { MemoryRouter, Route, Routes, useLocation } from 'react-router-dom';
import { DiProvider, type Container } from '@/infrastructure/di/container';
import { useAuthStore } from '@/presentation/stores/authStore';
import { UserRole } from '@/domain/enums';
import type { User } from '@/domain/entities';
import { UsersListPage } from './UsersListPage';

const DAY = 86_400_000;
const ago = (d: number) => new Date(Date.now() - d * DAY);

const user = (o: Partial<User> = {}): User => ({
  id: 'u1', email: 'a@shop.test', displayName: 'A', role: UserRole.cashier, isActive: true,
  phoneNumber: null, photoUrl: null, createdAt: new Date('2026-07-02T00:00:00Z'), updatedAt: null,
  createdBy: null, updatedBy: null, lastLoginAt: ago(1), ...o,
});
const me = user({ id: 'me', displayName: 'Czar', email: 'czar@shop.test', role: UserRole.admin });

function Probe() {
  const { pathname } = useLocation();
  return <div data-testid="path">{pathname}</div>;
}

function harness(users: User[]) {
  useAuthStore.setState({ user: me, status: 'signedIn' });
  const qc = new QueryClient({ defaultOptions: { mutations: { retry: false } } });
  const userRepo = {
    watchAll: vi.fn((cb: (users: User[]) => void) => { cb(users); return () => {}; }),
    listByRole: vi.fn(async () => []),
  } as unknown as Container['userRepo'];
  render(
    <DiProvider override={{ userRepo, activityLogRepo: { log: vi.fn() } as unknown as Container['activityLogRepo'] }}>
      <QueryClientProvider client={qc}>
        <MemoryRouter initialEntries={['/users']}>
          <Routes>
            <Route path="/users" element={<><UsersListPage /><Probe /></>}>
              <Route path="edit/:id" element={<div>modal</div>} />
              <Route path="add" element={<div>modal</div>} />
            </Route>
          </Routes>
        </MemoryRouter>
      </QueryClientProvider>
    </DiProvider>,
  );
  return { userRepo };
}

const kpi = (label: string) =>
  screen.getAllByText(label).map((el) => el.closest('section')).find((el): el is HTMLElement => el !== null)!;
const rowOf = (name: string) => screen.getByText(name).closest('tr') as HTMLElement;

const roster = [
  me,
  user({ id: 'a2', displayName: 'Admin', email: 'admin@test.com', role: UserRole.admin, lastLoginAt: ago(43) }),
  user({ id: 's1', displayName: 'Sam', email: 'staff@test.com', role: UserRole.staff, lastLoginAt: ago(65) }),
  user({ id: 'c1', displayName: 'Belle', email: 'belle@shop.test', lastLoginAt: ago(1) }),
  user({ id: 'c2', displayName: 'Tess', email: 'cashier@test.com', lastLoginAt: ago(12) }),
  user({ id: 'j', displayName: 'Jeric', email: 'jeric@shop.test', role: UserRole.staff, isActive: false, lastLoginAt: null }),
];

describe('UsersListPage — summary from one set', () => {
  it('role card counts active accounts; the KPIs count sign-ins', () => {
    harness(roster);
    const card = screen.getByTestId('accounts-by-role');
    expect(within(card).getByText('5 active')).toBeInTheDocument();
    expect(within(card).getByText('Admin').closest('button')!.textContent).toContain('2');
    expect(within(card).getByText('full access')).toBeInTheDocument();
    expect(within(kpi('Signed in this week')).getByText('2')).toBeInTheDocument();
    expect(within(kpi('Dormant 30+ days')).getByText('2').className).toContain('text-neg');
    expect(within(kpi('Never signed in')).getByText('1')).toBeInTheDocument();
  });
});

describe('UsersListPage — filters', () => {
  it('opens on Active only; Inactive shows the disabled account', async () => {
    harness(roster);
    expect(screen.queryByText('Jeric')).not.toBeInTheDocument();
    expect(screen.getByText('5 accounts')).toBeInTheDocument();
    await userEvent.click(screen.getByRole('radio', { name: 'Inactive' }));
    expect(screen.getByText('Jeric')).toBeInTheDocument();
    expect(rowOf('Jeric').className).toContain('opacity-[.62]');
    expect(screen.queryByText('Belle')).not.toBeInTheDocument();
  });

  it('role chips carry counts and filter the rows; the counts ignore the role filter', async () => {
    harness(roster);
    // Chips read "<Role> <count>"; the role-card rows read "<Role> <scope> <count>".
    const cashierChip = screen.getByRole('button', { name: /^Cashier \d+$/ });
    expect(cashierChip.textContent).toContain('2');
    await userEvent.click(cashierChip);
    expect(screen.getByText('Belle')).toBeInTheDocument();
    expect(screen.queryByText('Sam')).not.toBeInTheDocument();
    expect(screen.getByRole('button', { name: /^Admin \d+$/ }).textContent).toContain('2');
    await userEvent.click(screen.getByRole('button', { name: 'Clear filters' }));
    expect(screen.getByText('Sam')).toBeInTheDocument();
  });

  it('a role-card row filters too', async () => {
    harness(roster);
    await userEvent.click(within(screen.getByTestId('accounts-by-role')).getByText('Staff'));
    expect(screen.getByText('1 account')).toBeInTheDocument();
    expect(screen.getByText('Sam')).toBeInTheDocument();
    expect(screen.queryByText('Belle')).not.toBeInTheDocument();
  });

  it('search matches name or email', async () => {
    harness(roster);
    await userEvent.type(screen.getByPlaceholderText('Search name or email'), 'test.com');
    expect(await screen.findByText('3 accounts')).toBeInTheDocument();
    expect(screen.queryByText('Belle')).not.toBeInTheDocument();
  });

  it('a search that matches nothing blames the filters', async () => {
    harness(roster);
    await userEvent.type(screen.getByPlaceholderText('Search name or email'), 'zzz');
    expect(await screen.findByText('No users match these filters')).toBeInTheDocument();
  });
});

describe('UsersListPage — rows', () => {
  it('shows last sign-in with an escalating staleness line, YOU on my account, and Never for an unaccepted invite', async () => {
    harness(roster);
    expect(within(rowOf('Belle')).getByText('today').className).toContain('text-ink-3');
    expect(within(rowOf('Tess')).getByText('12 days ago').className).toContain('text-accent-text');
    expect(within(rowOf('Sam')).getByText('65 days ago').className).toContain('text-neg');
    expect(within(rowOf('Czar')).getByText('YOU')).toBeInTheDocument();
    await userEvent.click(screen.getByRole('radio', { name: 'Inactive' }));
    expect(within(rowOf('Jeric')).getByText('Never')).toBeInTheDocument();
    expect(within(rowOf('Jeric')).getByText('invite not accepted').className).toContain('text-neg');
  });

  it('Manage and the row open the manage modal route; Add user opens the add route', async () => {
    harness(roster);
    await userEvent.click(within(rowOf('Belle')).getByRole('button', { name: 'Manage' }));
    expect(screen.getByTestId('path').textContent).toBe('/users/edit/c1');
    await userEvent.click(screen.getByRole('button', { name: 'Add user' }));
    expect(screen.getByTestId('path').textContent).toBe('/users/add');
  });
});

describe('UsersListPage — pagination', () => {
  it('shows the footer once the active list exceeds 25', () => {
    harness([me, ...Array.from({ length: 25 }, (_, i) => user({ id: `u${i + 2}`, displayName: `User ${i + 2}` }))]);
    expect(screen.getByText('1–25 of 26')).toBeInTheDocument();
  });
});
