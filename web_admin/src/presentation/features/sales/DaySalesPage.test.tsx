// DaySalesPage: a single day's sales as expandable tiles. Items load lazily
// (first expand only — the fake repo's getById call count is the contract),
// and prev/next day re-queries the [00:00, 23:59:59.999] range.
import { describe, expect, it, vi } from 'vitest';
import { render, screen, waitFor } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { MemoryRouter } from 'react-router-dom';
import { QueryClient, QueryClientProvider } from '@tanstack/react-query';
import { DiProvider, type Container } from '@/infrastructure/di/container';
import { PaymentMethod, SaleStatus, DiscountType } from '@/domain/enums';
import type { Sale } from '@/domain/entities';
import { DaySalesPage } from './DaySalesPage';

function fakeSale(o: Partial<Sale> = {}): Sale {
  return {
    id: 's1',
    saleNumber: 'SN-0001',
    createdAt: new Date('2026-07-27T10:00:00'),
    updatedAt: null,
    cashierId: 'u1',
    cashierName: 'Cashier A',
    paymentMethod: PaymentMethod.cash,
    discountType: DiscountType.amount,
    items: [],
    tenders: {},
    laborLines: [],
    feeLines: [],
    amountReceived: 100,
    changeGiven: 0,
    status: SaleStatus.completed,
    draftId: null,
    notes: null,
    mechanicId: null,
    mechanicName: null,
    voidedAt: null,
    voidedBy: null,
    voidedByName: null,
    voidReason: null,
    ...o,
  };
}

function harness({
  list,
  getById,
}: {
  list: ReturnType<typeof vi.fn>;
  getById?: ReturnType<typeof vi.fn>;
}) {
  const qc = new QueryClient({ defaultOptions: { queries: { retry: false } } });
  const saleRepo: Partial<Container['saleRepo']> = {
    list,
    getById: getById ?? vi.fn().mockResolvedValue(null),
  };
  return render(
    <DiProvider override={{ saleRepo: saleRepo as Container['saleRepo'] }}>
      <QueryClientProvider client={qc}>
        <MemoryRouter initialEntries={['/sales/day']}>
          <DaySalesPage />
        </MemoryRouter>
      </QueryClientProvider>
    </DiProvider>,
  );
}

describe('DaySalesPage', () => {
  it("renders the day's sales as collapsed tiles", async () => {
    const list = vi.fn().mockResolvedValue([
      fakeSale({ id: 's1', saleNumber: 'SN-0001' }),
      fakeSale({ id: 's2', saleNumber: 'SN-0002', paymentMethod: PaymentMethod.gcash }),
    ]);
    harness({ list });

    expect(await screen.findByText('SN-0001')).toBeInTheDocument();
    expect(screen.getByText('SN-0002')).toBeInTheDocument();
  });

  it('shows an empty state when there are no sales that day', async () => {
    const list = vi.fn().mockResolvedValue([]);
    harness({ list });

    expect(await screen.findByText(/no sales/i)).toBeInTheDocument();
  });

  it('fetches items lazily on first expand and reuses the cache on the second expand', async () => {
    const sale = fakeSale({
      id: 's1',
      saleNumber: 'SN-0001',
      laborLines: [{ id: 'l1', description: 'Labor', fee: 50 }],
    });
    const list = vi.fn().mockResolvedValue([sale]);
    const getById = vi.fn().mockResolvedValue({
      ...sale,
      items: [
        {
          id: 'i1',
          productId: 'p1',
          sku: 'SKU1',
          name: 'Brake Pad',
          unitPrice: 100,
          unitCost: 50,
          quantity: 2,
          discountValue: 0,
          unit: 'pcs',
        },
      ],
    });
    harness({ list, getById });

    await screen.findByText('SN-0001');
    const user = userEvent.setup();
    const toggle = screen.getByRole('button', { name: /SN-0001/i });

    await user.click(toggle);
    expect(await screen.findByText(/Brake Pad/)).toBeInTheDocument();
    expect(getById).toHaveBeenCalledTimes(1);

    await user.click(toggle); // collapse
    await user.click(toggle); // expand again

    expect(await screen.findByText(/Brake Pad/)).toBeInTheDocument();
    expect(getById).toHaveBeenCalledTimes(1);
  });

  it('prev/next day buttons change the queried range', async () => {
    const list = vi.fn().mockResolvedValue([]);
    harness({ list });

    await waitFor(() => expect(list).toHaveBeenCalledTimes(1));
    const firstArgs = list.mock.calls[0][0];

    await userEvent.click(screen.getByRole('button', { name: /next day/i }));

    await waitFor(() => expect(list).toHaveBeenCalledTimes(2));
    const secondArgs = list.mock.calls[1][0];
    expect(secondArgs.start.getTime()).toBeGreaterThan(firstArgs.start.getTime());
    expect(secondArgs.end.getTime()).toBeGreaterThan(firstArgs.end.getTime());
  });
});
