import type {
  DocumentData,
  FirestoreDataConverter,
  QueryDocumentSnapshot,
} from 'firebase/firestore';
import type { AdjustmentReason } from '@/domain/entities';
import { requireDate, toDate } from './timestamps';

// Reads use this converter; writes go through the repository inline (so they
// can use serverTimestamp). toFirestore is required by the type but unused.
export const adjustmentReasonConverter: FirestoreDataConverter<AdjustmentReason> = {
  toFirestore(ar) {
    return {
      name: ar.name,
      requiresNote: ar.requiresNote,
      isActive: ar.isActive,
      createdBy: ar.createdBy,
      updatedBy: ar.updatedBy,
    };
  },
  fromFirestore(snapshot: QueryDocumentSnapshot<DocumentData>): AdjustmentReason {
    const d = snapshot.data();
    return {
      id: snapshot.id,
      name: d.name ?? '',
      requiresNote: d.requiresNote ?? false,
      isActive: d.isActive ?? true,
      createdAt: requireDate(d.createdAt, 'createdAt'),
      updatedAt: toDate(d.updatedAt),
      createdBy: d.createdBy ?? null,
      updatedBy: d.updatedBy ?? null,
    };
  },
};
