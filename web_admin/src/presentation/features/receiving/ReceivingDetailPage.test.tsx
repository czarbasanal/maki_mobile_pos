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
    { id: 'i2', productId: 'p2', sku: 'SKU-2', name: 'Chain', quantity: 5, unit: 'pcs', unitCost: 10, costCode: 'A', isNewVariation: true, newProductId: null, notes: null },
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
  invoiceNumber: null as string | null,
  receivedOn: null as string | null,
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

describe('ReceivingDetailPage — invoice/received-on facts', () => {
  it('shows neither additive fact when the receiving predates both fields', () => {
    renderPage();
    expect(screen.queryByText('Invoice / DR no.')).not.toBeInTheDocument();
    expect(screen.queryByText('Delivery date')).not.toBeInTheDocument();
  });

  it('shows both when the receiving carries them, without shifting the calendar day', () => {
    receiving.invoiceNumber = 'INV-4471';
    receiving.receivedOn = '2026-08-30';
    try {
      renderPage();
      expect(screen.getByText('Invoice / DR no.')).toBeInTheDocument();
      expect(screen.getByText('INV-4471')).toBeInTheDocument();
      expect(screen.getByText('Delivery date')).toBeInTheDocument();
      expect(screen.getByText('Aug 30, 2026')).toBeInTheDocument();
    } finally {
      receiving.invoiceNumber = null;
      receiving.receivedOn = null;
    }
  });
});

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

    // Redesign order: Item leads (thumbnail + name), then the scannable SKU
    // column, with Margin new between Sell price and Line total.
    const headers = screen.getAllByRole('columnheader').map((h) => h.textContent);
    expect(headers).toEqual(['Item', 'SKU', 'Qty', 'Unit cost', 'Sell price', 'Margin', 'Line total']);
  });

  it('puts each row’s SKU in the first cell, not trailing the name', () => {
    renderPage();

    const row = screen.getByText('Brake Pad').closest('tr')!;
    const cells = Array.from(row.querySelectorAll('td')).map((c) => c.textContent);
    // Item cell carries the name; the SKU sits alone in its own second cell.
    expect(cells[0]).toContain('Brake Pad');
    expect(cells[0]).not.toContain('SKU-1');
    expect(cells[1]).toContain('SKU-1');
  });

  it('keeps the new-variation badge with the item name', () => {
    // The badge describes the product, not its code, so splitting the column
    // must not strand it in the SKU cell.
    renderPage();

    const row = screen.getByText('Chain').closest('tr')!;
    const cells = Array.from(row.querySelectorAll('td'));
    expect(cells).toHaveLength(7);
    expect(cells[0].textContent).toContain('NEW VARIATION');
    expect(cells[1].textContent).not.toContain('NEW VARIATION');
  });
});
