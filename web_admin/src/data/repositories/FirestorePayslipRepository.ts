import {
  addDoc,
  collection,
  deleteDoc,
  doc,
  getDoc,
  onSnapshot,
  serverTimestamp,
  type Firestore,
} from 'firebase/firestore';
import type { PayslipRepository } from '@/domain/repositories/PayslipRepository';
import type { Unsubscribe } from '@/domain/repositories/AuthRepository';
import type { Payslip } from '@/domain/hr/types';
import { payslipConverter } from '@/data/converters/payslipConverter';
import { FirestoreCollections } from '@/infrastructure/firebase/collections';

// `payslips` is a collection of frozen, immutable snapshots — read the whole
// list and sort client-side (periodStart desc, then employeeName), the same
// small-collection idiom used by FirestoreMechanicRepository.
export class FirestorePayslipRepository implements PayslipRepository {
  constructor(private readonly db: Firestore) {}

  private col() {
    return collection(this.db, FirestoreCollections.payslips).withConverter(payslipConverter);
  }

  private sort(items: Payslip[]): Payslip[] {
    return items.sort((a, b) => {
      const byPeriod = b.periodStart.localeCompare(a.periodStart);
      return byPeriod !== 0 ? byPeriod : a.employeeName.localeCompare(b.employeeName);
    });
  }

  watchAll(cb: (payslips: Payslip[]) => void, onError?: (err: Error) => void): Unsubscribe {
    return onSnapshot(
      this.col(),
      (snap) => {
        cb(this.sort(snap.docs.map((d) => d.data())));
      },
      onError,
    );
  }

  async getById(id: string): Promise<Payslip | null> {
    const snap = await getDoc(
      doc(this.db, FirestoreCollections.payslips, id).withConverter(payslipConverter),
    );
    return snap.exists() ? snap.data() : null;
  }

  async create(input: Omit<Payslip, 'id' | 'createdAt'>): Promise<string> {
    const ref = await addDoc(collection(this.db, FirestoreCollections.payslips), {
      employeeId: input.employeeId,
      employeeName: input.employeeName,
      periodStart: input.periodStart,
      periodEnd: input.periodEnd,
      days: input.days,
      inputs: input.inputs,
      computed: input.computed,
      createdBy: input.createdBy,
      createdByName: input.createdByName,
      createdAt: serverTimestamp(),
    });
    return ref.id;
  }

  async delete(id: string): Promise<void> {
    await deleteDoc(doc(this.db, FirestoreCollections.payslips, id));
  }
}
