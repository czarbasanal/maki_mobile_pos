// Tags chip field: a live pull from useActiveTags, toggleable in edit mode,
// read-only under the cashier name-only tier (product-tags brief, Task 8).
import { describe, expect, it, vi } from 'vitest';
import { render, screen, waitFor } from '@testing-library/react';
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

const tagRepo: Partial<Container['tagRepo']> = {
  watchAll: (cb) => {
    cb([
      { id: 't1', name: 'Intact', color: 'green', description: null, isActive: true,
        createdAt: new Date('2026-09-01'), updatedAt: null, createdBy: null, updatedBy: null },
    ]);
    return () => {};
  },
};

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
        tagRepo: tagRepo as Container['tagRepo'],
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

describe('ProductModal — tags field', () => {
  it('edit mode: toggling a tag chip puts tagIds in the update patch', async () => {
    signIn(UserRole.admin);
    const repo = harness('/inventory/p9/edit', product({ tagIds: [] }), {
      update: vi.fn().mockResolvedValue(undefined),
    });
    await screen.findByDisplayValue('Brake shoe (Yamaha)');
    await userEvent.click(screen.getByRole('button', { name: 'Intact' }));
    await userEvent.click(screen.getByRole('button', { name: /save changes/i }));
    await waitFor(() => expect(repo.update).toHaveBeenCalled());
    const patch = (repo.update as ReturnType<typeof vi.fn>).mock.calls[0][1];
    expect(patch.tagIds).toEqual(['t1']);
  });

  it('cashier name-only mode: tags are shown but not toggleable', async () => {
    signIn(UserRole.cashier);
    harness('/inventory/p9/edit', product({ tagIds: ['t1'] }));
    await screen.findByDisplayValue('Brake shoe (Yamaha)');
    expect(screen.getByText('Intact')).toBeInTheDocument();
    expect(screen.queryByRole('button', { name: 'Intact' })).toBeNull();
  });
});
