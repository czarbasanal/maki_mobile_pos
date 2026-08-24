// Cashier edits are NAME (and image) only — mobile parity. The form disables
// everything else, and the save REBASES onto a fresh read so a cashier save
// can never write back stale values over someone's concurrent edit (those
// fields are not in the firestore.rules cashier denylist, so the client must
// not rely on seeding alone).
import { describe, expect, it, vi } from 'vitest';
import { render, screen, waitFor } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { MemoryRouter, Route, Routes } from 'react-router-dom';
import { QueryClient, QueryClientProvider } from '@tanstack/react-query';
import { DiProvider, type Container } from '@/infrastructure/di/container';
import { InventoryFormPage } from './InventoryFormPage';
import { defaultCostCode } from '@/domain/entities/CostCode';
import { useAuthStore } from '@/presentation/stores/authStore';
import { UserRole } from '@/domain/enums';
import type { Product } from '@/domain/entities';

function signIn(role: UserRole) {
  useAuthStore.setState({
    user: { id: 'u1', email: 'a@b.co', displayName: 'Tester', role, isActive: true } as never,
    status: 'signedIn',
  });
}

function product(): Product {
  return {
    id: 'p1', sku: 'ABC123', name: 'Brake shoe', costCode: 'NBF',
    cost: 170, price: 250, quantity: 8, reorderLevel: 3, unit: 'set',
    supplierId: null, supplierName: null, isActive: true,
    createdAt: new Date('2026-01-01'), updatedAt: null,
    createdBy: null, updatedBy: null, createdByName: null, updatedByName: null,
    searchKeywords: [], baseSku: null, variationNumber: null, barcodes: [],
    sellingOptions: [], category: null, imageUrl: null, notes: null,
  };
}

function harness(freshOnSave?: Product) {
  const qc = new QueryClient({ defaultOptions: { queries: { retry: false } } });
  const update = vi.fn().mockResolvedValue(undefined);
  const recordPriceChange = vi.fn().mockResolvedValue(undefined);
  const getById = vi.fn().mockResolvedValue(freshOnSave ?? product());
  // First read is the page load; a later read (the save's rebase) sees the
  // "concurrent edit" state when freshOnSave is provided.
  getById.mockResolvedValueOnce(product());
  const productRepo: Partial<Container['productRepo']> = {
    getById,
    update,
    updateProductWithClaims: vi.fn().mockResolvedValue(undefined),
    barcodeExists: vi.fn().mockResolvedValue(false),
    countSkuVariations: vi.fn().mockResolvedValue(0),
    recordPriceChange,
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
        <MemoryRouter initialEntries={['/inventory/p1/edit']}>
          <Routes>
            <Route path="/inventory/:id/edit" element={<InventoryFormPage />} />
            <Route path="/inventory" element={<div>list</div>} />
            <Route path="/inventory/:id" element={<div>view</div>} />
          </Routes>
        </MemoryRouter>
      </QueryClientProvider>
    </DiProvider>,
  );
  return { update, recordPriceChange };
}

describe('InventoryFormPage — cashier name-only editing', () => {
  it('shows the name-and-image banner and disables everything else', async () => {
    signIn(UserRole.cashier);
    harness();
    await screen.findByDisplayValue('Brake shoe');

    expect(screen.getByText('You can edit the product name and image.')).toBeInTheDocument();
    expect(screen.getByLabelText('Name')).not.toBeDisabled();
    expect(screen.getByLabelText('SKU')).toHaveAttribute('readonly');
    expect(screen.getByLabelText('Reorder level')).toBeDisabled();
    expect(screen.getByLabelText('Unit')).toBeDisabled();
    expect(screen.getByLabelText('Category')).toBeDisabled();
    expect(screen.getByLabelText('Supplier')).toBeDisabled();
    expect(screen.getByLabelText('Notes')).toBeDisabled();
    expect(screen.queryByPlaceholderText('Add barcode')).not.toBeInTheDocument();
    // Cost hidden, price dead (already staff behavior, pinned for cashier too).
    expect(screen.queryByLabelText('Cost')).toBeNull();
  });

  it('offers neither Delete nor Adjust stock to a cashier', async () => {
    signIn(UserRole.cashier);
    harness();
    await screen.findByDisplayValue('Brake shoe');
    expect(screen.queryByRole('button', { name: /delete/i })).not.toBeInTheDocument();
    expect(screen.queryByRole('button', { name: /adjust stock/i })).not.toBeInTheDocument();
  });

  it('the save rebases onto the FRESH doc — a concurrent edit survives', async () => {
    signIn(UserRole.cashier);
    const fresh: Product = {
      ...product(),
      notes: 'CHANGED ELSEWHERE',
      reorderLevel: 99,
      category: 'Brakes',
    };
    const { update, recordPriceChange } = harness(fresh);
    await screen.findByDisplayValue('Brake shoe');

    await userEvent.clear(screen.getByLabelText('Name'));
    await userEvent.type(screen.getByLabelText('Name'), 'Brake shoe rear');
    await userEvent.click(screen.getByRole('button', { name: /Save changes/ }));

    await waitFor(() => expect(update).toHaveBeenCalled());
    const patch = update.mock.calls[0][1];
    expect(patch.name).toBe('BRAKE SHOE REAR');
    // Rebased onto the fresh doc, not the stale form seed:
    expect(patch.notes).toBe('CHANGED ELSEWHERE');
    expect(patch.reorderLevel).toBe(99);
    expect(patch.category).toBe('Brakes');
    // Stored figures ride along unchanged (rules diff them out):
    expect(patch.cost).toBe(170);
    expect(patch.price).toBe(250);
    // A name edit can never move prices — no history write.
    expect(recordPriceChange).not.toHaveBeenCalled();
  });
});
