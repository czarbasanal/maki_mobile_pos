import type {
  DocumentData,
  FirestoreDataConverter,
  QueryDocumentSnapshot,
} from 'firebase/firestore';
import type { Tag } from '@/domain/entities';
import { normalizeTagColor } from '@/domain/tags/tagColors';
import { requireDate, toDate } from './timestamps';

// Reads use this converter; writes go through the repository inline (so they
// can use serverTimestamp). toFirestore is required by the type but unused.
export const tagConverter: FirestoreDataConverter<Tag> = {
  toFirestore(t) {
    return {
      name: t.name,
      color: t.color,
      description: t.description,
      isActive: t.isActive,
      createdBy: t.createdBy,
      updatedBy: t.updatedBy,
    };
  },
  fromFirestore(snapshot: QueryDocumentSnapshot<DocumentData>): Tag {
    const d = snapshot.data();
    return {
      id: snapshot.id,
      name: d.name ?? '',
      color: normalizeTagColor(d.color),
      description: d.description ?? null,
      isActive: d.isActive ?? true,
      createdAt: requireDate(d.createdAt, 'createdAt'),
      updatedAt: toDate(d.updatedAt),
      createdBy: d.createdBy ?? null,
      updatedBy: d.updatedBy ?? null,
    };
  },
};
