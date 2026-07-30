import { describe, expect, it, vi } from 'vitest';
import { render, screen } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { SellingOptionDialog } from './SellingOptionDialog';
import type { Product } from '@/domain/entities/Product';
import type { SellingOption } from '@/domain/entities/SellingOption';

const by6: SellingOption = { id: 'o1', label: 'By 6', pieces: 6, price: 600 };
const by3: SellingOption = { id: 'o2', label: 'By 3', pieces: 3, price: 330 };

const product = (overrides: Partial<Product> = {}) =>
  ({
    id: 'p1',
    sku: 'ABC-1',
    name: 'Pulley Ball',
    cost: 60,
    price: 120,
    unit: 'pcs',
    quantity: 12,
    sellingOptions: [by6, by3],
    ...overrides,
  }) as Product;

describe('SellingOptionDialog', () => {
  it('lists every option with its set price', () => {
    render(<SellingOptionDialog product={product()} onPick={vi.fn()} onClose={vi.fn()} />);
    expect(screen.getByText('By 6')).toBeInTheDocument();
    expect(screen.getByText('By 3')).toBeInTheDocument();
    expect(screen.getByText(/600/)).toBeInTheDocument();
    expect(screen.getByText(/330/)).toBeInTheDocument();
  });

  it('shows the per-piece price as a caption for every option, not just one', () => {
    render(<SellingOptionDialog product={product()} onPick={vi.fn()} onClose={vi.fn()} />);
    // By 6 -> 600/6 = 100/pc, By 3 -> 330/3 = 110/pc. A wrong implementation
    // that shows the SET price twice (no division) would fail this.
    expect(screen.getByText(/100/)).toBeInTheDocument();
    expect(screen.getByText(/110/)).toBeInTheDocument();
  });

  it('shows on-hand pieces', () => {
    render(<SellingOptionDialog product={product()} onPick={vi.fn()} onClose={vi.fn()} />);
    expect(screen.getByText(/12/)).toBeInTheDocument();
  });

  it('does not show the base (non-option) price anywhere', () => {
    // Base price (120) is not directly sellable once a product has options —
    // it must never appear in this dialog.
    render(<SellingOptionDialog product={product()} onPick={vi.fn()} onClose={vi.fn()} />);
    expect(screen.queryByText(/120/)).not.toBeInTheDocument();
  });

  it('calls onPick with the chosen option — clicking By 3 does not return By 6', async () => {
    const onPick = vi.fn();
    render(<SellingOptionDialog product={product()} onPick={onPick} onClose={vi.fn()} />);
    await userEvent.click(screen.getByText('By 3'));
    expect(onPick).toHaveBeenCalledTimes(1);
    expect(onPick).toHaveBeenCalledWith(by3);
  });

  it('calls onPick with the chosen option — clicking By 6 does not return By 3', async () => {
    // Symmetric to the test above: guards against an implementation that
    // hardcodes/returns the first option in the list regardless of the click.
    const onPick = vi.fn();
    render(<SellingOptionDialog product={product()} onPick={onPick} onClose={vi.fn()} />);
    await userEvent.click(screen.getByText('By 6'));
    expect(onPick).toHaveBeenCalledTimes(1);
    expect(onPick).toHaveBeenCalledWith(by6);
  });

  it('calls onClose when cancelled, and never calls onPick', async () => {
    const onPick = vi.fn();
    const onClose = vi.fn();
    render(<SellingOptionDialog product={product()} onPick={onPick} onClose={onClose} />);
    await userEvent.click(screen.getByRole('button', { name: /cancel/i }));
    expect(onClose).toHaveBeenCalledTimes(1);
    expect(onPick).not.toHaveBeenCalled();
  });

  it('always renders the set price even when there is exactly one option', () => {
    // This dialog is the only surface where the whole-set price is shown
    // before it lands on the ticket — it must not be skipped for a
    // single-option product.
    const single = product({ sellingOptions: [by6] });
    render(<SellingOptionDialog product={single} onPick={vi.fn()} onClose={vi.fn()} />);
    expect(screen.getByText('By 6')).toBeInTheDocument();
    expect(screen.getByText(/600/)).toBeInTheDocument();
  });

  describe('short stock', () => {
    // 4 on hand: By 6 (6 pieces) is short, By 3 (3 pieces) is not.
    const shortProduct = () => product({ quantity: 4 });

    it('warns on the option that exceeds on-hand pieces', () => {
      render(<SellingOptionDialog product={shortProduct()} onPick={vi.fn()} onClose={vi.fn()} />);
      expect(screen.getByText(/low stock/i)).toBeInTheDocument();
    });

    it('does not warn when every option is within on-hand pieces', () => {
      render(<SellingOptionDialog product={product({ quantity: 20 })} onPick={vi.fn()} onClose={vi.fn()} />);
      expect(screen.queryByText(/low stock/i)).not.toBeInTheDocument();
    });

    it('still calls onPick for a short-stock option — it warns, it does not block', async () => {
      const onPick = vi.fn();
      render(<SellingOptionDialog product={shortProduct()} onPick={onPick} onClose={vi.fn()} />);
      await userEvent.click(screen.getByText('By 6'));
      expect(onPick).toHaveBeenCalledWith(by6);
    });
  });
});
