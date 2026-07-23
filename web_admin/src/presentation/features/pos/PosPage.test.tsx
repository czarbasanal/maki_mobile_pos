import { describe, expect, it, vi } from 'vitest';
import { render, screen } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { MemoryRouter } from 'react-router-dom';
import { QueryClient, QueryClientProvider } from '@tanstack/react-query';
import { DiProvider, type Container } from '@/infrastructure/di/container';
import { PosPage } from './PosPage';
import { useCartStore } from '@/presentation/stores/cartStore';
import type { Product, Mechanic } from '@/domain/entities';

const product = (o: Partial<Product> = {}): Product =>
  ({ id: 'p1', sku: 'A', name: 'Plug', price: 100, cost: 60, unit: 'pcs', quantity: 9, isActive: true, ...o } as Product);

function harness(state?: { completedSaleNumber?: string }, products: Product[] = []) {
  const qc = new QueryClient({ defaultOptions: { mutations: { retry: false } } });
  const productRepo: Partial<Container['productRepo']> = {
    watchAll: (cb: (p: Product[]) => void) => {
      cb(products);
      return () => {};
    },
  };
  const mechanicRepo: Partial<Container['mechanicRepo']> = {
    watchAll: (cb: (mechanics: Mechanic[]) => void) => {
      cb([]);
      return () => {};
    },
  };
  const draftRepo: Partial<Container['draftRepo']> = {
    watchAll: vi.fn(() => () => {}),
    create: vi.fn(),
    update: vi.fn(),
  };

  return render(
    <DiProvider
      override={{
        productRepo: productRepo as Container['productRepo'],
        mechanicRepo: mechanicRepo as Container['mechanicRepo'],
        draftRepo: draftRepo as Container['draftRepo'],
      }}
    >
      <QueryClientProvider client={qc}>
        <MemoryRouter initialEntries={[{ pathname: '/pos', state }]}>
          <PosPage />
        </MemoryRouter>
      </QueryClientProvider>
    </DiProvider>,
  );
}

describe('PosPage', () => {
  it('shows the success banner from router state', () => {
    useCartStore.getState().clear();
    harness({ completedSaleNumber: 'S-00123' });
    expect(screen.getByText(/Sale/)).toBeInTheDocument();
    expect(screen.getByText('S-00123')).toBeInTheDocument();
    expect(screen.getByText(/completed\./)).toBeInTheDocument();
  });

  it('disables the Checkout link when the cart is empty', () => {
    useCartStore.getState().clear();
    harness();
    const link = screen.getByRole('link', { name: /checkout/i });
    expect(link.className).toContain('pointer-events-none');
  });

  it('hides the reset-sale button when the cart is empty', () => {
    useCartStore.getState().clear();
    harness();
    expect(screen.queryByLabelText('Reset sale')).toBeNull();
  });

  it('clears the whole ticket when reset is confirmed', async () => {
    useCartStore.getState().clear();
    useCartStore.getState().addLine(product());
    useCartStore.getState().setMechanic('m1', 'Juan');
    harness();

    await userEvent.click(screen.getByLabelText('Reset sale'));
    expect(screen.getByText('Clear this sale?')).toBeInTheDocument();
    await userEvent.click(screen.getByRole('button', { name: /^clear$/i }));

    expect(useCartStore.getState().lines).toHaveLength(0);
    expect(useCartStore.getState().laborLines).toHaveLength(0);
    expect(useCartStore.getState().mechanicId).toBeNull();
  });

  it('leaves the ticket untouched when reset is cancelled', async () => {
    useCartStore.getState().clear();
    useCartStore.getState().addLine(product());
    harness();

    await userEvent.click(screen.getByLabelText('Reset sale'));
    await userEvent.click(screen.getByRole('button', { name: /^cancel$/i }));

    expect(useCartStore.getState().lines).toHaveLength(1);
  });

  it('search results render as an overlay dropdown, only while searching', async () => {
    useCartStore.getState().clear();
    harness(undefined, [product()]);

    // Idle: no results panel in the layout at all (the old always-present
    // in-flow panel pushed the Checkout/Save-draft card down).
    expect(screen.queryByText(/type to search/i)).not.toBeInTheDocument();

    const input = screen.getByPlaceholderText(/search products/i);
    await userEvent.type(input, 'plug');
    const result = await screen.findByRole('button', { name: /plug/i });
    // The panel overlays (absolute positioning) instead of occupying flow.
    expect(result.closest('div[class*="absolute"]')).not.toBeNull();

    await userEvent.clear(input);
    expect(screen.queryByRole('button', { name: /plug/i })).not.toBeInTheDocument();
  });
});
