import type {
  DocumentData,
  FirestoreDataConverter,
  QueryDocumentSnapshot,
} from 'firebase/firestore';
import type { Employee } from '@/domain/hr/types';
import { toDate } from './timestamps';

// Reads use this converter; writes go through the repository inline (so they can
// use serverTimestamp). toFirestore is required by the type but unused on write.
export const employeeConverter: FirestoreDataConverter<Employee> = {
  toFirestore(e) {
    return {
      name: e.name,
      dailyRate: e.dailyRate,
      isActive: e.isActive,
    };
  },
  fromFirestore(snapshot: QueryDocumentSnapshot<DocumentData>): Employee {
    const d = snapshot.data();
    return {
      id: snapshot.id,
      name: d.name ?? '',
      dailyRate: d.dailyRate ?? 0,
      isActive: d.isActive ?? true,
      createdAt: toDate(d.createdAt),
      updatedAt: toDate(d.updatedAt),
    };
  },
};
