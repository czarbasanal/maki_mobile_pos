import type {
  DocumentData,
  FirestoreDataConverter,
  QueryDocumentSnapshot,
} from 'firebase/firestore';
import type { Mechanic } from '@/domain/entities';
import { requireDate, toDate } from './timestamps';

// Reads use this converter; writes go through the repository inline (so they can
// use serverTimestamp). toFirestore is required by the type but unused on write.
export const mechanicConverter: FirestoreDataConverter<Mechanic> = {
  toFirestore(m) {
    return {
      name: m.name,
      isActive: m.isActive,
      createdBy: m.createdBy,
      updatedBy: m.updatedBy,
    };
  },
  fromFirestore(snapshot: QueryDocumentSnapshot<DocumentData>): Mechanic {
    const d = snapshot.data();
    return {
      id: snapshot.id,
      name: d.name ?? '',
      isActive: d.isActive ?? true,
      createdAt: requireDate(d.createdAt, 'createdAt'),
      updatedAt: toDate(d.updatedAt),
      createdBy: d.createdBy ?? null,
      updatedBy: d.updatedBy ?? null,
    };
  },
};
