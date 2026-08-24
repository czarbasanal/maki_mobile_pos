import { afterEach, describe, expect, it, vi } from 'vitest';
import { render, screen } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { MemoryRouter } from 'react-router-dom';
import { QueryClient, QueryClientProvider } from '@tanstack/react-query';
import { DiProvider, type Container } from '@/infrastructure/di/container';
import { UserRole } from '@/domain/enums';
import type { User } from '@/domain/entities/User';
import { useAuthStore } from '@/presentation/stores/authStore';
import { Sidebar } from './Sidebar';

const admin: User = {
  id: 'u1',
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
};

function harness(initialPath: string) {
  useAuthStore.setState({ user: admin });
  const authRepo = { signOut: vi.fn() } as unknown as Container['authRepo'];
  const activityLogRepo = {
    log: vi.fn().mockResolvedValue(undefined),
  } as unknown as Container['activityLogRepo'];
  const qc = new QueryClient({ defaultOptions: { mutations: { retry: false } } });
  return render(
    <DiProvider override={{ authRepo, activityLogRepo }}>
      <QueryClientProvider client={qc}>
        <MemoryRouter initialEntries={[initialPath]}>
          <Sidebar />
        </MemoryRouter>
      </QueryClientProvider>
    </DiProvider>,
  );
}

describe('Sidebar — Inventory dropdown', () => {
  it('hides Reorder and Price History while outside the inventory subtree', () => {
    harness('/pos');
    expect(screen.getByRole('link', { name: /inventory/i })).toBeInTheDocument();
    expect(screen.queryByRole('link', { name: /reorder/i })).not.toBeInTheDocument();
    expect(screen.queryByRole('link', { name: /price history/i })).not.toBeInTheDocument();
  });

  it('shows the sub-items automatically anywhere in the inventory subtree', () => {
    harness('/inventory/reorder');
    expect(screen.getByRole('link', { name: /reorder/i })).toHaveAttribute(
      'href',
      '/inventory/reorder',
    );
    expect(screen.getByRole('link', { name: /price history/i })).toHaveAttribute(
      'href',
      '/inventory/price-history',
    );
  });

  it('chevron expands and collapses the group without navigating', async () => {
    harness('/pos');
    await userEvent.click(screen.getByRole('button', { name: /expand inventory/i }));
    expect(screen.getByRole('link', { name: /reorder/i })).toBeInTheDocument();
    await userEvent.click(screen.getByRole('button', { name: /collapse inventory/i }));
    expect(screen.queryByRole('link', { name: /reorder/i })).not.toBeInTheDocument();
  });

  it('can collapse the group even while a sub-item is active', async () => {
    harness('/inventory/reorder');
    expect(screen.getByRole('link', { name: /reorder/i })).toBeInTheDocument();
    await userEvent.click(screen.getByRole('button', { name: /collapse inventory/i }));
    expect(screen.queryByRole('link', { name: /reorder/i })).not.toBeInTheDocument();
    await userEvent.click(screen.getByRole('button', { name: /expand inventory/i }));
    expect(screen.getByRole('link', { name: /reorder/i })).toBeInTheDocument();
  });
});

function stubMatchMedia(matches: boolean) {
  vi.stubGlobal(
    'matchMedia',
    vi.fn().mockReturnValue({
      matches,
      media: '',
      onchange: null,
      addEventListener: vi.fn(),
      removeEventListener: vi.fn(),
      addListener: vi.fn(),
      removeListener: vi.fn(),
      dispatchEvent: vi.fn(),
    }),
  );
}

describe('Sidebar — collapsible rail', () => {
  afterEach(() => vi.unstubAllGlobals());

  it('collapses to an icon rail and expands back', async () => {
    harness('/pos');
    expect(screen.getByText('Job Orders')).toBeInTheDocument();
    expect(screen.getByText('Money')).toBeInTheDocument();

    await userEvent.click(screen.getByRole('button', { name: /collapse sidebar/i }));

    // Labels and section headings gone; destinations still reachable by
    // accessible name (icon-only links).
    expect(screen.queryByText('Job Orders')).not.toBeInTheDocument();
    expect(screen.queryByText('Money')).not.toBeInTheDocument();
    expect(screen.getByRole('link', { name: /job orders/i })).toBeInTheDocument();

    await userEvent.click(screen.getByRole('button', { name: /expand sidebar/i }));
    expect(screen.getByText('Job Orders')).toBeInTheDocument();
  });

  it('starts collapsed on a tablet-width viewport', () => {
    stubMatchMedia(true);
    harness('/pos');
    expect(screen.queryByText('Job Orders')).not.toBeInTheDocument();
    expect(screen.getByRole('button', { name: /expand sidebar/i })).toBeInTheDocument();
  });

  it('starts expanded on a desktop viewport', () => {
    stubMatchMedia(false);
    harness('/pos');
    expect(screen.getByText('Job Orders')).toBeInTheDocument();
    expect(screen.getByRole('button', { name: /collapse sidebar/i })).toBeInTheDocument();
  });

  it('a collapsed group still exposes its parent as an icon link, children hidden', async () => {
    harness('/hr/employees');
    // Expanded: the HR children are visible (active subtree).
    expect(screen.getByRole('link', { name: /payroll/i })).toBeInTheDocument();

    await userEvent.click(screen.getByRole('button', { name: /collapse sidebar/i }));
    expect(screen.getByRole('link', { name: /^hr$/i })).toBeInTheDocument();
    expect(screen.queryByRole('link', { name: /payroll/i })).not.toBeInTheDocument();
  });
});
