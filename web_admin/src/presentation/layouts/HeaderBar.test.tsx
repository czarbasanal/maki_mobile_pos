import { afterEach, describe, expect, it, vi } from 'vitest';
import { render, screen } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { createMemoryRouter, RouterProvider } from 'react-router-dom';
import { QueryClient, QueryClientProvider } from '@tanstack/react-query';
import { DiProvider, type Container } from '@/infrastructure/di/container';
import { ThemeProvider } from '@/core/theme/ThemeProvider';
import { UserRole } from '@/domain/enums';
import type { User, VoidRequest, JobOrder, DrawerState } from '@/domain/entities';
import { useAuthStore } from '@/presentation/stores/authStore';
import { AppShell } from './AppShell';
import type { PageChrome } from './HeaderBar';

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
  handle: PageChrome | undefined,
  drawerState: DrawerState = { lastSaleDay: 20260831, lastClosedDay: 20260830 },
) {
  useAuthStore.setState({ user: admin });

  const drawerStateRepo = {
    watch: (cb: (s: DrawerState) => void) => {
      cb(drawerState);
      return () => {};
    },
  } as unknown as Container['drawerStateRepo'];
  const voidRequestRepo = {
    watchRequests: (cb: (r: VoidRequest[]) => void) => {
      cb([]);
      return () => {};
    },
  } as unknown as Container['voidRequestRepo'];
  const jobOrderRepo = {
    watchAll: (cb: (jo: JobOrder[]) => void) => {
      cb([]);
      return () => {};
    },
  } as unknown as Container['jobOrderRepo'];
  const authRepo = { signOut: vi.fn() } as unknown as Container['authRepo'];
  const activityLogRepo = {
    log: vi.fn().mockResolvedValue(undefined),
  } as unknown as Container['activityLogRepo'];

  const qc = new QueryClient({
    defaultOptions: { mutations: { retry: false }, queries: { retry: false } },
  });

  const router = createMemoryRouter(
    [
      {
        path: '/',
        element: <AppShell />,
        children: [{ index: true, element: <div>stub child</div>, handle }],
      },
    ],
    { initialEntries: ['/'] },
  );

  return render(
    <DiProvider override={{ drawerStateRepo, voidRequestRepo, jobOrderRepo, authRepo, activityLogRepo }}>
      <QueryClientProvider client={qc}>
        <ThemeProvider>
          <RouterProvider router={router} />
        </ThemeProvider>
      </QueryClientProvider>
    </DiProvider>,
  );
}

describe('HeaderBar (via AppShell)', () => {
  it('renders title, subtitle and the primary action from the route handle', () => {
    harness({ title: 'Dashboard', subtitle: 'x', primaryAction: { label: 'New sale', to: '/pos' } });

    expect(screen.getByRole('heading', { name: 'Dashboard' })).toBeInTheDocument();
    expect(screen.getByText('x')).toBeInTheDocument();
    const action = screen.getByRole('link', { name: 'New sale' });
    expect(action).toHaveAttribute('href', '/pos');
  });

  it('shows "Register open" with an open drawer state', () => {
    harness({ title: 'Dashboard' }, { lastSaleDay: 20260831, lastClosedDay: 20260830 });
    expect(screen.getByText('Register open')).toBeInTheDocument();
  });

  it('shows "Register closed" when the day is sealed', () => {
    harness({ title: 'Dashboard' }, { lastSaleDay: 20260831, lastClosedDay: 20260831 });
    expect(screen.getByText('Register closed')).toBeInTheDocument();
  });

  it('renders the header with no title block for a route without a handle', () => {
    const { container } = harness(undefined);
    expect(container.querySelector('header')).toBeInTheDocument();
    expect(container.querySelector('header h1')).not.toBeInTheDocument();
    expect(screen.getByText('Register open')).toBeInTheDocument();
  });

  describe('theme toggle', () => {
    afterEach(() => {
      document.documentElement.removeAttribute('data-theme');
      localStorage.clear();
    });

    it('flips data-theme on <html>', async () => {
      harness({ title: 'Dashboard' });
      expect(document.documentElement.getAttribute('data-theme')).not.toBe('dark');

      // The boxed toggle is labeled with the mode it switches TO (reference
      // header): "Dark" while light, "Light" while dark.
      await userEvent.click(screen.getByRole('button', { name: 'Dark' }));

      expect(document.documentElement.getAttribute('data-theme')).toBe('dark');
    });
  });
});
