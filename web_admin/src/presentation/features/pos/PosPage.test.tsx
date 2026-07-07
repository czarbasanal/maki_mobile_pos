import { describe, expect, it, vi } from 'vitest';
import { render, screen } from '@testing-library/react';
import { MemoryRouter } from 'react-router-dom';
import { QueryClient, QueryClientProvider } from '@tanstack/react-query';
import { DiProvider, type Container } from '@/infrastructure/di/container';
import { PosPage } from './PosPage';
import { useCartStore } from '@/presentation/stores/cartStore';
import type { Product, Mechanic } from '@/domain/entities';

function harness(state?: { completedSaleNumber?: string }) {
  const qc = new QueryClient({ defaultOptions: { mutations: { retry: false } } });
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
});
