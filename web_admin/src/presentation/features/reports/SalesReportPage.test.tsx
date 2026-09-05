import { describe, expect, it, vi } from 'vitest';
import { screen, waitFor, within } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { SalesReportPage } from './SalesReportPage';
import { PaymentMethod, SaleStatus, UserRole } from '@/domain/enums';
import type { Sale } from '@/domain/entities';
import { formatMoney } from '@/core/utils/money';
import { shopTimeOf } from '@/domain/time/shopTime';
import { DAY_MS, item, renderReport, sale } from '@/test/reportFixtures';

type SalesArg = Sale[] | ((range: { start: Date; end: Date }) => Sale[]);
const harness = (sales: SalesArg, role: UserRole = UserRole.admin) =>
  renderReport(<SalesReportPage />, { sales, role, path: '/reports/sales' });

describe('SalesReportPage', () => {
  it('shows a Shop fees line beside Service / Labor, summing fees across sales', async () => {
    harness([
      sale({ id: 's1', feeLines: [{ id: 'f1', name: 'Convenience fee', amount: 50, description: null }] }),
      sale({ id: 's2', feeLines: [{ id: 'f2', name: 'Convenience fee', amount: 25, description: null }] }),
    ]);

    await waitFor(() => expect(screen.getByText('Service / Labor')).toBeInTheDocument());
    const row = screen.getByText('Shop fees').closest('div');
    expect(row?.textContent).toContain(formatMoney(75));
  });

  it('shows the Shop fees line (₱0.00) when no sale in range has fee lines', async () => {
    harness([sale({ feeLines: [] })]);
    await waitFor(() => expect(screen.getByText('Shop fees')).toBeInTheDocument());
    const row = screen.getByText('Shop fees').closest('div');
    expect(row?.textContent).toContain(formatMoney(0));
  });

  it('paginates the sales table at 25/page, revealing the rest on page 2', async () => {
    const many = Array.from({ length: 30 }, (_, i) =>
      sale({ id: `s${i + 1}`, saleNumber: `OR-${String(i + 1).padStart(4, '0')}` }),
    );
    harness(many);

    await waitFor(() => expect(screen.getByText('1–25 of 30')).toBeInTheDocument());
    expect(screen.getByText('OR-0001')).toBeInTheDocument();
    expect(screen.queryByText('OR-0026')).not.toBeInTheDocument();

    await userEvent.click(screen.getByRole('button', { name: 'Next' }));

    expect(screen.getByText('OR-0026')).toBeInTheDocument();
    expect(screen.queryByText('OR-0001')).not.toBeInTheDocument();
  });
});

describe('SalesReportPage — one scoped set', () => {
  // s1: 200 parts + 450 labor = 650 cash. s2: 200 parts + 450 labor = 650, gcash.
  const two = [sale({ id: 's1' }), sale({ id: 's2', saleNumber: 'OR-0002', paymentMethod: PaymentMethod.gcash })];

  it('Gross sales is parts only; the payment split total and the table "Total shown" are what was tendered', async () => {
    harness(two);
    const lead = (await screen.findByText('Gross sales')).closest('section') as HTMLElement;
    await waitFor(() => expect(within(lead).getByText('₱400.00')).toBeInTheDocument());
    expect(screen.getByTestId('total-shown').textContent).toContain('₱1,300.00');
    const payCard = screen.getByTestId('by-payment-card');
    expect(within(payCard).getByText('₱1,300.00')).toBeInTheDocument();
    const labor = screen.getByText('Service / labor').closest('section') as HTMLElement;
    expect(within(labor).getByText('₱900.00')).toBeInTheDocument();
    expect(within(labor).getByText('reported separately from gross')).toBeInTheDocument();
  });

  it('voided sales stay listed (struck) but are excluded from the count chip and the foot, and say so', async () => {
    harness([...two, sale({ id: 'v', saleNumber: 'OR-VOID', status: SaleStatus.voided })]);
    await screen.findByText('OR-VOID');
    // The card HEADER carries the count chip; the Items column also holds "2"s.
    const header = screen.getByText('Sales', { selector: 'h2' }).parentElement as HTMLElement;
    expect(within(header).getByText('2')).toBeInTheDocument();
    expect(within(header).getByText('1 voided')).toBeInTheDocument();
    const foot = screen.getByTestId('total-shown').closest('tr') as HTMLElement;
    expect(foot.textContent).toContain('Total tendered');
    expect(foot.textContent).toContain('excl. 1 voided');
    expect(foot.textContent).toContain('₱1,300.00');
  });

  it('every payment row carries its share of the tendered total', async () => {
    harness(two);
    const payCard = await screen.findByTestId('by-payment-card');
    // "Cash" also appears in the table's Paid via column — scope to the card.
    const cash = within(payCard).getByText('Cash').closest('div') as HTMLElement;
    expect(cash.textContent).toContain('50%');
    expect(cash.textContent).toContain('₱650.00');
  });

  it('Net sales frames the discounts taken off gross', async () => {
    harness([sale({ items: [item({ productId: 'd', unitPrice: 1000, unitCost: 600, quantity: 1, discountValue: 100 })] })]);
    const net = (await screen.findByText('Net sales')).closest('section') as HTMLElement;
    await waitFor(() => expect(within(net).getByText('₱900.00')).toBeInTheDocument());
    expect(within(net).getByText('after ₱100.00 in discounts')).toBeInTheDocument();
  });
});

describe('SalesReportPage — Top products lens', () => {
  // big: qty 1, revenue 500, margin 20%. many: qty 10, revenue 100, margin 90%.
  const s = sale({
    items: [
      item({ productId: 'big', name: 'Big', unitPrice: 500, unitCost: 400, quantity: 1 }),
      item({ productId: 'many', name: 'Many', unitPrice: 10, unitCost: 1, quantity: 10 }),
    ],
  });
  const order = () =>
    within(screen.getByTestId('top-products')).getAllByTestId('top-product-name').map((el) => el.textContent);

  it('defaults to revenue and re-sorts by qty sold or margin', async () => {
    harness([s]);
    await screen.findByTestId('top-products');
    expect(order()).toEqual(['Big', 'Many']);
    await userEvent.click(screen.getByRole('button', { name: 'Qty' }));
    expect(order()).toEqual(['Many', 'Big']);
    await userEvent.click(screen.getByRole('button', { name: 'Margin' }));
    expect(order()).toEqual(['Many', 'Big']);
    expect(within(screen.getByTestId('top-products')).getByText('90%')).toBeInTheDocument();
    await userEvent.click(screen.getByRole('button', { name: 'Revenue' }));
    expect(order()).toEqual(['Big', 'Many']);
  });

  it('hides the cost-derived Margin lens from a cashier', async () => {
    harness([s], UserRole.cashier);
    await screen.findByTestId('top-products');
    expect(screen.getByRole('button', { name: 'Qty' })).toBeInTheDocument();
    expect(screen.queryByRole('button', { name: 'Margin' })).not.toBeInTheDocument();
  });
});

describe('SalesReportPage — empty range explains and recovers', () => {
  it('Today with nothing recorded says why and offers Show last 7 days, which moves the range', async () => {
    const { saleRepo } = harness((r) => (r.end.getTime() - r.start.getTime() > 2 * DAY_MS ? [sale()] : []));
    expect(await screen.findByText('No sales in this range')).toBeInTheDocument();
    expect(screen.getByText(/The register recorded nothing today/)).toBeInTheDocument();

    await userEvent.click(screen.getByRole('button', { name: 'Show last 7 days' }));

    expect(screen.getByRole('radio', { name: '7 days' })).toHaveAttribute('aria-checked', 'true');
    await waitFor(() => expect(screen.getByText('OR-0001')).toBeInTheDocument());
    const calls = (saleRepo.list as ReturnType<typeof vi.fn>).mock.calls;
    const last = calls[calls.length - 1][0];
    expect(last.end.getTime() - last.start.getTime()).toBeGreaterThan(6 * DAY_MS);
  });

  it('the zero case renders a dash, never NaN', async () => {
    harness([]);
    await screen.findByText('No sales in this range');
    expect(document.body.textContent).not.toMatch(/NaN|Infinity/);
  });
});

describe('SalesReportPage — cashier daily lock', () => {
  it('locks a cashier to today: notice instead of the range control, query clamped', async () => {
    const { saleRepo } = harness([sale()], UserRole.cashier);
    await screen.findByText(
      "Showing today's sales only. Contact an admin for historical reports.",
    );
    expect(screen.queryByRole('radiogroup')).not.toBeInTheDocument();
    const arg = (saleRepo.list as ReturnType<typeof vi.fn>).mock.calls[0][0];
    const nowWall = shopTimeOf(new Date());
    const startWall = shopTimeOf(arg.start);
    expect(startWall.getUTCFullYear()).toBe(nowWall.getUTCFullYear());
    expect(startWall.getUTCMonth()).toBe(nowWall.getUTCMonth());
    expect(startWall.getUTCDate()).toBe(nowWall.getUTCDate());
    expect(startWall.getUTCHours()).toBe(0);
    expect(shopTimeOf(arg.end).getUTCDate()).toBe(nowWall.getUTCDate());
  });

  it('admin keeps the range control', async () => {
    harness([sale()]);
    await screen.findByText('Top products');
    expect(screen.getByRole('radiogroup')).toBeInTheDocument();
  });

  it("a cashier's empty state never points at a range control they cannot see", async () => {
    harness([], UserRole.cashier);
    expect(await screen.findByText('No sales in this range')).toBeInTheDocument();
    expect(screen.getByText('The register recorded nothing today. Check whether the shift was opened.')).toBeInTheDocument();
    expect(screen.queryByText(/Try Last 7 days/)).not.toBeInTheDocument();
    expect(screen.queryByRole('button', { name: /Show last/ })).not.toBeInTheDocument();
    expect(screen.getByText('Nothing sold yet today.')).toBeInTheDocument();
  });
});

describe('SalesReportPage — default range', () => {
  it('opens on Today, not the last 7 days', async () => {
    harness([]);
    expect(await screen.findByRole('radio', { name: 'Today' })).toHaveAttribute('aria-checked', 'true');
  });

  it('queries only today', async () => {
    const { saleRepo } = harness([]);
    await screen.findByRole('radiogroup');
    await waitFor(() => expect(saleRepo.list).toHaveBeenCalled());
    const { start, end } = (saleRepo.list as ReturnType<typeof vi.fn>).mock.calls[0][0];
    expect(end.getTime() - start.getTime()).toBeLessThan(DAY_MS);
  });
});
