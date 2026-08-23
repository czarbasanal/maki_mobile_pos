import { beforeEach, describe, expect, it, vi } from 'vitest';
import { render, screen, waitFor } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { MemoryRouter, Routes, Route } from 'react-router-dom';
import { QueryClient, QueryClientProvider } from '@tanstack/react-query';
import { DiProvider, type Container } from '@/infrastructure/di/container';
import { useAuthStore } from '@/presentation/stores/authStore';
import { PayslipDetailPage } from './PayslipDetailPage';
import { RoutePaths } from '@/presentation/router/routePaths';
import type { Payslip } from '@/domain/hr/types';
import { downloadElementAsJpg } from '@/core/utils/downloadJpg';

vi.mock('@/core/utils/downloadJpg', () => ({
  downloadElementAsJpg: vi.fn(async () => {}),
}));

const payslip = (overrides: Partial<Payslip> = {}): Payslip => ({
  id: 'ps1',
  employeeId: 'e1',
  employeeName: 'Juan Dela Cruz',
  periodStart: '2026-07-20',
  periodEnd: '2026-07-26',
  days: [
    { date: '2026-07-20', status: 'present' },
    { date: '2026-07-21', status: 'present' },
    { date: '2026-07-22', status: 'present' },
    { date: '2026-07-23', status: 'present' },
    { date: '2026-07-24', status: 'present' },
    { date: '2026-07-25', status: 'present' },
    { date: '2026-07-26', status: 'dayOff' },
  ],
  inputs: {
    hoursWorked: 48,
    dailyRate: 640,
    overtimeHours: 5,
    overtimeRatePerHour: 100,
    regularHolidayDays: 1,
    specialHolidayDays: 2,
    regularHolidayPct: 100,
    specialHolidayPct: 30,
    incentives: 200,
    deductions: { sss: 45, philhealth: 50, pagibig: 25, late: 0, absences: 0, cashAdvance: 500, others: [] },
  },
  computed: {
    hourlyRate: 80,
    basePay: 3840,
    overtimePay: 500,
    holidayPay: 1024,
    gross: 5564,
    totalDeductions: 620,
    net: 4944,
  },
  createdAt: new Date(2026, 6, 22),
  createdBy: 'u1',
  createdByName: 'Admin',
  ...overrides,
});

function harness(opts?: {
  payslip?: Payslip | null;
  getById?: ReturnType<typeof vi.fn>;
  del?: ReturnType<typeof vi.fn>;
 activityLog?: ReturnType<typeof vi.fn>; }) {
  const qc = new QueryClient({ defaultOptions: { queries: { retry: false }, mutations: { retry: false } } });
  const payslipRepo: Partial<Container['payslipRepo']> = {
    getById: opts?.getById ?? vi.fn(async () => (opts?.payslip !== undefined ? opts.payslip : payslip())),
    delete: opts?.del ?? vi.fn(async () => {}),
  };

  return render(
    <DiProvider
      override={{
        payslipRepo: payslipRepo as Container['payslipRepo'],
        activityLogRepo: { log: opts?.activityLog ?? vi.fn(async () => undefined) } as unknown as Container['activityLogRepo'],
      }}
    >
      <QueryClientProvider client={qc}>
        <MemoryRouter initialEntries={[`${RoutePaths.hrPayslips}/ps1`]}>
          <Routes>
            <Route path={RoutePaths.hrPayslipDetail} element={<PayslipDetailPage />} />
            <Route path={RoutePaths.hrPayslips} element={<div>PAYSLIPS LIST</div>} />
          </Routes>
        </MemoryRouter>
      </QueryClientProvider>
    </DiProvider>,
  );
}

describe('PayslipDetailPage', () => {
  beforeEach(() => {
    vi.mocked(downloadElementAsJpg).mockClear();
  });

  it('loads the payslip by route id and renders the PayslipCard', async () => {
    const getById = vi.fn(async (id: string) => payslip({ id }));
    harness({ getById });

    expect(await screen.findByText('NET PAY')).toBeInTheDocument();
    expect(getById).toHaveBeenCalledWith('ps1');
  });

  it('has an enabled Download JPG button that downloads the card as a JPG', async () => {
    harness();

    await screen.findByText('NET PAY');
    const button = screen.getByRole('button', { name: /download jpg/i });
    expect(button).toBeEnabled();

    await userEvent.click(button);

    await waitFor(() => expect(downloadElementAsJpg).toHaveBeenCalledTimes(1));
    const [el, filename] = vi.mocked(downloadElementAsJpg).mock.calls[0];
    expect(el).toBeInstanceOf(HTMLElement);
    expect(el.textContent).toContain('NET PAY');
    expect(filename).toBe('payslip-juan-dela-cruz-2026-07-20.jpg');
  });

  it('slugifies the employee name for the filename (non-alphanumerics collapse to a single dash, edges trimmed)', async () => {
    const getById = vi.fn(async (id: string) =>
      payslip({ id, employeeName: '  Ana   O’Brien-Santos!! ' }),
    );
    harness({ getById });

    await screen.findByText('NET PAY');
    await userEvent.click(screen.getByRole('button', { name: /download jpg/i }));

    await waitFor(() => expect(downloadElementAsJpg).toHaveBeenCalledTimes(1));
    const [, filename] = vi.mocked(downloadElementAsJpg).mock.calls[0];
    expect(filename).toBe('payslip-ana-o-brien-santos-2026-07-20.jpg');
  });

  it('deletes the payslip on confirm and navigates back to the list', async () => {
    const del = vi.fn(async () => {});
    harness({ del });

    await screen.findByText('NET PAY');
    await userEvent.click(screen.getByRole('button', { name: /delete payslip/i }));
    await userEvent.click(screen.getByRole('button', { name: /^delete$/i }));

    await waitFor(() => expect(del).toHaveBeenCalledWith('ps1'));
    expect(await screen.findByText('PAYSLIPS LIST')).toBeInTheDocument();
  });

  it('cancels out of the delete confirmation without calling the repo', async () => {
    const del = vi.fn(async () => {});
    harness({ del });

    await screen.findByText('NET PAY');
    await userEvent.click(screen.getByRole('button', { name: /delete payslip/i }));
    await userEvent.click(screen.getByRole('button', { name: /^cancel$/i }));

    expect(screen.queryByRole('button', { name: /^delete$/i })).not.toBeInTheDocument();
    expect(del).not.toHaveBeenCalled();
  });

  it('shows a not-found state when the payslip does not exist', async () => {
    harness({ payslip: null });

    expect(await screen.findByText(/not found/i)).toBeInTheDocument();
  });

  it('renders PageHeader with back link to payslips and title in the same header', async () => {
    harness();

    await screen.findByText('NET PAY');

    const backLink = screen.getByRole('link', { name: /back to payslips/i });
    const header = backLink.closest('header');

    expect(header).toBeInTheDocument();
    const h1 = header?.querySelector('h1');
    expect(h1).toHaveTextContent('Juan Dela Cruz');
    expect(backLink).toHaveAttribute('href', RoutePaths.hrPayslips);
  });
});

describe('payslip delete activity logging', () => {
  it('deleting a payslip writes a user_management entry', async () => {
    const activityLog = vi.fn(async (_entry: unknown) => undefined);
    const del = vi.fn(async () => {});
    // logActivity silently no-ops with no signed-in user — sign in as the
    // admin who would actually be deleting.
    useAuthStore.setState({
      status: 'signedIn',
      user: { id: 'u1', email: 'a@b.co', displayName: 'Admin', role: 'admin', isActive: true } as never,
    });
    harness({ del, activityLog });

    await screen.findByText('NET PAY');
    await userEvent.click(screen.getByRole('button', { name: /delete payslip/i }));
    await userEvent.click(screen.getByRole('button', { name: /^delete$/i }));

    await waitFor(() => expect(activityLog).toHaveBeenCalled());
    const entry = activityLog.mock.calls[0][0] as unknown as { type: string; action: string };
    expect(entry.type).toBe('user_management');
    expect(entry.action.toLowerCase()).toContain('deleted payslip');
  });
});

describe('payslip JPG download — feedback and names', () => {
  it('keeps diacritics as letters in the filename instead of dropping them', async () => {
    // 'Muñoz' used to slugify to 'mu-oz' — names are the one thing a payslip
    // is about, so ñ→n, é→e rather than a hole.
    harness({ payslip: payslip({ employeeName: 'Ana Muñoz' }) });
    await screen.findByText('NET PAY');

    await userEvent.click(screen.getByRole('button', { name: /download jpg/i }));

    await waitFor(() => expect(downloadElementAsJpg).toHaveBeenCalled());
    const [, filename] = vi.mocked(downloadElementAsJpg).mock.calls[0];
    expect(filename).toContain('ana-munoz');
  });

  it('shows a busy state while the JPG renders and re-enables after', async () => {
    let resolveRender!: () => void;
    vi.mocked(downloadElementAsJpg).mockReturnValueOnce(
      new Promise<void>((res) => { resolveRender = res; }),
    );
    harness();
    await screen.findByText('NET PAY');

    await userEvent.click(screen.getByRole('button', { name: /download jpg/i }));

    const busy = screen.getByRole('button', { name: /preparing/i });
    expect(busy).toBeDisabled();

    resolveRender();
    await waitFor(() =>
      expect(screen.getByRole('button', { name: /download jpg/i })).not.toBeDisabled(),
    );
  });

  it('surfaces a failed render instead of silently doing nothing', async () => {
    vi.mocked(downloadElementAsJpg).mockRejectedValueOnce(new Error('canvas boom'));
    harness();
    await screen.findByText('NET PAY');

    await userEvent.click(screen.getByRole('button', { name: /download jpg/i }));

    expect(
      await screen.findByText(/could not create the jpg/i),
    ).toBeInTheDocument();
  });
});

