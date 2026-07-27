import { describe, expect, it } from 'vitest';
import { render, screen } from '@testing-library/react';
import { MemoryRouter } from 'react-router-dom';
import type { Sale } from '@/domain/entities';
import { PaymentMethod, SaleStatus, DiscountType } from '@/domain/enums';
import { RecentSales } from './RecentSales';

const sale = (o: Partial<Sale> = {}): Sale => ({
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
    },
  ],
  tenders: { [PaymentMethod.cash]: 100 },
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
});

function harness(sales: Sale[] = [sale()]) {
  return render(
    <MemoryRouter>
      <RecentSales sales={sales} limit={8} />
    </MemoryRouter>,
  );
}

describe('RecentSales', () => {
  it('renders a clickable link to the sale detail page', () => {
    harness([sale({ id: 's123', saleNumber: 'SN-123' })]);

    const link = screen.getByRole('link');
    expect(link).toHaveAttribute('href', '/reports/sale/s123');
  });

  it('shows sale number in the link', () => {
    harness([sale({ id: 's456', saleNumber: 'SN-456' })]);

    expect(screen.getByText('SN-456')).toBeInTheDocument();
  });

  it('respects the limit prop', () => {
    const sales = [
      sale({ id: 's1', saleNumber: 'SN-1' }),
      sale({ id: 's2', saleNumber: 'SN-2' }),
      sale({ id: 's3', saleNumber: 'SN-3' }),
    ];
    harness(sales);

    const links = screen.getAllByRole('link');
    expect(links).toHaveLength(3);
  });
});
