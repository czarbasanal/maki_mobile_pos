import { describe, expect, it } from 'vitest';
import { render, screen } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { DiProvider, type Container } from '@/infrastructure/di/container';
import { CartBuilder } from './CartBuilder';
import { createCartStore } from '@/presentation/stores/cartStore';
import type { Product, Mechanic } from '@/domain/entities';
import type { SellingOption } from '@/domain/entities/SellingOption';

const by6: SellingOption = { id: 'o1', label: 'By 6', pieces: 6, price: 600 };
const by3: SellingOption = { id: 'o2', label: 'By 3', pieces: 3, price: 330 };

const plainProduct = (o: Partial<Product> = {}): Product =>
  ({ id: 'p1', sku: 'PLUG-1', name: 'Spark Plug', price: 100, cost: 60, unit: 'pcs', quantity: 9, isActive: true, sellingOptions: [], ...o } as Product);

const optionProduct = (o: Partial<Product> = {}): Product =>
  ({
    id: 'p2', sku: 'ABC-1', name: 'Pulley Ball', price: 120, cost: 60, unit: 'pcs',
    quantity: 12, isActive: true, sellingOptions: [by6, by3], ...o,
  } as Product);

function harness(products: Product[]) {
  const productRepo: Partial<Container['productRepo']> = {
    watchAll: (cb: (p: Product[]) => void) => {
      cb(products);
      return () => {};
    },
  };
  const mechanicRepo: Partial<Container['mechanicRepo']> = {
    watchAll: (cb: (mechanics: Mechanic[]) => void) => {
      cb([]);
      return () => {};
    },
  };
  const store = createCartStore();
  const utils = render(
    <DiProvider
      override={{
        productRepo: productRepo as Container['productRepo'],
        mechanicRepo: mechanicRepo as Container['mechanicRepo'],
      }}
    >
      <CartBuilder store={store} />
    </DiProvider>,
  );
  return { ...utils, store };
}

async function search(text: string) {
  const input = screen.getByPlaceholderText(/search products/i);
  await userEvent.type(input, text);
}

describe('CartBuilder — routing product picks through the selling-option gate', () => {
  it('adds a plain (no-option) product straight to the cart — no picker shown', async () => {
    const { store } = harness([plainProduct()]);
    await search('plug');
    await userEvent.click(await screen.findByRole('button', { name: /spark plug/i }));

    expect(store.getState().lines).toHaveLength(1);
    expect(store.getState().lines[0].productId).toBe('p1');
    expect(store.getState().lines[0].optionId).toBeNull();
    // The picker never appeared for a product with no selling options.
    expect(screen.queryByRole('button', { name: /^cancel$/i })).not.toBeInTheDocument();
  });

  it('opens the option picker instead of adding directly when the product has options', async () => {
    const { store } = harness([optionProduct()]);
    await search('pulley');
    await userEvent.click(await screen.findByRole('button', { name: /pulley ball/i }));

    // Nothing lands on the cart yet — the picker gates the add.
    expect(store.getState().lines).toHaveLength(0);
    // The picker is open (its Cancel button + both option rows are visible).
    expect(screen.getByRole('button', { name: /^cancel$/i })).toBeInTheDocument();
    expect(screen.getByText('By 6')).toBeInTheDocument();
    expect(screen.getByText('By 3')).toBeInTheDocument();
  });

  it('picking an option adds exactly that option via addLineWithOption, not addLine', async () => {
    const { store } = harness([optionProduct()]);
    await search('pulley');
    await userEvent.click(await screen.findByRole('button', { name: /pulley ball/i }));
    await userEvent.click(screen.getByText('By 3'));

    const { lines } = store.getState();
    expect(lines).toHaveLength(1);
    expect(lines[0].optionId).toBe('o2');
    expect(lines[0].optionLabel).toBe('By 3');
    expect(lines[0].quantity).toBe(3); // pieces, not 1 — proves addLineWithOption ran, not addLine
    expect(lines[0].unitPrice).toBe(110); // 330 / 3 per-piece
    // Picking closes the picker.
    expect(screen.queryByRole('button', { name: /^cancel$/i })).not.toBeInTheDocument();
  });

  it('cancelling the picker adds nothing to the cart', async () => {
    const { store } = harness([optionProduct()]);
    await search('pulley');
    await userEvent.click(await screen.findByRole('button', { name: /pulley ball/i }));
    await userEvent.click(screen.getByRole('button', { name: /^cancel$/i }));

    expect(store.getState().lines).toHaveLength(0);
    expect(screen.queryByRole('button', { name: /^cancel$/i })).not.toBeInTheDocument();
  });
});
