import { describe, expect, it, vi } from 'vitest';
import { act, render, screen, waitFor } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { MemoryRouter, Routes, Route, Link } from 'react-router-dom';
import { QueryClient, QueryClientProvider } from '@tanstack/react-query';
import { DiProvider, type Container } from '@/infrastructure/di/container';
import { DraftEditPage } from './DraftEditPage';
import { useCartStore } from '@/presentation/stores/cartStore';
import { useDraftEditStore } from '@/presentation/stores/draftEditStore';
import { useAuthStore } from '@/presentation/stores/authStore';
import { DiscountType } from '@/domain/enums/DiscountType';
import type { Draft, Product, Mechanic } from '@/domain/entities';
import type { ReactNode } from 'react';

const draft = (o: Partial<Draft> = {}): Draft => ({
  id: 'd1', name: 'Mr Cruz — Mio', items: [], laborLines: [], mechanicId: null, mechanicName: null,
  discountType: DiscountType.amount, createdBy: 'u1', createdByName: 'C', createdAt: new Date(),
  updatedAt: null, updatedBy: null, isConverted: false, convertedToSaleId: null, convertedAt: null, notes: null, ...o,
});

const product = (o: Partial<Product> = {}): Product =>
  ({ id: 'p1', sku: 'A', name: 'Plug', price: 100, cost: 60, unit: 'pcs', quantity: 9, isActive: true, ...o } as Product);

function harness(draftRepo: Partial<Container['draftRepo']>, node: ReactNode = <DraftEditPage />) {
  const qc = new QueryClient({ defaultOptions: { queries: { retry: false } } });
  const productRepo: Partial<Container['productRepo']> = {
    watchAll: (cb: (products: Product[]) => void) => {
      cb([]);
      return () => {};
    },
  };
  const mechanicRepo: Partial<Container['mechanicRepo']> = {
    watchAll: (cb: (mechanics: Mechanic[]) => void) => {
      cb([]);
      return () => {};
    },
  };
  return render(
    <DiProvider
      override={{
        draftRepo: draftRepo as Container['draftRepo'],
        productRepo: productRepo as Container['productRepo'],
        mechanicRepo: mechanicRepo as Container['mechanicRepo'],
      }}
    >
      <QueryClientProvider client={qc}>
        <MemoryRouter initialEntries={['/drafts/d1']}>
          <Routes><Route path="/drafts/:id" element={node} /></Routes>
        </MemoryRouter>
      </QueryClientProvider>
    </DiProvider>,
  );
}

describe('DraftEditPage', () => {
  it('shows the editor with the draft name once loaded', async () => {
    harness({ getById: vi.fn().mockResolvedValue(draft()) });
    await waitFor(() => expect(screen.getByDisplayValue('Mr Cruz — Mio')).toBeInTheDocument());
  });

  it('blocks editing a converted draft', async () => {
    harness({ getById: vi.fn().mockResolvedValue(draft({ isConverted: true })) });
    await waitFor(() => expect(screen.getByText(/already billed out/i)).toBeInTheDocument());
  });

  it('shows not-found when the draft is missing', async () => {
    harness({ getById: vi.fn().mockResolvedValue(null) });
    await waitFor(() => expect(screen.getByText(/Draft not found/i)).toBeInTheDocument());
  });

  it('re-hydrates the editor when navigating between drafts without unmounting', async () => {
    const draftsById: Record<string, Draft> = {
      d1: draft({ id: 'd1', name: 'Draft One' }),
      d2: draft({ id: 'd2', name: 'Draft Two' }),
    };
    const getById = vi.fn((id: string) => Promise.resolve(draftsById[id] ?? null));
    const qc = new QueryClient({ defaultOptions: { queries: { retry: false } } });
    const productRepo: Partial<Container['productRepo']> = {
      watchAll: (cb: (products: Product[]) => void) => {
        cb([]);
        return () => {};
      },
    };
    const mechanicRepo: Partial<Container['mechanicRepo']> = {
      watchAll: (cb: (mechanics: Mechanic[]) => void) => {
        cb([]);
        return () => {};
      },
    };

    render(
      <DiProvider
        override={{
          draftRepo: { getById } as unknown as Container['draftRepo'],
          productRepo: productRepo as Container['productRepo'],
          mechanicRepo: mechanicRepo as Container['mechanicRepo'],
        }}
      >
        <QueryClientProvider client={qc}>
          <MemoryRouter initialEntries={['/drafts/d1']}>
            <Link to="/drafts/d2">Go to draft two</Link>
            {/* Same Route element instance is reused across param changes (no key) — this is what exposed the bug. */}
            <Routes>
              <Route path="/drafts/:id" element={<DraftEditPage />} />
            </Routes>
          </MemoryRouter>
        </QueryClientProvider>
      </DiProvider>,
    );

    await screen.findByDisplayValue('Draft One');

    await userEvent.click(screen.getByText('Go to draft two'));

    await screen.findByDisplayValue('Draft Two');
  });

  it('saves the draft-edit store contents (not the live POS cart) and leaves the live cart untouched', async () => {
    useCartStore.getState().clear();
    useAuthStore.setState({
      user: { id: 'u1', email: 'a@b.co', displayName: 'Cashier', role: 'admin', isActive: true } as never,
    });
    const update = vi.fn().mockResolvedValue(undefined);

    harness({ getById: vi.fn().mockResolvedValue(draft({ id: 'd1', name: 'Draft One', items: [] })), update });

    await screen.findByDisplayValue('Draft One');

    // Mutate the draft-edit store (not the live cart) — this is the wiring under test.
    act(() => {
      useDraftEditStore.getState().addLine(product());
    });

    await userEvent.click(screen.getByRole('button', { name: /save changes/i }));

    await waitFor(() => expect(update).toHaveBeenCalled());
    const [id, patch] = update.mock.calls[0] as [string, { items: { productId: string }[] }];
    expect(id).toBe('d1');
    expect(patch.items).toHaveLength(1);
    expect(patch.items[0]).toMatchObject({ productId: 'p1' });

    // The live POS cart must remain untouched by editing/saving a draft.
    expect(useCartStore.getState().lines).toHaveLength(0);
  });
});
