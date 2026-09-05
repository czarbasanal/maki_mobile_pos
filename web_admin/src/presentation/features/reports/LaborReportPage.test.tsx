// Labor report (reports guide §1): "Jobs with labor" is a count, not money;
// a one-row breakdown says why it is one row.
import { describe, expect, it } from 'vitest';
import { screen, waitFor, within } from '@testing-library/react';
import { LaborReportPage } from './LaborReportPage';
import { UserRole } from '@/domain/enums';
import { renderReport, sale } from '@/test/reportFixtures';

const FOOTNOTE = 'One mechanic is recorded on every job in this range. Assign mechanics on the job order to break this down.';

describe('LaborReportPage — cashier daily lock', () => {
  it('locks a cashier to today with the labor lock notice, no range control', async () => {
    renderReport(<LaborReportPage />, { sales: [], role: UserRole.cashier, path: '/reports/labor' });
    await screen.findByText("Showing today's labor only. Contact an admin for historical reports.");
    expect(screen.queryByRole('radiogroup')).not.toBeInTheDocument();
  });

  it('admin keeps the range control', async () => {
    renderReport(<LaborReportPage />, { sales: [sale()], path: '/reports/labor' });
    await screen.findByText('Total labor');
    expect(screen.getByRole('radiogroup')).toBeInTheDocument();
  });
});

describe('LaborReportPage — figures', () => {
  it('counts jobs with labor and derives the average per job', async () => {
    renderReport(<LaborReportPage />, {
      sales: [sale({ id: 'a' }), sale({ id: 'b', laborLines: [{ id: 'l', description: 'x', fee: 150 }] })],
      path: '/reports/labor',
    });
    const jobs = (await screen.findByText('Jobs with labor')).closest('section') as HTMLElement;
    await waitFor(() => expect(within(jobs).getByText('2')).toBeInTheDocument());
    const avg = screen.getByText('Avg per job').closest('section') as HTMLElement;
    expect(within(avg).getByText('₱300.00')).toBeInTheDocument();
    expect(within(avg).getByText('across 1 mechanic')).toBeInTheDocument();
    expect(screen.queryByText('Service Sales')).not.toBeInTheDocument();
  });

  it('a single mechanic row carries the footnote explaining the one-row breakdown', async () => {
    renderReport(<LaborReportPage />, { sales: [sale()], path: '/reports/labor' });
    expect(await screen.findByText(FOOTNOTE)).toBeInTheDocument();
    const row = screen.getByText('Juan Dela Cruz').closest('tr') as HTMLElement;
    expect(within(row).getByText('100%')).toBeInTheDocument();
  });

  it('two mechanics need no footnote', async () => {
    renderReport(<LaborReportPage />, {
      sales: [sale({ id: 'a' }), sale({ id: 'b', mechanicId: 'm2', mechanicName: 'Pedro' })],
      path: '/reports/labor',
    });
    await screen.findByText('Pedro');
    expect(screen.queryByText(FOOTNOTE)).not.toBeInTheDocument();
  });

  it('an empty range explains and offers the next wider range', async () => {
    renderReport(<LaborReportPage />, { sales: [], path: '/reports/labor' });
    expect(await screen.findByText('No labor in this range')).toBeInTheDocument();
    expect(screen.getByRole('button', { name: 'Show last 30 days' })).toBeInTheDocument();
  });
});
