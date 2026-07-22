import { describe, expect, it, vi } from 'vitest';
import { render, screen } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { MemoryRouter, Routes, Route, useParams } from 'react-router-dom';
import { DiProvider, type Container } from '@/infrastructure/di/container';
import { PayslipsPage } from './PayslipsPage';
import { formatMoney } from '@/core/utils/money';
import type { Payslip } from '@/domain/hr/types';

const payslip = (overrides: Partial<Payslip> = {}): Payslip => ({
  id: 'ps1',
  employeeId: 'e1',
  employeeName: 'Juan Dela Cruz',
  periodStart: '2026-07-20',
  periodEnd: '2026-07-26',
  days: [],
  inputs: {
    hoursWorked: 48,
    dailyRate: 640,
    overtimeHours: 0,
    overtimeRatePerHour: 0,
    regularHolidayDays: 0,
    specialHolidayDays: 0,
    regularHolidayPct: 100,
    specialHolidayPct: 30,
    incentives: 0,
    deductions: { sss: 0, philhealth: 0, pagibig: 0, late: 0, absences: 0, cashAdvance: 0, others: [] },
  },
  computed: {
    hourlyRate: 80,
    basePay: 3840,
    overtimePay: 0,
    holidayPay: 0,
    gross: 3840,
    totalDeductions: 0,
    net: 3840,
  },
  createdAt: new Date(2026, 6, 22),
  createdBy: 'u1',
  createdByName: 'Admin',
  ...overrides,
});

function DetailStub() {
  const { id } = useParams();
  return <div>PAYSLIP DETAIL {id}</div>;
}

function harness(opts?: { payslips?: Payslip[] }) {
  const payslipRepo: Partial<Container['payslipRepo']> = {
    watchAll: vi.fn((cb: (payslips: Payslip[]) => void) => {
      cb(opts?.payslips ?? [payslip()]);
      return () => {};
    }),
  };

  return render(
    <DiProvider override={{ payslipRepo: payslipRepo as Container['payslipRepo'] }}>
      <MemoryRouter initialEntries={['/hr/payslips']}>
        <Routes>
          <Route path="/hr/payslips" element={<PayslipsPage />} />
          <Route path="/hr/payslips/:id" element={<DetailStub />} />
        </Routes>
      </MemoryRouter>
    </DiProvider>,
  );
}

describe('PayslipsPage', () => {
  it('renders rows from watchAll with period, employee, gross, and net', () => {
    harness({
      payslips: [
        payslip({ id: 'ps1', employeeName: 'Juan Dela Cruz', computed: { ...payslip().computed, gross: 5564, net: 4844 } }),
        payslip({ id: 'ps2', employeeName: 'Maria Santos', periodStart: '2026-07-13', periodEnd: '2026-07-19' }),
      ],
    });

    expect(screen.getByText('Juan Dela Cruz')).toBeInTheDocument();
    expect(screen.getByText(formatMoney(5564))).toBeInTheDocument();
    expect(screen.getByText(formatMoney(4844))).toBeInTheDocument();
    expect(screen.getByText('Maria Santos')).toBeInTheDocument();
  });

  it('navigates to the detail page on row click', async () => {
    harness({ payslips: [payslip({ id: 'ps-7', employeeName: 'Juan Dela Cruz' })] });

    await userEvent.click(screen.getByText('Juan Dela Cruz'));

    expect(await screen.findByText('PAYSLIP DETAIL ps-7')).toBeInTheDocument();
  });

  it('shows an empty state with no payslips', () => {
    harness({ payslips: [] });

    expect(screen.getByText(/no payslips/i)).toBeInTheDocument();
  });
});
