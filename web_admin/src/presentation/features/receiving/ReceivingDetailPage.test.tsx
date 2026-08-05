import { describe, expect, it, vi } from 'vitest';
import { render, screen } from '@testing-library/react';
import { QueryClient, QueryClientProvider } from '@tanstack/react-query';
import { MemoryRouter, Route, Routes } from 'react-router-dom';
import { ReceivingDetailPage } from './ReceivingDetailPage';

// 3 lines, 12 pieces — totalQuantity is a piece sum, never a line count.
const receiving = {
  id: 'rcv-1',
  referenceNumber: 'RCV-20260801',
  supplierId: 's1',
  supplierName: 'Acme',
  items: [
    { id: 'i1', productId: 'p1', sku: 'SKU-1', name: 'Brake Pad', quantity: 4, unit: 'pcs', unitCost: 10, costCode: 'A', isNewVariation: false, newProductId: null, notes: null },
    { id: 'i2', productId: 'p2', sku: 'SKU-2', name: 'Chain', quantity: 5, unit: 'pcs', unitCost: 10, costCode: 'A', isNewVariation: false, newProductId: null, notes: null },
    { id: 'i3', productId: 'p3', sku: 'SKU-3', name: 'Bolt', quantity: 3, unit: 'pcs', unitCost: 10, costCode: 'A', isNewVariation: false, newProductId: null, notes: null },
  ],
  totalCost: 120,
  totalQuantity: 12,
  status: 'completed',
  notes: null,
  createdAt: new Date('2026-08-05'),
  completedAt: new Date('2026-08-05'),
  createdBy: 'u1',
  createdByName: 'Tester',
  completedBy: 'u1',
};

vi.mock('@/presentation/hooks/useReceiving', () => ({
  useReceiving: () => ({
    data: receiving,
    isLoading: false,
    error: null,
  }),
}));

function renderPage() {
  const qc = new QueryClient({ defaultOptions: { queries: { retry: false } } });
  return render(
    <QueryClientProvider client={qc}>
      <MemoryRouter initialEntries={['/receiving/rcv-1']}>
        <Routes>
          <Route path="/receiving/:id" element={<ReceivingDetailPage />} />
        </Routes>
      </MemoryRouter>
    </QueryClientProvider>,
  );
}

describe('ReceivingDetailPage quantity label', () => {
  it('labels the total quantity row "Total units", not "Total items"', () => {
    renderPage();
    expect(screen.getByText('Total units')).toBeInTheDocument();
    expect(screen.queryByText('Total items')).toBeNull();
  });
});
