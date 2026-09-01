import { describe, expect, it, vi } from 'vitest';
import { render, screen, waitFor } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { MemoryRouter } from 'react-router-dom';
import { QueryClient, QueryClientProvider } from '@tanstack/react-query';
import { DiProvider, type Container } from '@/infrastructure/di/container';
import { useAuthStore } from '@/presentation/stores/authStore';
import { UserRole } from '@/domain/enums';
import type { User } from '@/domain/entities';
import { SalesReportPage } from './SalesReportPage';
import { DiscountType, PaymentMethod, SaleStatus } from '@/domain/enums';
import type { Sale } from '@/domain/entities';
import { formatMoney } from '@/core/utils/money';
import { shopTimeOf } from '@/domain/time/shopTime';

function sale(overrides: Partial<Sale> = {}): Sale {
  return {
    id: 's1',
    saleNumber: 'OR-0001',
    items: [
      {
        id: 'i1',
        productId: 'p1',
        sku: 'SKU-1',
        name: 'Spark Plug',
        unitPrice: 100,
        unitCost: 60,
        quantity: 2,
        discountValue: 0,
        unit: 'pcs',
        optionId: null,
        optionLabel: null,
        optionPieces: null,
        optionPrice: null,
      },
    ],
    laborLines: [{ id: 'l1', description: 'Tune-up', fee: 450 }],
    feeLines: [],
    mechanicId: 'm1',
    mechanicName: 'Juan Dela Cruz',
    motorcycleModel: null,
    discountType: DiscountType.amount,
    paymentMethod: PaymentMethod.cash,
    tenders: {},
    amountReceived: 650,
    changeGiven: 0,
    status: SaleStatus.completed,
    cashierId: 'c1',
    cashierName: 'Cashier',
    createdAt: new Date(),
    updatedAt: null,
    jobOrderId: null,
    notes: null,
    voidedAt: null,
    voidedBy: null,
    voidedByName: null,
    voidReason: null,
    ...overrides,
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

function harness(sales: Sale[], role: UserRole = UserRole.admin) {
  useAuthStore.setState({ status: 'signedIn', user: webUser(role) });
  const qc = new QueryClient({ defaultOptions: { queries: { retry: false } } });
  const saleRepo: Partial<Container['saleRepo']> = {
    list: vi.fn().mockResolvedValue(sales),
  };
  const view = render(
    <DiProvider override={{ saleRepo: saleRepo as Container['saleRepo'] }}>
      <QueryClientProvider client={qc}>
        <MemoryRouter>
          <SalesReportPage />
        </MemoryRouter>
      </QueryClientProvider>
    </DiProvider>,
  );
  return { view, saleRepo };
}

describe('SalesReportPage', () => {
  it('shows a Shop fees line beside Service / Labor, summing fees across sales', async () => {
    harness([
      sale({ id: 's1', feeLines: [{ id: 'f1', name: 'Convenience fee', amount: 50, description: null }] }),
      sale({ id: 's2', feeLines: [{ id: 'f2', name: 'Convenience fee', amount: 25, description: null }] }),
    ]);

    await waitFor(() => expect(screen.getByText('Service / Labor')).toBeInTheDocument());
    const row = screen.getByText('Shop fees').closest('div');
    expect(row?.textContent).toContain(formatMoney(75));
  });

  it('shows the Shop fees line (₱0.00) when no sale in range has fee lines', async () => {
    harness([sale({ feeLines: [] })]);
    await waitFor(() => expect(screen.getByText('Shop fees')).toBeInTheDocument());
    const row = screen.getByText('Shop fees').closest('div');
    expect(row?.textContent).toContain(formatMoney(0));
  });

  it('paginates the sales table at 25/page, revealing the rest on page 2', async () => {
    const many = Array.from({ length: 30 }, (_, i) =>
      sale({ id: `s${i + 1}`, saleNumber: `OR-${String(i + 1).padStart(4, '0')}` }),
    );
    harness(many);

    await waitFor(() => expect(screen.getByText('1–25 of 30')).toBeInTheDocument());
    expect(screen.getByText('OR-0001')).toBeInTheDocument();
    expect(screen.queryByText('OR-0026')).not.toBeInTheDocument();

    await userEvent.click(screen.getByRole('button', { name: 'Next' }));

    expect(screen.getByText('OR-0026')).toBeInTheDocument();
    expect(screen.queryByText('OR-0001')).not.toBeInTheDocument();
  });
});

describe('SalesReportPage — cashier daily lock + cost gating', () => {
  it('locks a cashier to today: notice instead of picker, query clamped', async () => {
    const { saleRepo } = harness([sale()], UserRole.cashier);
    await screen.findByText(
      "Showing today's sales only. Contact an admin for historical reports.",
    );
    expect(screen.queryByRole('combobox')).not.toBeInTheDocument();
    const arg = (saleRepo.list as ReturnType<typeof vi.fn>).mock.calls[0][0];
    // "Today" is the SHOP day now — the bounds are instants, so compare them
    // through the shop clock rather than the test machine's.
    const nowWall = shopTimeOf(new Date());
    const startWall = shopTimeOf(arg.start);
    expect(startWall.getUTCFullYear()).toBe(nowWall.getUTCFullYear());
    expect(startWall.getUTCMonth()).toBe(nowWall.getUTCMonth());
    expect(startWall.getUTCDate()).toBe(nowWall.getUTCDate());
    expect(startWall.getUTCHours()).toBe(0);
    expect(shopTimeOf(arg.end).getUTCDate()).toBe(nowWall.getUTCDate());
  });

  it('hides the cost-derived Profit column from a cashier', async () => {
    harness([sale()], UserRole.cashier);
    await screen.findByText('Top products');
    expect(screen.queryByText('Profit')).not.toBeInTheDocument();
  });

  it('admin keeps the range picker and the Profit column', async () => {
    harness([sale()]);
    await screen.findByText('Top products');
    expect(screen.getByRole('combobox')).toBeInTheDocument();
    expect(screen.getByText('Profit')).toBeInTheDocument();
  });
});

describe('SalesReportPage — default range', () => {
  it('opens on Today, not the last 7 days', async () => {
    // The page is opened to answer "how are we doing today"; a 7-day default
    // answered a different question without saying so. The picker's own
    // default has to match, or the dropdown and the figures disagree.
    harness([]);
    const picker = await screen.findByRole('combobox');
    expect((picker as HTMLSelectElement).value).toBe('today');
  });

  it('queries only today', async () => {
    const { saleRepo } = harness([]);
    await screen.findByRole('combobox');

    await waitFor(() => expect(saleRepo.list).toHaveBeenCalled());
    const { start, end } = (saleRepo.list as ReturnType<typeof vi.fn>).mock.calls[0][0];
    // One shop day, not seven.
    expect(end.getTime() - start.getTime()).toBeLessThan(24 * 60 * 60 * 1000);
  });
});
