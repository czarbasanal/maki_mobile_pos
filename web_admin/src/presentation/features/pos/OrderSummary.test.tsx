import { describe, expect, it } from 'vitest';
import { render, screen } from '@testing-library/react';
import { OrderSummary } from './OrderSummary';
import { DiscountType } from '@/domain/enums/DiscountType';
import type { CartLine } from '@/domain/sales/cart';
import type { LaborLine } from '@/domain/entities/LaborLine';
import type { FeeLine } from '@/domain/entities/FeeLine';

const line: CartLine = {
  id: 'p1', productId: 'p1', sku: 'OIL-AX7', name: 'Shell AX7 Oil',
  unitPrice: 320, unitCost: 210, quantity: 2, discountValue: 0, unit: 'pcs',
};
const labor: LaborLine = { id: 'l1', description: 'Change oil', fee: 150 };
const fee: FeeLine = { id: 'f1', name: 'Convenience fee', amount: 50 };

describe('OrderSummary', () => {
  it('lists items with net line totals and a grand total including labor', () => {
    render(<OrderSummary lines={[line]} discountType={DiscountType.amount} laborLines={[labor]} />);
    expect(screen.getByText('Shell AX7 Oil')).toBeInTheDocument();
    expect(screen.getByText(/Change oil/)).toBeInTheDocument();
    // 2×320 = 640 items + 150 labor = 790 total
    expect(screen.getByText('₱790.00')).toBeInTheDocument();
  });

  it('renders a labor row only when labor exists', () => {
    render(<OrderSummary lines={[line]} discountType={DiscountType.amount} laborLines={[]} />);
    expect(screen.queryByText('Labor')).not.toBeInTheDocument();
  });

  it('lists carried fee lines and folds them into the grand total (mirrors labor)', () => {
    render(
      <OrderSummary
        lines={[line]}
        discountType={DiscountType.amount}
        laborLines={[labor]}
        feeLines={[fee]}
      />,
    );
    expect(screen.getByText(/Convenience fee/)).toBeInTheDocument();
    expect(screen.getByText('Shop fees')).toBeInTheDocument();
    // 640 items + 150 labor + 50 fees = 840 total
    expect(screen.getByText('₱840.00')).toBeInTheDocument();
  });

  it('renders no fee row when feeLines is empty/omitted', () => {
    render(<OrderSummary lines={[line]} discountType={DiscountType.amount} laborLines={[]} />);
    expect(screen.queryByText('Shop fees')).not.toBeInTheDocument();
  });
});
