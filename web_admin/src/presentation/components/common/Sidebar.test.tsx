import { afterEach, describe, expect, it, vi } from 'vitest';
import { render, screen } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { MemoryRouter } from 'react-router-dom';
import { QueryClient, QueryClientProvider } from '@tanstack/react-query';
import { DiProvider, type Container } from '@/infrastructure/di/container';
import { UserRole } from '@/domain/enums';
import type { User } from '@/domain/entities/User';
import type { VoidRequest } from '@/domain/entities';
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

function harness(
  initialPath: string,
  user: User = admin,
  pendingVoids: VoidRequest[] = [],
) {
  useAuthStore.setState({ user });
  const voidRequestRepo = {
    watchRequests: (cb: (r: VoidRequest[]) => void) => {
      cb(pendingVoids);
      return () => {};
    },
  } as unknown as Container['voidRequestRepo'];
  const authRepo = { signOut: vi.fn() } as unknown as Container['authRepo'];
  const activityLogRepo = {
    log: vi.fn().mockResolvedValue(undefined),
  } as unknown as Container['activityLogRepo'];
  const qc = new QueryClient({ defaultOptions: { mutations: { retry: false } } });
  return render(
    <DiProvider override={{ authRepo, activityLogRepo, voidRequestRepo }}>
      <QueryClientProvider client={qc}>
        <MemoryRouter initialEntries={[initialPath]}>
          <Sidebar />
        </MemoryRouter>
      </QueryClientProvider>
    </DiProvider>,
  );
}

describe('Sidebar — Inventory is a flat item', () => {
  it('reaches Inventory in one click, with no sub-items to expand', () => {
    // Reorder moved inside the buying list and Price History stands on its
    // own, so the group had one child and then none — a dropdown that only
    // ever hid its parent.
    harness('/pos');
    expect(screen.getByRole('link', { name: /^inventory$/i })).toBeInTheDocument();
    expect(screen.queryByRole('link', { name: /reorder/i })).not.toBeInTheDocument();
  });

  it('lists Price History and Purchase Orders as their own items', () => {
    harness('/pos');
    expect(screen.getByRole('link', { name: /price history/i })).toBeInTheDocument();
    expect(screen.getByRole('link', { name: /purchase orders/i })).toBeInTheDocument();
  });

  it('does not mark Inventory active while Price History is the page', () => {
    // The sidebar marks a parent active for any path beneath it, so while
    // Price History lived at /inventory/price-history both items lit up and
    // the highlight said you were somewhere you were not.
    harness('/price-history');

    expect(screen.getByRole('link', { name: /price history/i }).className)
        .toContain('font-semibold');
    expect(screen.getByRole('link', { name: /^inventory$/i }).className)
        .not.toContain('font-semibold');
  });

  it('keeps them reachable from inside the inventory subtree too', () => {
    harness('/inventory');
    expect(screen.getByRole('link', { name: /price history/i })).toBeInTheDocument();
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

describe('Sidebar — cashier filtering (characterization)', () => {
  const cashier: User = { ...admin, id: 'u2', role: UserRole.cashier };

  it('collapses to the mobile-parity destinations', () => {
    harness('/pos', cashier);
    // Present: the cashier surface.
    for (const label of ['POS', 'Job Orders', 'Inventory', 'Expenses', 'Reports', 'Settings']) {
      expect(screen.getByRole('link', { name: label })).toBeInTheDocument();
    }
    // Absent: stock ops, admin surfaces, HR.
    for (const label of ['Receiving', 'Suppliers', 'Users', 'Activity Logs', 'HR']) {
      expect(screen.queryByRole('link', { name: label })).not.toBeInTheDocument();
    }
  });

  it('hides the cost-facing inventory children even inside the subtree', () => {
    harness('/inventory', cashier);
    expect(screen.queryByRole('link', { name: /reorder/i })).not.toBeInTheDocument();
    expect(screen.queryByRole('link', { name: /price history/i })).not.toBeInTheDocument();
  });
});

describe('Sidebar — Void Requests', () => {
  const request = (id: string, o: Partial<VoidRequest> = {}): VoidRequest => ({
    id,
    saleId: `s-${id}`,
    saleNumber: 'SALE-0001',
    saleGrandTotal: 285,
    requestedBy: 'u-belle',
    requestedByName: 'Belle',
    requestedByRole: 'cashier',
    reason: 'Payment issue',
    status: 'pending',
    read: false,
    createdAt: new Date('2026-08-30T13:00:00Z'),
    resolvedBy: null,
    resolvedByName: null,
    resolvedAt: null,
    rejectionReason: null,
    itemsSummary: null,
    ...o,
  });

  it('is a nav item, not a bell in the header', async () => {
    harness('/dashboard');
    expect(await screen.findByRole('link', { name: 'Void Requests' })).toBeInTheDocument();
    // The bell it replaced was a button in the header, opening a dropdown.
    expect(screen.queryByRole('button', { name: /void requests/i })).not.toBeInTheDocument();
  });

  it('badges the item with the number waiting', async () => {
    harness('/dashboard', admin, [request('r1'), request('r2')]);
    await screen.findByRole('link', { name: 'Void Requests' });
    expect(screen.getByText('2')).toBeInTheDocument();
  });

  it('shows no badge when nothing is pending', async () => {
    harness('/dashboard', admin, [request('r1', { status: 'approved', read: true })]);
    await screen.findByRole('link', { name: 'Void Requests' });
    expect(screen.queryByText('1')).not.toBeInTheDocument();
  });

  it('is hidden from a cashier, who files requests rather than approving them', () => {
    harness('/dashboard', { ...admin, role: UserRole.cashier });
    expect(screen.queryByRole('link', { name: 'Void Requests' })).not.toBeInTheDocument();
  });
});
