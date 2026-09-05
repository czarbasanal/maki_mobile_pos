import { describe, expect, it, vi } from 'vitest';
import { act, render, screen, waitFor } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { MemoryRouter, Routes, Route, Link } from 'react-router-dom';
import { QueryClient, QueryClientProvider } from '@tanstack/react-query';
import { DiProvider, type Container } from '@/infrastructure/di/container';
import { JobOrderEditPage } from './JobOrderEditPage';
import { useCartStore } from '@/presentation/stores/cartStore';
import { useJobOrderEditStore } from '@/presentation/stores/jobOrderEditStore';
import { useAuthStore } from '@/presentation/stores/authStore';
import { DiscountType } from '@/domain/enums/DiscountType';
import type { JobOrder, Product, Mechanic } from '@/domain/entities';
import type { ReactNode } from 'react';

const jobOrder = (o: Partial<JobOrder> = {}): JobOrder => ({
  id: 'd1', name: 'Mr Cruz — Mio', items: [], laborLines: [], feeLines: [], mechanicId: null, mechanicName: null, motorcycleModel: null,
  discountType: DiscountType.amount, createdBy: 'u1', createdByName: 'C', createdAt: new Date(),
  updatedAt: null, updatedBy: null, isConverted: false, convertedToSaleId: null, convertedAt: null, notes: null, ...o,
});

const product = (o: Partial<Product> = {}): Product =>
  ({ id: 'p1', sku: 'A', name: 'Plug', price: 100, cost: 60, unit: 'pcs', quantity: 9, isActive: true, ...o } as Product);

function harness(jobOrderRepo: Partial<Container['jobOrderRepo']>, node: ReactNode = <JobOrderEditPage />) {
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
  const activityLogRepo = {
    log: vi.fn().mockResolvedValue(undefined),
  } as unknown as Container['activityLogRepo'];
  return render(
    <DiProvider
      override={{
        jobOrderRepo: jobOrderRepo as Container['jobOrderRepo'],
        productRepo: productRepo as Container['productRepo'],
        mechanicRepo: mechanicRepo as Container['mechanicRepo'],
        activityLogRepo,
      }}
    >
      <QueryClientProvider client={qc}>
        <MemoryRouter initialEntries={['/job-orders/d1']}>
          <Routes><Route path="/job-orders/:id" element={node} /></Routes>
        </MemoryRouter>
      </QueryClientProvider>
    </DiProvider>,
  );
}

describe('JobOrderEditPage', () => {
  it('shows the editor with the job order name once loaded', async () => {
    harness({ getById: vi.fn().mockResolvedValue(jobOrder()) });
    await waitFor(() => expect(screen.getByDisplayValue('Mr Cruz — Mio')).toBeInTheDocument());
  });

  it('names the motorcycle being worked on', async () => {
    harness({ getById: vi.fn().mockResolvedValue(jobOrder({ motorcycleModel: 'Honda Click 125i' })) });
    await waitFor(() => expect(screen.getByText('Honda Click 125i')).toBeInTheDocument());
  });

  it('offers the motorcycle model picker (web can set it now)', async () => {
    harness({ getById: vi.fn().mockResolvedValue(jobOrder({ motorcycleModel: null })) });
    await waitFor(() =>
      expect(screen.getByRole('button', { name: /^Motorcycle/ })).toBeInTheDocument(),
    );
  });

  it('blocks editing a converted (billed) job order', async () => {
    harness({ getById: vi.fn().mockResolvedValue(jobOrder({ isConverted: true })) });
    await waitFor(() => expect(screen.getByText(/This Job Order is already billed out/i)).toBeInTheDocument());
  });

  it('shows not-found when the job order is missing', async () => {
    harness({ getById: vi.fn().mockResolvedValue(null) });
    await waitFor(() => expect(screen.getByText(/Job Order not found/i)).toBeInTheDocument());
  });

  it('re-hydrates the editor when navigating between job orders without unmounting', async () => {
    const jobOrdersById: Record<string, JobOrder> = {
      d1: jobOrder({ id: 'd1', name: 'JobOrder One' }),
      d2: jobOrder({ id: 'd2', name: 'JobOrder Two' }),
    };
    const getById = vi.fn((id: string) => Promise.resolve(jobOrdersById[id] ?? null));
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
          jobOrderRepo: { getById } as unknown as Container['jobOrderRepo'],
          productRepo: productRepo as Container['productRepo'],
          mechanicRepo: mechanicRepo as Container['mechanicRepo'],
        }}
      >
        <QueryClientProvider client={qc}>
          <MemoryRouter initialEntries={['/job-orders/d1']}>
            <Link to="/job-orders/d2">Go to job order two</Link>
            {/* Same Route element instance is reused across param changes (no key) — this is what exposed the bug. */}
            <Routes>
              <Route path="/job-orders/:id" element={<JobOrderEditPage />} />
            </Routes>
          </MemoryRouter>
        </QueryClientProvider>
      </DiProvider>,
    );

    await screen.findByDisplayValue('JobOrder One');

    await userEvent.click(screen.getByText('Go to job order two'));

    await screen.findByDisplayValue('JobOrder Two');
  });

  it('saves the jobOrder-edit store contents (not the live POS cart) and leaves the live cart untouched', async () => {
    useCartStore.getState().clear();
    useAuthStore.setState({
      user: { id: 'u1', email: 'a@b.co', displayName: 'Cashier', role: 'admin', isActive: true } as never,
    });
    const update = vi.fn().mockResolvedValue(undefined);

    harness({ getById: vi.fn().mockResolvedValue(jobOrder({ id: 'd1', name: 'JobOrder One', items: [] })), update });

    await screen.findByDisplayValue('JobOrder One');

    // Mutate the job order-edit store (not the live cart) — this is the wiring under test.
    act(() => {
      useJobOrderEditStore.getState().addLine(product());
    });

    await userEvent.click(screen.getByRole('button', { name: /save changes/i }));

    await waitFor(() => expect(update).toHaveBeenCalled());
    const [id, patch] = update.mock.calls[0] as [string, { items: { productId: string }[] }];
    expect(id).toBe('d1');
    expect(patch.items).toHaveLength(1);
    expect(patch.items[0]).toMatchObject({ productId: 'p1' });

    // The live POS cart must remain untouched by editing/saving a job order.
    expect(useCartStore.getState().lines).toHaveLength(0);
  });

  it('hydrates notes from the job order and saves the edited value', async () => {
    useCartStore.getState().clear();
    useAuthStore.setState({
      user: { id: 'u1', email: 'a@b.co', displayName: 'Cashier', role: 'admin', isActive: true } as never,
    });
    const update = vi.fn().mockResolvedValue(undefined);
    harness({
      getById: vi.fn().mockResolvedValue(jobOrder({ id: 'd1', name: 'JobOrder One', notes: 'Original note' })),
      update,
    });

    await screen.findByDisplayValue('JobOrder One');
    expect(screen.getByLabelText(/notes/i)).toHaveValue('Original note');

    await userEvent.clear(screen.getByLabelText(/notes/i));
    await userEvent.type(screen.getByLabelText(/notes/i), 'Replace clutch cable');
    await userEvent.click(screen.getByRole('button', { name: /save changes/i }));

    await waitFor(() => expect(update).toHaveBeenCalled());
    const [, patch] = update.mock.calls[0] as [string, { notes: string | null }];
    expect(patch.notes).toBe('Replace clutch cable');
  });

  it('clearing notes saves null, never an empty string', async () => {
    useCartStore.getState().clear();
    useAuthStore.setState({
      user: { id: 'u1', email: 'a@b.co', displayName: 'Cashier', role: 'admin', isActive: true } as never,
    });
    const update = vi.fn().mockResolvedValue(undefined);
    harness({
      getById: vi.fn().mockResolvedValue(jobOrder({ id: 'd1', name: 'JobOrder One', notes: 'Old' })),
      update,
    });

    await screen.findByDisplayValue('JobOrder One');
    await userEvent.clear(screen.getByLabelText(/notes/i));
    await userEvent.click(screen.getByRole('button', { name: /save changes/i }));

    await waitFor(() => expect(update).toHaveBeenCalled());
    const [, patch] = update.mock.calls[0] as [string, { notes: string | null }];
    expect(patch.notes).toBeNull();
  });

  it('preserves a fee-bearing jobOrder\'s shop fees when saved (money must not be dropped on edit)', async () => {
    useCartStore.getState().clear();
    useAuthStore.setState({
      user: { id: 'u1', email: 'a@b.co', displayName: 'Cashier', role: 'admin', isActive: true } as never,
    });
    const update = vi.fn().mockResolvedValue(undefined);
    const feeLines = [{ id: 'f1', name: 'Convenience fee', amount: 50, description: null }];

    harness({
      getById: vi.fn().mockResolvedValue(jobOrder({ id: 'd1', name: 'JobOrder One', feeLines })),
      update,
    });

    await screen.findByDisplayValue('JobOrder One');
    await userEvent.click(screen.getByRole('button', { name: /save changes/i }));

    await waitFor(() => expect(update).toHaveBeenCalled());
    const [, patch] = update.mock.calls[0] as [string, { feeLines: unknown }];
    expect(patch.feeLines).toEqual(feeLines);
  });
});

describe('JobOrderEditPage — motorcycle model persists (review blocker)', () => {
  it('saving carries the picked model into the update patch', async () => {
    const update = vi.fn().mockResolvedValue(undefined);
    harness({
      getById: vi.fn().mockResolvedValue(jobOrder({ motorcycleModel: null })),
      update,
    });
    await waitFor(() =>
      expect(screen.getByRole('button', { name: /^Motorcycle/ })).toBeInTheDocument(),
    );
    // Simulate a pick landing in the edit store (the picker's own behavior is
    // covered by MotorcycleModelPicker.test) then save.
    act(() => useJobOrderEditStore.getState().setMotorcycleModel('Nmax 155'));
    await userEvent.click(screen.getByRole('button', { name: /save changes/i }));
    await waitFor(() => expect(update).toHaveBeenCalled());
    const patch = update.mock.calls[0][1];
    expect(patch.motorcycleModel).toBe('Nmax 155');
  });
});
