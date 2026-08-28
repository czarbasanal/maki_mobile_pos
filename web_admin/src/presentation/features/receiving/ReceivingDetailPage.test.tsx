import { describe, expect, it, vi } from 'vitest';
import { render, screen } from '@testing-library/react';
import { QueryClient, QueryClientProvider } from '@tanstack/react-query';
import { DiProvider, type Container } from '@/infrastructure/di/container';
import type { Product } from '@/domain/entities';
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

function renderPage(products: Product[] = []) {
  const qc = new QueryClient({ defaultOptions: { queries: { retry: false } } });
  // The page resolves each line's selling price from the product catalogue.
  const productRepo: Partial<Container['productRepo']> = {
    watchAll: (cb: (p: Product[]) => void) => { cb(products); return () => {}; },
  };
  return render(
    <DiProvider override={{ productRepo: productRepo as Container['productRepo'] }}>
      <QueryClientProvider client={qc}>
        <MemoryRouter initialEntries={['/receiving/rcv-1']}>
          <Routes>
            <Route path="/receiving/:id" element={<ReceivingDetailPage />} />
          </Routes>
        </MemoryRouter>
      </QueryClientProvider>
    </DiProvider>,
  );
}

describe('ReceivingDetailPage quantity label', () => {
  it('labels the total quantity row "Total units", not "Total items"', () => {
    renderPage();
    expect(screen.getByText('Total units')).toBeInTheDocument();
    expect(screen.queryByText('Total items')).toBeNull();
  });
});

describe('ReceivingDetailPage item table columns', () => {
  it('gives the SKU its own column ahead of the item name', () => {
    renderPage();

    const headers = screen.getAllByRole('columnheader').map((h) => h.textContent);
    expect(headers).toEqual(['SKU', 'Item name', 'Qty', 'Cost', 'Price', 'Line total']);
  });

  it('puts each row’s SKU in the first cell, not trailing the name', () => {
    renderPage();

    const row = screen.getByText('Brake Pad').closest('tr')!;
    const cells = Array.from(row.querySelectorAll('td')).map((c) => c.textContent);
    expect(cells[0]).toBe('SKU-1');
    // The name cell must no longer carry the SKU alongside it.
    expect(cells[1]).toBe('Brake Pad');
  });

  it('keeps the new-variation badge with the item name', () => {
    // The badge describes the product, not its code, so splitting the column
    // must not strand it in the SKU cell.
    renderPage();

    const row = screen.getByText('Brake Pad').closest('tr')!;
    const cells = Array.from(row.querySelectorAll('td'));
    expect(cells).toHaveLength(6);
  });
});
