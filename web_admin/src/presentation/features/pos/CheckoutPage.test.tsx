import { describe, expect, it, vi } from 'vitest';
import { render, screen, waitFor } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { MemoryRouter, Routes, Route, useLocation } from 'react-router-dom';
import { QueryClient, QueryClientProvider } from '@tanstack/react-query';
import { DiProvider, type Container } from '@/infrastructure/di/container';
import { CheckoutPage } from './CheckoutPage';
import { useCartStore } from '@/presentation/stores/cartStore';
import { useAuthStore } from '@/presentation/stores/authStore';
import type { JobOrder, Product } from '@/domain/entities';
import { DiscountType } from '@/domain/enums/DiscountType';

const product = (o: Partial<Product> = {}): Product =>
  ({ id: 'p1', sku: 'A', name: 'Plug', price: 100, cost: 60, unit: 'pcs', quantity: 9, isActive: true, ...o } as Product);

function PosStub() {
  const { state } = useLocation() as { state: { completedSaleNumber?: string } | null };
  return <div>POS PAGE {state?.completedSaleNumber ?? ''}</div>;
}

function harness(saleRepo: Partial<Container['saleRepo']>, extra: Partial<Container> = {}) {
  const qc = new QueryClient({ defaultOptions: { mutations: { retry: false } } });
  const activityLogRepo = {
    log: vi.fn().mockResolvedValue(undefined),
  } as unknown as Container['activityLogRepo'];
  return render(
    <DiProvider override={{ saleRepo: saleRepo as Container['saleRepo'], activityLogRepo, ...extra }}>
      <QueryClientProvider client={qc}>
        <MemoryRouter initialEntries={['/pos/checkout']}>
          <Routes>
            <Route path="/pos/checkout" element={<CheckoutPage />} />
            <Route path="/pos" element={<PosStub />} />
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
    await waitFor(() => expect(screen.getByText(/POS PAGE S-00100/)).toBeInTheDocument());
    expect(useCartStore.getState().lines).toHaveLength(0);
  });

  it('carries a resumed jobOrder\'s shop fees through to the created sale (money must not be lost on bill-out)', async () => {
    useCartStore.getState().clear();
    useAuthStore.setState({ user: { id: 'u1', email: 'a@b.co', displayName: 'Cashier', role: 'admin', isActive: true } as never });

    const jobOrder: JobOrder = {
      id: 'd1',
      name: 'Mr Cruz bike',
      items: [
        { id: 'i1', productId: 'p1', sku: 'A', name: 'Plug', unitPrice: 100, unitCost: 60, quantity: 1, discountValue: 0, unit: 'pcs', optionId: null, optionLabel: null, optionPieces: null, optionPrice: null },
      ],
      laborLines: [],
      feeLines: [{ id: 'f1', name: 'Convenience fee', amount: 50 }],
      mechanicId: null,
      mechanicName: null,
      motorcycleModel: null,
      discountType: DiscountType.amount,
      createdBy: 'u1',
      createdByName: 'Cashier',
      createdAt: new Date('2026-02-01'),
      updatedAt: null,
      updatedBy: null,
      isConverted: false,
      convertedToSaleId: null,
      convertedAt: null,
      notes: null,
    };
    useCartStore.getState().loadJobOrder(jobOrder);

    const create = vi.fn().mockResolvedValue({ id: 's1', saleNumber: 'S-00101' });
    harness({ create });

    await userEvent.click(screen.getByRole('button', { name: /^gcash$/i }));
    await userEvent.click(screen.getByRole('button', { name: /complete sale/i }));
    await waitFor(() => expect(create).toHaveBeenCalledTimes(1));

    const [saleInput] = create.mock.calls[0] as [{ feeLines: unknown; jobOrderId: string | null }];
    expect(saleInput.jobOrderId).toBe('d1');
    expect(saleInput.feeLines).toEqual(jobOrder.feeLines);
  });
});

// --- Money-safety gates (mobile parity) ---

import { shopDayInt } from '@/domain/time/shopTime';

const drawerRepo = (s: { lastSaleDay: number | null; lastClosedDay: number | null }) =>
  ({
    watch: (cb: (v: typeof s) => void) => {
      cb(s);
      return () => {};
    },
  }) as Container['drawerStateRepo'];

describe('CheckoutPage — money-safety gates', () => {
  it('blocks completion behind an unsettled previous day, with the operational banner', async () => {
    useCartStore.getState().clear();
    useCartStore.getState().addLine(product());
    const today = shopDayInt(new Date());
    harness(
      { create: vi.fn() },
      { drawerStateRepo: drawerRepo({ lastSaleDay: today - 1, lastClosedDay: today - 2 }) },
    );
    await userEvent.click(screen.getByRole('button', { name: /^gcash$/i }));
    expect(screen.getByText(/Close the day on the register phone/)).toBeInTheDocument();
    expect(screen.getByRole('button', { name: /complete sale/i })).toBeDisabled();
  });

  it('blocks completion when labor is charged without a mechanic', async () => {
    useCartStore.getState().clear();
    useCartStore.getState().addLine(product());
    useCartStore.getState().addLaborLine();
    const laborId = useCartStore.getState().laborLines[0].id;
    useCartStore.getState().setLaborLine(laborId, { description: 'Change oil', fee: 150 });
    harness({ create: vi.fn() });
    await userEvent.click(screen.getByRole('button', { name: /^gcash$/i }));
    expect(screen.getByText('Assign a mechanic before saving labor.')).toBeInTheDocument();
    expect(screen.getByRole('button', { name: /complete sale/i })).toBeDisabled();
  });

  it('completes a labor-only sale (no product lines) end to end', async () => {
    useCartStore.getState().clear();
    useCartStore.getState().addLaborLine();
    const laborId = useCartStore.getState().laborLines[0].id;
    useCartStore.getState().setLaborLine(laborId, { description: 'Change oil', fee: 150 });
    useCartStore.getState().setMechanic('m1', 'Berto');
    useAuthStore.setState({ user: { id: 'u1', email: 'a@b.co', displayName: 'Cashier', role: 'admin', isActive: true } as never });
    const create = vi.fn().mockResolvedValue({ id: 's1', saleNumber: 'S-00200' });
    harness({ create });
    expect(screen.queryByText(/POS PAGE/)).not.toBeInTheDocument();
    await userEvent.click(screen.getByRole('button', { name: /^gcash$/i }));
    await userEvent.click(screen.getByRole('button', { name: /complete sale/i }));
    await waitFor(() => expect(create).toHaveBeenCalledTimes(1));
    const [written] = create.mock.calls[0];
    expect(written.items).toHaveLength(0);
    expect(written.laborLines).toEqual([{ id: laborId, description: 'Change oil', fee: 150 }]);
  });

  it('remaps a server permission-denied to the drawer message', async () => {
    useCartStore.getState().clear();
    useCartStore.getState().addLine(product());
    useAuthStore.setState({ user: { id: 'u1', email: 'a@b.co', displayName: 'Cashier', role: 'admin', isActive: true } as never });
    const denied = Object.assign(new Error('Missing or insufficient permissions.'), {
      code: 'permission-denied',
    });
    const create = vi.fn().mockRejectedValue(denied);
    harness({ create });
    await userEvent.click(screen.getByRole('button', { name: /^gcash$/i }));
    await userEvent.click(screen.getByRole('button', { name: /complete sale/i }));
    await waitFor(() =>
      expect(
        screen.getByText("Sale blocked: the previous day's drawer must be closed first."),
      ).toBeInTheDocument(),
    );
  });
});
