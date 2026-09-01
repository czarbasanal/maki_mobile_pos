import { describe, expect, it } from 'vitest';
import { act, render, screen, within } from '@testing-library/react';
import { QueryClient, QueryClientProvider } from '@tanstack/react-query';
import userEvent from '@testing-library/user-event';
import { DiProvider, type Container } from '@/infrastructure/di/container';
import { CartBuilder } from './CartBuilder';
import { Toaster } from '@/presentation/components/ui/Toaster';
import { createCartStore } from '@/presentation/stores/cartStore';
import type { Product, Mechanic } from '@/domain/entities';
import type { SellingOption } from '@/domain/entities/SellingOption';

const by6: SellingOption = { id: 'o1', label: 'By 6', pieces: 6, price: 600 };
const by3: SellingOption = { id: 'o2', label: 'By 3', pieces: 3, price: 330 };

const plainProduct = (o: Partial<Product> = {}): Product =>
  ({ id: 'p1', sku: 'PLUG-1', name: 'Spark Plug', price: 100, cost: 60, unit: 'pcs', quantity: 9, isActive: true, sellingOptions: [], barcodes: [], category: null, ...o } as Product);

const optionProduct = (o: Partial<Product> = {}): Product =>
  ({
    id: 'p2', sku: 'ABC-1', name: 'Pulley Ball', price: 120, cost: 60, unit: 'pcs',
    quantity: 12, isActive: true, sellingOptions: [by6, by3], barcodes: [], category: null, ...o,
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
  const motorcycleModelRepo: Partial<Container['motorcycleModelRepo']> = {
    watchActive: (cb: (models: never[]) => void) => {
      cb([]);
      return () => {};
    },
  };
  const store = createCartStore();
  const qc = new QueryClient({ defaultOptions: { mutations: { retry: false } } });
  const utils = render(
    <DiProvider
      override={{
        productRepo: productRepo as Container['productRepo'],
        mechanicRepo: mechanicRepo as Container['mechanicRepo'],
        motorcycleModelRepo: motorcycleModelRepo as Container['motorcycleModelRepo'],
      }}
    >
      <QueryClientProvider client={qc}>
        <CartBuilder store={store} searchDebounce={0} />
        <Toaster />
      </QueryClientProvider>
    </DiProvider>,
  );
  return { ...utils, store };
}

async function search(text: string) {
  const input = screen.getByPlaceholderText(/search part name/i);
  await userEvent.type(input, text);
}

describe('CartBuilder — routing product picks through the selling-option gate', () => {
  it('adds a plain (no-option) product straight to the cart — no picker shown', async () => {
    const { store } = harness([plainProduct()]);
    await search('plug');
    await userEvent.click(await screen.findByText('Spark Plug'));

    expect(store.getState().lines).toHaveLength(1);
    expect(store.getState().lines[0].productId).toBe('p1');
    expect(store.getState().lines[0].optionId).toBeNull();
    // The picker never appeared for a product with no selling options.
    expect(screen.queryByRole('button', { name: /^cancel$/i })).not.toBeInTheDocument();
  });

  it('opens the option picker instead of adding directly when the product has options', async () => {
    const { store } = harness([optionProduct()]);
    await search('pulley');
    await userEvent.click(await screen.findByText('Pulley Ball'));

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
    await userEvent.click(await screen.findByText('Pulley Ball'));
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
    await userEvent.click(await screen.findByText('Pulley Ball'));
    await userEvent.click(screen.getByRole('button', { name: /^cancel$/i }));

    expect(store.getState().lines).toHaveLength(0);
    expect(screen.queryByRole('button', { name: /^cancel$/i })).not.toBeInTheDocument();
  });
});

describe('CartBuilder — cart row shows the selling-option label (10th render site the migration missed)', () => {
  it("shows the option label on an option line's cart row, not just the checkout screen", async () => {
    const { store } = harness([optionProduct()]);
    await search('pulley');
    await userEvent.click(await screen.findByText('Pulley Ball'));
    await userEvent.click(screen.getByText('By 3'));
    // Clear the search box so the results panel — which independently shows
    // the bare product name — doesn't make the cart row's text ambiguous.
    await userEvent.clear(screen.getByPlaceholderText(/search part name/i));

    expect(store.getState().lines).toHaveLength(1);
    // A wrong implementation (bare l.name) would show "Pulley Ball" with no
    // way to tell this line apart from a By 6 line of the same product.
    // Scope to the cart list — the added-to-cart toast echoes the same label.
    expect(within(screen.getByRole('list')).getByText('Pulley Ball · By 3')).toBeInTheDocument();
  });

  it('shows the set-count caption for more than one set, mirroring OrderSummary', async () => {
    const { store } = harness([optionProduct()]);
    await search('pulley');
    await userEvent.click(await screen.findByText('Pulley Ball'));
    await userEvent.click(screen.getByText('By 3'));
    await userEvent.clear(screen.getByPlaceholderText(/search part name/i));
    // Second set: bumps the line to 2 sets (6 pieces) — the caption should
    // then read "By 3 × 2 (6 pcs)", same rule as OrderSummary/Receipt.
    // A direct store mutation (not routed through userEvent) needs its own
    // act() so React flushes the resulting re-render before we assert.
    act(() => {
      store.getState().addLineWithOption(optionProduct(), by3);
    });

    expect(screen.getByText(/By 3 × 2/)).toBeInTheDocument();
    expect(screen.getByText(/6 pcs/)).toBeInTheDocument();
  });

  it("a plain line's cart row is unchanged — bare name, no option caption", async () => {
    harness([plainProduct()]);
    await search('plug');
    await userEvent.click(await screen.findByText('Spark Plug'));
    await userEvent.clear(screen.getByPlaceholderText(/search part name/i));

    expect(within(screen.getByRole('list')).getByText('Spark Plug')).toBeInTheDocument();
  });
});

describe('CartBuilder — qty box label disambiguates sets from pieces', () => {
  // Found via review of an earlier task: the qty input already binds to
  // SETS for an option line (saleItemOptionSets(l) ?? l.quantity), but its
  // label still read the same bare "Qty" either way — a cashier can't tell
  // whether they're typing sets or pieces in a money-entry field.
  it('labels the box "Qty" for a plain line', async () => {
    harness([plainProduct()]);
    await search('plug');
    await userEvent.click(await screen.findByText('Spark Plug'));

    expect(screen.getByLabelText('Quantity of Spark Plug')).toBeInTheDocument();
    expect(screen.queryByLabelText(/^Sets of/)).not.toBeInTheDocument();
  });

  it('labels the box "Sets" for an option line', async () => {
    harness([optionProduct()]);
    await search('pulley');
    await userEvent.click(await screen.findByText('Pulley Ball'));
    await userEvent.click(screen.getByText('By 3'));

    expect(screen.getByLabelText('Sets of Pulley Ball')).toBeInTheDocument();
    expect(screen.queryByLabelText(/^Quantity of/)).not.toBeInTheDocument();
  });
});

describe('CartBuilder — wedge-scanner Enter (B4)', () => {
  it('Enter with a known barcode adds the product and clears the box', async () => {
    const { store } = harness([
      plainProduct({ id: 'p9', name: 'Chain Lube', sku: '00070200', barcodes: ['4801234567890'] }),
    ]);
    const box = screen.getByPlaceholderText(/search part name/i);
    await userEvent.type(box, '4801234567890{Enter}');
    expect(store.getState().lines).toHaveLength(1);
    expect(store.getState().lines[0].productId).toBe('p9');
    expect(box).toHaveValue('');
  });

  it('Enter with a variation SKU (base-N, the only dashed shape) resolves the product', async () => {
    const { store } = harness([
      plainProduct({ id: 'p9', name: 'Chain Lube v2', sku: '00070200-2', barcodes: [] }),
    ]);
    await userEvent.type(screen.getByPlaceholderText(/search part name/i), '00070200-2{Enter}');
    expect(store.getState().lines[0]?.productId).toBe('p9');
  });

  it('Enter with an unknown code warns and keeps the text', async () => {
    const { store } = harness([plainProduct({ id: 'p9', barcodes: [] })]);
    const box = screen.getByPlaceholderText(/search part name/i);
    await userEvent.type(box, '999888{Enter}');
    const status = await screen.findByRole('status');
    expect(status).toHaveTextContent('Product not found');
    expect(status).toHaveTextContent('999888');
    expect(store.getState().lines).toHaveLength(0);
    expect(box).toHaveValue('999888');
  });
});
