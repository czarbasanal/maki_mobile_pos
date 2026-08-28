import { beforeEach, describe, expect, it, vi } from 'vitest';
import { act, fireEvent, render, screen } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { MemoryRouter, Routes, Route, useParams } from 'react-router-dom';
import { QueryClient, QueryClientProvider } from '@tanstack/react-query';
import { DiProvider, type Container } from '@/infrastructure/di/container';
import { JobOrdersPage } from './JobOrdersPage';
import { RoutePaths } from '@/presentation/router/routePaths';
import { cartGrandTotal } from '@/domain/sales/cart';
import { formatMoney } from '@/core/utils/money';
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
  createdAt: new Date(2026, 6, 23),
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

    const joCell = screen.getByText('JO-072326-001');
    expect(joCell).toHaveClass('font-mono');
    expect(screen.getByText('Kuya Bert')).toBeInTheDocument();
    // The bike is how staff recognise a ticket at a glance — same as mobile's
    // list tile, which shows it as a chip.
    expect(screen.getByText('Honda Click 125i')).toBeInTheDocument();
    expect(screen.getByText(formatMoney(cartGrandTotal(open.items, open.laborLines, open.discountType, open.feeLines)))).toBeInTheDocument();
    expect(screen.getByText('Open')).toBeInTheDocument();
  });

  it('shows a Billed pill for converted job orders and keeps them in the list, visually muted', () => {
    const billed = jobOrder({ id: 'd2', name: 'JO-072326-002', isConverted: true });
    harness([billed]);

    expect(screen.getByText('JO-072326-002')).toBeInTheDocument();
    expect(screen.getByText('Billed')).toBeInTheDocument();
    // Muted: the JO number itself carries the hint/muted text color once billed.
    expect(screen.getByText('JO-072326-002')).toHaveClass('text-light-text-hint');
  });

  it('keeps both open and converted rows in the same list', () => {
    const open = jobOrder({ id: 'd1', name: 'JO-072326-001', isConverted: false });
    const billed = jobOrder({ id: 'd2', name: 'JO-072326-002', isConverted: true });
    harness([open, billed]);

    expect(screen.getByText('JO-072326-001')).toBeInTheDocument();
    expect(screen.getByText('JO-072326-002')).toBeInTheDocument();
    expect(screen.getByText('Open')).toBeInTheDocument();
    expect(screen.getByText('Billed')).toBeInTheDocument();
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
