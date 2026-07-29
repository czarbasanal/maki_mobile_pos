// Read-side implementation of ActivityLogRepository. Reads are one-shot:
// /admin/logs issues a single getDocs when the admin submits filters, so
// there is no snapshot listener here. log() is the write side, used by every
// web mutation hook through application/activityLogger.

import {
  addDoc,
  collection,
  getDocs,
  limit as fsLimit,
  orderBy,
  query,
  serverTimestamp,
  Timestamp,
  where,
  type Firestore,
  type QueryConstraint,
} from 'firebase/firestore';
import type {
  ActivityLogQuery,
  ActivityLogRepository,
} from '@/domain/repositories/ActivityLogRepository';
import { ALL_ACTIVITY_TYPES, type ActivityLog } from '@/domain/entities';
import { FirestoreCollections } from '@/infrastructure/firebase/collections';
import { activityLogConverter } from '@/data/converters/activityLogConverter';

export class FirestoreActivityLogRepository implements ActivityLogRepository {
  constructor(private readonly db: Firestore) {}

  private col() {
    return collection(this.db, FirestoreCollections.userLogs).withConverter(
      activityLogConverter,
    );
  }

  private constraints(q: ActivityLogQuery): QueryConstraint[] {
    const out: QueryConstraint[] = [];
    const types = q.types ?? [];
    // Every type selected is the same as none, and skipping the constraint
    // keeps the query off the type+createdAt composite index.
    if (types.length > 0 && types.length < ALL_ACTIVITY_TYPES.length) {
      out.push(where('type', 'in', types));
    }
    if (q.start) out.push(where('createdAt', '>=', Timestamp.fromDate(q.start)));
    if (q.end) out.push(where('createdAt', '<=', Timestamp.fromDate(q.end)));
    out.push(orderBy('createdAt', 'desc'));
    if (q.limit) out.push(fsLimit(q.limit));
    return out;
  }

  async list(q: ActivityLogQuery = {}): Promise<ActivityLog[]> {
    const snap = await getDocs(query(this.col(), ...this.constraints(q)));
    return snap.docs.map((d) => d.data());
  }

  async log(input: Omit<ActivityLog, 'id' | 'createdAt'>): Promise<void> {
    // Wired now — useful so any later mutation hook on the React side can
    // emit activity logs without another data-layer revision.
    await addDoc(this.col(), {
      ...input,
      createdAt: serverTimestamp(),
    } as unknown as ActivityLog);
  }
}
