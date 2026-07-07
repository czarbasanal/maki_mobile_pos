import { describe, expect, it, vi } from 'vitest';
import { render, screen, waitFor } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { MemoryRouter, Routes, Route } from 'react-router-dom';
import { QueryClient, QueryClientProvider } from '@tanstack/react-query';
import { DiProvider, type Container } from '@/infrastructure/di/container';
import { CheckoutPage } from './CheckoutPage';
import { useCartStore } from '@/presentation/stores/cartStore';
import { useAuthStore } from '@/presentation/stores/authStore';
import type { Product } from '@/domain/entities';

const product = (o: Partial<Product> = {}): Product =>
  ({ id: 'p1', sku: 'A', name: 'Plug', price: 100, cost: 60, unit: 'pcs', quantity: 9, isActive: true, ...o } as Product);

function harness(saleRepo: Partial<Container['saleRepo']>) {
  const qc = new QueryClient({ defaultOptions: { mutations: { retry: false } } });
  return render(
    <DiProvider override={{ saleRepo: saleRepo as Container['saleRepo'] }}>
      <QueryClientProvider client={qc}>
        <MemoryRouter initialEntries={['/pos/checkout']}>
          <Routes>
            <Route path="/pos/checkout" element={<CheckoutPage />} />
            <Route path="/pos" element={<div>POS PAGE {`${history.state}`}</div>} />
          </Routes>
        </MemoryRouter>
      </QueryClientProvider>
    </DiProvider>,
  );
}

describe('CheckoutPage', () => {
  it('redirects to /pos when the cart is empty', () => {
    useCartStore.getState().clear();
    harness({ create: vi.fn() });
    expect(screen.getByText(/POS PAGE/)).toBeInTheDocument();
  });

  it('completes the sale and returns to /pos', async () => {
    useCartStore.getState().clear();
    useCartStore.getState().addLine(product());
    useAuthStore.setState({ user: { id: 'u1', email: 'a@b.co', displayName: 'Cashier', role: 'admin', isActive: true } as never });
    const create = vi.fn().mockResolvedValue({ id: 's1', saleNumber: 'S-00100' });
    harness({ create });
    // Default payment mode is 'cash', which requires cash-received input before
    // it's valid. Switch to GCash (paid-in-full, no extra input needed) so the
    // Complete sale button is enabled — PaymentSection/usePaymentDraft are
    // shared, unmodified code, not something this task owns.
    await userEvent.click(screen.getByRole('button', { name: /^gcash$/i }));
    await userEvent.click(screen.getByRole('button', { name: /complete sale/i }));
    await waitFor(() => expect(create).toHaveBeenCalledTimes(1));
    await waitFor(() => expect(screen.getByText(/POS PAGE/)).toBeInTheDocument());
    expect(useCartStore.getState().lines).toHaveLength(0);
  });
});
