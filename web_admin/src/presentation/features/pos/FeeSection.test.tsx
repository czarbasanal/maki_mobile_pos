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

describe('FeeSection — inline rows', () => {
  it('Add fee appends a row; picking a fee prefills its default amount', async () => {
    const store = harness();
    await userEvent.click(screen.getByRole('button', { name: /add fee/i }));
    await userEvent.selectOptions(screen.getByLabelText('Shop fee'), 'Tire changer');
    expect(store.getState().feeLines[0]).toMatchObject({ name: 'Tire changer', amount: 50 });
    expect(screen.getByDisplayValue('50.00')).toBeInTheDocument();
  });

  it('the amount edits inline after picking', async () => {
    const store = harness();
    await userEvent.click(screen.getByRole('button', { name: /add fee/i }));
    await userEvent.selectOptions(screen.getByLabelText('Shop fee'), 'Tire changer');
    const amount = screen.getByDisplayValue('50.00');
    await userEvent.clear(amount);
    await userEvent.type(amount, '80');
    expect(store.getState().feeLines[0].amount).toBe(80);
  });

  it('Charge Item grows an inline description input and stores it', async () => {
    const store = harness();
    await userEvent.click(screen.getByRole('button', { name: /add fee/i }));
    await userEvent.selectOptions(screen.getByLabelText('Shop fee'), 'Charge Item');
    expect(screen.getByText(/enter an amount/i)).toBeInTheDocument();
    await userEvent.type(screen.getByPlaceholderText(/what's being charged/i), 'Outside part');
    expect(store.getState().feeLines[0].description).toBe('Outside part');
  });

  it('warns until a Charge Item is described', async () => {
    harness();
    await userEvent.click(screen.getByRole('button', { name: /add fee/i }));
    await userEvent.selectOptions(screen.getByLabelText('Shop fee'), 'Charge Item');
    const amount = screen.getByPlaceholderText('₱');
    await userEvent.type(amount, '120');
    expect(screen.getByText(/describe what's being charged/i)).toBeInTheDocument();
  });

  it('amount stays disabled until a fee is picked; remove works', async () => {
    const store = harness();
    await userEvent.click(screen.getByRole('button', { name: /add fee/i }));
    expect(screen.getByPlaceholderText('₱')).toBeDisabled();
    await userEvent.click(screen.getByRole('button', { name: /remove fee/i }));
    expect(store.getState().feeLines).toHaveLength(0);
  });

  it('shows the empty-catalog note when a row exists but no fees are configured', async () => {
    harness(createCartStore(), []);
    await userEvent.click(screen.getByRole('button', { name: /add fee/i }));
    expect(screen.getByText(/no shop fees configured/i)).toBeInTheDocument();
  });

  it('a carried fee name missing from the catalog stays selectable', () => {
    const store = createCartStore();
    store.getState().addFeeLine();
    const row = store.getState().feeLines[0];
    store.getState().setFeeLine(row.id, { name: 'Legacy Disposal', amount: 30 });
    harness(store);
    expect(screen.getByRole('option', { name: 'Legacy Disposal' })).toBeInTheDocument();
  });
});
