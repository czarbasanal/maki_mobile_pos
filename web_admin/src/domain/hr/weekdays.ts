// Shared ISO weekday list (1=Monday..7=Sunday) used by every "week starts
// on" control in the HR module (HrSettingsPage, EmployeesPage, PayrollPage)
// so the value/label pairs can't drift between them.

export interface Weekday {
  value: number;
  label: string;
}

export const WEEKDAYS: Weekday[] = [
  { value: 1, label: 'Monday' },
  { value: 2, label: 'Tuesday' },
  { value: 3, label: 'Wednesday' },
  { value: 4, label: 'Thursday' },
  { value: 5, label: 'Friday' },
  { value: 6, label: 'Saturday' },
  { value: 7, label: 'Sunday' },
];

export function weekdayLabel(day: number): string {
  return WEEKDAYS.find((w) => w.value === day)?.label ?? '';
}
