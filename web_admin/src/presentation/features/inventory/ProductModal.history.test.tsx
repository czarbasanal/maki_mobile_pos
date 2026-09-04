// Record history panel (product-modal guide, 2026-09 revision): edit mode
// shows who created and who last touched the part, as plain text above the
// Danger zone — absolute shop-zone timestamps, never inputs.
import { describe, expect, it, vi } from 'vitest';
import { render, screen } from '@testing-library/react';
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
    // 01:42Z / 08:18Z are 9:42 AM / 4:18 PM in the shop zone (Asia/Manila +8).
    createdAt: new Date('2026-03-14T01:42:00Z'),
    updatedAt: new Date('2026-09-01T08:18:00Z'),
    createdBy: 'u-czar', updatedBy: 'u-bern',
    createdByName: 'Czar', updatedByName: 'Bern',
    searchKeywords: [], baseSku: null, variationNumber: null, barcodes: [],
    sellingOptions: [], category: 'Brakes', imageUrl: null, notes: null,
    tagIds: [],
    ...over,
  };
}

function harness(entry: string, p: Product = product()) {
  const qc = new QueryClient({ defaultOptions: { queries: { retry: false } } });
  const productRepo: Partial<Container['productRepo']> = {
    getById: vi.fn().mockResolvedValue(p),
    findByNameKey: vi.fn().mockResolvedValue(null),
    skuExists: vi.fn().mockResolvedValue(false),
    barcodeExists: vi.fn().mockResolvedValue(false),
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
  const tagRepo = {
    watchAll: (cb: (t: never[]) => void) => { cb([]); return () => {}; },
  } as unknown as Container['tagRepo'];
  const activityLogRepo = { log: vi.fn().mockResolvedValue(undefined) } as unknown as Container['activityLogRepo'];
  render(
    <DiProvider
      override={{
        productRepo: productRepo as Container['productRepo'],
        categoryRepo: categoryRepo as Container['categoryRepo'],
        supplierRepo: supplierRepo as Container['supplierRepo'],
        costCodeRepo: costCodeRepo as Container['costCodeRepo'],
        tagRepo,
        activityLogRepo,
      }}
    >
      <QueryClientProvider client={qc}>
        <MemoryRouter initialEntries={[entry]}>
          <Routes>
            <Route path="/inventory" element={<div><Outlet /></div>}>
              <Route path="add" element={<ProductModal />} />
            </Route>
            <Route path="/inventory/:id/edit" element={<ProductModal />} />
          </Routes>
        </MemoryRouter>
      </QueryClientProvider>
    </DiProvider>,
  );
}

describe('ProductModal — record history', () => {
  it('edit mode shows creator and last editor with shop-zone timestamps', async () => {
    signIn();
    harness('/inventory/p9/edit');
    await screen.findByDisplayValue('Brake shoe (Yamaha)');

    expect(screen.getByText('Record history')).toBeInTheDocument();
    expect(screen.getByText('Created by')).toBeInTheDocument();
    expect(screen.getByText('Czar')).toBeInTheDocument();
    expect(screen.getByText('Mar 14, 2026 · 9:42 AM')).toBeInTheDocument();
    expect(screen.getByText('Last updated by')).toBeInTheDocument();
    expect(screen.getByText('Bern')).toBeInTheDocument();
    expect(screen.getByText('Sep 1, 2026 · 4:18 PM')).toBeInTheDocument();
  });

  it('shows an em dash when the editor or creator name is unknown', async () => {
    signIn();
    harness('/inventory/p9/edit', product({ updatedByName: null, updatedAt: null }));
    await screen.findByDisplayValue('Brake shoe (Yamaha)');

    expect(screen.getByText('Last updated by')).toBeInTheDocument();
    // Person and timestamp both fall back to an em dash — never repeat the creator.
    expect(screen.getAllByText('—').length).toBeGreaterThanOrEqual(1);
    expect(screen.queryByText('Sep 1, 2026 · 4:18 PM')).toBeNull();
  });

  it('add mode has no record history panel', () => {
    signIn();
    harness('/inventory/add');
    expect(screen.queryByText('Record history')).toBeNull();
  });
});
