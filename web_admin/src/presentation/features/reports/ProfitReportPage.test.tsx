// Profit report (reports guide §1): four cards in one row, Gross profit
// leading with its margin as the note, margin as a coloured column.
import { describe, expect, it } from 'vitest';
import { screen, waitFor, within } from '@testing-library/react';
import { ProfitReportPage } from './ProfitReportPage';
import { item, renderReport, sale } from '@/test/reportFixtures';

// rich: 100 − 40 → 60% margin (pos). thin: 100 − 90 → 10% (neg). mid: 100 − 65 → 35% (ink-2)
const s = sale({
  items: [
    item({ productId: 'rich', name: 'Rich', unitPrice: 100, unitCost: 40, quantity: 1 }),
    item({ productId: 'thin', name: 'Thin', unitPrice: 100, unitCost: 90, quantity: 1 }),
    item({ productId: 'mid', name: 'Mid', unitPrice: 100, unitCost: 65, quantity: 1 }),
  ],
  laborLines: [{ id: 'l', description: 'Fit', fee: 200 }],
});

describe('ProfitReportPage', () => {
  it('Gross profit leads as net parts − COGS with the margin as its note; labor stays out', async () => {
    renderReport(<ProfitReportPage />, { sales: [s], path: '/reports/profit' });
    const lead = (await screen.findByText('Gross profit')).closest('section') as HTMLElement;
    // parts 300 (labor 200 stays out), cogs 195 → 105; 35.0% margin
    await waitFor(() => expect(within(lead).getByText('₱105.00')).toBeInTheDocument());
    expect(within(lead).getByText('35.0% margin')).toBeInTheDocument();
    expect(lead.className).toContain('bg-accent-soft');
    const cogs = screen.getByText('Total COGS').closest('section') as HTMLElement;
    expect(within(cogs).getByText('65.0% of sales')).toBeInTheDocument();
    const gross = screen.getByText('Gross sales').closest('section') as HTMLElement;
    expect(within(gross).getByText('₱300.00')).toBeInTheDocument();
  });

  it('margin is a column, coloured by band: ≥50 pos, 25–49 ink-2, <25 neg', async () => {
    renderReport(<ProfitReportPage />, { sales: [s], path: '/reports/profit' });
    const rich = (await screen.findByText('Rich')).closest('tr') as HTMLElement;
    expect(within(rich).getByText('60%').className).toContain('text-pos');
    const mid = screen.getByText('Mid').closest('tr') as HTMLElement;
    expect(within(mid).getByText('35%').className).toContain('text-ink-2');
    const thin = screen.getByText('Thin').closest('tr') as HTMLElement;
    expect(within(thin).getByText('10%').className).toContain('text-neg');
  });

  it('the table lists products by profit desc so its columns reconcile with the KPIs', async () => {
    renderReport(<ProfitReportPage />, { sales: [s], path: '/reports/profit' });
    await screen.findByText('Rich');
    const names = screen.getAllByRole('row').slice(1).map((r) => within(r).getAllByRole('cell')[0].textContent);
    expect(names).toEqual(['Rich', 'Mid', 'Thin']);
  });

  it('an empty range explains and offers the NEXT wider range (already on 7 days → 30 days)', async () => {
    renderReport(<ProfitReportPage />, { sales: [], path: '/reports/profit' });
    expect(await screen.findByText('No sales in this range')).toBeInTheDocument();
    expect(screen.getByRole('button', { name: 'Show last 30 days' })).toBeInTheDocument();
    expect(document.body.textContent).not.toMatch(/NaN|Infinity/);
    // the lead card's margin has no denominator — a dash, never "0.0%"
    const lead = screen.getByText('Gross profit').closest('section') as HTMLElement;
    expect(within(lead).getByText('— margin')).toBeInTheDocument();
  });
});
