import { describe, expect, it } from 'vitest';
import { render, screen } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { DiProvider, type Container } from '@/infrastructure/di/container';
import { createCartStore } from '@/presentation/stores/cartStore';
import { FeeSection } from './FeeSection';
import type { ShopFee } from '@/domain/entities';

const fees: ShopFee[] = [
  { id: 's1', name: 'Tire changer', defaultAmount: 50, isActive: true },
  { id: 's2', name: 'Charge Item', defaultAmount: null, isActive: true },
];

function harness(store = createCartStore(), catalog: ShopFee[] = fees) {
  const shopFeeRepo = {
    watchActive: (cb: (v: ShopFee[]) => void) => {
      cb(catalog);
      return () => {};
    },
  } as Container['shopFeeRepo'];
  render(
    <DiProvider override={{ shopFeeRepo }}>
      <FeeSection store={store} />
    </DiProvider>,
  );
  return store;
}

describe('FeeSection', () => {
  it('adds a catalog fee with its default amount prefilled', async () => {
    const store = harness();
    await userEvent.click(screen.getByRole('button', { name: /add fee/i }));
    await userEvent.click(screen.getByRole('button', { name: /tire changer/i }));
    expect(screen.getByLabelText(/amount/i)).toHaveValue('50.00');
    await userEvent.click(screen.getByRole('button', { name: /^add$/i }));
    expect(store.getState().feeLines).toHaveLength(1);
    expect(store.getState().feeLines[0]).toMatchObject({
      name: 'Tire changer',
      amount: 50,
      description: null,
    });
  });

  it('requires a description for Charge Item', async () => {
    const store = harness();
    await userEvent.click(screen.getByRole('button', { name: /add fee/i }));
    await userEvent.click(screen.getByRole('button', { name: /charge item/i }));
    await userEvent.type(screen.getByLabelText(/amount/i), '120');
    expect(screen.getByRole('button', { name: /^add$/i })).toBeDisabled();
    await userEvent.type(screen.getByLabelText(/description/i), 'Outside part');
    await userEvent.click(screen.getByRole('button', { name: /^add$/i }));
    expect(store.getState().feeLines[0]).toMatchObject({
      name: 'Charge Item',
      amount: 120,
      description: 'Outside part',
    });
  });

  it('refuses a zero amount', async () => {
    harness();
    await userEvent.click(screen.getByRole('button', { name: /add fee/i }));
    await userEvent.click(screen.getByRole('button', { name: /tire changer/i }));
    await userEvent.clear(screen.getByLabelText(/amount/i));
    expect(screen.getByRole('button', { name: /^add$/i })).toBeDisabled();
  });

  it('shows the empty-catalog message', async () => {
    harness(createCartStore(), []);
    await userEvent.click(screen.getByRole('button', { name: /add fee/i }));
    expect(screen.getByText(/no shop fees configured/i)).toBeInTheDocument();
  });

  it('renders lines with display labels; edit amount and remove work', async () => {
    const store = createCartStore();
    store.getState().addFeeLine({ id: 'f1', name: 'Charge Item', amount: 120, description: 'Outside part' });
    harness(store);
    expect(screen.getByText('Charge Item — Outside part')).toBeInTheDocument();

    const amountInput = screen.getByDisplayValue('120');
    await userEvent.clear(amountInput);
    await userEvent.type(amountInput, '150');
    expect(store.getState().feeLines[0].amount).toBe(150);

    await userEvent.click(screen.getByRole('button', { name: /remove fee/i }));
    expect(store.getState().feeLines).toHaveLength(0);
  });
});
