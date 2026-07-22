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
    // 2026-07-22 (the fixed "today") is itself a Wednesday, so a
    // Wednesday-start period begins and ends on it, not the previous Monday.
    const lastDay = screen.getByRole('button', { name: /7\/28/ });
    expect(lastDay).toHaveTextContent(/day off/i);
    // The old Mon-start period's first day (7/20) is outside the new window.
    expect(screen.queryByRole('button', { name: /7\/20/ })).not.toBeInTheDocument();
  });

  it('manually changing the week-start-day select re-derives the period window', async () => {
    await renderForm();

    expect(screen.getByRole('button', { name: /7\/26/ })).toHaveTextContent(/day off/i);

    await userEvent.selectOptions(screen.getByLabelText('Week starts on'), '3');

    const lastDay = screen.getByRole('button', { name: /7\/28/ });
    expect(lastDay).toHaveTextContent(/day off/i);
    // The old Mon-start period's first day (7/20) is outside the new window.
    expect(screen.queryByRole('button', { name: /7\/20/ })).not.toBeInTheDocument();
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
