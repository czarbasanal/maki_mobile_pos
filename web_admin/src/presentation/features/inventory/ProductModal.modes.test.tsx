// One ProductModal, two modes (product-modal guide): add at /inventory/add,
// edit at /inventory/:id/edit, both over the list on the shared Modal shell.
// The danger zone lives at the bottom of the BODY (edit only): deactivate is
// the reversible soft layer, delete is HARD (user call) — gated behind
// deactivate-first and a typed-SKU confirmation.
import { describe, expect, it, vi } from 'vitest';
import { render, screen, waitFor, within } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { MemoryRouter, Outlet, Route, Routes } from 'react-router-dom';
import { QueryClient, QueryClientProvider } from '@tanstack/react-query';
import { DiProvider, type Container } from '@/infrastructure/di/container';
import { ProductModal } from './ProductModal';
import { defaultCostCode } from '@/domain/entities/CostCode';
import { useAuthStore } from '@/presentation/stores/authStore';
import { UserRole } from '@/domain/enums';
import type { Product } from '@/domain/entities';

function signIn(role: UserRole = UserRole.admin) {
  useAuthStore.setState({
    user: { id: 'u1', email: 'a@b.co', displayName: 'Tester', role, isActive: true } as never,
    status: 'signedIn',
  });
}

function product(over: Partial<Product> = {}): Product {
  return {
    id: 'p9', sku: 'ABC123', name: 'Brake shoe (Yamaha)', costCode: 'NBF',
    cost: 170, price: 250, quantity: 8, reorderLevel: 3, unit: 'set',
    supplierId: null, supplierName: null, isActive: true,
    createdAt: new Date('2026-01-01'), updatedAt: null,
    createdBy: null, updatedBy: null, createdByName: null, updatedByName: null,
    searchKeywords: [], baseSku: null, variationNumber: null, barcodes: [],
    sellingOptions: [], category: 'Brakes', imageUrl: null, notes: null, tagIds: [],
    ...over,
  };
}

function harness(entry: string, p: Product = product(), repoOver: Partial<Container['productRepo']> = {}) {
  const qc = new QueryClient({ defaultOptions: { queries: { retry: false } } });
  const productRepo: Partial<Container['productRepo']> = {
    getById: vi.fn().mockResolvedValue(p),
    deactivate: vi.fn().mockResolvedValue(undefined),
    reactivate: vi.fn().mockResolvedValue(undefined),
    hardDelete: vi.fn().mockResolvedValue(undefined),
    findByNameKey: vi.fn().mockResolvedValue(null),
    skuExists: vi.fn().mockResolvedValue(false),
    barcodeExists: vi.fn().mockResolvedValue(false),
    ...repoOver,
  };
  const categoryRepo: Partial<Container['categoryRepo']> = {
    watchAll: (_kind, cb) => { cb([]); return () => {}; },
    peekNextSequence: vi.fn().mockResolvedValue(1),
  };
  const supplierRepo: Partial<Container['supplierRepo']> = {
    watchAll: (cb) => { cb([]); return () => {}; },
  };
  const costCodeRepo: Partial<Container['costCodeRepo']> = {
    watch: (cb) => { cb(defaultCostCode); return () => {}; },
  };
  const activityLogRepo = { log: vi.fn().mockResolvedValue(undefined) } as unknown as Container['activityLogRepo'];
  render(
    <DiProvider
      override={{
        productRepo: productRepo as Container['productRepo'],
        categoryRepo: categoryRepo as Container['categoryRepo'],
        supplierRepo: supplierRepo as Container['supplierRepo'],
        costCodeRepo: costCodeRepo as Container['costCodeRepo'],
        activityLogRepo,
      }}
    >
      <QueryClientProvider client={qc}>
        <MemoryRouter initialEntries={[entry]}>
          <Routes>
            <Route
              path="/inventory"
              element={
                <div>
                  <span>LIST UNDERNEATH</span>
                  <Outlet />
                </div>
              }
            >
              <Route path="add" element={<ProductModal />} />
            </Route>
            <Route path="/inventory/:id" element={<div>Product view</div>} />
            <Route path="/inventory/:id/edit" element={<ProductModal />} />
          </Routes>
        </MemoryRouter>
      </QueryClientProvider>
    </DiProvider>,
  );
  return productRepo;
}

describe('ProductModal — add mode', () => {
  it('opens over the list with the teaching subtitle and no danger zone', () => {
    signIn();
    harness('/inventory/add');

    expect(screen.getByText('LIST UNDERNEATH')).toBeInTheDocument();
    expect(screen.getByRole('dialog', { name: 'New product' })).toBeInTheDocument();
    expect(
      screen.getByText('Set a cost and a price and the register handles the rest.'),
    ).toBeInTheDocument();
    expect(screen.getByRole('button', { name: 'Create product' })).toBeInTheDocument();
    expect(screen.queryByText('Danger zone')).toBeNull();
  });

  it('a clean draft closes on Escape; a dirty one asks first', async () => {
    signIn();
    harness('/inventory/add');

    await userEvent.type(screen.getByLabelText('Name'), 'NEW PART');
    await userEvent.keyboard('{Escape}');
    expect(await screen.findByText('Discard changes?')).toBeInTheDocument();

    await userEvent.click(screen.getByRole('button', { name: 'Discard' }));
    await waitFor(() =>
      expect(screen.queryByRole('dialog', { name: 'New product' })).toBeNull(),
    );
    expect(screen.getByText('LIST UNDERNEATH')).toBeInTheDocument();
  });
});

describe('ProductModal — edit mode', () => {
  it("subtitle carries the record's own facts", async () => {
    signIn();
    harness('/inventory/p9/edit');

    expect(await screen.findByText('ABC123 · BRAKES · 8 on hand')).toBeInTheDocument();
    expect(screen.getByRole('button', { name: 'Save changes' })).toBeInTheDocument();
  });

  it('cancelling returns to the list — the read-only product view is retired', async () => {
    signIn();
    harness('/inventory/p9/edit');
    await screen.findByDisplayValue('Brake shoe (Yamaha)');

    await userEvent.click(screen.getByRole('button', { name: 'Cancel' }));
    await waitFor(() => expect(screen.getByText('LIST UNDERNEATH')).toBeInTheDocument());
  });
});

describe('ProductModal — danger zone', () => {
  it('while active: Delete is inert and its copy explains the gate', async () => {
    signIn();
    const repo = harness('/inventory/p9/edit');
    await screen.findByDisplayValue('Brake shoe (Yamaha)');

    expect(
      screen.getByText('Deactivate it first — an active part cannot be deleted.'),
    ).toBeInTheDocument();
    const del = screen.getByRole('button', { name: 'Delete' });
    expect(del).toHaveAttribute('aria-disabled', 'true');
    await userEvent.click(del);
    expect(screen.queryByRole('dialog', { name: 'Delete product?' })).toBeNull();
    expect(repo.hardDelete).not.toHaveBeenCalled();
  });

  it('deactivating confirms, and warns about stock on hand', async () => {
    signIn();
    const repo = harness('/inventory/p9/edit', product({ quantity: 78 }));
    await screen.findByDisplayValue('Brake shoe (Yamaha)');

    await userEvent.click(screen.getByRole('button', { name: 'Deactivate' }));
    const dialog = await screen.findByRole('dialog', { name: 'Deactivate product?' });
    expect(dialog).toHaveTextContent('78 on hand will stop appearing at the register');

    await userEvent.click(within(dialog).getByRole('button', { name: 'Deactivate' }));
    await waitFor(() =>
      expect(repo.deactivate).toHaveBeenCalledWith('p9', 'u1', 'Tester'),
    );
  });

  it('a deactivated product offers Reactivate, and Delete only after the typed SKU', async () => {
    signIn();
    const repo = harness('/inventory/p9/edit', product({ isActive: false }));
    await screen.findByDisplayValue('Brake shoe (Yamaha)');

    expect(screen.getByText('Product is deactivated')).toBeInTheDocument();
    expect(screen.getByRole('button', { name: 'Reactivate' })).toBeInTheDocument();

    await userEvent.click(screen.getByRole('button', { name: 'Delete' }));
    const dialog = await screen.findByRole('dialog', { name: 'Delete product?' });
    const confirm = within(dialog).getByRole('button', { name: 'Delete product' });
    expect(confirm).toBeDisabled();

    await userEvent.type(within(dialog).getByRole('textbox'), 'WRONG');
    expect(confirm).toBeDisabled();
    expect(repo.hardDelete).not.toHaveBeenCalled();

    await userEvent.clear(within(dialog).getByRole('textbox'));
    await userEvent.type(within(dialog).getByRole('textbox'), 'abc123');
    expect(confirm).not.toBeDisabled();
    await userEvent.click(confirm);

    await waitFor(() => expect(repo.hardDelete).toHaveBeenCalledWith('p9'));
    // The record is gone — back to the list, never the orphaned product view.
    await waitFor(() => expect(screen.getByText('LIST UNDERNEATH')).toBeInTheDocument());
  });

  it('hides the danger zone from non-admins', async () => {
    signIn(UserRole.staff);
    harness('/inventory/p9/edit');
    await screen.findByDisplayValue('Brake shoe (Yamaha)');

    expect(screen.queryByText('Danger zone')).toBeNull();
  });
});

describe('ProductModal — submit and draft protection', () => {
  it('a second click during a slow create does not fire a second write', async () => {
    signIn();
    // Never resolves — the first submit stays in flight for the whole test.
    const create = vi.fn().mockReturnValue(new Promise(() => {}));
    harness('/inventory/add', product(), { create });

    await userEvent.click(screen.getByLabelText('Auto'));
    await userEvent.type(screen.getByLabelText('SKU'), 'ZZ999');
    await userEvent.type(screen.getByLabelText('Name'), 'DOUBLE CLICK PART');
    await userEvent.type(screen.getByLabelText('Cost'), '10');
    await userEvent.type(screen.getByLabelText('Price'), '20');
    await userEvent.type(screen.getByLabelText('Initial quantity'), '1');

    const save = screen.getByRole('button', { name: /Create product|Saving/ });
    await userEvent.click(save);
    await waitFor(() => expect(create).toHaveBeenCalledTimes(1));
    await userEvent.click(screen.getByRole('button', { name: /Saving|Create product/ }));
    expect(create).toHaveBeenCalledTimes(1);
  });

  it('deactivating does not wipe an in-progress edit', async () => {
    signIn();
    harness('/inventory/p9/edit');
    const name = (await screen.findByDisplayValue('Brake shoe (Yamaha)')) as HTMLInputElement;

    await userEvent.clear(name);
    await userEvent.type(name, 'RENAMED MID-EDIT');

    await userEvent.click(screen.getByRole('button', { name: 'Deactivate' }));
    const dialog = await screen.findByRole('dialog', { name: 'Deactivate product?' });
    await userEvent.click(within(dialog).getByRole('button', { name: 'Deactivate' }));
    await waitFor(() =>
      expect(screen.queryByRole('dialog', { name: 'Deactivate product?' })).toBeNull(),
    );

    // The lifecycle write refetches the product; the draft must survive it.
    expect((screen.getByLabelText('Name') as HTMLInputElement).value).toBe('RENAMED MID-EDIT');
  });
});
