// Editing happens inside the product drawer rather than on its own page, at
// /inventory/:id/edit — so Back returns to the product view instead of dumping
// you on the list, and an edit link is still shareable.
import { describe, expect, it, vi } from 'vitest';
import { render, screen, waitFor, within } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { MemoryRouter, Route, Routes } from 'react-router-dom';
import { QueryClient, QueryClientProvider } from '@tanstack/react-query';
import { DiProvider, type Container } from '@/infrastructure/di/container';
import { ProductEditDrawer } from './ProductEditDrawer';
import { defaultCostCode } from '@/domain/entities/CostCode';
import { useAuthStore } from '@/presentation/stores/authStore';
import { UserRole } from '@/domain/enums';
import type { Product } from '@/domain/entities';

function signIn(role: UserRole = UserRole.admin) {
  useAuthStore.setState({
    user: {
      id: 'u1', email: 'a@b.co', displayName: 'Tester', role, isActive: true,
    } as never,
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
    sellingOptions: [], category: null, imageUrl: null, notes: null,
    ...over,
  };
}

function harness(p: Product = product()) {
  const qc = new QueryClient({ defaultOptions: { queries: { retry: false } } });
  const productRepo: Partial<Container['productRepo']> = {
    getById: vi.fn().mockResolvedValue(p),
    adjustStock: vi.fn().mockResolvedValue(undefined),
    updateProductWithClaims: vi.fn().mockResolvedValue(undefined),
    update: vi.fn().mockResolvedValue(undefined),
    countSkuVariations: vi.fn().mockResolvedValue(0),
    deactivate: vi.fn().mockResolvedValue(undefined),
    recordPriceChange: vi.fn().mockResolvedValue(undefined),
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
        <MemoryRouter initialEntries={['/inventory/p9/edit']}>
          <Routes>
            <Route path="/inventory" element={<div>Inventory list</div>} />
            <Route path="/inventory/:id" element={<div>Product view</div>} />
            <Route path="/inventory/:id/edit" element={<ProductEditDrawer />} />
          </Routes>
        </MemoryRouter>
      </QueryClientProvider>
    </DiProvider>,
  );
  return productRepo;
}

describe('ProductEditDrawer', () => {
  it('edits inside a drawer, not on a page of its own', async () => {
    signIn();
    harness();

    expect(await screen.findByRole('dialog', { name: /Brake shoe/ })).toBeInTheDocument();
    expect(await screen.findByDisplayValue('Brake shoe (Yamaha)')).toBeInTheDocument();
  });

  it('drops the page chrome the drawer already provides', async () => {
    signIn();
    harness();
    await screen.findByDisplayValue('Brake shoe (Yamaha)');

    // The drawer header carries the title and a close button, so the form's
    // own "Edit product" heading and back-to-inventory link would duplicate it.
    expect(screen.queryByRole('heading', { name: 'Edit product' })).toBeNull();
    expect(screen.queryByRole('link', { name: /Inventory/ })).toBeNull();
  });

  it('offers Save and Cancel at the end of the form', async () => {
    signIn();
    harness();
    await screen.findByDisplayValue('Brake shoe (Yamaha)');

    expect(screen.getByRole('button', { name: /Save changes/ })).toBeInTheDocument();
    expect(screen.getByRole('link', { name: 'Cancel' })).toBeInTheDocument();
  });

  it('cancelling returns to the product view, not the list', async () => {
    signIn();
    harness();
    await screen.findByDisplayValue('Brake shoe (Yamaha)');

    await userEvent.click(screen.getByRole('link', { name: 'Cancel' }));

    await waitFor(() => expect(screen.getByText('Product view')).toBeInTheDocument());
  });

  it('closing the drawer returns to the product view', async () => {
    signIn();
    harness();
    await screen.findByDisplayValue('Brake shoe (Yamaha)');

    await userEvent.click(screen.getByRole('button', { name: 'Close' }));

    await waitFor(() => expect(screen.getByText('Product view')).toBeInTheDocument());
  });

  it('offers delete from inside the edit drawer', async () => {
    signIn();
    harness();
    await screen.findByDisplayValue('Brake shoe (Yamaha)');

    expect(screen.getByRole('button', { name: /Delete/ })).toBeInTheDocument();
  });

  it('confirms before deleting rather than acting on the first click', async () => {
    signIn();
    const repo = harness();
    await screen.findByDisplayValue('Brake shoe (Yamaha)');

    await userEvent.click(screen.getByRole('button', { name: /Delete/ }));

    expect(await screen.findByRole('dialog', { name: 'Delete Product?' })).toBeInTheDocument();
    expect(repo.deactivate).not.toHaveBeenCalled();
  });

  it('deletes and returns to the list once confirmed', async () => {
    signIn();
    const repo = harness();
    await screen.findByDisplayValue('Brake shoe (Yamaha)');

    await userEvent.click(screen.getByRole('button', { name: /Delete/ }));
    const dialog = await screen.findByRole('dialog', { name: 'Delete Product?' });
    await userEvent.click(within(dialog).getByRole('button', { name: 'Delete' }));

    await waitFor(() => expect(repo.deactivate).toHaveBeenCalled());
    // The product is hidden from inventory now, so returning to the product
    // view would land on something the list no longer shows.
    await waitFor(() => expect(screen.getByText('Inventory list')).toBeInTheDocument());
  });

  it('keeps stock adjustment reachable while editing', async () => {
    signIn();
    harness();
    await screen.findByDisplayValue('Brake shoe (Yamaha)');

    await userEvent.click(screen.getByRole('button', { name: /Adjust stock/ }));

    expect(await screen.findByRole('dialog', { name: 'Adjust stock' })).toBeInTheDocument();
  });
});
