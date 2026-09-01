import { describe, expect, it, vi } from 'vitest';
import { render, screen, within } from '@testing-library/react';
import { QueryClient, QueryClientProvider } from '@tanstack/react-query';
import { MemoryRouter } from 'react-router-dom';
import { DiProvider, type Container } from '@/infrastructure/di/container';
import { ReceivingEntryPage } from './ReceivingEntryPage';

// 3 lines, 12 pieces — totalQuantity is a piece sum, never a line count.
const entry = {
  products: [],
  isResuming: false,
  referenceNumber: 'RCV-20260805',
  isLoadingRefs: false,
  suppliers: [],
  supplierId: '',
  setSupplierId: vi.fn(),
  search: '',
  setSearch: vi.fn(),
  matches: [],
  lines: [
    { id: 'i1', productId: 'p1', sku: 'SKU-1', name: 'Brake Pad', quantity: 4, unit: 'pcs', unitCost: 10, costCode: 'A', isNewVariation: false, newProductId: null, notes: null, pendingNewProduct: null },
    { id: 'i2', productId: 'p2', sku: 'SKU-2', name: 'Chain', quantity: 5, unit: 'pcs', unitCost: 10, costCode: 'A', isNewVariation: false, newProductId: null, notes: null, pendingNewProduct: null },
    { id: 'i3', productId: 'p3', sku: 'SKU-3', name: 'Bolt', quantity: 3, unit: 'pcs', unitCost: 10, costCode: 'A', isNewVariation: false, newProductId: null, notes: null, pendingNewProduct: null },
  ],
  addExisting: vi.fn(),
  addNew: vi.fn(),
  updateExisting: vi.fn(),
  updateNew: vi.fn(),
  removeLine: vi.fn(),
  totals: { quantity: 12, cost: 120 },
  error: null,
  isBusy: false,
  saveDraft: vi.fn(),
  receive: vi.fn(),
};

vi.mock('./useReceivingEntry', () => ({
  useReceivingEntry: () => entry,
}));

vi.mock('@/presentation/hooks/useCategories', () => ({
  useActiveCategories: () => ({ data: [] }),
}));

function renderPage() {
  const qc = new QueryClient({ defaultOptions: { queries: { retry: false } } });
  // The NewProductDialog (mounted even while closed) pulls categoryRepo from DI.
  const categoryRepo: Partial<Container['categoryRepo']> = {
    peekNextSequence: vi.fn(async () => 1),
  };
  return render(
    <DiProvider override={{ categoryRepo: categoryRepo as Container['categoryRepo'] }}>
      <QueryClientProvider client={qc}>
        <MemoryRouter initialEntries={['/receiving/new']}>
          <ReceivingEntryPage />
        </MemoryRouter>
      </QueryClientProvider>
    </DiProvider>,
  );
}

describe('ReceivingEntryPage quantity label', () => {
  it('labels the footer total quantity "units", not "items"', () => {
    // The footer is unconditional (no loading/empty gate), and the number
    // renders in its own <span> ahead of the word, so the two never share
    // a single text node — assert against the flattened footer text rather
    // than a node-scoped query.
    const { container } = renderPage();
    expect(container.textContent).toContain('12 units');
    expect(container.textContent).not.toContain('12 items');
  });
});

describe('ReceivingEntryPage item table columns', () => {
  it('gives the SKU its own column, matching the completed-receiving table', () => {
    renderPage();

    // Trailing blank header is the remove-button column.
    const headers = screen.getAllByRole('columnheader').map((h) => h.textContent);
    expect(headers).toEqual(['SKU', 'Item name', 'Qty', 'Cost', 'Price', 'Line total', '']);
  });

  it('puts each line’s SKU in the first cell, not trailing the name', () => {
    renderPage();

    const row = screen.getByText('Brake Pad').closest('tr')!;
    const cells = Array.from(row.querySelectorAll('td')).map((c) => c.textContent);
    expect(cells[0]).toBe('SKU-1');
    expect(cells[1]).toBe('Brake Pad');
  });

  it('spans the empty-state row across every column', () => {
    // Adding a column without widening this colSpan leaves "No items yet."
    // short of the table and the layout visibly ragged. The mock returns the
    // same `entry` object every call, so emptying it here really does empty
    // the rendered table — no doMock, which would be a no-op after import.
    const original = entry.lines;
    entry.lines = [];
    try {
      renderPage();
      const table = screen.getByRole('table');
      const headerCount = within(table).getAllByRole('columnheader').length;
      const placeholder = screen.getByText('No items yet.');
      expect(placeholder.closest('td')!.getAttribute('colspan')).toBe(
        String(headerCount),
      );
    } finally {
      entry.lines = original;
    }
  });
});

describe('ReceivingEntryPage pending-SKU display', () => {
  const pendingLine = (id: string, name: string) => ({
    id, productId: '', sku: '00220001', name, quantity: 1, unit: 'pcs',
    unitCost: 10, costCode: '', isNewVariation: false, newProductId: null, notes: null,
    pendingNewProduct: {
      category: 'Wheels', price: 20, reorderLevel: 0,
      autoGenerateSku: true, autoSkuCategoryCode: '0022',
      barcodes: [], notes: null, sellingOptions: [],
    },
  });

  it('shows no code for new products awaiting allocation, and not one repeated code', () => {
    // The reported bug: every new product added before saving displayed the
    // same SKU, because each one carried the same registry-floor seed.
    const original = entry.lines;
    // The shared fixture's lines all carry `pendingNewProduct: null`, so its
    // inferred element type cannot hold a pending spec — widen for this case.
    entry.lines = [
      pendingLine('n1', 'New Tyre A'),
      pendingLine('n2', 'New Tyre B'),
    ] as unknown as typeof entry.lines;
    try {
      renderPage();
      expect(screen.getAllByText('Assigned when saved')).toHaveLength(2);
      expect(screen.queryByText('00220001')).not.toBeInTheDocument();
    } finally {
      entry.lines = original;
    }
  });

  it('still shows a real SKU for an existing product line', () => {
    renderPage();
    expect(screen.getByText('SKU-1')).toBeInTheDocument();
  });
});

describe('ReceivingEntryPage selling price column', () => {
  it('resolves an existing line’s price from the product catalogue', () => {
    const originalP = entry.products;
    entry.products = [
      { id: 'p1', price: 180 },
    ] as unknown as typeof entry.products;
    try {
      renderPage();
      const row = screen.getByText('Brake Pad').closest('tr')!;
      // SKU | Item name | Qty | Cost | Price | Line total | remove
      const cells = Array.from(row.querySelectorAll('td')).map((c) => c.textContent);
      expect(cells[4]).toContain('180');
    } finally {
      entry.products = originalP;
    }
  });

  it('uses the typed price for a new product that does not exist yet', () => {
    const originalL = entry.lines;
    entry.lines = [{
      id: 'n1', productId: '', sku: '00220001', name: 'New Tyre', quantity: 1, unit: 'pcs',
      unitCost: 720, costCode: '', isNewVariation: false, newProductId: null, notes: null,
      pendingNewProduct: {
        category: 'Wheels', price: 900, reorderLevel: 0, autoGenerateSku: true,
        autoSkuCategoryCode: '0022', barcodes: [], notes: null, sellingOptions: [],
      },
    }] as unknown as typeof entry.lines;
    try {
      renderPage();
      const row = screen.getByText('New Tyre').closest('tr')!;
      const cells = Array.from(row.querySelectorAll('td')).map((c) => c.textContent);
      expect(cells[4]).toContain('900');
    } finally {
      entry.lines = originalL;
    }
  });

  it('shows a dash when the product is gone rather than a wrong number', () => {
    renderPage(); // fixture has no products loaded
    const row = screen.getByText('Brake Pad').closest('tr')!;
    const cells = Array.from(row.querySelectorAll('td')).map((c) => c.textContent);
    expect(cells[4]).toBe('—');
  });
});

const productP1 = {
  id: 'p1', sku: 'SKU-1', name: 'Brake Pad', category: null, unit: 'pcs',
  cost: 10, price: 25, quantity: 5, reorderLevel: 2, costCode: 'A',
  barcodes: [], sellingOptions: [], supplierId: null, supplierName: null,
  baseSku: null, variationNumber: null, isActive: true, imageUrl: null, notes: null,
  searchKeywords: [], createdAt: new Date(), updatedAt: null,
  createdBy: 'u1', updatedBy: 'u1', createdByName: 'C', updatedByName: 'C',
};

describe('ReceivingEntryPage — variation price entry', () => {
  it('price stays disabled at the base cost and unlocks when the cost differs', async () => {
    const { userEvent } = await import('@testing-library/user-event').then((m) => ({ userEvent: m.default }));
    entry.matches = [productP1] as never;
    entry.products = [productP1] as never;
    renderPage();
    await userEvent.click(screen.getByRole('button', { name: /Brake Pad/ }));

    const price = screen.getByLabelText('Price');
    expect(price).toBeDisabled();
    expect(price).toHaveValue(25);

    const cost = screen.getByLabelText('Unit cost', { selector: 'input' });
    await userEvent.clear(cost);
    await userEvent.type(cost, '12');
    expect(screen.getByLabelText('Price')).toBeEnabled();
    expect(screen.getByText(/variation will be created at this cost and price/)).toBeInTheDocument();

    await userEvent.clear(screen.getByLabelText('Price'));
    await userEvent.type(screen.getByLabelText('Price'), '30');
    await userEvent.click(screen.getByRole('button', { name: 'Add' }));
    expect(entry.addExisting).toHaveBeenCalledWith(expect.objectContaining({ id: 'p1' }), 1, 12, 30);
    entry.matches = [] as never;
    entry.products = [] as never;
  });
});

describe('ReceivingEntryPage — row editing', () => {
  it('the pencil on an existing line reopens the box prefilled and Update rewrites the line', async () => {
    const { userEvent } = await import('@testing-library/user-event').then((m) => ({ userEvent: m.default }));
    entry.products = [productP1] as never;
    renderPage();

    const row = screen.getByText('Brake Pad', { selector: 'td span' }).closest('tr')!;
    await userEvent.click(within(row).getByRole('button', { name: 'Edit' }));

    expect(screen.getByLabelText('Qty', { selector: 'input' })).toHaveValue(4);
    const update = screen.getByRole('button', { name: 'Update' });
    await userEvent.click(update);
    expect(entry.updateExisting).toHaveBeenCalledWith('i1', { quantity: 4, unitCost: 10, unitPrice: null });
    entry.products = [] as never;
  });

  it('the pencil is disabled when the line’s product no longer exists', () => {
    renderPage(); // entry.products is empty — every product is "gone"
    const row = screen.getByText('Chain').closest('tr')!;
    expect(within(row).getByRole('button', { name: 'Edit' })).toBeDisabled();
  });

  it('the pencil on a new-product line opens the dialog in edit mode, prefilled', async () => {
    const { userEvent } = await import('@testing-library/user-event').then((m) => ({ userEvent: m.default }));
    const saved = entry.lines[2];
    entry.lines[2] = {
      ...saved, productId: '', name: 'Squid', sku: 'SQ-9',
      pendingNewProduct: {
        category: null, price: 130, reorderLevel: 1, autoGenerateSku: false,
        autoSkuCategoryCode: null, barcodes: [], notes: null, sellingOptions: [],
      },
    } as never;
    renderPage();

    const row = screen.getByText('Squid').closest('tr')!;
    await userEvent.click(within(row).getByRole('button', { name: 'Edit' }));

    expect(await screen.findByText('Edit product')).toBeInTheDocument();
    expect(screen.getByDisplayValue('Squid')).toBeInTheDocument();
    await userEvent.click(screen.getByRole('button', { name: 'Save changes' }));
    expect(entry.updateNew).toHaveBeenCalledWith('i3', expect.objectContaining({ name: 'Squid', price: 130 }));
    entry.lines[2] = saved;
  });
});
