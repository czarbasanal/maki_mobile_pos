// Price changes (reports guide §1): reason chips with counts, SKU copy
// buttons, the delta as a signed chip inline with the price, the option label
// as a sub-line under the product, and two DIFFERENT empties — an empty range
// is not the same message as an empty filter result.
import { describe, expect, it } from 'vitest';
import { screen, waitFor, within } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { PriceChangeReportPage } from './PriceChangeReportPage';
import type { Product } from '@/domain/entities';
import type { PriceChangeEntry } from '@/domain/products/priceChangeReport';
import { DAY_MS, renderReport } from '@/test/reportFixtures';
import { PriceChangeReportPage as Page } from './PriceChangeReportPage';

const pulleyBall = (o: Partial<Product> = {}): Product =>
  ({
    id: 'p1', sku: 'ABC-1', name: 'Pulley Ball', cost: 60, price: 120, quantity: 5,
    reorderLevel: 1, unit: 'pcs', isActive: true, ...o,
  }) as Product;

function entry(o: Partial<PriceChangeEntry> = {}): PriceChangeEntry {
  return {
    id: 'e1', productId: 'p1', price: 120, cost: 70,
    changedAt: new Date(), changedBy: 'u1', reason: 'Price update',
    optionId: null, optionLabel: null, optionPieces: null,
    ...o,
  };
}

const harness = (entries: PriceChangeEntry[], products: Product[] = [pulleyBall()]) =>
  renderReport(<PriceChangeReportPage />, { priceChanges: entries, products, path: '/reports/price-changes' });

describe('PriceChangeReportPage table', () => {
  it('shows the option label under the product name for an option row, nothing extra for a base row', async () => {
    harness([
      entry({ id: 'base', price: 120 }),
      entry({ id: 'opt', price: 330, optionId: 'o2', optionLabel: 'By 3', optionPieces: 3 }),
    ]);
    const optionRow = (await screen.findByText('₱330.00')).closest('tr') as HTMLElement;
    const baseRow = screen.getByText('₱120.00').closest('tr') as HTMLElement;
    // Columns: Product(0), SKU(1), Reason(2), Price(3), New cost(4), When(5)
    expect(within(optionRow).getAllByRole('cell')[0].textContent).toBe('Pulley BallBy 3');
    expect(within(baseRow).getAllByRole('cell')[0].textContent).toBe('Pulley Ball');
    expect(within(baseRow).getAllByRole('cell')).toHaveLength(6);
  });

  it('carries the SKU in mono with a copy button', async () => {
    harness([entry()]);
    const row = (await screen.findByText('₱120.00')).closest('tr') as HTMLElement;
    expect(within(row).getByText('ABC-1')).toBeInTheDocument();
    expect(within(row).getByRole('button', { name: 'Copy SKU' })).toBeInTheDocument();
  });

  it('a row whose product is not loaded yet has no copy button (nothing to copy)', async () => {
    harness([entry({ productId: 'ghost' })], []);
    const row = (await screen.findByText('₱120.00')).closest('tr') as HTMLElement;
    expect(within(row).queryByRole('button', { name: 'Copy SKU' })).not.toBeInTheDocument();
  });

  it('the Reason tag groups selling-option events as Options and keeps the raw reason as its title', async () => {
    harness([entry({ reason: 'Option changed', optionId: 'o1', optionLabel: 'By 3', optionPieces: 3 })]);
    // The chip row also says "Options" — the tag is the one carrying the raw reason as its title.
    const tag = await screen.findByTitle('Option changed');
    expect(tag.textContent).toBe('Options');
  });

  it('renders the price delta as a signed chip inline with the price: a rise is neg, a cut is pos', async () => {
    harness([
      entry({ id: 'a', price: 100, changedAt: new Date(Date.now() - 3000) }),
      entry({ id: 'b', price: 140, changedAt: new Date(Date.now() - 2000) }),
      entry({ id: 'c', price: 120, changedAt: new Date(Date.now() - 1000) }),
    ]);
    const rise = (await screen.findByText('₱140.00')).closest('tr') as HTMLElement;
    expect(within(rise).getByText('+40.00').className).toContain('text-neg');
    const cut = screen.getByText('₱120.00').closest('tr') as HTMLElement;
    expect(within(cut).getByText('-20.00').className).toContain('text-pos');
    const first = screen.getByText('₱100.00').closest('tr') as HTMLElement;
    expect(within(first).queryByText(/^[+-]\d/)).not.toBeInTheDocument();
  });
});

describe('PriceChangeReportPage — KPIs, chips, filters', () => {
  const mixed = [
    entry({ id: 'r', reason: 'receiving', price: 100, changedAt: new Date(Date.now() - 3000) }),
    entry({ id: 'i', reason: 'Initial price', productId: 'p2', price: 50 }),
    entry({ id: 'u', reason: 'Price update', price: 140, changedAt: new Date(Date.now() - 1000) }),
  ];
  const products = [pulleyBall(), pulleyBall({ id: 'p2', sku: 'ZZZ-9', name: 'Zinc Washer' })];

  it('KPIs count changes logged, increases, cuts and new products from the scoped set', async () => {
    harness(mixed, products);
    const logged = (await screen.findByText('Changes logged')).closest('section') as HTMLElement;
    await waitFor(() => expect(within(logged).getByText('3')).toBeInTheDocument());
    expect(logged.className).toContain('bg-accent-soft');
    const ups = screen.getByText('Price increases').closest('section') as HTMLElement;
    expect(within(ups).getByText('1')).toBeInTheDocument();
    const news = screen.getByText('New products').closest('section') as HTMLElement;
    expect(within(news).getByText('1')).toBeInTheDocument();
    expect(within(news).getByText('first price set')).toBeInTheDocument();
  });

  it('reason chips carry counts and filter the table; the KPIs stay scoped to the range', async () => {
    harness(mixed, products);
    await screen.findByText('Zinc Washer');
    const chip = screen.getByRole('button', { name: /Initial price/ });
    expect(chip.textContent).toContain('1');
    await userEvent.click(chip);
    expect(screen.getByText('Zinc Washer')).toBeInTheDocument();
    expect(screen.queryByText('₱140.00')).not.toBeInTheDocument();
    expect(screen.getByText('1 change')).toBeInTheDocument();
    const logged = screen.getByText('Changes logged').closest('section') as HTMLElement;
    expect(within(logged).getByText('3')).toBeInTheDocument();
  });

  it('an empty RANGE explains; on the 30-day default there is nothing wider to offer, on Today it offers 7 days', async () => {
    harness([]);
    expect(await screen.findByText('No price changes in this range')).toBeInTheDocument();
    expect(screen.queryByRole('button', { name: /Show last/ })).not.toBeInTheDocument();
    expect(screen.queryByText('No price changes match these filters')).not.toBeInTheDocument();
    await userEvent.click(screen.getByRole('radio', { name: 'Today' }));
    expect(await screen.findByRole('button', { name: 'Show last 7 days' })).toBeInTheDocument();
  });

  it('search goes through the shared product matcher: tokens in any order', async () => {
    harness(mixed, products);
    await screen.findByText('Zinc Washer');
    await userEvent.type(screen.getByPlaceholderText('Search product or SKU'), 'washer zinc');
    await waitFor(() => expect(screen.queryByText('Pulley Ball')).not.toBeInTheDocument());
    expect(screen.getByText('Zinc Washer')).toBeInTheDocument();
  });

  it('a reason chip that drops out of the new range heals the filter back to All', async () => {
    renderReport(<Page />, {
      products,
      path: '/reports/price-changes',
      priceChanges: (r) => (r.end.getTime() - r.start.getTime() > 2 * DAY_MS ? mixed : [mixed[0]]),
    });
    await screen.findByText('Zinc Washer');
    await userEvent.click(screen.getByRole('button', { name: /Initial price/ }));
    expect(screen.queryByText('₱140.00')).not.toBeInTheDocument();
    await userEvent.click(screen.getByRole('radio', { name: 'Today' }));
    // Only the receiving row exists today: the table shows it, not a dead filter.
    expect(await screen.findByText('₱100.00')).toBeInTheDocument();
    expect(screen.getByRole('button', { name: /^All/ })).toHaveAttribute('aria-pressed', 'true');
  });

  it('an empty FILTER result is a different message with Clear filters', async () => {
    harness(mixed, products);
    await screen.findByText('Zinc Washer');
    await userEvent.type(screen.getByPlaceholderText('Search product or SKU'), 'nonsense');
    expect(await screen.findByText('No price changes match these filters')).toBeInTheDocument();
    expect(screen.queryByText('No price changes in this range')).not.toBeInTheDocument();
    await userEvent.click(screen.getByRole('button', { name: 'Clear filters' }));
    expect(await screen.findByText('Zinc Washer')).toBeInTheDocument();
  });
});
