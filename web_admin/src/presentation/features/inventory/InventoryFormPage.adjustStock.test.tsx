// Stock adjustment is reachable from the Edit Product page as well as the
// product drawer — you often notice a count is wrong while already editing the
// item, and having to close the form, reopen the drawer and adjust from there
// loses whatever you had typed.
import { describe, expect, it, vi } from 'vitest';
import { render, screen } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { MemoryRouter, Route, Routes } from 'react-router-dom';
import { QueryClient, QueryClientProvider } from '@tanstack/react-query';
import { DiProvider, type Container } from '@/infrastructure/di/container';
import { InventoryFormPage } from './InventoryFormPage';
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
            <Route path="/inventory/:id/edit" element={<InventoryFormPage />} />
            <Route path="/inventory/add" element={<InventoryFormPage />} />
          </Routes>
        </MemoryRouter>
      </QueryClientProvider>
    </DiProvider>,
  );
  return productRepo;
}

describe('InventoryFormPage — stock adjustment', () => {
  it('offers stock adjustment while editing a product', async () => {
    signIn();
    harness();
    await screen.findByDisplayValue('Brake shoe (Yamaha)');

    await userEvent.click(screen.getByRole('button', { name: /Adjust stock/ }));

    expect(await screen.findByRole('dialog', { name: 'Adjust stock' })).toBeInTheDocument();
  });

  it('binds the dialog to the product being edited, not a blank one', async () => {
    // The dialog previews the resulting quantity in the product's own unit, so
    // seeing "set" proves it received this product rather than a placeholder.
    signIn();
    harness(product({ quantity: 8, unit: 'set' }));
    await screen.findByDisplayValue('Brake shoe (Yamaha)');

    await userEvent.click(screen.getByRole('button', { name: /Adjust stock/ }));
    const dialog = await screen.findByRole('dialog', { name: 'Adjust stock' });

    expect(dialog).toHaveTextContent('New quantity:');
    expect(dialog).toHaveTextContent('set');
  });
});

describe('InventoryFormPage — stock adjustment is edit-only', () => {
  it('is absent when creating a product, which has no stock to adjust yet', async () => {
    signIn();
    const qc = new QueryClient({ defaultOptions: { queries: { retry: false } } });
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
    render(
      <DiProvider
        override={{
          categoryRepo: categoryRepo as Container['categoryRepo'],
          supplierRepo: supplierRepo as Container['supplierRepo'],
          costCodeRepo: costCodeRepo as Container['costCodeRepo'],
        }}
      >
        <QueryClientProvider client={qc}>
          <MemoryRouter initialEntries={['/inventory/add']}>
            <Routes>
              <Route path="/inventory/add" element={<InventoryFormPage />} />
            </Routes>
          </MemoryRouter>
        </QueryClientProvider>
      </DiProvider>,
    );

    expect(screen.queryByRole('button', { name: /Adjust stock/ })).toBeNull();
  });
});
