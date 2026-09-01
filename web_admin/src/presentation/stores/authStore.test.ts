import { beforeEach, describe, expect, it } from 'vitest';
import { useAuthStore } from './authStore';
import { useCartStore } from './cartStore';
import { useJobOrderEditStore } from './jobOrderEditStore';
import type { Product, User } from '@/domain/entities';

const user = (id: string): User =>
  ({ id, email: `${id}@maki.ph`, displayName: id, role: 'cashier', isActive: true } as User);

const product = (): Product =>
  ({ id: 'p1', sku: 'A', name: 'A', price: 100, cost: 60, unit: 'pcs', quantity: 5 } as Product);

beforeEach(() => {
  useAuthStore.setState({ status: 'signedOut', user: null });
  useCartStore.getState().clear();
  useJobOrderEditStore.getState().clear();
});

describe('authStore cart hygiene', () => {
  it('sign-out (reset) empties both cart stores', () => {
    useAuthStore.getState().setUser(user('cashier-1'));
    useCartStore.getState().addLine(product());
    useJobOrderEditStore.getState().addLine(product());

    useAuthStore.getState().reset();

    expect(useCartStore.getState().lines).toHaveLength(0);
    expect(useJobOrderEditStore.getState().lines).toHaveLength(0);
  });

  it('a user switch empties the carts — the next cashier never inherits a ticket', () => {
    useAuthStore.getState().setUser(user('cashier-1'));
    useCartStore.getState().addLine(product());

    useAuthStore.getState().setUser(user('cashier-2'));

    expect(useCartStore.getState().lines).toHaveLength(0);
  });

  it('re-setting the SAME user keeps the cart (auth refresh must not eat a ticket)', () => {
    useAuthStore.getState().setUser(user('cashier-1'));
    useCartStore.getState().addLine(product());

    useAuthStore.getState().setUser(user('cashier-1'));

    expect(useCartStore.getState().lines).toHaveLength(1);
  });
});
