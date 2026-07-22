import type {
  DocumentData,
  FirestoreDataConverter,
  QueryDocumentSnapshot,
} from 'firebase/firestore';
import type { Payslip, PayslipDay, PayslipInputs } from '@/domain/hr/types';
import { toDate } from './timestamps';

// A payslip is a frozen snapshot generated once by the payroll form — inputs
// and computed are stored (and read back) verbatim as nested maps, so this
// converter does not re-derive individual sub-fields. The only tolerance is
// for documents written before a field existed: a missing `others` array
// (nested under inputs.deductions) or a missing top-level `days` array both
// default to `[]`.
export const payslipConverter: FirestoreDataConverter<Payslip> = {
  toFirestore(p) {
    return {
      employeeId: p.employeeId,
      employeeName: p.employeeName,
      periodStart: p.periodStart,
      periodEnd: p.periodEnd,
      days: p.days,
      inputs: p.inputs,
      computed: p.computed,
      createdBy: p.createdBy,
      createdByName: p.createdByName,
    };
  },
  fromFirestore(snapshot: QueryDocumentSnapshot<DocumentData>): Payslip {
    const d = snapshot.data();
    const inputs = (d.inputs ?? {}) as PayslipInputs;
    const deductions = inputs.deductions ?? ({} as PayslipInputs['deductions']);
    return {
      id: snapshot.id,
      employeeId: d.employeeId ?? '',
      employeeName: d.employeeName ?? '',
      periodStart: d.periodStart ?? '',
      periodEnd: d.periodEnd ?? '',
      days: (d.days ?? []) as PayslipDay[],
      inputs: {
        ...inputs,
        deductions: {
          ...deductions,
          others: deductions.others ?? [],
        },
      },
      computed: d.computed,
      createdAt: toDate(d.createdAt),
      createdBy: d.createdBy ?? null,
      createdByName: d.createdByName ?? null,
    };
  },
};
