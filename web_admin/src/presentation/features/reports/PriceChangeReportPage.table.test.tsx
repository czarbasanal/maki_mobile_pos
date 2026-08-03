// The Option column on the price-change TABLE (as opposed to the CSV export,
// covered in PriceChangeReportPage.test.ts). Renders the page against a
// mocked repository so we can assert on the actual <td> cell content, not
// just that a label string appears somewhere on the page — a stray "By 3"
// anywhere in the DOM would pass a weaker assertion even if it landed in the
// wrong column or the wrong row.
import { describe, expect, it, vi } from 'vitest';
import { render, screen, within } from '@testing-library/react';
import { MemoryRouter } from 'react-router-dom';
import { QueryClient, QueryClientProvider } from '@tanstack/react-query';
import { DiProvider, type Container } from '@/infrastructure/di/container';
import { PriceChangeReportPage } from './PriceChangeReportPage';
import type { Product } from '@/domain/entities';
import type { PriceChangeEntry } from '@/domain/products/priceChangeReport';

const pulleyBall = (o: Partial<Product> = {}): Product =>
  ({
    id: 'p1',
    sku: 'ABC-1',
    name: 'Pulley Ball',
    cost: 60,
    price: 120,
    quantity: 5,
    reorderLevel: 1,
    unit: 'pcs',
    isActive: true,
    ...o,
  }) as Product;

function entry(o: Partial<PriceChangeEntry> = {}): PriceChangeEntry {
  return {
    id: 'e1',
    productId: 'p1',
    price: 120,
    cost: 70,
    changedAt: new Date('2026-07-01T00:00:00Z'),
    changedBy: 'u1',
    reason: 'Restock',
    optionId: null,
    optionLabel: null,
    optionPieces: null,
    ...o,
  };
}

function harness(entries: PriceChangeEntry[], products: Product[] = [pulleyBall()]) {
  const qc = new QueryClient({ defaultOptions: { queries: { retry: false } } });
  const productRepo: Partial<Container['productRepo']> = {
    listPriceChangesInRange: vi.fn().mockResolvedValue(entries),
    watchAll: (cb: (p: Product[]) => void) => {
      cb(products);
      return () => {};
    },
  };
  return render(
    <DiProvider override={{ productRepo: productRepo as Container['productRepo'] }}>
      <QueryClientProvider client={qc}>
        <MemoryRouter initialEntries={['/reports/price-changes']}>
          <PriceChangeReportPage />
        </MemoryRouter>
      </QueryClientProvider>
    </DiProvider>,
  );
}

describe('PriceChangeReportPage table — Option column', () => {
  it('shows an Option column header', async () => {
    harness([entry()]);
    expect(await screen.findByRole('columnheader', { name: 'Option' })).toBeInTheDocument();
  });

  it("shows the option's label in the Option cell for an option row, and leaves it blank in the Option cell for a base row of the same product", async () => {
    harness([
      entry({ id: 'base', reason: 'Base restock', price: 120 }),
      entry({
        id: 'opt',
        reason: 'By 3 restock',
        price: 330,
        optionId: 'o2',
        optionLabel: 'By 3',
        optionPieces: 3,
      }),
    ]);

    const baseRow = (await screen.findByText('Base restock')).closest('tr');
    const optionRow = screen.getByText('By 3 restock').closest('tr');
    if (!baseRow || !optionRow) throw new Error('expected row not found');

    // Columns: Product(0), SKU(1), Option(2), ...
    const baseCells = within(baseRow).getAllByRole('cell');
    const optionCells = within(optionRow).getAllByRole('cell');
    expect(baseCells[2].textContent).toBe('');
    expect(optionCells[2].textContent).toBe('By 3');
  });

  it('renders a product with no options exactly as before, aside from a blank Option cell', async () => {
    harness([entry()]);

    const row = (await screen.findByText('Restock')).closest('tr');
    if (!row) throw new Error('expected row not found');

    const cells = within(row).getAllByRole('cell');
    expect(cells[0].textContent).toBe('Pulley Ball'); // Product unaffected
    expect(cells[1].textContent).toBe('ABC-1'); // SKU unaffected
    expect(cells[2].textContent).toBe(''); // Option: blank, not "Base" or "—"
  });
});
