import type { PayslipComputed, PayslipInputs } from './types';

export function computePayslip(i: PayslipInputs): PayslipComputed {
  const hourlyRate = i.dailyRate === 0 ? 0 : i.dailyRate / 8;
  const basePay = i.hoursWorked * hourlyRate;
  const overtimePay = i.overtimeHours * i.overtimeRatePerHour;
  const holidayPay =
    i.regularHolidayDays * i.dailyRate * (i.regularHolidayPct / 100) +
    i.specialHolidayDays * i.dailyRate * (i.specialHolidayPct / 100);
  const gross = basePay + overtimePay + holidayPay + i.incentives;
  const d = i.deductions;
  const totalDeductions =
    d.sss + d.philhealth + d.pagibig + d.late + d.absences + d.cashAdvance +
    d.others.reduce((s, o) => s + o.amount, 0);
  return { hourlyRate, basePay, overtimePay, holidayPay, gross, totalDeductions, net: gross - totalDeductions };
}
