import { describe, expect, it } from 'vitest';
import { render, screen } from '@testing-library/react';
import { Receipt } from './Receipt';
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

describe('Receipt', () => {
  it('does not show a Shop fees line when there are no fee lines', () => {
    render(<Receipt sale={sale()} />);
    expect(screen.queryByText('Shop fees')).not.toBeInTheDocument();
  });

  it('shows each fee line and a Shop fees total when fees are present', () => {
    render(
      <Receipt
        sale={sale({ feeLines: [{ id: 'f1', name: 'Convenience fee', amount: 50, description: null }] })}
      />,
    );
    expect(screen.getByText(/Convenience fee/)).toBeInTheDocument();
    expect(screen.getByText('Shop fees')).toBeInTheDocument();
    // TOTAL = 200 (parts) + 450 (labor) + 50 (fees) = 700.00 (also echoed by the
    // single-method cash tender line, since tenders defaults to the grand total).
    expect(screen.getAllByText(formatMoney(700)).length).toBeGreaterThanOrEqual(1);
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

    it('shows the option label beside the name for a single set', () => {
      render(<Receipt sale={sale({ items: [optionItem(3)] })} />);
      expect(screen.getByText(/By 3/)).toBeInTheDocument();
      expect(screen.queryByText(/× 2/)).not.toBeInTheDocument();
    });

    it('shows the set count and total pieces for more than one set', () => {
      render(<Receipt sale={sale({ items: [optionItem(6)] })} />);
      expect(screen.getByText(/By 3 × 2/)).toBeInTheDocument();
      expect(screen.getByText(/6 pcs/)).toBeInTheDocument();
    });

    it('a line with no option renders unchanged', () => {
      render(<Receipt sale={sale()} />);
      expect(screen.queryByText(/By /)).not.toBeInTheDocument();
    });
  });
});

describe('Receipt — voided sale', () => {
  const voided = () =>
    sale({
      status: SaleStatus.voided,
      voidedAt: new Date('2026-05-14'),
      voidReason: 'Wrong item scanned',
    });

  it('strikes the sale number so a printed copy cannot be mistaken for a live one', () => {
    render(<Receipt sale={voided()} />);
    expect(screen.getByText('OR-0001')).toHaveClass('line-through');
  });

  it('keeps the VOIDED banner and names the reason', () => {
    render(<Receipt sale={voided()} />);
    expect(screen.getByText(/\*\*\* VOIDED \*\*\*/)).toBeInTheDocument();
    expect(screen.getByText(/Wrong item scanned/)).toBeInTheDocument();
  });

  it('leaves a completed receipt unstruck', () => {
    render(<Receipt sale={sale()} />);
    expect(screen.getByText('OR-0001')).not.toHaveClass('line-through');
  });
});
