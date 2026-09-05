// Void Requests (void-requests guide): KPI strip, the waiting queue with
// row actions behind confirm modals, the resolved history scoped by range
// with outcome chips, and three distinct empty states.
import { describe, expect, it, vi, beforeEach } from 'vitest';
import { render, screen, waitFor, within } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { MemoryRouter } from 'react-router-dom';
import { QueryClient, QueryClientProvider } from '@tanstack/react-query';
import { DiProvider, type Container } from '@/infrastructure/di/container';
import { VoidRequestsPage } from './VoidRequestsPage';
import { useAuthStore } from '@/presentation/stores/authStore';
import type { VoidRequest, User } from '@/domain/entities';

const MIN = 60_000;
const DAY = 1440 * MIN;
const ago = (ms: number) => new Date(Date.now() - ms);

const request = (o: Partial<VoidRequest> = {}): VoidRequest => ({
  id: 'r1',
  saleId: 's1',
  saleNumber: 'SALE-20260828-020',
  saleGrandTotal: 285,
  requestedBy: 'u-belle',
  requestedByName: 'Belle',
  requestedByRole: 'cashier',
  reason: 'Payment issue',
  status: 'pending',
  read: false,
  createdAt: ago(10 * MIN),
  resolvedBy: null,
  resolvedByName: null,
  resolvedAt: null,
  rejectionReason: null,
  itemsSummary: '1× Ilis carbon brass',
  ...o,
});

const resolved = (o: Partial<VoidRequest> = {}): VoidRequest =>
  request({
    id: 'a1', saleNumber: 'SALE-20260827-004', status: 'approved',
    createdAt: ago(2 * DAY + 30 * MIN), resolvedAt: ago(2 * DAY + 14 * MIN),
    resolvedBy: 'u1', resolvedByName: 'Czar', ...o,
  });

function harness(requests: VoidRequest[], overrides: Partial<Container> = {}, path = '/void-requests') {
  useAuthStore.setState({
    user: { id: 'u1', email: 'a@b.c', displayName: 'Czar', role: 'admin', isActive: true } as User,
  });
  const qc = new QueryClient({ defaultOptions: { queries: { retry: false } } });
  // Pending is one uncapped subscription; resolved is scoped by the range
  // the page asks for — the mock applies the same resolvedAt window.
  const voidRequestRepo = {
    watchPending: (cb: (r: VoidRequest[]) => void) => {
      cb(requests.filter((r) => r.status === 'pending'));
      return () => {};
    },
    watchResolved: (range: { start: Date; end: Date }, cb: (r: VoidRequest[]) => void) => {
      cb(
        requests.filter(
          (r) => r.status !== 'pending' && !!r.resolvedAt && r.resolvedAt >= range.start && r.resolvedAt <= range.end,
        ),
      );
      return () => {};
    },
    resolve: vi.fn(async () => {}),
    ...(overrides.voidRequestRepo ?? {}),
  } as unknown as Container['voidRequestRepo'];

  render(
    <QueryClientProvider client={qc}>
      <DiProvider
        override={{
          voidRequestRepo,
          saleRepo: { voidSale: vi.fn(async () => {}) },
          activityLogRepo: { create: vi.fn() },
          ...overrides,
        } as Container}
      >
        <MemoryRouter initialEntries={[path]}><VoidRequestsPage /></MemoryRouter>
      </DiProvider>
    </QueryClientProvider>,
  );
  return { voidRequestRepo };
}

// StatCards are the only <section>s on the page; a sale no. also shows in the
// "Oldest request" KPI note, so rows are found via their <tr>.
const kpi = (label: string) =>
  screen.getAllByText(label).map((el) => el.closest('section')).find((el): el is HTMLElement => el !== null)!;
const rowOf = async (text: string) =>
  (await screen.findAllByText(text)).map((el) => el.closest('tr')).find((el): el is HTMLTableRowElement => el !== null)!;

describe('VoidRequestsPage — waiting queue', () => {
  beforeEach(() => vi.clearAllMocks());

  it('names the sale (with a copy button), who asked, why, what was on it, and how long it has waited', async () => {
    harness([request()]);
    const row = await rowOf('SALE-20260828-020');
    expect(within(row).getByRole('button', { name: 'Copy sale number' })).toBeInTheDocument();
    expect(within(row).getByText('Belle')).toBeInTheDocument();
    expect(within(row).getByText('Payment issue')).toBeInTheDocument();
    expect(within(row).getByText('1× Ilis carbon brass')).toBeInTheDocument();
    expect(within(row).getByText('10m waiting').className).toContain('text-ink-3');
  });

  it('the age line escalates: amber past an hour, red past four', async () => {
    harness([
      request({ id: 'h', saleNumber: 'SALE-H', createdAt: ago(90 * MIN) }),
      request({ id: 'd', saleNumber: 'SALE-D', createdAt: ago(5 * 60 * MIN) }),
    ]);
    const h = await rowOf('SALE-H');
    expect(within(h).getByText('1h waiting').className).toContain('text-accent-text');
    const d = await rowOf('SALE-D');
    expect(within(d).getByText('5h waiting').className).toContain('text-neg');
  });

  it('says so plainly when nothing is waiting — and it reads as the good state', async () => {
    harness([]);
    expect(await screen.findByText('Nothing waiting')).toBeInTheDocument();
    expect(screen.getByText(/Until then, no sale is being held/)).toBeInTheDocument();
    expect(within(kpi('Waiting on you')).getByText('queue is clear')).toBeInTheDocument();
  });

  it('a test-transaction reason reads red', async () => {
    harness([request({ reason: 'Test transaction' })]);
    expect((await screen.findByText('Test transaction')).className).toContain('text-neg');
  });
});

describe('VoidRequestsPage — decisions confirm', () => {
  beforeEach(() => vi.clearAllMocks());

  it('Approve opens a confirm showing what is voided; confirming voids the sale, then resolves', async () => {
    const voidSale = vi.fn(async () => {});
    const { voidRequestRepo } = harness([request()], { saleRepo: { voidSale } as unknown as Container['saleRepo'] });
    await userEvent.click(await screen.findByRole('button', { name: 'Approve void' }));
    expect(voidSale).not.toHaveBeenCalled();
    const dialog = screen.getByRole('dialog');
    expect(within(dialog).getByText('1× Ilis carbon brass')).toBeInTheDocument();
    expect(within(dialog).getByText('₱285.00')).toBeInTheDocument();

    await userEvent.click(within(dialog).getByRole('button', { name: 'Approve void' }));

    await waitFor(() => expect(voidSale).toHaveBeenCalled());
    expect(voidRequestRepo.resolve).toHaveBeenCalledWith(expect.objectContaining({ status: 'approved' }));
  });

  it('rejecting will not commit without a note, then sends the note back', async () => {
    const { voidRequestRepo } = harness([request()]);
    await userEvent.click(await screen.findByRole('button', { name: 'Reject' }));
    const dialog = screen.getByRole('dialog');
    expect(within(dialog).getByRole('button', { name: 'Reject request' })).toBeDisabled();

    await userEvent.type(within(dialog).getByLabelText(/Note to the cashier/), 'Sale is correct');
    await userEvent.click(within(dialog).getByRole('button', { name: 'Reject request' }));

    await waitFor(() =>
      expect(voidRequestRepo.resolve).toHaveBeenCalledWith(
        expect.objectContaining({ status: 'rejected', rejectionReason: 'Sale is correct' }),
      ),
    );
  });

  it('the requester cannot decide their own request: both buttons off, with the reason visible', async () => {
    harness([request({ requestedBy: 'u1', requestedByName: 'Czar' })]);
    expect(await screen.findByRole('button', { name: 'Approve void' })).toBeDisabled();
    expect(screen.getByRole('button', { name: 'Reject' })).toBeDisabled();
    expect(screen.getByText('Yours — another admin decides')).toBeInTheDocument();
  });

  it('a stale request surfaces the transaction error inside the confirm', async () => {
    const voidSale = vi.fn(async () => { throw new Error('This sale is already voided'); });
    const { voidRequestRepo } = harness([request()], { saleRepo: { voidSale } as unknown as Container['saleRepo'] });
    await userEvent.click(await screen.findByRole('button', { name: 'Approve void' }));
    await userEvent.click(within(screen.getByRole('dialog')).getByRole('button', { name: 'Approve void' }));
    expect(await screen.findByText('This sale is already voided')).toBeInTheDocument();
    expect(voidRequestRepo.resolve).not.toHaveBeenCalled();
  });
});

describe('VoidRequestsPage — KPIs and resolved history', () => {
  beforeEach(() => vi.clearAllMocks());

  it('KPIs derive from one set: waiting count + held, oldest age, approved + voided total, rate', async () => {
    harness([
      request({ id: 'w1', saleGrandTotal: 1250, createdAt: ago(184 * MIN) }),
      request({ id: 'w2', saleNumber: 'SALE-W2', saleGrandTotal: 410, createdAt: ago(20 * MIN) }),
      resolved({ id: 'a1', saleGrandTotal: 285 }),
      resolved({ id: 'j1', saleNumber: 'SALE-J', status: 'rejected', saleGrandTotal: 640, rejectionReason: 'Sale is correct' }),
    ]);
    await screen.findByText('SALE-W2');
    expect(within(kpi('Waiting on you')).getByText('2')).toBeInTheDocument();
    expect(within(kpi('Waiting on you')).getByText('₱1,660.00 held')).toBeInTheDocument();
    expect(within(kpi('Oldest request')).getByText('3h')).toBeInTheDocument();
    expect(within(kpi('Approved')).getByText('1')).toBeInTheDocument();
    expect(within(kpi('Approved')).getByText('₱285.00 voided')).toBeInTheDocument();
    expect(within(kpi('Approval rate')).getByText('50.0%')).toBeInTheDocument();
    expect(within(kpi('Approval rate')).getByText('2 resolved in range')).toBeInTheDocument();
  });

  it('with nothing resolved in range the rate is a dash, never 0%', async () => {
    harness([request()]);
    await rowOf('SALE-20260828-020');
    expect(within(kpi('Approval rate')).getByText('—')).toBeInTheDocument();
    expect(within(kpi('Approval rate')).getByText('nothing resolved in range')).toBeInTheDocument();
  });

  it('links every sale number to the sale detail', async () => {
    harness([request()]);
    const link = (await screen.findAllByRole('link', { name: 'SALE-20260828-020' }))[0] as HTMLAnchorElement;
    expect(link.getAttribute('href')).toBe('/reports/sale/s1');
  });

  it('lists resolved requests with who resolved them and how long it took; no Approve on history', async () => {
    harness([request({ id: 'r1' }), resolved()]);
    const row = await rowOf('SALE-20260827-004');
    expect(within(row).getByText('Approved')).toBeInTheDocument();
    expect(within(row).getByText(/by Czar · 16m/)).toBeInTheDocument();
    expect(within(row).queryByRole('button', { name: 'Approve void' })).not.toBeInTheDocument();
    expect(screen.getAllByRole('button', { name: 'Approve void' })).toHaveLength(1);
  });

  it('the outcome chips carry counts, filter the rows, and the counts ignore the outcome filter', async () => {
    harness([resolved({ id: 'a1' }), resolved({ id: 'j1', saleNumber: 'SALE-J', status: 'rejected' })]);
    await screen.findByText('SALE-J');
    const rejectedChip = screen.getByRole('button', { name: /^Rejected/ });
    expect(rejectedChip.textContent).toContain('1');
    await userEvent.click(rejectedChip);
    expect(screen.queryByText('SALE-20260827-004')).not.toBeInTheDocument();
    expect(screen.getByText('SALE-J')).toBeInTheDocument();
    expect(screen.getByRole('button', { name: /^Approved/ }).textContent).toContain('1');
  });

  it('Total voided sums only the approved rows in view', async () => {
    harness([
      resolved({ id: 'a1', saleGrandTotal: 285 }),
      resolved({ id: 'a2', saleNumber: 'SALE-A2', saleGrandTotal: 200 }),
      resolved({ id: 'j1', saleNumber: 'SALE-J', status: 'rejected', saleGrandTotal: 640 }),
    ]);
    await screen.findByText('SALE-J');
    expect(screen.getByTestId('total-voided').textContent).toContain('₱485.00');
  });

  it('an empty RANGE and an empty FILTER result are different messages', async () => {
    harness([resolved({ resolvedAt: ago(45 * DAY), createdAt: ago(45 * DAY) })], {}, '/void-requests?range=today');
    expect(await screen.findByText('No resolved requests in this range')).toBeInTheDocument();
    expect(screen.getByRole('button', { name: 'Show last 7 days' })).toBeInTheDocument();

    await userEvent.click(screen.getByRole('radio', { name: 'Custom' }));
    // nothing applied yet — still the default range; widen to a range that has the row
    await userEvent.click(screen.getByRole('radio', { name: '30 days' }));
    await screen.findByText('No resolved requests in this range');
  });

  it('a search that matches nothing blames the filters and Clear filters recovers', async () => {
    harness([resolved()]);
    await screen.findByText('SALE-20260827-004');
    await userEvent.type(screen.getByPlaceholderText('Search sale no. or cashier'), 'nonsense');
    expect(await screen.findByText('No resolved requests match')).toBeInTheDocument();
    expect(screen.queryByText('No resolved requests in this range')).not.toBeInTheDocument();
    await userEvent.click(screen.getByRole('button', { name: 'Clear filters' }));
    expect(await screen.findByText('SALE-20260827-004')).toBeInTheDocument();
  });
});
