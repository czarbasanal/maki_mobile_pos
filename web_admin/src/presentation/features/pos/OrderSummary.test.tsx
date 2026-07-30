import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';
import { render, screen } from '@testing-library/react';
import { OrderSummary } from './OrderSummary';
import { DiscountType } from '@/domain/enums/DiscountType';
import type { CartLine } from '@/domain/sales/cart';
import type { LaborLine } from '@/domain/entities/LaborLine';
import type { FeeLine } from '@/domain/entities/FeeLine';

const line: CartLine = {
  id: 'p1', productId: 'p1', sku: 'OIL-AX7', name: 'Shell AX7 Oil',
  unitPrice: 320, unitCost: 210, quantity: 2, discountValue: 0, unit: 'pcs',
  optionId: null, optionLabel: null, optionPieces: null, optionPrice: null,
};
const labor: LaborLine = { id: 'l1', description: 'Change oil', fee: 150 };
const fee: FeeLine = { id: 'f1', name: 'Convenience fee', amount: 50 };

// Two option lines of the SAME product (p1), different optionId/optionPrice —
// exactly the shape the cart store can now hold (By 6 + By 3 of one product).
const by6Line: CartLine = {
  id: 'p1::o1', productId: 'p1', sku: 'ABC-1', name: 'Pulley Ball',
  unitPrice: 100, unitCost: 60, quantity: 6, discountValue: 0, unit: 'pcs',
  optionId: 'o1', optionLabel: 'By 6', optionPieces: 6, optionPrice: 600,
};
const by3Line: CartLine = {
  id: 'p1::o2', productId: 'p1', sku: 'ABC-1', name: 'Pulley Ball',
  unitPrice: 110, unitCost: 60, quantity: 3, discountValue: 0, unit: 'pcs',
  optionId: 'o2', optionLabel: 'By 3', optionPieces: 3, optionPrice: 330,
};

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

  describe('two option lines of one product', () => {
    let errorSpy: ReturnType<typeof vi.spyOn>;
    beforeEach(() => {
      // key={l.productId} would give both <li> the same React key ('p1');
      // React logs this as a console.error, which is the reliable signal a
      // single-mount content check can't give us (both rows' text renders
      // correctly either way — the collision only bites reconciliation).
      errorSpy = vi.spyOn(console, 'error').mockImplementation(() => {});
    });
    afterEach(() => errorSpy.mockRestore());

    it('renders both rows distinctly with no duplicate-key warning', () => {
      render(
        <OrderSummary lines={[by6Line, by3Line]} discountType={DiscountType.amount} laborLines={[]} />,
      );
      // Both rows present, each with its own quantity × unit price.
      expect(screen.getByText('6 × ₱100.00')).toBeInTheDocument();
      expect(screen.getByText('3 × ₱110.00')).toBeInTheDocument();
      // React's own duplicate-key diagnostic is the actual discriminator:
      // it fires only when both <li> share one key (l.productId), not when
      // each has its own (l.id).
      const dupKeyWarning = errorSpy.mock.calls.some((args) =>
        String(args[0]).includes('same key'),
      );
      expect(dupKeyWarning).toBe(false);
    });
  });

  describe('selling option (found beyond the brief — the pre-checkout order review is the same "cart tile" surface)', () => {
    it('shows the option label beside the name for a single set', () => {
      // by3Line: quantity 3, optionPieces 3 — exactly one set.
      render(<OrderSummary lines={[by3Line]} discountType={DiscountType.amount} laborLines={[]} />);
      expect(screen.getByText(/By 3/)).toBeInTheDocument();
      expect(screen.queryByText(/× 2/)).not.toBeInTheDocument();
    });

    it('shows the set count and total pieces for more than one set', () => {
      const twoSets: CartLine = { ...by3Line, quantity: 6 };
      render(<OrderSummary lines={[twoSets]} discountType={DiscountType.amount} laborLines={[]} />);
      expect(screen.getByText(/By 3 × 2/)).toBeInTheDocument();
      expect(screen.getByText(/6 pcs/)).toBeInTheDocument();
    });

    it('a plain line renders unchanged', () => {
      render(<OrderSummary lines={[line]} discountType={DiscountType.amount} laborLines={[]} />);
      expect(screen.queryByText(/By /)).not.toBeInTheDocument();
    });
  });
});
