import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';
import { render, screen, waitFor } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { MemoryRouter, Routes, Route, useParams } from 'react-router-dom';
import { QueryClient, QueryClientProvider } from '@tanstack/react-query';
import { DiProvider, type Container } from '@/infrastructure/di/container';
import { PayrollPage } from './PayrollPage';
import { useAuthStore } from '@/presentation/stores/authStore';
import { formatMoney } from '@/core/utils/money';
import { DEFAULT_HR_SETTINGS, type Employee, type HrSettings } from '@/domain/hr/types';

const employee = (o: Partial<Employee> = {}): Employee => ({
  id: 'e1',
  name: 'Juan',
  dailyRate: 640,
  isActive: true,
  weekStartDay: null,
  createdAt: null,
  updatedAt: null,
  ...o,
});

function PayslipStub() {
  const { id } = useParams();
  return <div>PAYSLIP PAGE {id}</div>;
}

function harness(opts?: {
  employees?: Employee[];
  settings?: HrSettings;
  create?: ReturnType<typeof vi.fn>;
}) {
  const qc = new QueryClient({ defaultOptions: { mutations: { retry: false } } });
  const employeeRepo: Partial<Container['employeeRepo']> = {
    watchAll: vi.fn((cb: (employees: Employee[]) => void) => {
      cb(opts?.employees ?? [employee()]);
      return () => {};
    }),
  };
  const hrSettingsRepo: Partial<Container['hrSettingsRepo']> = {
    get: vi.fn(async () => opts?.settings ?? { ...DEFAULT_HR_SETTINGS }),
  };
  const payslipRepo: Partial<Container['payslipRepo']> = {
    create: opts?.create ?? vi.fn(async () => 'ps1'),
  };

  useAuthStore.setState({
    status: 'signedIn',
    user: { id: 'u1', email: 'admin@maki.co', displayName: 'Admin', role: 'admin', isActive: true } as never,
  });

  return render(
    <DiProvider
      override={{
        employeeRepo: employeeRepo as Container['employeeRepo'],
        hrSettingsRepo: hrSettingsRepo as Container['hrSettingsRepo'],
        payslipRepo: payslipRepo as Container['payslipRepo'],
      }}
    >
      <QueryClientProvider client={qc}>
        <MemoryRouter initialEntries={['/hr/payroll']}>
          <Routes>
            <Route path="/hr/payroll" element={<PayrollPage />} />
            <Route path="/hr/payslips/:id" element={<PayslipStub />} />
          </Routes>
        </MemoryRouter>
      </QueryClientProvider>
    </DiProvider>,
  );
}

async function renderForm(opts?: Parameters<typeof harness>[0]) {
  const view = harness(opts);
  await waitFor(() => expect(screen.getByLabelText('Employee')).toBeInTheDocument());
  return view;
}

describe('PayrollPage', () => {
  beforeEach(() => {
    // 2026-07-22 is a Wednesday — fixes payPeriodFor(new Date(), weekStartDay)
    // to the same period payPeriod.test.ts already documents (Jul 20 - 26).
    vi.useFakeTimers({ toFake: ['Date'] });
    vi.setSystemTime(new Date(2026, 6, 22));
  });

  afterEach(() => {
    vi.useRealTimers();
  });

  it('picking an employee prefills the daily rate, and typing hours updates the live base pay', async () => {
    await renderForm();

    await userEvent.selectOptions(screen.getByLabelText('Employee'), 'e1');
    expect(screen.getByLabelText('Daily rate')).toHaveValue(640);

    await userEvent.type(screen.getByLabelText('Hours worked'), '48');

    await waitFor(() => expect(screen.getAllByText(formatMoney(3840)).length).toBeGreaterThan(0));
  });

  it('defaults the week-start-day select to settings.weekStartDay, then re-anchors the period when an employee with an override is picked', async () => {
    const withOverride = employee({ id: 'e2', name: 'Maria', weekStartDay: 3 });
    await renderForm({ employees: [employee(), withOverride] });

    expect(screen.getByLabelText('Week starts on')).toHaveValue('1');

    await userEvent.selectOptions(screen.getByLabelText('Employee'), 'e2');

    expect(screen.getByLabelText('Week starts on')).toHaveValue('3');
    // The mounted period is Mon 7/20 - Sun 7/26. Re-anchoring to a
    // Wednesday start is derived from that DISPLAYED period's own END
    // (7/26, a Sunday) — the most recent Wednesday on/before 7/26 is 7/22,
    // giving 7/22-7/28. End-anchoring (rather than start-anchoring)
    // guarantees the new window overlaps the displayed one; here it happens
    // to equal payPeriodFor(today, 3) too, since "today" (7/22) sits inside
    // the mounted period.
    const lastDay = screen.getByRole('button', { name: /7\/28/ });
    expect(lastDay).toHaveTextContent(/day off/i);
    // The old Mon-start period's first day (7/20) is outside the new window.
    expect(screen.queryByRole('button', { name: /7\/20/ })).not.toBeInTheDocument();
  });

  it('manually changing the week-start-day select re-derives the period window', async () => {
    await renderForm();

    expect(screen.getByRole('button', { name: /7\/26/ })).toHaveTextContent(/day off/i);

    await userEvent.selectOptions(screen.getByLabelText('Week starts on'), '3');

    // See the previous test: re-anchored from the displayed period's END
    // (7/26), giving 7/22-7/28.
    const lastDay = screen.getByRole('button', { name: /7\/28/ });
    expect(lastDay).toHaveTextContent(/day off/i);
    expect(screen.queryByRole('button', { name: /7\/20/ })).not.toBeInTheDocument();
  });

  it('navigating to next week then picking a no-override employee keeps the displayed period and grid taps', async () => {
    await renderForm();

    await userEvent.click(screen.getByRole('button', { name: 'Next week' }));
    // Shifted to the following week: Mon 7/27 - Sun 8/2.
    expect(screen.getByRole('button', { name: /8\/2/ })).toHaveTextContent(/day off/i);

    // Tap a day cell before switching employees, to prove the grid isn't reseeded.
    const firstDay = screen.getByRole('button', { name: /7\/27/ });
    expect(firstDay).toHaveTextContent(/present/i);
    await userEvent.click(firstDay);
    expect(firstDay).toHaveTextContent(/absent/i);

    // e1 has no weekStartDay override, so it resolves to settings.weekStartDay
    // (1) — the same as the current startDay. Picking it must not touch the
    // period or the grid at all.
    await userEvent.selectOptions(screen.getByLabelText('Employee'), 'e1');

    expect(screen.getByLabelText('Daily rate')).toHaveValue(640);
    expect(screen.getByLabelText('Week starts on')).toHaveValue('1');
    expect(screen.getByRole('button', { name: /7\/27/ })).toHaveTextContent(/absent/i);
    expect(screen.getByRole('button', { name: /8\/2/ })).toHaveTextContent(/day off/i);
    // The mount-time period's days must not have come back.
    expect(screen.queryByRole('button', { name: /7\/26/ })).not.toBeInTheDocument();
  });

  it('navigating to next week then picking an employee with a different override re-anchors from the displayed period, not today', async () => {
    const fridayOverride = employee({ id: 'e2', name: 'Maria', weekStartDay: 5 });
    await renderForm({ employees: [employee(), fridayOverride] });

    await userEvent.click(screen.getByRole('button', { name: 'Next week' }));
    // Shifted to the following week: Mon 7/27 - Sun 8/2.
    expect(screen.getByRole('button', { name: /8\/2/ })).toHaveTextContent(/day off/i);

    await userEvent.selectOptions(screen.getByLabelText('Employee'), 'e2');

    expect(screen.getByLabelText('Week starts on')).toHaveValue('5');
    // Re-anchored from the DISPLAYED period's END (8/2, the Sunday the
    // admin navigated to) — the most recent Friday on/before it is 7/31,
    // giving 7/31-8/6 (which overlaps the displayed 7/27-8/2 week by 3
    // days: 7/31, 8/1, 8/2). The mount-time-anchor bug would instead
    // reproduce payPeriodFor(today=7/22, 5) = 7/17-7/23, discarding the
    // navigation entirely; a start-anchored approach would instead produce
    // 7/24-7/30, a window that doesn't overlap the displayed week at all.
    expect(screen.getByRole('button', { name: /7\/31/ })).toBeInTheDocument();
    const lastDay = screen.getByRole('button', { name: /8\/6/ });
    expect(lastDay).toHaveTextContent(/day off/i);
    expect(screen.queryByRole('button', { name: /7\/17/ })).not.toBeInTheDocument();
    // Not the start-anchored result either.
    expect(screen.queryByRole('button', { name: /7\/24/ })).not.toBeInTheDocument();
    // Not simply left unchanged at the navigated Mon-start window.
    expect(screen.queryByRole('button', { name: /7\/27/ })).not.toBeInTheDocument();
  });

  it('cycles a day cell present -> absent -> dayOff -> present on click', async () => {
    await renderForm();

    // The last day of the seeded period (2026-07-26) defaults to "Day off".
    const lastDay = screen.getByRole('button', { name: /7\/26/ });
    expect(lastDay).toHaveTextContent(/day off/i);

    await userEvent.click(lastDay);
    expect(lastDay).toHaveTextContent(/present/i);

    await userEvent.click(lastDay);
    expect(lastDay).toHaveTextContent(/absent/i);

    await userEvent.click(lastDay);
    expect(lastDay).toHaveTextContent(/day off/i);
  });

  it('disables Generate until an employee is picked', async () => {
    await renderForm();

    expect(screen.getByRole('button', { name: /generate payslip/i })).toBeDisabled();
    await userEvent.selectOptions(screen.getByLabelText('Employee'), 'e1');
    expect(screen.getByRole('button', { name: /generate payslip/i })).toBeEnabled();
  });

  it('disables Generate when a numeric field goes negative', async () => {
    await renderForm();

    await userEvent.selectOptions(screen.getByLabelText('Employee'), 'e1');
    expect(screen.getByRole('button', { name: /generate payslip/i })).toBeEnabled();

    await userEvent.type(screen.getByLabelText('Incentives'), '-5');
    expect(screen.getByRole('button', { name: /generate payslip/i })).toBeDisabled();
  });

  it('creates the payslip with the frozen snapshot and navigates to the detail page', async () => {
    const create = vi.fn(async (_input: Parameters<Container['payslipRepo']['create']>[0]) => 'ps-99');
    await renderForm({ create });

    await userEvent.selectOptions(screen.getByLabelText('Employee'), 'e1');
    await userEvent.type(screen.getByLabelText('Hours worked'), '48');
    await userEvent.click(screen.getByRole('button', { name: /generate payslip/i }));

    await waitFor(() => expect(create).toHaveBeenCalledTimes(1));
    const arg = create.mock.calls[0][0];
    expect(arg.employeeId).toBe('e1');
    expect(arg.employeeName).toBe('Juan');
    expect(arg.periodStart).toBe('2026-07-20');
    expect(arg.periodEnd).toBe('2026-07-26');
    expect(arg.days).toHaveLength(7);
    expect(arg.computed.net).toBe(3840);
    expect(arg.createdBy).toBe('u1');
    expect(arg.createdByName).toBe('Admin');

    await waitFor(() => expect(screen.getByText(/PAYSLIP PAGE ps-99/)).toBeInTheDocument());
  });

  it('adds and removes a dynamic other-deduction row', async () => {
    await renderForm();

    await userEvent.click(screen.getByRole('button', { name: /^add$/i }));
    const labelInput = screen.getByLabelText('Other deduction label');
    const amountInput = screen.getByLabelText('Other deduction amount');
    await userEvent.type(labelInput, 'Load');
    await userEvent.type(amountInput, '100');
    expect(labelInput).toHaveValue('Load');

    await userEvent.click(screen.getByRole('button', { name: /remove other deduction/i }));
    expect(screen.queryByLabelText('Other deduction label')).not.toBeInTheDocument();
  });
});
