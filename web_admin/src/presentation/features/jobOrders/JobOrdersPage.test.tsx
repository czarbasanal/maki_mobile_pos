import { describe, expect, it, vi } from 'vitest';
import { render, screen } from '@testing-library/react';
import { MemoryRouter, Routes, Route, useParams } from 'react-router-dom';
import { QueryClient, QueryClientProvider } from '@tanstack/react-query';
import { DiProvider, type Container } from '@/infrastructure/di/container';
import { JobOrdersPage } from './JobOrdersPage';
import { RoutePaths } from '@/presentation/router/routePaths';
import { cartGrandTotal } from '@/domain/sales/cart';
import { formatMoney } from '@/core/utils/money';
import { DiscountType } from '@/domain/enums/DiscountType';
import type { Draft } from '@/domain/entities';

const draft = (o: Partial<Draft> = {}): Draft => ({
  id: 'd1',
  name: 'JO-072326-001',
  items: [],
  laborLines: [],
  feeLines: [],
  mechanicId: null,
  mechanicName: null,
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

function harness(drafts: Draft[]) {
  const qc = new QueryClient({ defaultOptions: { queries: { retry: false } } });
  const draftRepo: Partial<Container['draftRepo']> = {
    watchAll: vi.fn((cb: (drafts: Draft[]) => void) => {
      cb(drafts);
      return () => {};
    }),
  };
  return render(
    <DiProvider override={{ draftRepo: draftRepo as Container['draftRepo'] }}>
      <QueryClientProvider client={qc}>
        <MemoryRouter initialEntries={[RoutePaths.jobOrders]}>
          <Routes>
            <Route path={RoutePaths.jobOrders} element={<JobOrdersPage />} />
            <Route path={RoutePaths.jobOrderEdit} element={<EditStub />} />
          </Routes>
        </MemoryRouter>
      </QueryClientProvider>
    </DiProvider>,
  );
}

describe('JobOrdersPage', () => {
  it('renders the JO number in mono, mechanic, total, and date for an open job order', () => {
    const open = draft({
      id: 'd1',
      name: 'JO-072326-001',
      mechanicName: 'Kuya Bert',
      isConverted: false,
    });
    harness([open]);

    const joCell = screen.getByText('JO-072326-001');
    expect(joCell).toHaveClass('font-mono');
    expect(screen.getByText('Kuya Bert')).toBeInTheDocument();
    expect(screen.getByText(formatMoney(cartGrandTotal(open.items, open.laborLines, open.discountType, open.feeLines)))).toBeInTheDocument();
    expect(screen.getByText('Open')).toBeInTheDocument();
  });

  it('shows a Billed pill for converted job orders and keeps them in the list, visually muted', () => {
    const billed = draft({ id: 'd2', name: 'JO-072326-002', isConverted: true });
    harness([billed]);

    expect(screen.getByText('JO-072326-002')).toBeInTheDocument();
    expect(screen.getByText('Billed')).toBeInTheDocument();
    // Muted: the JO number itself carries the hint/muted text color once billed.
    expect(screen.getByText('JO-072326-002')).toHaveClass('text-light-text-hint');
  });

  it('keeps both open and converted rows in the same list', () => {
    const open = draft({ id: 'd1', name: 'JO-072326-001', isConverted: false });
    const billed = draft({ id: 'd2', name: 'JO-072326-002', isConverted: true });
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
});

describe('JobOrdersPage — pagination', () => {
  it('shows the pager once the job order list exceeds 25', () => {
    const many = Array.from({ length: 26 }, (_, i) => draft({ id: `d${i + 1}`, name: `JO-072326-${String(i + 1).padStart(3, '0')}` }));
    harness(many);

    expect(screen.getByText('1–25 of 26')).toBeInTheDocument();
  });

  it('hides the pager at exactly 25 job orders', () => {
    const exactly25 = Array.from({ length: 25 }, (_, i) => draft({ id: `d${i + 1}`, name: `JO-072326-${String(i + 1).padStart(3, '0')}` }));
    harness(exactly25);

    expect(screen.queryByText(/of 25/)).not.toBeInTheDocument();
  });
});
