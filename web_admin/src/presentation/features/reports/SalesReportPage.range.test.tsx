// Reproduction for "the sales table only ever shows today": drive the real
// segmented control and assert the TABLE rows follow the selected range.
import { describe, expect, it, vi } from 'vitest';
import { screen, waitFor } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { SalesReportPage } from './SalesReportPage';
import { DAY_MS, renderReport, sale } from '@/test/reportFixtures';

const todaySale = sale({ id: 't', saleNumber: 'OR-TODAY' });
const oldSale = sale({ id: 'o', saleNumber: 'OR-OLD', createdAt: new Date(Date.now() - 3 * DAY_MS) });

describe('SalesReportPage — opens on the range the index handed over', () => {
  it('?range=last7 (from the index card) lists the older sale straight away', async () => {
    renderReport(<SalesReportPage />, {
      path: '/reports/sales?range=last7',
      sales: (r) => (r.start.getTime() <= oldSale.createdAt.getTime() ? [todaySale, oldSale] : [todaySale]),
    });
    expect(await screen.findByText('OR-OLD')).toBeInTheDocument();
    expect(screen.getByRole('radio', { name: '7 days' })).toHaveAttribute('aria-checked', 'true');
  });
});

describe('SalesReportPage — the table follows the range control', () => {
  it('picking 7 days refetches with a 7-day window and lists the older sale', async () => {
    const { saleRepo } = renderReport(<SalesReportPage />, {
      path: '/reports/sales',
      sales: (r) => (r.start.getTime() <= oldSale.createdAt.getTime() ? [todaySale, oldSale] : [todaySale]),
    });
    await screen.findByText('OR-TODAY');
    expect(screen.queryByText('OR-OLD')).not.toBeInTheDocument();

    await userEvent.click(screen.getByRole('radio', { name: '7 days' }));

    await waitFor(() => expect(screen.getByText('OR-OLD')).toBeInTheDocument());
    const calls = (saleRepo.list as ReturnType<typeof vi.fn>).mock.calls;
    const last = calls[calls.length - 1][0];
    expect(last.end.getTime() - last.start.getTime()).toBeGreaterThan(6 * DAY_MS);
  });
});
