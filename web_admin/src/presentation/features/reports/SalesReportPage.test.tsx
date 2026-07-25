import { describe, expect, it, vi } from 'vitest';
import { render, screen, waitFor } from '@testing-library/react';
import { MemoryRouter } from 'react-router-dom';
import { QueryClient, QueryClientProvider } from '@tanstack/react-query';
import { DiProvider, type Container } from '@/infrastructure/di/container';
import { SalesReportPage } from './SalesReportPage';
import { DiscountType, PaymentMethod, SaleStatus } from '@/domain/enums';
import type { Sale } from '@/domain/entities';
import { formatMoney } from '@/core/utils/money';

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
      },
    ],
    laborLines: [{ id: 'l1', description: 'Tune-up', fee: 450 }],
    feeLines: [],
    mechanicId: 'm1',
    mechanicName: 'Juan Dela Cruz',
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
    draftId: null,
    notes: null,
    voidedAt: null,
    voidedBy: null,
    voidedByName: null,
    voidReason: null,
    ...overrides,
  };
}

function harness(sales: Sale[]) {
  const qc = new QueryClient({ defaultOptions: { queries: { retry: false } } });
  const saleRepo: Partial<Container['saleRepo']> = {
    list: vi.fn().mockResolvedValue(sales),
  };
  return render(
    <DiProvider override={{ saleRepo: saleRepo as Container['saleRepo'] }}>
      <QueryClientProvider client={qc}>
        <MemoryRouter>
          <SalesReportPage />
        </MemoryRouter>
      </QueryClientProvider>
    </DiProvider>,
  );
}

describe('SalesReportPage', () => {
  it('shows a Shop fees line beside Service / Labor, summing fees across sales', async () => {
    harness([
      sale({ id: 's1', feeLines: [{ id: 'f1', name: 'Convenience fee', amount: 50 }] }),
      sale({ id: 's2', feeLines: [{ id: 'f2', name: 'Convenience fee', amount: 25 }] }),
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
});
