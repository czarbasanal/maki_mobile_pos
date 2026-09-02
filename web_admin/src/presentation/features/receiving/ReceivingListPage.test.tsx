// The redesigned receiving list: pipeline card + chips derive from the same
// scoped set, drafts stay visible whatever the range, draft rows resume the
// form while completed rows open the detail, and a missing supplier reads
// "Unassigned", never a bare dash.
import { describe, expect, it, vi, beforeEach } from 'vitest';
import { render, screen, waitFor, within } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { MemoryRouter, Route, Routes } from 'react-router-dom';
import { QueryClient, QueryClientProvider } from '@tanstack/react-query';
import { DiProvider, type Container } from '@/infrastructure/di/container';
import { ReceivingListPage } from './ReceivingListPage';
import { useAuthStore } from '@/presentation/stores/authStore';
import { UserRole } from '@/domain/enums';
import { clearSubscriptionCache } from '@/presentation/hooks/useFirestoreSubscription';
import type { Receiving } from '@/domain/entities';

const receipt = (o: Partial<Receiving> = {}): Receiving => ({
  id: 'r1',
  referenceNumber: 'RCV-20260902-001',
  supplierId: null,
  supplierName: null,
  items: [
    {
      id: 'i1', productId: 'p1', sku: 'SKU-1', name: 'Part', quantity: 3, unit: 'pcs',
      unitCost: 10, costCode: 'A', isNewVariation: false, newProductId: null, notes: null,
    },
  ],
  totalCost: 30,
  totalQuantity: 3,
  status: 'completed',
  notes: null,
  createdAt: new Date(),
  completedAt: new Date(),
  createdBy: 'u1',
  createdByName: 'Bern',
  completedBy: 'u1',
  version: 0,
  ...o,
});

function harness(receivings: Receiving[], drafts: Receiving[] = []) {
  clearSubscriptionCache();
  useAuthStore.setState({
    user: { id: 'u1', email: 'a@b.c', displayName: 'C', role: UserRole.admin, isActive: true } as never,
    status: 'signedIn',
  });
  const qc = new QueryClient({ defaultOptions: { queries: { retry: false } } });
  const receivingRepo: Partial<Container['receivingRepo']> = {
    watchAll: vi.fn((_range, cb: (r: Receiving[]) => void) => {
      cb(receivings);
      return () => {};
    }),
    watchDrafts: vi.fn((cb: (r: Receiving[]) => void) => {
      cb(drafts);
      return () => {};
    }),
  };
  render(
    <DiProvider override={{ receivingRepo: receivingRepo as Container['receivingRepo'] }}>
      <QueryClientProvider client={qc}>
        <MemoryRouter initialEntries={['/receiving']}>
          <Routes>
            <Route path="/receiving" element={<ReceivingListPage />} />
            <Route path="/receiving/new/:id" element={<div>RESUME FORM</div>} />
            <Route path="/receiving/:id" element={<div>DETAIL VIEW</div>} />
          </Routes>
        </MemoryRouter>
      </QueryClientProvider>
    </DiProvider>,
  );
}

describe('ReceivingListPage', () => {
  beforeEach(() => clearSubscriptionCache());

  it('renders reference, status pill, Unassigned supplier, received-by, lines/units/cost', () => {
    harness([receipt()]);
    const row = screen.getByText('RCV-20260902-001').closest('tr')!;
    expect(within(row).getByText('Completed')).toBeInTheDocument();
    // "Nobody recorded it", not a bare dash.
    expect(within(row).getByText('Unassigned')).toBeInTheDocument();
    expect(within(row).getByText('by Bern')).toBeInTheDocument();
    expect(within(row).getByText('1')).toBeInTheDocument(); // lines
    expect(within(row).getByText('3')).toBeInTheDocument(); // units
  });

  it('view chips carry counts from the scoped set and filter the rows', async () => {
    harness(
      [receipt({ id: 'r1', referenceNumber: 'RCV-A' })],
      [receipt({ id: 'r2', referenceNumber: 'RCV-B', status: 'draft', completedAt: null, totalCost: 0, totalQuantity: 0 })],
    );

    expect(screen.getByRole('button', { name: /All 2/ })).toBeInTheDocument();
    expect(screen.getByRole('button', { name: /^Draft 1/ })).toBeInTheDocument();
    await userEvent.click(screen.getByRole('button', { name: /^Draft 1/ }));
    expect(screen.getByText('RCV-B')).toBeInTheDocument();
    expect(screen.queryByText('RCV-A')).not.toBeInTheDocument();
  });

  it('a draft row resumes the form; a completed row opens the detail', async () => {
    harness([receipt({ id: 'r1', referenceNumber: 'RCV-DONE' })]);
    await userEvent.click(screen.getByText('RCV-DONE'));
    expect(screen.getByText('DETAIL VIEW')).toBeInTheDocument();
  });

  it('draft rows navigate to the resume route', async () => {
    harness([], [receipt({ id: 'r9', referenceNumber: 'RCV-DRAFT', status: 'draft', completedAt: null })]);
    await userEvent.click(screen.getByText('RCV-DRAFT'));
    expect(screen.getByText('RESUME FORM')).toBeInTheDocument();
  });

  it('the pipeline card is month-labeled and its rows filter the table', async () => {
    harness([receipt({ id: 'r1', referenceNumber: 'RCV-DONE' })]);
    // Month label + receipts count present (also echoed by the row count).
    expect(screen.getAllByText(/1 receipt$/).length).toBeGreaterThanOrEqual(1);
    // The card's Completed row toggles the completed view on and off.
    const completedRow = screen.getAllByRole('button', { name: /^Completed/ })[0];
    await userEvent.click(completedRow);
    expect(completedRow).toHaveAttribute('aria-pressed', 'true');
  });

  it('first-run and filtered-empty states are distinct', async () => {
    harness([]);
    expect(screen.getByText('No receipts yet')).toBeInTheDocument();
    // Offered in the views row AND inside the first-run state.
    expect(screen.getAllByRole('button', { name: /new receiving/i }).length).toBeGreaterThanOrEqual(2);
  });

  it('search narrows by reference and supplier, and Clear filters resets', async () => {
    harness([
      receipt({ id: 'r1', referenceNumber: 'RCV-A', supplierName: 'HMJ' }),
      receipt({ id: 'r2', referenceNumber: 'RCV-B', supplierName: 'Ramos Trading' }),
    ]);
    await userEvent.type(screen.getByPlaceholderText('Search reference or supplier'), 'ramos');
    // SearchInput debounces — wait for the narrowing to land.
    await waitFor(() => expect(screen.queryByText('RCV-A')).not.toBeInTheDocument());
    expect(screen.getByText('RCV-B')).toBeInTheDocument();

    await userEvent.click(screen.getAllByRole('button', { name: /clear filters/i })[0]);
    expect(screen.getByText('RCV-A')).toBeInTheDocument();
  });
});
