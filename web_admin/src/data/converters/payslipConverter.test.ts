import { describe, expect, it } from 'vitest';
import { Timestamp } from 'firebase/firestore';
import type { Payslip, PayslipDay, PayslipInputs, PayslipComputed } from '@/domain/hr/types';
import { payslipConverter } from './payslipConverter';

// Minimal fake snapshot — the converter only reads `.id` and `.data()`.
const snap = (id: string, data: Record<string, unknown>) =>
  ({ id, data: () => data }) as never;

const days: PayslipDay[] = [
  { date: '2026-07-20', status: 'present' },
  { date: '2026-07-21', status: 'present' },
  { date: '2026-07-22', status: 'present' },
  { date: '2026-07-23', status: 'present' },
  { date: '2026-07-24', status: 'present' },
  { date: '2026-07-25', status: 'present' },
  { date: '2026-07-26', status: 'dayOff' },
];

const inputs: PayslipInputs = {
  hoursWorked: 48,
  dailyRate: 640,
  overtimeHours: 2,
  overtimeRatePerHour: 100,
  regularHolidayDays: 0,
  specialHolidayDays: 0,
  regularHolidayPct: 100,
  specialHolidayPct: 30,
  incentives: 200,
  deductions: {
    sss: 100,
    philhealth: 50,
    pagibig: 20,
    late: 0,
    absences: 0,
    cashAdvance: 0,
    others: [{ label: 'Uniform', amount: 30 }],
  },
};

const computed: PayslipComputed = {
  hourlyRate: 80,
  basePay: 3840,
  overtimePay: 200,
  holidayPay: 0,
  gross: 4240,
  totalDeductions: 200,
  net: 4040,
};

describe('payslipConverter.toFirestore', () => {
  it('writes the full snapshot map verbatim, incl. nested deductions.others', () => {
    const p: Payslip = {
      id: 'ignored-on-write',
      employeeId: 'e1',
      employeeName: 'Juan',
      periodStart: '2026-07-20',
      periodEnd: '2026-07-26',
      days,
      inputs,
      computed,
      createdAt: null,
      createdBy: 'u1',
      createdByName: 'Admin',
    };
    expect(payslipConverter.toFirestore(p as never)).toEqual({
      employeeId: 'e1',
      employeeName: 'Juan',
      periodStart: '2026-07-20',
      periodEnd: '2026-07-26',
      days,
      inputs,
      computed,
      createdBy: 'u1',
      createdByName: 'Admin',
    });
  });
});

describe('payslipConverter.fromFirestore', () => {
  it('reads the full snapshot incl. nested deductions.others and createdAt', () => {
    const created = Timestamp.fromDate(new Date('2026-07-26T10:00:00Z'));
    const p = payslipConverter.fromFirestore(
      snap('p1', {
        employeeId: 'e1',
        employeeName: 'Juan',
        periodStart: '2026-07-20',
        periodEnd: '2026-07-26',
        days,
        inputs,
        computed,
        createdAt: created,
        createdBy: 'u1',
        createdByName: 'Admin',
      }),
    );
    expect(p).toEqual({
      id: 'p1',
      employeeId: 'e1',
      employeeName: 'Juan',
      periodStart: '2026-07-20',
      periodEnd: '2026-07-26',
      days,
      inputs,
      computed,
      createdAt: created.toDate(),
      createdBy: 'u1',
      createdByName: 'Admin',
    });
  });

  it('tolerates a missing others array and a missing days array', () => {
    const { others: _others, ...deductionsWithoutOthers } = inputs.deductions;
    const inputsWithoutOthers = { ...inputs, deductions: deductionsWithoutOthers };
    const p = payslipConverter.fromFirestore(
      snap('p2', {
        employeeId: 'e1',
        employeeName: 'Juan',
        periodStart: '2026-07-20',
        periodEnd: '2026-07-26',
        // days omitted entirely
        inputs: inputsWithoutOthers,
        computed,
        createdBy: 'u1',
        createdByName: 'Admin',
      }),
    );
    expect(p.days).toEqual([]);
    expect(p.inputs.deductions.others).toEqual([]);
    expect(p.createdAt).toBeNull();
  });

  it('defaults employeeId/employeeName/periodStart/periodEnd/createdBy/createdByName when missing', () => {
    const p = payslipConverter.fromFirestore(
      snap('p3', {
        inputs,
        computed,
      }),
    );
    expect(p.employeeId).toBe('');
    expect(p.employeeName).toBe('');
    expect(p.periodStart).toBe('');
    expect(p.periodEnd).toBe('');
    expect(p.createdBy).toBeNull();
    expect(p.createdByName).toBeNull();
  });
});
