import { describe, expect, it, vi, beforeEach } from 'vitest';
import { render, screen, waitFor } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { MemoryRouter } from 'react-router-dom';
import { QueryClient, QueryClientProvider } from '@tanstack/react-query';
import { DiProvider, type Container } from '@/infrastructure/di/container';
import { VoidRequestsBell } from './VoidRequestsBell';
import { useAuthStore } from '@/presentation/stores/authStore';
import type { VoidRequest, User } from '@/domain/entities';

const request = (o: Partial<VoidRequest> = {}): VoidRequest => ({
  id: 'r1',
  saleId: 's1',
  saleNumber: 'SALE-20260828-020',
  saleGrandTotal: 285,
  requestedBy: 'u-belle',
  requestedByName: 'Belle',
  requestedByRole: 'cashier',
  reason: 'Payment issue',
  status: 'pending',
  read: false,
  createdAt: new Date('2026-08-28T13:00:00Z'),
  resolvedBy: null,
  resolvedByName: null,
  resolvedAt: null,
  rejectionReason: null,
  itemsSummary: '1× Ilis carbon brass',
  ...o,
});

const user = (role: string): User =>
  ({ id: 'u1', email: 'a@b.c', displayName: 'Czar', role, isActive: true }) as User;

function harness(requests: VoidRequest[], overrides: Partial<Container> = {}) {
  const qc = new QueryClient({ defaultOptions: { queries: { retry: false } } });
  const voidRequestRepo = {
    watchRequests: (cb: (r: VoidRequest[]) => void) => {
      cb(requests);
      return () => {};
    },
    markAllRead: vi.fn(async () => {}),
    resolve: vi.fn(async () => {}),
    ...(overrides.voidRequestRepo ?? {}),
  } as unknown as Container['voidRequestRepo'];

  render(
    <QueryClientProvider client={qc}>
      <DiProvider
        override={{
          voidRequestRepo,
          saleRepo: { voidSale: vi.fn(async () => {}) },
          activityLogRepo: { create: vi.fn() },
          ...overrides,
        } as Container}
      >
        <MemoryRouter>
          <VoidRequestsBell />
        </MemoryRouter>
      </DiProvider>
    </QueryClientProvider>,
  );
  return { voidRequestRepo };
}

describe('VoidRequestsBell', () => {
  beforeEach(() => {
    useAuthStore.setState({ user: user('admin') });
  });

  it('shows the unread count on the bell', async () => {
    harness([request({ id: 'r1' }), request({ id: 'r2' })]);
    await waitFor(() => expect(screen.getByText('2')).toBeInTheDocument());
  });

  it('shows no badge when nothing is waiting', async () => {
    harness([request({ status: 'approved', read: true })]);
    await waitFor(() =>
      expect(screen.getByRole('button', { name: /void requests/i })).toBeInTheDocument(),
    );
    expect(screen.queryByText('1')).not.toBeInTheDocument();
  });

  it('opens a panel naming the sale, who asked, and why', async () => {
    harness([request()]);
    await userEvent.click(await screen.findByRole('button', { name: /void requests/i }));

    expect(screen.getByText('SALE-20260828-020')).toBeInTheDocument();
    expect(screen.getByText(/Belle/)).toBeInTheDocument();
    expect(screen.getByText(/Payment issue/)).toBeInTheDocument();
    expect(screen.getByText(/Ilis carbon brass/)).toBeInTheDocument();
  });

  it('clears the badge when the panel is opened', async () => {
    const { voidRequestRepo } = harness([request()]);
    await userEvent.click(await screen.findByRole('button', { name: /void requests/i }));
    await waitFor(() => expect(voidRequestRepo.markAllRead).toHaveBeenCalled());
  });

  it('approving voids the sale and resolves the request', async () => {
    const voidSale = vi.fn(async () => {});
    const { voidRequestRepo } = harness([request()], {
      saleRepo: { voidSale } as unknown as Container['saleRepo'],
    });
    await userEvent.click(await screen.findByRole('button', { name: /void requests/i }));
    await userEvent.click(screen.getByRole('button', { name: /approve/i }));

    await waitFor(() => expect(voidSale).toHaveBeenCalled());
    expect(voidRequestRepo.resolve).toHaveBeenCalledWith(
      expect.objectContaining({ status: 'approved' }),
    );
  });

  it('rejecting asks for a reason before resolving', async () => {
    const { voidRequestRepo } = harness([request()]);
    await userEvent.click(await screen.findByRole('button', { name: /void requests/i }));
    await userEvent.click(screen.getByRole('button', { name: /reject/i }));

    // Nothing written yet — the cashier is owed an explanation.
    expect(voidRequestRepo.resolve).not.toHaveBeenCalled();

    await userEvent.type(screen.getByPlaceholderText(/why/i), 'Sale is correct');
    await userEvent.click(screen.getByRole('button', { name: /confirm reject/i }));

    await waitFor(() =>
      expect(voidRequestRepo.resolve).toHaveBeenCalledWith(
        expect.objectContaining({ status: 'rejected', rejectionReason: 'Sale is correct' }),
      ),
    );
  });

  it('renders nothing for a role that cannot void', async () => {
    useAuthStore.setState({ user: user('cashier') });
    harness([request()]);
    expect(screen.queryByRole('button', { name: /void requests/i })).not.toBeInTheDocument();
  });
});
