// Staff can edit products (limited), but per-item COST is admin-only — the
// phone shows staff a cost CODE and hides the number behind a password, while
// the web edit form displayed the raw stored cost to anyone who could open it.
// Price is not secret (it's on the POS) but staff may not CHANGE it — the
// rules reject the whole update if they do, so the field must be read-only
// rather than an invitation to a save that cannot succeed.
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

function harness() {
  const qc = new QueryClient({ defaultOptions: { queries: { retry: false } } });
  const updateProductWithClaims = vi.fn().mockResolvedValue(undefined);
  // An unchanged-SKU save goes through plain update(), not the claims path.
  const update = vi.fn().mockResolvedValue(undefined);
  const productRepo: Partial<Container['productRepo']> = {
    getById: vi.fn().mockResolvedValue(product()),
    updateProductWithClaims,
    update,
    barcodeExists: vi.fn().mockResolvedValue(false),
    countSkuVariations: vi.fn().mockResolvedValue(0),
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
  return { updateProductWithClaims, update };
}

describe('InventoryFormPage — staff editing and cost secrecy', () => {
  it('hides the Cost field from staff in edit mode', async () => {
    signIn(UserRole.staff);
    harness();
    await screen.findByDisplayValue('Brake shoe');

    expect(screen.queryByLabelText('Cost')).toBeNull();
    // The stored figure must not appear anywhere on the form.
    expect(screen.queryByDisplayValue('170')).toBeNull();
  });

  it('makes Price read-only for staff — the rules reject a staff price change', async () => {
    signIn(UserRole.staff);
    harness();
    await screen.findByDisplayValue('Brake shoe');

    const price = screen.getByLabelText('Price') as HTMLInputElement;
    expect(price).toBeDisabled();
  });

  it('a staff save still carries the STORED cost and price unchanged', async () => {
    signIn(UserRole.staff);
    const { update } = harness();
    await screen.findByDisplayValue('Brake shoe');

    await userEvent.clear(screen.getByLabelText('Name'));
    await userEvent.type(screen.getByLabelText('Name'), 'Brake shoe rear');
    await userEvent.click(screen.getByRole('button', { name: /Save changes/ }));

    await waitFor(() => expect(update).toHaveBeenCalled());
    const patch = update.mock.calls[0][1];
    // Unchanged values never appear in the rules' affectedKeys, so carrying
    // them keeps the staff update passing exactly as before.
    expect(patch.cost).toBe(170);
    expect(patch.price).toBe(250);
    // Name inputs uppercase as you type — a shipped behavior, not this test's concern.
    expect(patch.name).toBe('BRAKE SHOE REAR');
  });

  it('admins keep the editable Cost and Price fields', async () => {
    signIn(UserRole.admin);
    harness();
    await screen.findByDisplayValue('Brake shoe');

    expect(screen.getByLabelText('Cost')).toBeInTheDocument();
    expect(screen.getByLabelText('Price')).not.toBeDisabled();
  });
});
