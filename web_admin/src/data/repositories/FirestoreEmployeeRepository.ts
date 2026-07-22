import {
  addDoc,
  collection,
  doc,
  getDoc,
  onSnapshot,
  serverTimestamp,
  updateDoc,
  type Firestore,
} from 'firebase/firestore';
import type {
  EmployeeCreateInput,
  EmployeeRepository,
  EmployeeUpdateInput,
} from '@/domain/repositories/EmployeeRepository';
import type { Unsubscribe } from '@/domain/repositories/AuthRepository';
import type { Employee } from '@/domain/hr/types';
import { employeeConverter } from '@/data/converters/employeeConverter';
import { FirestoreCollections } from '@/infrastructure/firebase/collections';

// `employees` is a small collection — read the whole list and filter/sort
// client-side (no composite index), mirroring FirestoreMechanicRepository.
export class FirestoreEmployeeRepository implements EmployeeRepository {
  constructor(private readonly db: Firestore) {}

  private col() {
    return collection(this.db, FirestoreCollections.employees).withConverter(employeeConverter);
  }

  private shape(items: Employee[], includeInactive: boolean): Employee[] {
    const out = includeInactive ? items : items.filter((e) => e.isActive);
    return out.sort((a, b) => a.name.localeCompare(b.name));
  }

  watchAll(
    cb: (employees: Employee[]) => void,
    opts?: { includeInactive?: boolean },
    onError?: (err: Error) => void,
  ): Unsubscribe {
    return onSnapshot(
      this.col(),
      (snap) => {
        cb(this.shape(snap.docs.map((d) => d.data()), opts?.includeInactive ?? false));
      },
      onError,
    );
  }

  async create(input: EmployeeCreateInput): Promise<Employee> {
    const ref = await addDoc(collection(this.db, FirestoreCollections.employees), {
      name: input.name,
      dailyRate: input.dailyRate,
      isActive: true,
      createdAt: serverTimestamp(),
      updatedAt: serverTimestamp(),
    });
    const snap = await getDoc(ref.withConverter(employeeConverter));
    const created = snap.data();
    if (!created) throw new Error('Failed to load the created employee');
    return created;
  }

  async update(id: string, input: EmployeeUpdateInput): Promise<void> {
    const data: Record<string, unknown> = {
      updatedAt: serverTimestamp(),
    };
    if (input.name !== undefined) data.name = input.name;
    if (input.dailyRate !== undefined) data.dailyRate = input.dailyRate;
    if (input.isActive !== undefined) data.isActive = input.isActive;
    await updateDoc(doc(this.db, FirestoreCollections.employees, id), data);
  }
}
