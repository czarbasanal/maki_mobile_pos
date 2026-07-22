import type {
  DocumentData,
  FirestoreDataConverter,
  QueryDocumentSnapshot,
} from 'firebase/firestore';
import type { Employee, PayslipDefaults, PayslipDeductions } from '@/domain/hr/types';
import { toDate } from './timestamps';

// Tolerant parse of a raw `deductions` map (mirrors the payslip converter's
// leniency): every numeric field defaults to 0, `others` defaults to [].
function toPayslipDeductions(raw: unknown): PayslipDeductions {
  const d = (raw ?? {}) as Record<string, unknown>;
  const others = Array.isArray(d.others)
    ? d.others.map((o) => {
        const oo = (o ?? {}) as Record<string, unknown>;
        return { label: (oo.label as string) ?? '', amount: (oo.amount as number) ?? 0 };
      })
    : [];
  return {
    sss: (d.sss as number) ?? 0,
    philhealth: (d.philhealth as number) ?? 0,
    pagibig: (d.pagibig as number) ?? 0,
    late: (d.late as number) ?? 0,
    absences: (d.absences as number) ?? 0,
    cashAdvance: (d.cashAdvance as number) ?? 0,
    others,
  };
}

// Tolerant parse of the optional `payslipDefaults` map (Amendment 2): missing
// or explicit null both mean "no saved defaults"; a partial map fills in
// missing numeric fields as 0, missing `others` as [], and a missing/short
// `dayPattern` is passed through as-is (the consumer applies it positionally
// and leaves days beyond its length at their own default seed).
function toPayslipDefaults(raw: unknown): PayslipDefaults | null {
  if (raw == null || typeof raw !== 'object') return null;
  const d = raw as Record<string, unknown>;
  return {
    hoursWorked: (d.hoursWorked as number) ?? 0,
    overtimeHours: (d.overtimeHours as number) ?? 0,
    overtimeRatePerHour: (d.overtimeRatePerHour as number) ?? 0,
    regularHolidayDays: (d.regularHolidayDays as number) ?? 0,
    specialHolidayDays: (d.specialHolidayDays as number) ?? 0,
    incentives: (d.incentives as number) ?? 0,
    deductions: toPayslipDeductions(d.deductions),
    dayPattern: Array.isArray(d.dayPattern) ? (d.dayPattern as PayslipDefaults['dayPattern']) : [],
  };
}

// Reads use this converter; writes go through the repository inline (so they can
// use serverTimestamp). toFirestore is required by the type but unused on write.
export const employeeConverter: FirestoreDataConverter<Employee> = {
  toFirestore(e) {
    return {
      name: e.name,
      dailyRate: e.dailyRate,
      isActive: e.isActive,
      weekStartDay: e.weekStartDay,
      payslipDefaults: e.payslipDefaults,
    };
  },
  fromFirestore(snapshot: QueryDocumentSnapshot<DocumentData>): Employee {
    const d = snapshot.data();
    return {
      id: snapshot.id,
      name: d.name ?? '',
      dailyRate: d.dailyRate ?? 0,
      isActive: d.isActive ?? true,
      // Missing or explicit null both mean "use settings/hr.weekStartDay".
      weekStartDay: d.weekStartDay ?? null,
      payslipDefaults: toPayslipDefaults(d.payslipDefaults),
      createdAt: toDate(d.createdAt),
      updatedAt: toDate(d.updatedAt),
    };
  },
};
