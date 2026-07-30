import { describe, expect, it, vi } from 'vitest';
import { render, screen, waitFor } from '@testing-library/react';
import { MemoryRouter, Routes, Route } from 'react-router-dom';
import { QueryClient, QueryClientProvider } from '@tanstack/react-query';
import { DiProvider, type Container } from '@/infrastructure/di/container';
import { SaleDetailPage } from './SaleDetailPage';
import { DiscountType, PaymentMethod, SaleStatus } from '@/domain/enums';
import type { Category, Sale } from '@/domain/entities';
import { formatMoney } from '@/core/utils/money';
import {
  saleGrandTotal,
  saleLaborSubtotal,
  salePartsSubtotal,
  saleTotalDiscount,
} from '@/domain/entities';

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
        discountValue: 20,
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
    discountType: DiscountType.amount,
    paymentMethod: PaymentMethod.cash,
    tenders: {},
    amountReceived: 650,
    changeGiven: 0,
    status: SaleStatus.completed,
    cashierId: 'c1',
    cashierName: 'Cashier',
    createdAt: new Date('2026-05-13T10:00:00Z'),
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

function harness(saleRepo: Partial<Container['saleRepo']>) {
  const qc = new QueryClient({ defaultOptions: { queries: { retry: false } } });
  const categoryRepo: Partial<Container['categoryRepo']> = {
    watchAll: (_kind, cb: (categories: Category[]) => void) => {
      cb([]);
      return () => {};
    },
  };
  return render(
    <DiProvider
      override={{
        saleRepo: saleRepo as Container['saleRepo'],
        categoryRepo: categoryRepo as Container['categoryRepo'],
      }}
    >
      <QueryClientProvider client={qc}>
        <MemoryRouter initialEntries={['/reports/sales/s1']}>
          <Routes>
            <Route path="/reports/sales/:id" element={<SaleDetailPage />} />
          </Routes>
        </MemoryRouter>
      </QueryClientProvider>
    </DiProvider>,
  );
}

describe('SaleDetailPage', () => {
  it('does not show a Shop fees row when the sale has no fee lines', async () => {
    harness({ getById: vi.fn().mockResolvedValue(sale()) });
    await waitFor(() => expect(screen.getByRole('heading', { name: 'OR-0001' })).toBeInTheDocument());
    expect(screen.queryByText('Shop fees')).not.toBeInTheDocument();
  });

  it('shows fee rows in the item table and a Shop fees total when fees are present', async () => {
    const withFees = sale({
      feeLines: [{ id: 'f1', name: 'Convenience fee', amount: 50 }],
    });
    harness({ getById: vi.fn().mockResolvedValue(withFees) });
    await waitFor(() => expect(screen.getByRole('heading', { name: 'OR-0001' })).toBeInTheDocument());

    // Rendered twice: once in the on-screen table, once in the hidden print receipt.
    expect(screen.getAllByText(/Convenience fee/).length).toBeGreaterThanOrEqual(1);
    expect(screen.getAllByText('Shop fees').length).toBeGreaterThanOrEqual(1);
  });

  describe('selling option', () => {
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

    it('shows the option label beside the name for a single set', async () => {
      harness({ getById: vi.fn().mockResolvedValue(sale({ items: [optionItem(3)] })) });
      await waitFor(() => expect(screen.getByRole('heading', { name: 'OR-0001' })).toBeInTheDocument());

      expect(screen.getAllByText(/By 3/).length).toBeGreaterThanOrEqual(1);
      expect(screen.queryByText(/× 2/)).not.toBeInTheDocument();
    });

    it('shows the set count and total pieces for more than one set', async () => {
      harness({ getById: vi.fn().mockResolvedValue(sale({ items: [optionItem(6)] })) });
      await waitFor(() => expect(screen.getByRole('heading', { name: 'OR-0001' })).toBeInTheDocument());

      expect(screen.getAllByText(/By 3 × 2/).length).toBeGreaterThanOrEqual(1);
      expect(screen.getAllByText(/6 pcs/).length).toBeGreaterThanOrEqual(1);
    });

    it('a line with no option renders unchanged', async () => {
      harness({ getById: vi.fn().mockResolvedValue(sale()) });
      await waitFor(() => expect(screen.getByRole('heading', { name: 'OR-0001' })).toBeInTheDocument());

      expect(screen.queryByText(/By /)).not.toBeInTheDocument();
    });
  });

  it('reconciles: rendered Total equals parts − discount + labor + fees for a composite sale', async () => {
    const composite = sale({
      feeLines: [{ id: 'f1', name: 'Convenience fee', amount: 50 }],
    });
    harness({ getById: vi.fn().mockResolvedValue(composite) });
    await waitFor(() => expect(screen.getByRole('heading', { name: 'OR-0001' })).toBeInTheDocument());

    const expectedTotal =
      salePartsSubtotal(composite) -
      saleTotalDiscount(composite) +
      saleLaborSubtotal(composite) +
      50; // fees
    expect(expectedTotal).toBe(saleGrandTotal(composite));
    expect(screen.getAllByText(formatMoney(expectedTotal)).length).toBeGreaterThanOrEqual(1);
  });
});
