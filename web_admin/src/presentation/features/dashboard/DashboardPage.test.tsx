import { describe, expect, it } from 'vitest';
import { render, screen, waitFor } from '@testing-library/react';
import { MemoryRouter } from 'react-router-dom';
import { QueryClient, QueryClientProvider } from '@tanstack/react-query';
import { DiProvider, type Container } from '@/infrastructure/di/container';
import { useAuthStore } from '@/presentation/stores/authStore';
import { UserRole, PaymentMethod, SaleStatus, DiscountType } from '@/domain/enums';
import type { Sale, Product } from '@/domain/entities';
import { DashboardPage } from './DashboardPage';

const fakeSale = (o: Partial<Sale> = {}): Sale => ({
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
});

function harness(sales: Sale[] = [fakeSale()], role: UserRole = UserRole.admin) {
  useAuthStore.setState({
    user: { id: 'u1', email: 'a@b.co', displayName: 'Tester', role, isActive: true } as never,
  });
  const qc = new QueryClient({ defaultOptions: { queries: { retry: false } } });
  const saleRepo: Partial<Container['saleRepo']> = {
    watchToday: (cb: (sales: Sale[]) => void) => {
      cb(sales);
      return () => {};
    },
  };
  const productRepo: Partial<Container['productRepo']> = {
    watchAll: (cb: (products: Product[]) => void) => {
      cb([]);
      return () => {};
    },
  };
  return render(
    <DiProvider override={{ saleRepo: saleRepo as Container['saleRepo'], productRepo: productRepo as Container['productRepo'] }}>
      <QueryClientProvider client={qc}>
        <MemoryRouter initialEntries={['/']}>
          <DashboardPage />
        </MemoryRouter>
      </QueryClientProvider>
    </DiProvider>,
  );
}

describe('DashboardPage', () => {
  it('links "View all" on the Recent sales panel to the day sales page', async () => {
    harness();

    const link = await screen.findByRole('link', { name: /view all/i });
    expect(link).toHaveAttribute('href', '/sales/day');
  });

  it('renders all 5 summary cards without emphasized style', async () => {
    harness();

    await waitFor(() => {
      // Check that all 5 card titles are present
      expect(screen.getByText('Sales today')).toBeInTheDocument();
      expect(screen.getByText('Gross Sales')).toBeInTheDocument();
      expect(screen.getByText('Total COGS')).toBeInTheDocument();
      expect(screen.getByText('Gross profit')).toBeInTheDocument();
      expect(screen.getByText('Avg order')).toBeInTheDocument();

      // Verify that no card has the bg-light-text class (which indicates emphasized style)
      const titleElements = screen.getAllByText(/Sales today|Gross Sales|Total COGS|Gross profit|Avg order/);
      titleElements.forEach((titleEl) => {
        // Walk up to find the card div
        let current: HTMLElement | null = titleEl;
        while (current && current.tagName !== 'BODY') {
          if (current.className?.includes('bg-light-card')) {
            // Found the card - it should NOT have bg-light-text
            expect(current.className).not.toContain('bg-light-text');
            break;
          }
          current = current.parentElement;
        }
      });
    });
  });
});

describe('DashboardPage cost visibility', () => {
  it('hides Total COGS and Gross profit from a cashier — mobile parity', async () => {
    harness([fakeSale()], UserRole.cashier);

    expect(await screen.findByText('Sales today')).toBeInTheDocument();
    expect(screen.queryByText('Total COGS')).toBeNull();
    expect(screen.queryByText('Gross profit')).toBeNull();
  });
});

