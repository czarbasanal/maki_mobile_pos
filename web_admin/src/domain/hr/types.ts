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
// One saved "profile" of payslip-form values per employee, auto-applied when
// picked on the payroll form (Amendment 2). Holiday PERCENTAGES are excluded
// on purpose — those stay settings-seeded, not per-employee.
export interface PayslipDefaults {
  hoursWorked: number; overtimeHours: number; overtimeRatePerHour: number;
  regularHolidayDays: number; specialHolidayDays: number; incentives: number;
  deductions: PayslipDeductions;
  // Positional: index 0 = the employee's effective week-start day. Applied
  // onto whatever period is on screen when loaded (index i -> period.dates[i]).
  dayPattern: DayStatus[];
}
export interface Employee {
  id: string; name: string; dailyRate: number; isActive: boolean;
  // ISO 1-7 (1=Mon..7=Sun); null = use settings/hr.weekStartDay.
  weekStartDay: number | null;
  payslipDefaults: PayslipDefaults | null;
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
