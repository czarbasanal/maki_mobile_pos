import { describe, expect, it, vi } from 'vitest';
import { render, screen, waitFor } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { MemoryRouter } from 'react-router-dom';
import { QueryClient, QueryClientProvider } from '@tanstack/react-query';
import { DiProvider, type Container } from '@/infrastructure/di/container';
import { PosPage } from './PosPage';
import { useCartStore } from '@/presentation/stores/cartStore';
import { useAuthStore } from '@/presentation/stores/authStore';
import { nextJobOrderNumber } from '@/domain/jobOrders/joNumber';
import { DiscountType } from '@/domain/enums/DiscountType';
import type { Product, Mechanic, JobOrder } from '@/domain/entities';

const product = (o: Partial<Product> = {}): Product =>
  ({ id: 'p1', sku: 'A', name: 'Plug', price: 100, cost: 60, unit: 'pcs', quantity: 9, isActive: true, ...o } as Product);

const jobOrder = (o: Partial<JobOrder> = {}): JobOrder =>
  ({
    id: 'd1',
    name: 'JO-010100-005',
    items: [],
    laborLines: [],
    feeLines: [],
    mechanicId: null,
    mechanicName: null,
    discountType: DiscountType.amount,
    createdBy: 'u1',
    createdByName: 'Cashier',
    createdAt: new Date(),
    updatedAt: null,
    updatedBy: null,
    isConverted: false,
    convertedToSaleId: null,
    convertedAt: null,
    notes: null,
    ...o,
  } as JobOrder);

/**
 * `jobOrderNames` controls the fake jobOrderRepo.watchAll:
 * - `undefined` (default): never calls back — mirrors the still-loading state
 *   the original harness used before PosPage read job orders at all.
 * - an array: resolves immediately with job orders carrying those names.
 */
function harness(
  state?: { completedSaleNumber?: string },
  products: Product[] = [],
  jobOrderNames?: string[],
) {
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
  const create = vi.fn();
  const update = vi.fn();
  const jobOrderRepo: Partial<Container['jobOrderRepo']> = {
    watchAll: vi.fn((cb: (jobOrders: JobOrder[]) => void) => {
      if (jobOrderNames === undefined) return () => {};
      cb(jobOrderNames.map((name, i) => jobOrder({ id: `existing-${i}`, name })));
      return () => {};
    }),
    create,
    update,
  };

  const activityLogRepo = {
    log: vi.fn().mockResolvedValue(undefined),
  } as unknown as Container['activityLogRepo'];
  const utils = render(
    <DiProvider
      override={{
        productRepo: productRepo as Container['productRepo'],
        mechanicRepo: mechanicRepo as Container['mechanicRepo'],
        jobOrderRepo: jobOrderRepo as Container['jobOrderRepo'],
        activityLogRepo,
      }}
    >
      <QueryClientProvider client={qc}>
        <MemoryRouter initialEntries={[{ pathname: '/pos', state }]}>
          <PosPage />
        </MemoryRouter>
      </QueryClientProvider>
    </DiProvider>,
  );
  return { ...utils, create, update };
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

    await userEvent.click(screen.getByRole('button', { name: /reset cart/i }));
    expect(screen.getByText('Reset cart?')).toBeInTheDocument();
    await userEvent.click(screen.getByRole('button', { name: /^reset$/i }));

    expect(useCartStore.getState().lines).toHaveLength(0);
    expect(useCartStore.getState().laborLines).toHaveLength(0);
    expect(useCartStore.getState().mechanicId).toBeNull();
  });

  it('leaves the ticket untouched when reset is cancelled', async () => {
    useCartStore.getState().clear();
    useCartStore.getState().addLine(product());
    harness();

    await userEvent.click(screen.getByRole('button', { name: /reset cart/i }));
    await userEvent.click(screen.getByRole('button', { name: /^cancel$/i }));

    expect(useCartStore.getState().lines).toHaveLength(1);
  });

  it('search results render only while searching', async () => {
    useCartStore.getState().clear();
    harness(undefined, [product()]);

    // Idle: no results card at all.
    expect(screen.queryByText(/no parts match/i)).not.toBeInTheDocument();

    const input = screen.getByPlaceholderText(/search part name/i);
    await userEvent.type(input, 'plug');
    // The register results card lists the part with its on-hand and Add.
    await screen.findByRole('button', { name: /^add$/i });

    await userEvent.clear(input);
    await waitFor(() =>
      expect(screen.queryByRole('button', { name: /^add$/i })).not.toBeInTheDocument(),
    );
  });
});

describe('Save as Job Order dialog', () => {
  it('computes a JO number for a new job order and saves it as the jobOrder name', async () => {
    useCartStore.getState().clear();
    useCartStore.getState().addLine(product());
    useAuthStore.setState({
      user: { id: 'u1', email: 'a@b.co', displayName: 'Cashier', role: 'admin', isActive: true } as never,
    });
    const { create } = harness(undefined, [], []);

    await userEvent.click(screen.getByRole('button', { name: /save as job order/i }));
    const expected = nextJobOrderNumber(new Date(), []);
    const numberEl = screen.getByText(expected);
    expect(numberEl.className).toContain('font-mono');

    await userEvent.click(screen.getByRole('button', { name: /^save$/i }));
    expect(create).toHaveBeenCalledWith(expect.objectContaining({ name: expected }));
  });

  it('passes typed notes (trimmed) on save', async () => {
    useCartStore.getState().clear();
    useCartStore.getState().addLine(product());
    useAuthStore.setState({
      user: { id: 'u1', email: 'a@b.co', displayName: 'Cashier', role: 'admin', isActive: true } as never,
    });
    const { create } = harness(undefined, [], []);

    await userEvent.click(screen.getByRole('button', { name: /save as job order/i }));
    await userEvent.type(screen.getByLabelText(/notes/i), '  Check brakes  ');
    await userEvent.click(screen.getByRole('button', { name: /^save$/i }));

    expect(create).toHaveBeenCalledWith(expect.objectContaining({ notes: 'Check brakes' }));
    // Saving parks the ticket and clears the cart — notes included.
    expect(useCartStore.getState().notes).toBeNull();
  });

  it('prefills the notes textarea from the cart (resumed JO keeps its notes)', async () => {
    useCartStore.getState().clear();
    useCartStore.getState().addLine(product());
    useCartStore.getState().setNotes('Customer waiting');
    useAuthStore.setState({
      user: { id: 'u1', email: 'a@b.co', displayName: 'Cashier', role: 'admin', isActive: true } as never,
    });
    harness(undefined, [], []);

    await userEvent.click(screen.getByRole('button', { name: /save as job order/i }));
    expect(screen.getByLabelText(/notes/i)).toHaveValue('Customer waiting');
  });

  it('keeps the existing name when updating a jobOrder (no renumber)', async () => {
    useCartStore.getState().clear();
    useCartStore.getState().loadJobOrder(jobOrder({ id: 'd1', name: 'JO-010100-005' }));
    useCartStore.getState().addLine(product());
    useAuthStore.setState({
      user: { id: 'u1', email: 'a@b.co', displayName: 'Cashier', role: 'admin', isActive: true } as never,
    });
    const { update } = harness(undefined, [], ['JO-010100-005', 'JO-999999-002']);

    await userEvent.click(screen.getByRole('button', { name: /update job order/i }));
    expect(screen.getByText('JO-010100-005')).toBeInTheDocument();

    await userEvent.click(screen.getByRole('button', { name: /^save$/i }));
    expect(update).toHaveBeenCalledWith(
      'd1',
      expect.objectContaining({ name: 'JO-010100-005' }),
      expect.any(String),
    );
  });

  it('disables confirm while jobOrders are still loading, to avoid a stale-empty-list collision', async () => {
    useCartStore.getState().clear();
    useCartStore.getState().addLine(product());
    harness(undefined, [], undefined);

    await userEvent.click(screen.getByRole('button', { name: /save as job order/i }));
    expect(screen.getByRole('button', { name: /^save$/i })).toBeDisabled();
  });
});
