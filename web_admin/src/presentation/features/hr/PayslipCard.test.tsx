import { describe, expect, it } from 'vitest';
import { render, screen } from '@testing-library/react';
import { PayslipCard } from './PayslipCard';
import { formatMoney } from '@/core/utils/money';
import type { Payslip } from '@/domain/hr/types';

// Mirrors computePayslip.test.ts's BASE worked example (640 daily rate, 48h,
// 5 OT hours @100, 1 regular + 2 special holiday days, 200 incentives,
// deductions 45+50+25+0+0+500 + others) -> net 4844. The `others` list adds a
// second, zero-amount row so the test can assert every `others` row renders
// even when standard zero-value lines (Late, Absences) are omitted.
// NOTE: overtimePay (5*100=500) and cashAdvance (500) collide in value —
// deliberately, since that's the spec's worked example — so tests that need
// to tell those two rows apart scope their query to the row, not the value.
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
    deductions: {
      sss: 45,
      philhealth: 50,
      pagibig: 25,
      late: 0,
      absences: 0,
      cashAdvance: 500,
      others: [
        { label: 'Load', amount: 100 },
        { label: 'Uniform', amount: 0 },
      ],
    },
  },
  computed: {
    hourlyRate: 80,
    basePay: 3840,
    overtimePay: 500,
    holidayPay: 1024,
    gross: 5564,
    totalDeductions: 720,
    net: 4844,
  },
  createdAt: new Date(2026, 6, 22),
  createdBy: 'u1',
  createdByName: 'Admin',
  ...overrides,
});

// A row is `<div><span><span>{label}</span>[caption]</span><span>{value}</span></div>` —
// find the label's own leaf span, then read the whole row's text.
function rowText(label: string): string {
  return screen.getByText(label).closest('div')?.textContent ?? '';
}

describe('PayslipCard', () => {
  it('renders the shop header, employee, and period', () => {
    render(<PayslipCard payslip={payslip()} />);

    expect(screen.getByText('MAKI MOTORCYCLE PARTS & SERVICES')).toBeInTheDocument();
    expect(screen.getByText('Juan Dela Cruz')).toBeInTheDocument();
  });

  it('renders the 7-cell attendance mini-row (present/day-off)', () => {
    render(<PayslipCard payslip={payslip()} />);

    expect(screen.getAllByText('✓')).toHaveLength(6);
    expect(screen.getByText('off')).toBeInTheDocument();
  });

  it('renders an absent day as ✗', () => {
    const withAbsence = payslip({
      days: [
        { date: '2026-07-20', status: 'absent' },
        { date: '2026-07-21', status: 'present' },
        { date: '2026-07-22', status: 'present' },
        { date: '2026-07-23', status: 'present' },
        { date: '2026-07-24', status: 'present' },
        { date: '2026-07-25', status: 'present' },
        { date: '2026-07-26', status: 'dayOff' },
      ],
    });
    render(<PayslipCard payslip={withAbsence} />);

    expect(screen.getByText('✗')).toBeInTheDocument();
  });

  it('renders the earnings table including the Base Pay hours×rate caption', () => {
    render(<PayslipCard payslip={payslip()} />);

    expect(screen.getByText('Base Pay')).toBeInTheDocument();
    expect(screen.getByText('48h × ₱80.00/hr')).toBeInTheDocument();
    expect(rowText('Overtime')).toContain(formatMoney(500));
    expect(rowText('Holiday Pay')).toContain(formatMoney(1024));
    expect(rowText('Incentives')).toContain(formatMoney(200));
    expect(screen.getByText(formatMoney(3840))).toBeInTheDocument();
  });

  it('worked example: NET PAY renders ₱4,844.00, zero-value deduction rows are omitted, and both others labels render', () => {
    render(<PayslipCard payslip={payslip()} />);

    // NET PAY, emphasized.
    expect(screen.getByText('NET PAY')).toBeInTheDocument();
    expect(formatMoney(4844)).toBe('₱4,844.00');
    expect(screen.getByText('₱4,844.00')).toBeInTheDocument();

    // Gross / total deductions.
    expect(screen.getByText(formatMoney(5564))).toBeInTheDocument();
    expect(screen.getByText(formatMoney(720))).toBeInTheDocument();

    // Nonzero standard deduction lines render.
    expect(rowText('SSS')).toContain(formatMoney(45));
    expect(rowText('PhilHealth')).toContain(formatMoney(50));
    expect(rowText('Pag-IBIG')).toContain(formatMoney(25));
    expect(rowText('Cash advance')).toContain(formatMoney(500));

    // Zero-value standard deduction lines (Late, Absences) are omitted.
    expect(screen.queryByText('Late')).not.toBeInTheDocument();
    expect(screen.queryByText('Absences')).not.toBeInTheDocument();

    // Every `others` row renders — including the zero-amount one.
    expect(rowText('Load')).toContain(formatMoney(100));
    expect(rowText('Uniform')).toContain(formatMoney(0));
  });

  it('omits the whole deductions section gracefully when there are no deduction lines at all', () => {
    const base = payslip();
    const noDeductions = payslip({
      inputs: {
        ...base.inputs,
        deductions: {
          sss: 0,
          philhealth: 0,
          pagibig: 0,
          late: 0,
          absences: 0,
          cashAdvance: 0,
          others: [],
        },
      },
      computed: { ...base.computed, totalDeductions: 0, net: base.computed.gross },
    });
    render(<PayslipCard payslip={noDeductions} />);

    expect(screen.queryByText('SSS')).not.toBeInTheDocument();
    expect(screen.queryByText('Cash advance')).not.toBeInTheDocument();
    expect(rowText('Total Deductions')).toContain(formatMoney(0));
  });

  it('renders the footer caption with the generated date', () => {
    render(<PayslipCard payslip={payslip()} />);

    expect(screen.getByText('Generated Jul 22, 2026')).toBeInTheDocument();
  });
});
