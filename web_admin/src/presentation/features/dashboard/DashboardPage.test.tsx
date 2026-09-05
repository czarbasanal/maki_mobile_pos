import { describe, expect, it, vi } from 'vitest';
import { act, fireEvent, render, screen, waitFor, within } from '@testing-library/react';
import { MemoryRouter } from 'react-router-dom';
import { QueryClient, QueryClientProvider } from '@tanstack/react-query';
import { DiProvider, type Container } from '@/infrastructure/di/container';
import { useAuthStore } from '@/presentation/stores/authStore';
import { UserRole, PaymentMethod, SaleStatus, DiscountType } from '@/domain/enums';
import type { Sale, Product, VoidRequest } from '@/domain/entities';
import { DashboardPage } from './DashboardPage';

function fakeSale(o: Partial<Sale> = {}): Sale {
  return {
    id: 's1',
    saleNumber: 'SN-001',
    createdAt: new Date('2026-07-27T10:00:00'),
    updatedAt: null,
    cashierId: 'u1',
    cashierName: 'Cashier A',
    paymentMethod: PaymentMethod.cash,
    discountType: DiscountType.amount,
    items: [
      {
        id: 'si1',
        productId: 'p1',
        sku: 'SKU-001',
        name: 'Product 1',
        quantity: 1,
        unitPrice: 100,
        unitCost: 50,
        discountValue: 0,
        unit: 'pcs',
        optionId: null,
        optionLabel: null,
        optionPieces: null,
        optionPrice: null,
      },
    ],
    tenders: { [PaymentMethod.cash]: 100 },
    laborLines: [],
    feeLines: [],
    amountReceived: 100,
    changeGiven: 0,
    status: SaleStatus.completed,
    jobOrderId: null,
    notes: null,
    mechanicId: null,
    mechanicName: null,
    motorcycleModel: null,
    voidedAt: null,
    voidedBy: null,
    voidedByName: null,
    voidReason: null,
    ...o,
  };
}

function fakeProduct(o: Partial<Product> = {}): Product {
  return {
    id: 'p1',
    sku: 'S',
    name: 'N',
    costCode: '',
    cost: 0,
    price: 0,
    quantity: 10,
    reorderLevel: 2,
    unit: 'pcs',
    supplierId: null,
    supplierName: null,
    isActive: true,
    createdAt: new Date(),
    updatedAt: null,
    createdBy: null,
    updatedBy: null,
    createdByName: null,
    updatedByName: null,
    searchKeywords: [],
    baseSku: null,
    variationNumber: null,
    barcodes: [],
    sellingOptions: [],
    category: null,
    imageUrl: null,
    notes: null,
    tagIds: [],
    ...o,
  };
}

function fakeVoidRequest(o: Partial<VoidRequest> = {}): VoidRequest {
  return {
    id: 'v1',
    saleId: 's1',
    saleNumber: 'SN-001',
    saleGrandTotal: 100,
    requestedBy: 'u2',
    requestedByName: 'Cashier B',
    requestedByRole: 'cashier',
    reason: 'Wrong item',
    status: 'pending',
    read: false,
    createdAt: new Date('2026-07-27T10:00:00'),
    resolvedBy: null,
    resolvedByName: null,
    resolvedAt: null,
    rejectionReason: null,
    itemsSummary: null,
    ...o,
  };
}

function harness({
  sales = [fakeSale()],
  yesterdaySales = [],
  products = [],
  pendingVoids = [],
  role = UserRole.admin,
}: {
  sales?: Sale[];
  yesterdaySales?: Sale[];
  products?: Product[];
  pendingVoids?: VoidRequest[];
  role?: UserRole;
} = {}) {
  useAuthStore.setState({
    user: { id: 'u1', email: 'a@b.co', displayName: 'Tester', role, isActive: true } as never,
  });
  const qc = new QueryClient({ defaultOptions: { queries: { retry: false } } });
  const saleRepo: Partial<Container['saleRepo']> = {
    watchToday: (cb: (sales: Sale[]) => void) => {
      cb(sales);
      return () => {};
    },
    list: async () => yesterdaySales,
  };
  const productRepo: Partial<Container['productRepo']> = {
    watchAll: (cb: (products: Product[]) => void) => {
      cb(products);
      return () => {};
    },
  };
  const voidRequestRepo: Partial<Container['voidRequestRepo']> = {
    watchPending: (cb: (r: VoidRequest[]) => void) => {
      cb(pendingVoids);
      return () => {};
    },
  };
  return render(
    <DiProvider
      override={{
        saleRepo: saleRepo as Container['saleRepo'],
        productRepo: productRepo as Container['productRepo'],
        voidRequestRepo: voidRequestRepo as Container['voidRequestRepo'],
      }}
    >
      <QueryClientProvider client={qc}>
        <MemoryRouter initialEntries={['/']}>
          <DashboardPage />
        </MemoryRouter>
      </QueryClientProvider>
    </DiProvider>,
  );
}

describe('DashboardPage — KPIs', () => {
  it('renders all five KPI labels for an admin', async () => {
    harness();

    await waitFor(() => {
      expect(screen.getByText('Sales today')).toBeInTheDocument();
      expect(screen.getByText('Gross Sales')).toBeInTheDocument();
      expect(screen.getByText('Total COGS')).toBeInTheDocument();
      expect(screen.getByText('Gross profit')).toBeInTheDocument();
      expect(screen.getByText('Avg order')).toBeInTheDocument();
    });
  });

  it('hides COGS and Gross profit from a cashier', async () => {
    harness({ role: UserRole.cashier });

    expect(await screen.findByText('Sales today')).toBeInTheDocument();
    expect(screen.queryByText('Total COGS')).toBeNull();
    expect(screen.queryByText('Gross profit')).toBeNull();
  });

  it('renders a delta chip vs yesterday on Sales today', async () => {
    const today = Array.from({ length: 27 }, (_, i) => fakeSale({ id: `t${i}`, saleNumber: `SN-${i}` }));
    const yesterday = Array.from({ length: 25 }, (_, i) => fakeSale({ id: `y${i}`, saleNumber: `SY-${i}` }));
    harness({ sales: today, yesterdaySales: yesterday });

    const label = await screen.findByText('Sales today');
    const card = label.closest('section');
    expect(card).not.toBeNull();
    expect(await within(card!).findByText('+8.0%')).toBeInTheDocument();
  });
});

describe('DashboardPage — recent sales', () => {
  it('lists recent sales with sale number, tender, status and total', async () => {
    harness({ sales: [fakeSale({ id: 's1', saleNumber: 'SN-001' })] });

    const saleNo = await screen.findByText('SN-001');
    const row = saleNo.closest('tr');
    expect(row).not.toBeNull();
    expect(within(row!).getByText('Cash')).toBeInTheDocument();
    expect(within(row!).getByText('Completed')).toBeInTheDocument();
    expect(within(row!).getByText('₱100.00')).toBeInTheDocument();
  });

  it('filters the recent list by sale number via search', async () => {
    harness({
      sales: [
        fakeSale({ id: 's1', saleNumber: 'SN-001' }),
        fakeSale({ id: 's2', saleNumber: 'SN-002' }),
      ],
    });

    await screen.findByText('SN-002');

    vi.useFakeTimers();
    try {
      fireEvent.change(screen.getByPlaceholderText('Search sale no.'), { target: { value: 'SN-001' } });
      act(() => vi.advanceTimersByTime(250));

      expect(screen.getByText('SN-001')).toBeInTheDocument();
      expect(screen.queryByText('SN-002')).toBeNull();
    } finally {
      vi.useRealTimers();
    }
  });

  it('renders the empty chart state when there are no sales', async () => {
    harness({ sales: [] });

    expect(await screen.findAllByText('No sales yet today')).not.toHaveLength(0);
  });
});

describe('DashboardPage — needs attention', () => {
  async function needsAttentionCard() {
    const title = await screen.findByText('Needs attention');
    const card = title.closest('section');
    expect(card).not.toBeNull();
    return card!;
  }

  it('hides needs-attention rows whose count is zero', async () => {
    harness({ products: [fakeProduct({ quantity: 10, reorderLevel: 2 })] });

    const card = await needsAttentionCard();
    expect(within(card).queryByText('Out of stock')).toBeNull();
  });

  it('shows an out-of-stock row linking to inventory when count > 0', async () => {
    harness({ products: [fakeProduct({ id: 'p-out', quantity: 0 })] });

    const card = await needsAttentionCard();
    const label = await within(card).findByText('Out of stock');
    const row = label.closest('li');
    expect(row).not.toBeNull();
    const link = row!.querySelector('a');
    expect(link).toHaveAttribute('href', '/inventory');
  });

  it('shows the all-clear empty state for an admin with zero voids and zero stock issues', async () => {
    harness({ products: [fakeProduct({ quantity: 10, reorderLevel: 2 })], pendingVoids: [] });

    const card = await needsAttentionCard();
    expect(await within(card).findByText('All clear — nothing needs attention')).toBeInTheDocument();
    expect(within(card).queryByText('Out of stock')).toBeNull();
    expect(within(card).queryByText('Void requests')).toBeNull();
  });

  it('shows a void-requests row linking to the approval queue when voids are pending', async () => {
    harness({ pendingVoids: [fakeVoidRequest({ id: 'v1' }), fakeVoidRequest({ id: 'v2' })] });

    const card = await needsAttentionCard();
    const label = await within(card).findByText('Void requests');
    expect(within(card).getByText('2 pending manager approval')).toBeInTheDocument();
    const row = label.closest('li');
    expect(row).not.toBeNull();
    const link = row!.querySelector('a');
    expect(link).toHaveAttribute('href', '/void-requests');
  });

  it('hides the void-requests row from a cashier even with voids pending', async () => {
    harness({ role: UserRole.cashier, pendingVoids: [fakeVoidRequest()] });

    const card = await needsAttentionCard();
    expect(within(card).queryByText('Void requests')).toBeNull();
  });
});
