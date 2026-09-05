// The index (reports guide §1): permission-filtered cards, each carrying two
// LIVE figures for the active range — the hub answers "how did we do" without
// opening a report, and every figure moves when the range moves.
import { describe, expect, it } from 'vitest';
import { screen, waitFor, within } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { ReportsHubPage } from './ReportsHubPage';
import { UserRole } from '@/domain/enums';
import { DAY_MS, renderReport, sale } from '@/test/reportFixtures';

// s1 = parts 200 (cost 120) + labor 450, kept OUT of gross. sWide only shows up on a range wider than 8 days.
const s1 = sale();
const sWide = sale({ id: 's2', saleNumber: 'OR-0002', createdAt: new Date(Date.now() - 20 * DAY_MS) });
const byRange = (r: { start: Date; end: Date }) =>
  r.end.getTime() - r.start.getTime() > 8 * DAY_MS ? [s1, sWide] : [s1];

describe('ReportsHubPage — permission-filtered tiles', () => {
  it('admin sees all four reports', async () => {
    renderReport(<ReportsHubPage />, { sales: [s1] });
    for (const title of ['Sales report', 'Profit report', 'Labor report', 'Price changes']) {
      expect(await screen.findByText(title)).toBeInTheDocument();
    }
  });

  it('cashier sees only Sales and Labor (mobile parity), locked to today', async () => {
    renderReport(<ReportsHubPage />, { sales: [s1], role: UserRole.cashier });
    expect(await screen.findByText('Sales report')).toBeInTheDocument();
    expect(screen.getByText('Labor report')).toBeInTheDocument();
    expect(screen.queryByText('Profit report')).not.toBeInTheDocument();
    expect(screen.queryByText('Price changes')).not.toBeInTheDocument();
    expect(screen.queryByRole('radiogroup')).not.toBeInTheDocument();
  });
});

describe('ReportsHubPage — error state', () => {
  it('a failed price-history query surfaces as an error with retry, not a Price changes card of zeros', async () => {
    renderReport(<ReportsHubPage />, { sales: [s1], priceChanges: new Error('index missing') });
    expect(await screen.findByText('Could not load reports.')).toBeInTheDocument();
    expect(screen.getByRole('button', { name: 'Retry' })).toBeInTheDocument();
    expect(screen.queryByText('Price changes')).not.toBeInTheDocument();
  });
});

describe('ReportsHubPage — live figures', () => {
  it('each card carries two figures for the active range, derived from the one scoped set', async () => {
    renderReport(<ReportsHubPage />, { sales: [s1] });
    const salesCard = (await screen.findByText('Sales report')).closest('a') as HTMLElement;
    await waitFor(() => expect(within(salesCard).getByText('₱200.00')).toBeInTheDocument());
    expect(within(salesCard).getByText('1')).toBeInTheDocument();
    const profitCard = screen.getByText('Profit report').closest('a') as HTMLElement;
    // profit = 200 − 120 cogs = 80; margin 40.0%
    expect(within(profitCard).getByText('₱80.00')).toBeInTheDocument();
    expect(within(profitCard).getByText('40.0%')).toBeInTheDocument();
    const laborCard = screen.getByText('Labor report').closest('a') as HTMLElement;
    expect(within(laborCard).getByText('₱450.00')).toBeInTheDocument();
  });

  it('moving the range re-derives every card figure', async () => {
    renderReport(<ReportsHubPage />, { sales: byRange });
    const salesCard = (await screen.findByText('Sales report')).closest('a') as HTMLElement;
    await waitFor(() => expect(within(salesCard).getByText('₱200.00')).toBeInTheDocument());
    await userEvent.click(screen.getByRole('radio', { name: '30 days' }));
    await waitFor(() => expect(within(salesCard).getByText('₱400.00')).toBeInTheDocument());
    expect(within(salesCard).getByText('2')).toBeInTheDocument();
  });
});
