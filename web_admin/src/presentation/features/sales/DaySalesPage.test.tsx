// DaySalesPage: a single day's sales as expandable tiles. list() already
// returns every sale with .items populated (matching the real
// FirestoreSaleRepository contract), so expand is a purely local toggle —
// getById must never be called from this page. Prev/next day re-queries the
// [00:00, 23:59:59.999] range.
import { describe, expect, it, vi } from 'vitest';
import { render, screen, waitFor } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { MemoryRouter } from 'react-router-dom';
import { QueryClient, QueryClientProvider } from '@tanstack/react-query';
import { DiProvider, type Container } from '@/infrastructure/di/container';
import { useAuthStore } from '@/presentation/stores/authStore';
import { UserRole } from '@/domain/enums';
import type { User } from '@/domain/entities';
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
    jobOrderId: null,
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

function webUser(role: UserRole): User {
  return {
    id: `u-${role}`,
    email: `${role}@shop.test`,
    displayName: `${role} user`,
    role,
    isActive: true,
    phoneNumber: null,
    photoUrl: null,
    createdAt: new Date('2026-01-01'),
    updatedAt: null,
    createdBy: null,
    updatedBy: null,
    lastLoginAt: null,
  };
}

function harness({
  list,
  getById,
  role = UserRole.admin,
}: {
  list: ReturnType<typeof vi.fn>;
  getById?: ReturnType<typeof vi.fn>;
  role?: UserRole;
}) {
  useAuthStore.setState({ status: 'signedIn', user: webUser(role) });
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

  it('expands to show item lines already present on the sale, with no getById call', async () => {
    const sale = fakeSale({
      id: 's1',
      saleNumber: 'SN-0001',
      laborLines: [{ id: 'l1', description: 'Labor', fee: 50 }],
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
          optionId: null,
          optionLabel: null,
          optionPieces: null,
          optionPrice: null,
        },
      ],
    });
    const list = vi.fn().mockResolvedValue([sale]);
    const getById = vi.fn().mockResolvedValue(null);
    harness({ list, getById });

    await screen.findByText('SN-0001');
    const user = userEvent.setup();
    const toggle = screen.getByRole('button', { name: /SN-0001/i });

    await user.click(toggle);
    expect(await screen.findByText(/Brake Pad/)).toBeInTheDocument();

    await user.click(toggle); // collapse
    await user.click(toggle); // expand again

    expect(await screen.findByText(/Brake Pad/)).toBeInTheDocument();
    expect(getById).not.toHaveBeenCalled();
  });

  describe('selling option (found beyond the brief)', () => {
    // The expanded sale row renders "{quantity} × {name}" straight from
    // pieces — a By-3 line at 6 pieces would read "6 × Pulley Ball" with no
    // hint it's two sets of three, not six loose pieces.
    const optionItem = (quantity: number) => ({
      id: 'i1',
      productId: 'p1',
      sku: 'ABC-1',
      name: 'Pulley Ball',
      unitPrice: 110,
      unitCost: 60,
      quantity,
      discountValue: 0,
      unit: 'pcs',
      optionId: 'o2',
      optionLabel: 'By 3',
      optionPieces: 3,
      optionPrice: 330,
    });

    async function expandSale(list: ReturnType<typeof vi.fn>) {
      harness({ list });
      await screen.findByText('SN-0001');
      await userEvent.click(screen.getByRole('button', { name: /SN-0001/i }));
    }

    it('shows the option label beside the name for a single set', async () => {
      const list = vi.fn().mockResolvedValue([fakeSale({ items: [optionItem(3)] })]);
      await expandSale(list);

      expect(await screen.findByText(/By 3/)).toBeInTheDocument();
      expect(screen.queryByText(/× 2/)).not.toBeInTheDocument();
    });

    it('shows the set count and total pieces for more than one set', async () => {
      const list = vi.fn().mockResolvedValue([fakeSale({ items: [optionItem(6)] })]);
      await expandSale(list);

      expect(await screen.findByText(/By 3 × 2/)).toBeInTheDocument();
      expect(screen.getByText(/6 pcs/)).toBeInTheDocument();
    });

    it('a line with no option renders unchanged', async () => {
      const list = vi.fn().mockResolvedValue([
        fakeSale({
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
              optionId: null,
              optionLabel: null,
              optionPieces: null,
              optionPrice: null,
            },
          ],
        }),
      ]);
      await expandSale(list);

      expect(await screen.findByText(/Brake Pad/)).toBeInTheDocument();
      expect(screen.queryByText(/By /)).not.toBeInTheDocument();
    });
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

describe('DaySalesPage — cashier daily lock', () => {
  it('pins a cashier to today: no day navigation, date input disabled', async () => {
    const list = vi.fn().mockResolvedValue([]);
    harness({ list, role: UserRole.cashier });
    await screen.findByText(/no sales/i);
    expect(screen.queryByRole('button', { name: 'Previous day' })).not.toBeInTheDocument();
    expect(screen.queryByRole('button', { name: 'Next day' })).not.toBeInTheDocument();
    expect(screen.getByLabelText('Date')).toBeDisabled();
  });
});
