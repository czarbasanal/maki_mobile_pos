import { describe, expect, it } from 'vitest';
import { computePayslip } from './computePayslip';
import type { PayslipInputs } from './types';

const BASE: PayslipInputs = {
  hoursWorked: 48, dailyRate: 640,
  overtimeHours: 5, overtimeRatePerHour: 100,
  regularHolidayDays: 1, specialHolidayDays: 2,
  regularHolidayPct: 100, specialHolidayPct: 30,
  incentives: 200,
  deductions: { sss: 45, philhealth: 50, pagibig: 25, late: 0, absences: 0, cashAdvance: 500, others: [{ label: 'Load', amount: 100 }] },
};

describe('computePayslip', () => {
  it('computes the worked example end-to-end', () => {
    const c = computePayslip(BASE);
    expect(c.hourlyRate).toBe(80);        // 640/8
    expect(c.basePay).toBe(3840);         // 48*80
    expect(c.overtimePay).toBe(500);      // 5*100
    expect(c.holidayPay).toBe(1024);      // 1*640*1.0 + 2*640*0.3 = 640+384
    expect(c.gross).toBe(5564);           // 3840+500+1024+200
    expect(c.totalDeductions).toBe(720);  // 45+50+25+0+0+500+100
    expect(c.net).toBe(4844);
  });

  it('all-zero inputs yield all-zero outputs', () => {
    const zero: PayslipInputs = {
      hoursWorked: 0, dailyRate: 0, overtimeHours: 0, overtimeRatePerHour: 0,
      regularHolidayDays: 0, specialHolidayDays: 0, regularHolidayPct: 100, specialHolidayPct: 30,
      incentives: 0,
      deductions: { sss: 0, philhealth: 0, pagibig: 0, late: 0, absences: 0, cashAdvance: 0, others: [] },
    };
    const c = computePayslip(zero);
    expect(c).toEqual({ hourlyRate: 0, basePay: 0, overtimePay: 0, holidayPay: 0, gross: 0, totalDeductions: 0, net: 0 });
  });

  it('net can go negative when deductions exceed gross', () => {
    const c = computePayslip({ ...BASE, hoursWorked: 0, overtimeHours: 0, regularHolidayDays: 0, specialHolidayDays: 0, incentives: 0 });
    expect(c.gross).toBe(0);
    expect(c.net).toBe(-720);
  });
});
