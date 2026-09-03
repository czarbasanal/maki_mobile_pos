// The redesigned PO list: ViewChips over the three statuses, per-view
// teaching empty states, and rows that open the order.
import { describe, expect, it, vi, beforeEach } from 'vitest';
import { render, screen, within } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { MemoryRouter, Route, Routes } from 'react-router-dom';
import { QueryClient, QueryClientProvider } from '@tanstack/react-query';
import { DiProvider, type Container } from '@/infrastructure/di/container';
import { PurchaseOrdersPage } from './PurchaseOrdersPage';
import { clearSubscriptionCache } from '@/presentation/hooks/useFirestoreSubscription';
import type { PurchaseOrder } from '@/domain/entities';

const po = (o: Partial<PurchaseOrder> = {}): PurchaseOrder => ({
  id: 'po1',
  referenceNumber: 'PO-20260903-001',
  supplierId: null,
  supplierName: null,
  items: [
    {
      id: 'i1', productId: 'p1', sku: 'SKU-1', name: 'Part', quantity: 4, unit: 'pcs',
      unitCost: 100, costCode: 'A', supplierId: null, supplierName: null,
    },
  ],
  totalCost: 400,
  totalQuantity: 4,
  status: 'ordered',
  notes: null,
  createdAt: new Date(),
  createdBy: 'u1',
  createdByName: 'Czar',
  orderedAt: null,
  receivedAt: null,
  receivingId: null,
  windowDays: null,
  coverDays: null,
  ...o,
});

function harness(orders: PurchaseOrder[]) {
  clearSubscriptionCache();
  const qc = new QueryClient({ defaultOptions: { queries: { retry: false } } });
  const purchaseOrderRepo: Partial<Container['purchaseOrderRepo']> = {
    watchAll: vi.fn((cb: (o: PurchaseOrder[]) => void) => {
      cb(orders);
      return () => {};
    }),
  };
  render(
    <DiProvider override={{ purchaseOrderRepo: purchaseOrderRepo as Container['purchaseOrderRepo'] }}>
      <QueryClientProvider client={qc}>
        <MemoryRouter initialEntries={['/purchase-orders']}>
          <Routes>
            <Route path="/purchase-orders" element={<PurchaseOrdersPage />} />
            <Route path="/purchase-orders/:id" element={<div>PO DETAIL</div>} />
            <Route path="/purchase-orders/new" element={<div>BUILDER</div>} />
          </Routes>
        </MemoryRouter>
      </QueryClientProvider>
    </DiProvider>,
  );
}

describe('PurchaseOrdersPage (redesign)', () => {
  beforeEach(() => clearSubscriptionCache());

  it('chips carry counts; pending holds drafts AND out-buying orders', () => {
    harness([
      po({ id: 'a', referenceNumber: 'PO-A', status: 'draft' }),
      po({ id: 'b', referenceNumber: 'PO-B', status: 'ordered' }),
      po({ id: 'c', referenceNumber: 'PO-C', status: 'received' }),
    ]);
    expect(screen.getByRole('button', { name: /Pending 2/ })).toBeInTheDocument();
    expect(screen.getByRole('button', { name: /Completed 1/ })).toBeInTheDocument();
    // Pending view shows both, with distinct pills.
    const rowA = screen.getByText('PO-A').closest('tr')!;
    expect(within(rowA).getByText('Draft')).toBeInTheDocument();
    const rowB = screen.getByText('PO-B').closest('tr')!;
    expect(within(rowB).getByText('Out buying')).toBeInTheDocument();
  });

  it('each empty view teaches with its own copy', async () => {
    harness([]);
    expect(screen.getByText('Nothing pending')).toBeInTheDocument();
    await userEvent.click(screen.getByRole('button', { name: /Completed 0/ }));
    expect(screen.getByText('No completed orders')).toBeInTheDocument();
    expect(screen.getByText(/finished buying against will land here/)).toBeInTheDocument();
    await userEvent.click(screen.getByRole('button', { name: /Cancelled 0/ }));
    expect(screen.getByText('No cancelled orders')).toBeInTheDocument();
  });

  it('a row opens the order', async () => {
    harness([po({ id: 'a', referenceNumber: 'PO-A' })]);
    await userEvent.click(screen.getByText('PO-A'));
    expect(screen.getByText('PO DETAIL')).toBeInTheDocument();
  });
});
