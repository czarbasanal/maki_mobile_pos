import { beforeEach, describe, expect, it } from 'vitest';
import { useCartStore } from './cartStore';
import { DiscountType } from '@/domain/enums/DiscountType';
import type { Product } from '@/domain/entities';

const product = (over: Partial<Product> = {}): Product =>
  ({ id: 'p1', sku: 'A', name: 'A', price: 100, cost: 60, unit: 'pcs', quantity: 10, ...over } as Product);

describe('cartStore', () => {
  beforeEach(() => useCartStore.getState().clear());

  it('adds a product as a line and merges quantity on re-add', () => {
    useCartStore.getState().addLine(product());
    useCartStore.getState().addLine(product());
    const { lines } = useCartStore.getState();
    expect(lines).toHaveLength(1);
    expect(lines[0].quantity).toBe(2);
    expect(lines[0].unitPrice).toBe(100);
    expect(lines[0].unitCost).toBe(60);
  });

  it('resets line discounts when the discount type changes', () => {
    useCartStore.getState().addLine(product());
    useCartStore.getState().setLineDiscount('p1', 15);
    expect(useCartStore.getState().lines[0].discountValue).toBe(15);
    useCartStore.getState().setDiscountType(DiscountType.percentage);
    expect(useCartStore.getState().discountType).toBe(DiscountType.percentage);
    expect(useCartStore.getState().lines[0].discountValue).toBe(0);
  });

  it('clamps quantity to a positive integer and removes lines', () => {
    useCartStore.getState().addLine(product());
    useCartStore.getState().setQty('p1', 0);
    expect(useCartStore.getState().lines[0].quantity).toBe(1);
    useCartStore.getState().removeLine('p1');
    expect(useCartStore.getState().lines).toHaveLength(0);
  });
});
