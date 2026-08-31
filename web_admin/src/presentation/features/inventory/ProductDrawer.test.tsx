// The product view is a drawer over the inventory list, not its own page, so
// you keep your place in the list. It stays URL-backed (/inventory/:id) — Back
// closes it, a refresh reopens it, and a product link is still shareable.
import { describe, expect, it, vi } from 'vitest';
import { render, screen, waitFor } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { MemoryRouter, Route, Routes } from 'react-router-dom';
import { QueryClient, QueryClientProvider } from '@tanstack/react-query';
import { DiProvider, type Container } from '@/infrastructure/di/container';
import { ProductDrawer } from './ProductDrawer';
import { useAuthStore } from '@/presentation/stores/authStore';
import { UserRole } from '@/domain/enums';
import type { Product } from '@/domain/entities';

function signIn(role: UserRole = UserRole.admin) {
  useAuthStore.setState({
    user: {
      id: 'u1', email: 'a@b.co', displayName: 'Tester',
      role, isActive: true,
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
    sellingOptions: [], category: 'Brakes', imageUrl: null, notes: null,
    ...over,
  };
}

/** Renders the drawer at /inventory/:id with a stub list behind it, so the
 *  "closing returns to the list" behavior is observable. */
function harness(p: Product | null = product()) {
  const qc = new QueryClient({ defaultOptions: { queries: { retry: false } } });
  const productRepo: Partial<Container['productRepo']> = {
    getById: vi.fn().mockResolvedValue(p),
    adjustStock: vi.fn().mockResolvedValue(undefined),
  };
  const activityLogRepo = { log: vi.fn().mockResolvedValue(undefined) } as unknown as Container['activityLogRepo'];
  return render(
    <DiProvider
      override={{
        productRepo: productRepo as Container['productRepo'],
        activityLogRepo,
      }}
    >
      <QueryClientProvider client={qc}>
        <MemoryRouter initialEntries={['/inventory/p9']}>
          <Routes>
            <Route path="/inventory" element={<div>Inventory list</div>} />
            <Route path="/inventory/:id" element={<ProductDrawer />} />
          </Routes>
        </MemoryRouter>
      </QueryClientProvider>
    </DiProvider>,
  );
}

describe('ProductDrawer', () => {
  it('opens as a drawer showing the product', async () => {
    signIn();
    harness();

    const drawer = await screen.findByRole('dialog', { name: /Brake shoe/ });
    expect(drawer).toBeInTheDocument();
    expect(screen.getByText('ABC123')).toBeInTheDocument();
    expect(screen.getByText('8 set')).toBeInTheDocument();
  });

  it('shows a placeholder when the product has no photo', async () => {
    signIn();
    harness(product({ imageUrl: null }));

    expect(await screen.findByLabelText('No image')).toBeInTheDocument();
  });

  it('shows the photo when there is one', async () => {
    signIn();
    harness(product({ imageUrl: 'https://example.test/brake.jpg' }));

    const img = await screen.findByRole('img', { name: 'Brake shoe (Yamaha)' });
    expect(img).toHaveAttribute('src', 'https://example.test/brake.jpg');
  });

  it('offers stock adjustment from inside the drawer', async () => {
    signIn();
    harness();
    await screen.findByRole('dialog', { name: /Brake shoe/ });

    await userEvent.click(screen.getByRole('button', { name: /Adjust stock/ }));

    expect(await screen.findByRole('dialog', { name: 'Adjust stock' })).toBeInTheDocument();
  });

  it('returns to the inventory list when closed', async () => {
    signIn();
    harness();
    await screen.findByRole('dialog', { name: /Brake shoe/ });

    await userEvent.click(screen.getByRole('button', { name: 'Close' }));

    await waitFor(() => expect(screen.getByText('Inventory list')).toBeInTheDocument());
    expect(screen.queryByRole('dialog', { name: /Brake shoe/ })).toBeNull();
  });

  it('keeps price history reachable from the action row', async () => {
    signIn();
    harness();
    await screen.findByRole('dialog', { name: /Brake shoe/ });

    expect(screen.getByRole('link', { name: /Price history/ })).toHaveAttribute(
      'href',
      '/price-history?product=p9',
    );
  });

  it('does not offer delete from the read-only view', async () => {
    // Deleting now lives inside the edit drawer, so the view stays free of
    // destructive actions.
    signIn();
    harness();
    await screen.findByRole('dialog', { name: /Brake shoe/ });

    expect(screen.queryByRole('button', { name: /Delete/ })).toBeNull();
  });

  it('says so plainly when the product is gone', async () => {
    signIn();
    harness(null);

    expect(await screen.findByText('Product not found')).toBeInTheDocument();
  });
});

describe('ProductDrawer cost visibility', () => {
  it('hides Cost and Margin from staff — price stays', async () => {
    signIn(UserRole.staff);
    harness();
    await screen.findByRole('dialog', { name: /Brake shoe/ });

    expect(screen.queryByText('Cost')).toBeNull();
    expect(screen.queryByText('Margin')).toBeNull();
    expect(screen.getByText('Price')).toBeInTheDocument();
  });

  it('shows Cost and Margin to admins', async () => {
    signIn(UserRole.admin);
    harness();
    await screen.findByRole('dialog', { name: /Brake shoe/ });

    expect(screen.getByText('Cost')).toBeInTheDocument();
    expect(screen.getByText('Margin')).toBeInTheDocument();
  });
});


describe('ProductDrawer — cashier action gating (mobile parity)', () => {
  it('cashier keeps Edit (name-only) but loses stock/cost actions', async () => {
    signIn(UserRole.cashier);
    harness();
    await screen.findByRole('dialog', { name: /Brake shoe/ });
    expect(screen.getByRole('link', { name: /edit/i })).toBeInTheDocument();
    expect(screen.queryByRole('button', { name: /adjust stock/i })).not.toBeInTheDocument();
    expect(screen.queryByRole('link', { name: /price history/i })).not.toBeInTheDocument();
  });

  it('cashier cannot reactivate an inactive product (isActive is rules-denied)', async () => {
    signIn(UserRole.cashier);
    harness({ ...product(), isActive: false });
    await screen.findByRole('dialog', { name: /Brake shoe/ });
    expect(screen.queryByRole('button', { name: /reactivate/i })).not.toBeInTheDocument();
  });

  it('staff keeps Adjust stock and Reactivate', async () => {
    signIn(UserRole.staff);
    harness({ ...product(), isActive: false });
    await screen.findByRole('dialog', { name: /Brake shoe/ });
    expect(screen.getByRole('button', { name: /adjust stock/i })).toBeInTheDocument();
    expect(screen.getByRole('button', { name: /reactivate/i })).toBeInTheDocument();
  });
});
