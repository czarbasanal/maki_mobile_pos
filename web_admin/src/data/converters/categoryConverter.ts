import type {
  DocumentData,
  FirestoreDataConverter,
  QueryDocumentSnapshot,
} from 'firebase/firestore';
import type { Category } from '@/domain/entities';
import { requireDate, toDate } from './timestamps';

// Reads use this converter; writes go through the repository inline (so they can
// use serverTimestamp). toFirestore is required by the type but unused on the
// write path.
export const categoryConverter: FirestoreDataConverter<Category> = {
  toFirestore(c) {
    return {
      name: c.name,
      isActive: c.isActive,
      createdBy: c.createdBy,
      updatedBy: c.updatedBy,
    };
  },
  fromFirestore(snapshot: QueryDocumentSnapshot<DocumentData>): Category {
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
