import { describe, expect, it, vi, beforeEach } from 'vitest';
import { render, screen, waitFor } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { MemoryRouter } from 'react-router-dom';
import { QueryClient, QueryClientProvider } from '@tanstack/react-query';
import { DiProvider, type Container } from '@/infrastructure/di/container';
import { VoidRequestsPage } from './VoidRequestsPage';
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

function harness(requests: VoidRequest[], overrides: Partial<Container> = {}) {
  useAuthStore.setState({
    user: {
      id: 'u1', email: 'a@b.c', displayName: 'Czar', role: 'admin', isActive: true,
    } as User,
  });
  const qc = new QueryClient({ defaultOptions: { queries: { retry: false } } });
  const voidRequestRepo = {
    watchRequests: (cb: (r: VoidRequest[]) => void) => { cb(requests); return () => {}; },
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
        <MemoryRouter><VoidRequestsPage /></MemoryRouter>
      </DiProvider>
    </QueryClientProvider>,
  );
  return { voidRequestRepo };
}

describe('VoidRequestsPage', () => {
  beforeEach(() => vi.clearAllMocks());

  it('names the sale, who asked, why, and what was on it', async () => {
    harness([request()]);
    expect(await screen.findByText('SALE-20260828-020')).toBeInTheDocument();
    expect(screen.getByText(/Belle/)).toBeInTheDocument();
    expect(screen.getByText(/Payment issue/)).toBeInTheDocument();
    expect(screen.getByText(/Ilis carbon brass/)).toBeInTheDocument();
  });

  it('says so plainly when nothing is waiting', async () => {
    harness([]);
    expect(await screen.findByText(/Nothing waiting/i)).toBeInTheDocument();
  });

  it('approving voids the sale, then resolves the request', async () => {
    const voidSale = vi.fn(async () => {});
    const { voidRequestRepo } = harness([request()], {
      saleRepo: { voidSale } as unknown as Container['saleRepo'],
    });
    await userEvent.click(await screen.findByRole('button', { name: /approve/i }));

    await waitFor(() => expect(voidSale).toHaveBeenCalled());
    expect(voidRequestRepo.resolve).toHaveBeenCalledWith(
      expect.objectContaining({ status: 'approved' }),
    );
  });

  it('rejecting will not commit without a reason', async () => {
    const { voidRequestRepo } = harness([request()]);
    await userEvent.click(await screen.findByRole('button', { name: /^reject$/i }));

    // The cashier is owed an explanation, so the commit stays disabled.
    expect(voidRequestRepo.resolve).not.toHaveBeenCalled();
    expect(screen.getByRole('button', { name: /confirm reject/i })).toBeDisabled();

    await userEvent.type(screen.getByPlaceholderText(/why/i), 'Sale is correct');
    await userEvent.click(screen.getByRole('button', { name: /confirm reject/i }));

    await waitFor(() =>
      expect(voidRequestRepo.resolve).toHaveBeenCalledWith(
        expect.objectContaining({ status: 'rejected', rejectionReason: 'Sale is correct' }),
      ),
    );
  });

  it('lists resolved requests separately, with who resolved them', async () => {
    harness([
      request({ id: 'r1' }),
      request({
        id: 'r2',
        saleNumber: 'SALE-20260827-004',
        status: 'rejected',
        resolvedByName: 'Czar',
        rejectionReason: 'Sale is correct',
      }),
    ]);

    expect(await screen.findByText('Resolved')).toBeInTheDocument();
    expect(screen.getByText('SALE-20260827-004')).toBeInTheDocument();
    expect(screen.getByText('Rejected')).toBeInTheDocument();
    expect(screen.getByText('Czar')).toBeInTheDocument();
    // A resolved one is history — it must not offer Approve again.
    expect(screen.getAllByRole('button', { name: /approve/i })).toHaveLength(1);
  });
});
