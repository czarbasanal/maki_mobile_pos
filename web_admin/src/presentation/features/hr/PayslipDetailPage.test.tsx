import { describe, expect, it, vi } from 'vitest';
import { render, screen, waitFor } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { MemoryRouter, Routes, Route } from 'react-router-dom';
import { QueryClient, QueryClientProvider } from '@tanstack/react-query';
import { DiProvider, type Container } from '@/infrastructure/di/container';
import { PayslipDetailPage } from './PayslipDetailPage';
import type { Payslip } from '@/domain/hr/types';

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
}) {
  const qc = new QueryClient({ defaultOptions: { queries: { retry: false }, mutations: { retry: false } } });
  const payslipRepo: Partial<Container['payslipRepo']> = {
    getById: opts?.getById ?? vi.fn(async () => (opts?.payslip !== undefined ? opts.payslip : payslip())),
    delete: opts?.del ?? vi.fn(async () => {}),
  };

  return render(
    <DiProvider override={{ payslipRepo: payslipRepo as Container['payslipRepo'] }}>
      <QueryClientProvider client={qc}>
        <MemoryRouter initialEntries={['/hr/payslips/ps1']}>
          <Routes>
            <Route path="/hr/payslips/:id" element={<PayslipDetailPage />} />
            <Route path="/hr/payslips" element={<div>PAYSLIPS LIST</div>} />
          </Routes>
        </MemoryRouter>
      </QueryClientProvider>
    </DiProvider>,
  );
}

describe('PayslipDetailPage', () => {
  it('loads the payslip by route id and renders the PayslipCard', async () => {
    const getById = vi.fn(async (id: string) => payslip({ id }));
    harness({ getById });

    expect(await screen.findByText('NET PAY')).toBeInTheDocument();
    expect(getById).toHaveBeenCalledWith('ps1');
  });

  it('has a disabled Download JPG button', async () => {
    harness();

    await screen.findByText('NET PAY');
    expect(screen.getByRole('button', { name: /download jpg/i })).toBeDisabled();
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
});
