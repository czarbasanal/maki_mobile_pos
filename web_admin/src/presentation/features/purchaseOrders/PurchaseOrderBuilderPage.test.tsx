// The redesigned builder: scope chips, override-visible qty with reset,
// unchecked rows grey out and blank their Amount, and the sticky bar's
// primary refuses an empty selection.
import { describe, expect, it, vi, beforeEach } from 'vitest';
import { fireEvent, render, screen, within } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { MemoryRouter, Route, Routes } from 'react-router-dom';
import { QueryClient, QueryClientProvider } from '@tanstack/react-query';
import { DiProvider, type Container } from '@/infrastructure/di/container';
import { PurchaseOrderBuilderPage } from './PurchaseOrderBuilderPage';
import { clearSubscriptionCache } from '@/presentation/hooks/useFirestoreSubscription';
import type { Product, Sale } from '@/domain/entities';

const product = (o: Partial<Product> = {}): Product =>
  ({
    id: 'p1', sku: 'SKU-1', name: 'Brake Pad', category: null, unit: 'pcs',
    cost: 100, price: 250, quantity: 0, reorderLevel: 2, costCode: 'A',
    barcodes: [], sellingOptions: [], supplierId: null, supplierName: null,
    baseSku: null, variationNumber: null, isActive: true, imageUrl: null, notes: null,
    searchKeywords: [], createdAt: new Date(), updatedAt: null,
    createdBy: 'u1', updatedBy: 'u1', createdByName: 'C', updatedByName: 'C',
    ...o,
  }) as Product;

function harness(products: Product[], createFn = vi.fn(), sales: Sale[] = []) {
  clearSubscriptionCache();
  const qc = new QueryClient({ defaultOptions: { queries: { retry: false } } });
  const override = {
    productRepo: {
      watchAll: (cb: (p: Product[]) => void) => {
        cb(products);
        return () => {};
      },
    },
    saleRepo: {
      // The velocity window reads recent sales; out-of-stock parts are
      // listed regardless, low-stock rows need movement to appear.
      list: vi.fn(async (): Promise<Sale[]> => sales),
    },
    purchaseOrderRepo: { create: createFn },
  } as unknown as Container;
  render(
    <DiProvider override={override}>
      <QueryClientProvider client={qc}>
        <MemoryRouter initialEntries={['/purchase-orders/new']}>
          <Routes>
            <Route path="/purchase-orders/new" element={<PurchaseOrderBuilderPage />} />
            <Route path="/purchase-orders/:id" element={<div>PO DETAIL</div>} />
          </Routes>
        </MemoryRouter>
      </QueryClientProvider>
    </DiProvider>,
  );
}

describe('PurchaseOrderBuilderPage (redesign)', () => {
  beforeEach(() => clearSubscriptionCache());

  it('lists an out-of-stock part with its OUT badge, supplier Not set, and scope counts', async () => {
    harness([product({ quantity: 0 })]);
    expect(await screen.findByText('Brake Pad')).toBeInTheDocument();
    expect(screen.getByText('OUT')).toBeInTheDocument();
    expect(screen.getByText('Not set')).toBeInTheDocument();
    expect(screen.getByRole('button', { name: /Needs buying 1/ })).toBeInTheDocument();
    expect(screen.getByRole('button', { name: /Out of stock 1/ })).toBeInTheDocument();
  });

  it('an edited qty shows the override border and a reset that restores the suggestion', async () => {
    harness([product({ quantity: 0 })]);
    const input = await screen.findByLabelText('Quantity for Brake Pad');
    const suggested = (input as HTMLInputElement).value;

    await userEvent.clear(input);
    await userEvent.type(input, '9');
    expect(input).toHaveClass('border-accent-text');

    await userEvent.click(screen.getByTitle(`Reset to suggested (${suggested})`));
    expect(input).toHaveValue(Number(suggested));
    expect(input).not.toHaveClass('border-accent-text');
  });

  it('unchecking a line greys it, blanks Amount, and empties the selection disables Create', async () => {
    harness([product({ quantity: 0 })]);
    const row = (await screen.findByText('Brake Pad')).closest('tr')!;
    expect(within(row).queryByText('—')).not.toBeInTheDocument();

    await userEvent.click(within(row).getByRole('checkbox', { name: /Include Brake Pad/ }));
    expect(row).toHaveClass('bg-surface-2');
    expect(within(row).getByText('—')).toBeInTheDocument();
    expect(screen.getByRole('button', { name: 'Create purchase order' })).toBeDisabled();
  });

  it('the sticky bar counts lines, units, suppliers and the estimated cost', async () => {
    harness([
      product({ id: 'p1', sku: 'A', name: 'Pad', quantity: 0, cost: 100, supplierName: 'HMJ' }),
      product({ id: 'p2', sku: 'B', name: 'Chain', quantity: 0, cost: 50, supplierName: 'Ramos' }),
    ]);
    await screen.findByText('Pad');
    expect(screen.getByText('Estimated cost')).toBeInTheDocument();
    // Two chosen lines from two suppliers.
    const suppliers = screen.getByText('Suppliers').nextElementSibling!;
    expect(suppliers.textContent).toBe('2');
  });
});

const chainSale = {
  id: 's1',
  items: [{ id: 'si1', productId: 'p2', quantity: 30 }],
  laborLines: [],
  feeLines: [],
  status: 'completed',
  voidedAt: null,
} as unknown as Sale;

describe('PurchaseOrderBuilderPage — selection vs scope (review pins)', () => {
  it('switching scope preserves picks and qty overrides', async () => {
    harness(
      [
        product({ id: 'p1', sku: 'A', name: 'Pad', quantity: 0 }),
        product({ id: 'p2', sku: 'B', name: 'Chain', quantity: 5, reorderLevel: 10 }),
      ],
      vi.fn(),
      [chainSale],
    );
    const row = (await screen.findByText('Pad')).closest('tr')!;
    await userEvent.click(within(row).getByRole('checkbox', { name: /Include Pad/ }));
    const input = screen.getByLabelText('Quantity for Chain');
    // Direct change: clearing a controlled number input coerces '' -> 1
    // mid-typing (known tradeoff), which would turn "type 7" into 17.
    fireEvent.change(input, { target: { value: '7' } });

    // Scope away and back — the same rows array is only filtered, so the
    // unchecked line and the override must survive.
    await userEvent.click(screen.getByRole('button', { name: /Out of stock 1/ }));
    await userEvent.click(screen.getByRole('button', { name: /Needs buying 2/ }));

    const rowAfter = screen.getByText('Pad').closest('tr')!;
    expect(within(rowAfter).getByRole('checkbox', { name: /Include Pad/ })).toHaveAttribute(
      'aria-checked',
      'false',
    );
    expect(screen.getByLabelText('Quantity for Chain')).toHaveValue(7);
  });

  it('the header toggle acts on the VISIBLE scope only', async () => {
    harness(
      [
        product({ id: 'p1', sku: 'A', name: 'Pad', quantity: 0 }),
        product({ id: 'p2', sku: 'B', name: 'Chain', quantity: 5, reorderLevel: 10 }),
      ],
      vi.fn(),
      [chainSale],
    );
    await screen.findByText('Pad');
    // Narrow to out-of-stock (Pad only), unselect-all there.
    await userEvent.click(screen.getByRole('button', { name: /Out of stock 1/ }));
    await userEvent.click(screen.getByRole('checkbox', { name: 'Select all' }));

    // Chain (hidden, still picked) keeps the bar's line count at 1.
    const lines = screen.getByText('Lines').nextElementSibling!;
    expect(lines.textContent).toBe('1');
  });
});
