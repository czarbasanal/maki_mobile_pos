import { beforeEach, describe, expect, it, vi } from 'vitest';
import { act, fireEvent, render, screen, within } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { MemoryRouter, Routes, Route, useParams } from 'react-router-dom';
import { QueryClient, QueryClientProvider } from '@tanstack/react-query';
import { DiProvider, type Container } from '@/infrastructure/di/container';
import { JobOrdersPage } from './JobOrdersPage';
import { RoutePaths } from '@/presentation/router/routePaths';
import { cartGrandTotal } from '@/domain/sales/cart';
import { DiscountType } from '@/domain/enums/DiscountType';
import type { JobOrder } from '@/domain/entities';

const jobOrder = (o: Partial<JobOrder> = {}): JobOrder => ({
  id: 'd1',
  name: 'JO-072326-001',
  items: [],
  laborLines: [],
  feeLines: [],
  mechanicId: null,
  mechanicName: null,
  motorcycleModel: null,
  discountType: DiscountType.amount,
  createdBy: 'u1',
  createdByName: 'C',
  // Today by default: the page now filters to the current day, and these
  // tests are about how a row renders, not about which day it falls on.
  createdAt: new Date(),
  updatedAt: null,
  updatedBy: null,
  isConverted: false,
  convertedToSaleId: null,
  convertedAt: null,
  notes: null,
  ...o,
});

function EditStub() {
  const { id } = useParams();
  return <div>JOB ORDER EDIT {id}</div>;
}

function SaleStub() {
  const { id } = useParams();
  return <div>SALE DETAIL {id}</div>;
}

function harness(jobOrders: JobOrder[]) {
  const qc = new QueryClient({ defaultOptions: { queries: { retry: false } } });
  let emit: (next: JobOrder[]) => void = () => {};
  const jobOrderRepo: Partial<Container['jobOrderRepo']> = {
    watchAll: vi.fn((cb: (jobOrders: JobOrder[]) => void) => {
      emit = cb;
      cb(jobOrders);
      return () => {};
    }),
  };
  const view = render(
    <DiProvider override={{ jobOrderRepo: jobOrderRepo as Container['jobOrderRepo'] }}>
      <QueryClientProvider client={qc}>
        <MemoryRouter initialEntries={[RoutePaths.jobOrders]}>
          <Routes>
            <Route path={RoutePaths.jobOrders} element={<JobOrdersPage />} />
            <Route path={RoutePaths.jobOrderEdit} element={<EditStub />} />
            <Route path={RoutePaths.saleDetail} element={<SaleStub />} />
          </Routes>
        </MemoryRouter>
      </QueryClientProvider>
    </DiProvider>,
  );
  return { ...view, emit: (next: JobOrder[]) => emit(next) };
}

describe('JobOrdersPage', () => {
  it('renders the JO number in mono, mechanic, total, and date for an open job order', () => {
    const open = jobOrder({
      id: 'd1',
      name: 'JO-072326-001',
      mechanicName: 'Kuya Bert',
      motorcycleModel: 'Honda Click 125i',
      isConverted: false,
    });
    harness([open]);

    const joCell = screen.getByText('JO-072326-001').closest('td')!;
    expect(joCell).toHaveClass('font-mono');
    expect(screen.getByText('Kuya Bert')).toBeInTheDocument();
    // The bike is how staff recognise a ticket at a glance — same as mobile's
    // list tile, which shows it as a chip.
    expect(screen.getByText('Honda Click 125i')).toBeInTheDocument();
    // An empty ticket shows — for total and items, not ₱0.00 (guide §A).
    expect(cartGrandTotal(open.items, open.laborLines, open.discountType, open.feeLines)).toBe(0);
    const row = joCell.closest('tr')!;
    expect(within(row).getByText('Open')).toBeInTheDocument();
  });

  it('shows a Billed pill for converted job orders and keeps them in the list', () => {
    const billed = jobOrder({ id: 'd2', name: 'JO-072326-002', isConverted: true });
    harness([billed]);

    const row = screen.getByText('JO-072326-002').closest('tr')!;
    expect(within(row).getByText('Billed')).toBeInTheDocument();
  });

  it('keeps both open and converted rows in the same list', () => {
    const open = jobOrder({ id: 'd1', name: 'JO-072326-001', isConverted: false });
    const billed = jobOrder({ id: 'd2', name: 'JO-072326-002', isConverted: true });
    harness([open, billed]);

    const openRow = screen.getByText('JO-072326-001').closest('tr')!;
    const billedRow = screen.getByText('JO-072326-002').closest('tr')!;
    expect(within(openRow).getByText('Open')).toBeInTheDocument();
    expect(within(billedRow).getByText('Billed')).toBeInTheDocument();
  });

  it('shows an empty state with no job orders', () => {
    harness([]);
    expect(screen.getByText(/no job orders/i)).toBeInTheDocument();
  });

  it('billed row View opens the converted sale, not the (refusing) edit screen', () => {
    const billed = jobOrder({
      id: 'd2',
      name: 'JO-072326-002',
      isConverted: true,
      convertedToSaleId: 's9',
    });
    harness([billed]);

    fireEvent.click(screen.getByRole('button', { name: /view sale/i }));
    expect(screen.getByText('SALE DETAIL s9')).toBeInTheDocument();
  });

  it('billed row with no converted-sale link shows no action at all', () => {
    const billed = jobOrder({
      id: 'd2',
      name: 'JO-072326-002',
      isConverted: true,
      convertedToSaleId: null,
    });
    harness([billed]);

    expect(screen.queryByRole('button', { name: /view/i })).not.toBeInTheDocument();
  });
});

describe('JobOrdersPage — pagination', () => {
  // Isolated here rather than at the end of the resize test: a mid-test
  // failure there would leak the stored size and break the NEXT test with an
  // error pointing nowhere near the cause.
  beforeEach(() => localStorage.clear());

  it('shows the pager once the job order list exceeds 25', () => {
    const many = Array.from({ length: 26 }, (_, i) => jobOrder({ id: `d${i + 1}`, name: `JO-072326-${String(i + 1).padStart(3, '0')}` }));
    harness(many);

    expect(screen.getByText('1–25 of 26')).toBeInTheDocument();
  });

  it('choosing more rows per page shows them, and the choice sticks per table', async () => {
    const many = Array.from({ length: 30 }, (_, i) =>
      jobOrder({ id: `d${i + 1}`, name: `JO-072326-${String(i + 1).padStart(3, '0')}` }),
    );
    const view = harness(many);
    expect(screen.getByText('1–25 of 30')).toBeInTheDocument();
    expect(screen.queryByText('JO-072326-030')).not.toBeInTheDocument();

    await userEvent.selectOptions(screen.getByLabelText(/rows per page/i), '50');

    expect(screen.getByText('1–30 of 30')).toBeInTheDocument();
    expect(screen.getByText('JO-072326-030')).toBeInTheDocument();
    // Still reachable so the size can be changed back.
    expect(screen.getByLabelText(/rows per page/i)).toHaveValue('50');

    // Remembered on the next visit, and scoped to this table only.
    view.unmount();
    harness(many);
    expect(screen.getByLabelText(/rows per page/i)).toHaveValue('50');
    expect(localStorage.getItem('maki.pageSize.inventory')).toBeNull();
  });

  it('hides the pager at exactly 25 job orders', () => {
    const exactly25 = Array.from({ length: 25 }, (_, i) => jobOrder({ id: `d${i + 1}`, name: `JO-072326-${String(i + 1).padStart(3, '0')}` }));
    harness(exactly25);

    expect(screen.queryByText(/of 25/)).not.toBeInTheDocument();
  });

  it('snaps back to the last page when the list shrinks under a parked page 2 (delete-in-place)', () => {
    const many = Array.from({ length: 26 }, (_, i) =>
      jobOrder({ id: `d${i + 1}`, name: `JO-072326-${String(i + 1).padStart(3, '0')}` }),
    );
    const { emit } = harness(many);

    fireEvent.click(screen.getByRole('button', { name: 'Next' }));
    expect(screen.getByText('26–26 of 26')).toBeInTheDocument();

    // Live snapshot shrinks to 25 (e.g. the parked-on row was deleted): the
    // pager unmounts (total <= pageSize), so without a clamp the page stays 2
    // and the table renders empty with no Prev button to escape.
    act(() => emit(many.slice(0, 25)));
    expect(screen.getByText('JO-072326-001')).toBeInTheDocument();
    expect(screen.queryByText(/of 25/)).not.toBeInTheDocument();
  });
});

describe('JobOrdersPage — date range', () => {
  const today = new Date();
  const yesterday = new Date(today.getTime() - 26 * 60 * 60 * 1000);

  it('shows today by default and hides other days', () => {
    harness([
      jobOrder({ id: 'd1', name: 'JO-TODAY', createdAt: today }),
      jobOrder({ id: 'd2', name: 'JO-OLD', createdAt: yesterday }),
    ]);

    expect(screen.getByText('JO-TODAY')).toBeInTheDocument();
    expect(screen.queryByText('JO-OLD')).not.toBeInTheDocument();
  });

  it('counts open tickets left outside the range instead of losing them', () => {
    // A bike left overnight is still an open ticket; a date filter would hide
    // it, so the page says how many are out there.
    harness([
      jobOrder({ id: 'd1', name: 'JO-TODAY', createdAt: today }),
      jobOrder({ id: 'd2', name: 'JO-OLD', createdAt: yesterday, isConverted: false }),
    ]);

    expect(
      screen.getByText(/1 open job order outside this range/i),
    ).toBeInTheDocument();
  });

  it('offers the segmented presets from the guide, all nowrap', () => {
    harness([jobOrder({ id: 'd1', name: 'JO-TODAY', createdAt: today })]);

    const group = screen.getByRole('radiogroup', { name: 'Date range' });
    const labels = within(group)
      .getAllByRole('radio')
      .map((r) => r.textContent);
    expect(labels).toEqual(['Today', 'Yesterday', '7 days', '30 days']);
    expect(screen.getByRole('radio', { name: 'Today' })).toHaveAttribute('aria-checked', 'true');
  });

  it('widening to 7 days brings the older ticket back', async () => {
    harness([
      jobOrder({ id: 'd1', name: 'JO-TODAY', createdAt: today }),
      jobOrder({ id: 'd2', name: 'JO-OLD', createdAt: yesterday }),
    ]);
    expect(screen.queryByText('JO-OLD')).not.toBeInTheDocument();

    await userEvent.click(screen.getByRole('radio', { name: '7 days' }));
    expect(screen.getByText('JO-OLD')).toBeInTheDocument();
  });

  it('does not count an already billed-out job order as left behind', () => {
    harness([
      jobOrder({ id: 'd1', name: 'JO-TODAY', createdAt: today }),
      jobOrder({ id: 'd2', name: 'JO-OLD', createdAt: yesterday, isConverted: true }),
    ]);

    expect(screen.queryByText(/outside this range/i)).not.toBeInTheDocument();
  });
});

describe('JobOrdersPage — saved views + filters (reskin)', () => {
  const today = new Date();

  it('view chips carry live counts and filter the rows', async () => {
    harness([
      jobOrder({ id: 'd1', name: 'JO-A', isConverted: false }),
      jobOrder({ id: 'd2', name: 'JO-B', isConverted: true }),
      jobOrder({ id: 'd3', name: 'JO-C', isConverted: true }),
    ]);

    expect(screen.getByRole('button', { name: /All 3/ })).toBeInTheDocument();
    expect(screen.getByRole('button', { name: /Open 1/ })).toBeInTheDocument();
    expect(screen.getByRole('button', { name: /Billed 2/ })).toBeInTheDocument();

    await userEvent.click(screen.getByRole('button', { name: /Billed 2/ }));
    expect(screen.queryByText('JO-A')).not.toBeInTheDocument();
    expect(screen.getByText('JO-B')).toBeInTheDocument();
  });

  it('the mechanic dropdown filters rows and offers counts', async () => {
    harness([
      jobOrder({ id: 'd1', name: 'JO-A', mechanicId: 'm1', mechanicName: 'Jeric', createdAt: today }),
      jobOrder({ id: 'd2', name: 'JO-B', mechanicId: 'm2', mechanicName: 'Nonoy', createdAt: today }),
    ]);

    await userEvent.click(screen.getByRole('button', { name: /Mechanic/ }));
    await userEvent.click(screen.getByRole('option', { name: /Jeric/ }));

    expect(screen.getByText('JO-A')).toBeInTheDocument();
    expect(screen.queryByText('JO-B')).not.toBeInTheDocument();
    expect(screen.getByText(/1 ticket$/)).toBeInTheDocument();
  });

  it('filtered-to-nothing shows the no-matches state with Clear filters, never the first-run copy', async () => {
    harness([jobOrder({ id: 'd1', name: 'JO-A', mechanicName: 'Jeric', createdAt: today })]);

    await userEvent.type(screen.getByPlaceholderText(/Search JO no/), 'zzz');
    expect(await screen.findByText(/no job orders match these filters/i)).toBeInTheDocument();
    expect(screen.queryByText(/no job orders yet/i)).not.toBeInTheDocument();

    // Both the filter band and the empty state offer Clear filters.
    await userEvent.click(screen.getAllByRole('button', { name: /clear filters/i })[0]);
    expect(screen.getByText('JO-A')).toBeInTheDocument();
  });

  it('first-run (no job orders at all) teaches and offers the primary action', () => {
    harness([]);
    expect(screen.getByText(/no job orders yet/i)).toBeInTheDocument();
    expect(screen.getByText(/open a ticket when a unit comes in/i)).toBeInTheDocument();
    expect(screen.getAllByRole('button', { name: /new job order/i }).length).toBeGreaterThanOrEqual(2);
  });
});

describe('JobOrdersPage — open tickets beyond the preset cap stay reachable', () => {
  it('the outside-range notice reveals old open tickets, and Hide puts them back', async () => {
    const today = new Date();
    const monthsAgo = new Date(today.getTime() - 90 * 24 * 60 * 60 * 1000);
    harness([
      jobOrder({ id: 'd1', name: 'JO-TODAY', createdAt: today }),
      jobOrder({ id: 'd2', name: 'JO-ANCIENT', createdAt: monthsAgo, isConverted: false }),
    ]);
    expect(screen.queryByText('JO-ANCIENT')).not.toBeInTheDocument();

    // The 30-day preset is the widest offered; without this affordance an
    // open ticket older than that could never be listed again.
    await userEvent.click(screen.getByRole('button', { name: /show it/i }));
    expect(screen.getByText('JO-ANCIENT')).toBeInTheDocument();
    expect(screen.getByText('JO-TODAY')).toBeInTheDocument();

    await userEvent.click(screen.getByRole('button', { name: 'Hide' }));
    expect(screen.queryByText('JO-ANCIENT')).not.toBeInTheDocument();
  });

  it('changing the date preset resets the reveal', async () => {
    const today = new Date();
    const monthsAgo = new Date(today.getTime() - 90 * 24 * 60 * 60 * 1000);
    harness([jobOrder({ id: 'd2', name: 'JO-ANCIENT', createdAt: monthsAgo, isConverted: false })]);

    await userEvent.click(screen.getByRole('button', { name: /show it/i }));
    expect(screen.getByText('JO-ANCIENT')).toBeInTheDocument();

    await userEvent.click(screen.getByRole('radio', { name: '7 days' }));
    expect(screen.queryByText('JO-ANCIENT')).not.toBeInTheDocument();
  });
});
