import { describe, expect, it } from 'vitest';
import { render, screen } from '@testing-library/react';
import { OrderSummary } from './OrderSummary';
import { DiscountType } from '@/domain/enums/DiscountType';
import type { CartLine } from '@/domain/sales/cart';
import type { LaborLine } from '@/domain/entities/LaborLine';

const line: CartLine = {
  id: 'p1', productId: 'p1', sku: 'OIL-AX7', name: 'Shell AX7 Oil',
  unitPrice: 320, unitCost: 210, quantity: 2, discountValue: 0, unit: 'pcs',
};
const labor: LaborLine = { id: 'l1', description: 'Change oil', fee: 150 };

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
});
