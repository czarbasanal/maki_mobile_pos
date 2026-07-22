export type DayStatus = 'present' | 'absent' | 'dayOff';
export interface PayslipDay { date: string; status: DayStatus }
export interface OtherDeduction { label: string; amount: number }
export interface PayslipDeductions {
  sss: number; philhealth: number; pagibig: number;
  late: number; absences: number; cashAdvance: number;
  others: OtherDeduction[];
}
export interface PayslipInputs {
  hoursWorked: number; dailyRate: number;
  overtimeHours: number; overtimeRatePerHour: number;
  regularHolidayDays: number; specialHolidayDays: number;
  regularHolidayPct: number; specialHolidayPct: number;
  incentives: number; deductions: PayslipDeductions;
}
export interface PayslipComputed {
  hourlyRate: number; basePay: number; overtimePay: number; holidayPay: number;
  gross: number; totalDeductions: number; net: number;
}
export interface Employee {
  id: string; name: string; dailyRate: number; isActive: boolean;
  createdAt: Date | null; updatedAt: Date | null;
}
export interface HrSettings { weekStartDay: number; regularHolidayPct: number; specialHolidayPct: number }
export const DEFAULT_HR_SETTINGS: HrSettings = { weekStartDay: 1, regularHolidayPct: 100, specialHolidayPct: 30 };
export interface Payslip {
  id: string; employeeId: string; employeeName: string;
  periodStart: string; periodEnd: string; days: PayslipDay[];
  inputs: PayslipInputs; computed: PayslipComputed;
  createdAt: Date | null; createdBy: string | null; createdByName: string | null;
}
