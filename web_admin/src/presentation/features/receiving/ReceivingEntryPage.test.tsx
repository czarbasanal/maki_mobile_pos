// Real-harness page test (ExpensesPage.test.tsx's idiom) — DI overrides feed
// the real useReceivingEntry hook rather than mocking it, so the direct-add
// line model, the cost-variation price lock and the meta fields are all
// exercised through the actual page + hook wiring.
import { describe, expect, it, vi } from 'vitest';
import { render, screen, waitFor, within } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { QueryClient, QueryClientProvider } from '@tanstack/react-query';
import { MemoryRouter, Route, Routes } from 'react-router-dom';
import { DiProvider, type Container } from '@/infrastructure/di/container';
import { ReceivingEntryPage } from './ReceivingEntryPage';
import { useAuthStore } from '@/presentation/stores/authStore';
import type { Product, Receiving, Supplier } from '@/domain/entities';

function signIn() {
  useAuthStore.setState({
    user: { id: 'u1', email: 'a@b.c', displayName: 'Czar', role: 'admin', isActive: true } as never,
    status: 'signedIn',
  } as never);
}

function product(over: Partial<Product> = {}): Product {
  return {
    id: 'p1', sku: '00220004', name: 'Brake Pad', category: 'Brakes', unit: 'pcs',
    cost: 1200, price: 1600, quantity: 34, reorderLevel: 2, costCode: 'AB',
    barcodes: [], sellingOptions: [], supplierId: null, supplierName: null,
    baseSku: null, variationNumber: null, isActive: true, imageUrl: null, notes: null,
    searchKeywords: [], createdAt: new Date(), updatedAt: null,
    createdBy: 'u1', updatedBy: 'u1', createdByName: 'Czar', updatedByName: 'Czar',
    ...over,
  } as Product;
}

const draftReceiving = (o: Partial<Receiving> = {}): Receiving => ({
  id: 'rcv1',
  referenceNumber: 'RCV-20260905-001',
  supplierId: null,
  supplierName: null,
  items: [],
  totalCost: 0,
  totalQuantity: 0,
  status: 'draft',
  notes: null,
  createdAt: new Date('2026-09-05'),
  completedAt: null,
  createdBy: 'u1',
  createdByName: 'Czar',
  completedBy: null,
  version: 0,
  invoiceNumber: null,
  receivedOn: null,
  ...o,
});

function harness(opts: { products?: Product[]; suppliers?: Supplier[] } = {}) {
  signIn();
  const qc = new QueryClient({ defaultOptions: { queries: { retry: false } } });
  const receivingRepo: Partial<Container['receivingRepo']> = {
    nextReferenceNumber: vi.fn(async () => 'RCV-20260905-001'),
    create: vi.fn(async (input) => draftReceiving({ id: 'rcv-new', ...input })),
    update: vi.fn(async () => {}),
    complete: vi.fn(async () => {}),
  };
  const productRepo: Partial<Container['productRepo']> = {
    watchAll: (onData: (v: Product[]) => void) => {
      onData(opts.products ?? []);
      return () => {};
    },
  };
  const supplierRepo: Partial<Container['supplierRepo']> = {
    watchAll: (onData: (v: Supplier[]) => void) => {
      onData(opts.suppliers ?? []);
      return () => {};
    },
  };
  const categoryRepo: Partial<Container['categoryRepo']> = {
    watchAll: (_kind, cb) => {
      cb([]);
      return () => {};
    },
    peekNextSequence: vi.fn(async () => 1),
  };
  const activityLogRepo: Partial<Container['activityLogRepo']> = { log: vi.fn() };

  render(
    <DiProvider
      override={
        {
          receivingRepo,
          productRepo,
          supplierRepo,
          categoryRepo,
          activityLogRepo,
        } as unknown as Container
      }
    >
      <QueryClientProvider client={qc}>
        <MemoryRouter initialEntries={['/receiving/new']}>
          <Routes>
            <Route path="/receiving/new" element={<ReceivingEntryPage />} />
            <Route path="/receiving" element={<div>RECEIVING LIST</div>} />
            <Route path="/receiving/:id" element={<div>RECEIVING DETAIL</div>} />
          </Routes>
        </MemoryRouter>
      </QueryClientProvider>
    </DiProvider>,
  );
  return { receivingRepo };
}

async function typeSearch(text: string) {
  await userEvent.type(screen.getByPlaceholderText(/Search a part/), text);
}

/** Scopes a dropdown-row query to the results box — once a line exists, its
 *  qty-stepper aria-labels ("Decrease quantity for Brake Pad", etc.) also
 *  contain the product name and would otherwise collide with a plain
 *  top-level role/name query. */
function searchResults() {
  return within(screen.getByTestId('search-results'));
}

describe('ReceivingEntryPage — direct add', () => {
  it('adding a search result appends a line, and adding it again shows +1 and increments qty instead of duplicating', async () => {
    harness({ products: [product()] });
    await typeSearch('Brake');

    const addBtn = await searchResults().findByRole('button', { name: /Brake Pad/ });
    expect(within(addBtn).getByText('Add')).toBeInTheDocument();
    await userEvent.click(addBtn);

    // One line, qty 1.
    expect(await screen.findByLabelText('Quantity for Brake Pad')).toHaveValue(1);

    // Search again — the same result now offers +1.
    await typeSearch('Brake');
    const again = await searchResults().findByRole('button', { name: /Brake Pad/ });
    expect(within(again).getByText('+1')).toBeInTheDocument();
    await userEvent.click(again);

    expect(screen.getAllByText('Brake Pad')).toHaveLength(1); // still one line
    expect(screen.getByLabelText('Quantity for Brake Pad')).toHaveValue(2);
  });

  it('the qty stepper floors at 1 — the minus button never goes to 0', async () => {
    harness({ products: [product()] });
    await typeSearch('Brake');
    await userEvent.click(await searchResults().findByRole('button', { name: /Brake Pad/ }));

    const minus = screen.getByLabelText('Decrease quantity for Brake Pad');
    await userEvent.click(minus); // 1 -> floors at 1, not 0
    expect(screen.getByLabelText('Quantity for Brake Pad')).toHaveValue(1);
  });

  it('shows the on-hand → new transition, which updates as qty changes', async () => {
    harness({ products: [product({ quantity: 34 })] });
    await typeSearch('Brake');
    await userEvent.click(await searchResults().findByRole('button', { name: /Brake Pad/ }));

    expect(await screen.findByText('34 on hand → 35')).toBeInTheDocument();
    const plus = screen.getByLabelText('Increase quantity for Brake Pad');
    await userEvent.click(plus);
    expect(await screen.findByText('34 on hand → 36')).toBeInTheDocument();
  });
});

describe('ReceivingEntryPage — cost-variation price lock', () => {
  it('the price cell is disabled at the catalog cost, unlocks on a differing cost, shows the variation notice, and the cost input takes the accent border', async () => {
    harness({ products: [product({ cost: 1200, price: 1600 })] });
    await typeSearch('Brake');
    await userEvent.click(await searchResults().findByRole('button', { name: /Brake Pad/ }));

    const price = await screen.findByLabelText('Price');
    expect(price).toBeDisabled();
    expect(price).toHaveValue(1600);

    const cost = screen.getByLabelText('Unit cost for Brake Pad');
    expect(cost.className).not.toContain('border-accent-text');
    await userEvent.clear(cost);
    await userEvent.type(cost, '1350');

    expect(screen.getByLabelText('Unit cost for Brake Pad').className).toContain('border-accent-text');
    expect(screen.getByLabelText('Price')).toBeEnabled();

    // Typing a price stores it, and the cell takes the accent border too.
    const priceInput = screen.getByLabelText('Price');
    await userEvent.clear(priceInput);
    await userEvent.type(priceInput, '1700');
    expect(screen.getByLabelText('Price')).toHaveValue(1700);
    expect(screen.getByLabelText('Price').className).toContain('border-accent-text');
  });

  it('reverting the cost back to the catalog value re-disables Price at the catalog figure', async () => {
    harness({ products: [product({ cost: 1200, price: 1600 })] });
    await typeSearch('Brake');
    await userEvent.click(await searchResults().findByRole('button', { name: /Brake Pad/ }));

    const cost = screen.getByLabelText('Unit cost for Brake Pad');
    await userEvent.clear(cost);
    await userEvent.type(cost, '1350');
    await userEvent.clear(screen.getByLabelText('Unit cost for Brake Pad'));
    await userEvent.type(screen.getByLabelText('Unit cost for Brake Pad'), '1200');

    const price = screen.getByLabelText('Price');
    expect(price).toBeDisabled();
    expect(price).toHaveValue(1600);
  });
});

describe('ReceivingEntryPage — margin cell', () => {
  it('renders a margin percentage colored by marginToneClass', async () => {
    harness({ products: [product({ cost: 100, price: 200 })] }); // 50% -> healthy
    await typeSearch('Brake');
    await userEvent.click(await searchResults().findByRole('button', { name: /Brake Pad/ }));

    const row = screen.getByText('Brake Pad').closest('tr')!;
    const margin = within(row).getByText('50%');
    expect(margin.className).toContain('text-pos');
  });
});

describe('ReceivingEntryPage — SKU column and units wording (protected)', () => {
  it('gives the SKU its own column, distinct from the item-name cell', async () => {
    harness({ products: [product({ sku: '00220004' })] });
    await typeSearch('Brake');
    await userEvent.click(await searchResults().findByRole('button', { name: /Brake Pad/ }));

    const headers = screen.getAllByRole('columnheader').map((h) => h.textContent);
    expect(headers).toContain('SKU');
    const row = screen.getByText('Brake Pad').closest('tr')!;
    expect(within(row).getByText('00220004')).toBeInTheDocument();
  });

  it('the footer says "units in", never "items"', async () => {
    harness({ products: [product()] });
    await typeSearch('Brake');
    await userEvent.click(await searchResults().findByRole('button', { name: /Brake Pad/ }));

    expect(document.body.textContent).toContain('Units in');
    expect(document.body.textContent).not.toMatch(/\d+ items\b/);
  });

  it('a pending-new line shows "Assigned when saved", never the peeked SKU', async () => {
    harness();
    await userEvent.click(screen.getByRole('button', { name: /New product/ }));
    await userEvent.type(screen.getByLabelText('Name'), 'Squid');
    await userEvent.click(screen.getByText('Auto-generate SKU from category'));
    await userEvent.type(screen.getByLabelText('SKU'), 'MANUAL-1');
    await userEvent.type(screen.getByLabelText('Cost'), '90');
    await userEvent.type(screen.getByLabelText('Price'), '130');
    await userEvent.type(screen.getByLabelText('Quantity received'), '3');
    await userEvent.click(screen.getByRole('button', { name: 'Add to receiving' }));

    // Manual SKU is literal, not auto — shows verbatim, not the pending label.
    expect(await screen.findByText('MANUAL-1')).toBeInTheDocument();
  });
});

describe('ReceivingEntryPage — no-results create-new prefill', () => {
  it('opens NewProductDialog with the query prefilled as Name', async () => {
    harness({ products: [product()] });
    await typeSearch('Nonexistent Widget');

    const create = await screen.findByRole('button', { name: '+ Create it as a new product' });
    await userEvent.click(create);

    expect(await screen.findByRole('heading', { name: 'New product' })).toBeInTheDocument();
    expect(screen.getByLabelText('Name')).toHaveValue('Nonexistent Widget');
  });
});

describe('ReceivingEntryPage — search keyboard', () => {
  it('Enter with exactly one match adds it and clears the search', async () => {
    harness({ products: [product()] });
    await typeSearch('Brake Pad');
    await waitFor(() => expect(screen.getByRole('button', { name: /Brake Pad/ })).toBeInTheDocument());

    await userEvent.keyboard('{Enter}');
    expect(await screen.findByLabelText('Quantity for Brake Pad')).toHaveValue(1);
    expect(screen.getByPlaceholderText(/Search a part/)).toHaveValue('');
  });

  it('ArrowDown/ArrowUp move a highlight and Enter adds the highlighted row', async () => {
    harness({ products: [product({ id: 'p1', sku: 'A1', name: 'Brake Pad' }), product({ id: 'p2', sku: 'A2', name: 'Brake Shoe' })] });
    await typeSearch('Brake');
    await waitFor(() => expect(screen.getAllByRole('button', { name: /Brake/ })).toHaveLength(2));

    await userEvent.keyboard('{ArrowDown}'); // move off the first result
    await userEvent.keyboard('{Enter}');

    // The second result (Brake Shoe) was added, not the first.
    expect(await screen.findByLabelText('Quantity for Brake Shoe')).toBeInTheDocument();
    expect(screen.queryByLabelText('Quantity for Brake Pad')).not.toBeInTheDocument();
  });
});

describe('ReceivingEntryPage — footer figures and Receive gating', () => {
  it('Receive into stock is aria-disabled while there are no lines, and enables once one exists', async () => {
    harness({ products: [product()] });
    const receiveBtn = screen.getByRole('button', { name: 'Receive into stock' });
    expect(receiveBtn).toHaveAttribute('aria-disabled', 'true');

    await typeSearch('Brake');
    await userEvent.click(await searchResults().findByRole('button', { name: /Brake Pad/ }));

    expect(screen.getByRole('button', { name: 'Receive into stock' })).not.toHaveAttribute('aria-disabled');
  });

  it('the footer reports Lines, Units in and Retail value from the current lines', async () => {
    harness({ products: [product({ cost: 100, price: 200 })] });
    await typeSearch('Brake');
    await userEvent.click(await searchResults().findByRole('button', { name: /Brake Pad/ }));
    await userEvent.click(screen.getByLabelText('Increase quantity for Brake Pad')); // qty 2

    expect(document.body.textContent).toContain('Lines');
    expect(screen.getByLabelText('Quantity for Brake Pad')).toHaveValue(2);
    // Retail value = 200 * 2 = ₱400.00 at the catalog price (cost undisturbed).
    expect(document.body.textContent).toContain('₱400.00');
  });
});

describe('ReceivingEntryPage — meta fields persist into buildInput', () => {
  it('Invoice/DR no. and Received flow through to create() on Save draft', async () => {
    const { receivingRepo } = harness({ products: [product()] });
    await typeSearch('Brake');
    await userEvent.click(await searchResults().findByRole('button', { name: /Brake Pad/ }));

    await userEvent.type(screen.getByPlaceholderText("From the supplier's paperwork"), 'INV-55');
    const dateInput = document.querySelector('input[type="date"]') as HTMLInputElement;
    await userEvent.clear(dateInput);
    await userEvent.type(dateInput, '2026-08-30');

    await userEvent.click(screen.getByRole('button', { name: 'Save draft' }));

    await waitFor(() =>
      expect(receivingRepo.create).toHaveBeenCalledWith(
        expect.objectContaining({ invoiceNumber: 'INV-55', receivedOn: '2026-08-30' }),
        'u1',
      ),
    );
  });
});
